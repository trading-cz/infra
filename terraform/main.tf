provider "hcloud" {
  token = var.hcloud_token
}

# Generate random K3s token
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

locals {
  environment  = var.environment
  k3s_token    = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token.result
  
  # Common labels
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    cluster     = var.cluster_name
  }
}

# SSH Key
resource "hcloud_ssh_key" "default" {
  name       = "${var.cluster_name}-${var.environment}"
  public_key = var.ssh_public_key
  labels     = local.common_labels
}

# Private Network
resource "hcloud_network" "private" {
  name     = "${var.cluster_name}-${var.environment}-network"
  ip_range = var.network_ip_range
  labels   = local.common_labels
}

resource "hcloud_network_subnet" "private" {
  network_id   = hcloud_network.private.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_ip_range
}

# Firewall
resource "hcloud_firewall" "k3s" {
  name   = "${var.cluster_name}-${var.environment}-firewall"
  labels = local.common_labels

  # SSH access
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Allow SSH"
  }

  # Kubernetes API
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Allow Kubernetes API"
  }

  # HTTP/HTTPS for ingress
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Allow HTTP"
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Allow HTTPS"
  }

  # Kafka external access (NodePort range)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "30000-32767"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Allow NodePort range"
  }

  # ICMP
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Allow ICMP"
  }
}

# K3s Control Plane Server
resource "hcloud_server" "control_plane" {
  name        = "${var.cluster_name}-${var.environment}-control"
  server_type = var.control_plane_server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s.id]
  
  labels = merge(local.common_labels, {
    role = "control-plane"
    node_type = "master"
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private.id
    ip         = "10.0.1.10"
  }

  depends_on = [
    hcloud_network_subnet.private
  ]

  # User data for K3s installation
  user_data = templatefile("${path.module}/templates/control-plane-init.sh", {
    k3s_version = var.k3s_version
    k3s_token   = local.k3s_token
    node_ip     = "10.0.1.10"
  })
}

# Kafka Worker Nodes
resource "hcloud_server" "kafka_nodes" {
  count = var.kafka_node_count

  name        = "${var.cluster_name}-${var.environment}-kafka-${count.index}"
  server_type = var.kafka_server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s.id]

  labels = merge(local.common_labels, {
    role      = "kafka"
    node_type = "worker"
    kafka_id  = tostring(count.index)
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private.id
    ip         = "10.0.1.${20 + count.index}"
  }

  depends_on = [
    hcloud_network_subnet.private,
    hcloud_server.control_plane
  ]

  # User data for K3s agent installation
  user_data = templatefile("${path.module}/templates/worker-init.sh", {
    k3s_version    = var.k3s_version
    k3s_token      = local.k3s_token
    k3s_url        = "https://${hcloud_server.control_plane.network[0].ip}:6443"
    node_ip        = "10.0.1.${20 + count.index}"
    node_label     = "node-role.kubernetes.io/kafka=true"
  })
}

# Wait for K3s to be ready
resource "null_resource" "wait_for_k3s" {
  depends_on = [
    hcloud_server.control_plane,
    hcloud_server.kafka_nodes
  ]

  provisioner "local-exec" {
    command = "sleep 60"
  }
}

