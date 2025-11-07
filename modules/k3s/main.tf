terraform {
  required_version = ">= 1.13.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.54.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

// K3s module: main.tf
// This module provisions the K3s control plane and worker nodes

resource "hcloud_server" "control_plane" {
  name        = var.control_plane_name
  server_type = var.control_plane_server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = [var.ssh_key_id]
  # Enable firewall for security
  firewall_ids = [var.firewall_id]

  labels = var.labels

  public_net {
    ipv4_enabled = true
    ipv4         = var.control_plane_primary_ip_id # Attach Primary IP #1
    ipv6_enabled = false                           # IPv6 not needed - using private network for internal comms
  }

  network {
    network_id = var.network_id
    ip         = var.control_plane_ip
  }

  user_data = var.control_plane_user_data
}

resource "hcloud_server" "kafka_nodes" {
  count = var.kafka_node_count

  name        = "${var.cluster_name}-${var.environment}-kafka-${count.index}"
  server_type = var.kafka_server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = [var.ssh_key_id]
  # All kafka nodes get firewall (kafka-0 has public IP for external Kafka access)
  firewall_ids = [var.firewall_id]

  labels = var.labels

  public_net {
    # kafka-0: Gets Primary IP #2 (persistent, €1/month)
    # kafka-1, kafka-2: Get ephemeral IPs (€0 if destroyed < 1 hour, ~€0.005/hour otherwise)
    # All nodes need internet to download K3s installer
    ipv4_enabled = true
    ipv4         = count.index == 0 ? var.kafka_primary_ip_id : null
    ipv6_enabled = false
  }

  network {
    network_id = var.network_id
    ip         = "10.0.1.${20 + count.index}"
  }

  # Generate user_data with correct node IP for each kafka node
  user_data = templatefile("${path.root}/templates/worker-init.sh", {
    k3s_version = var.k3s_version
    k3s_token   = var.k3s_token
    k3s_url     = "https://${var.control_plane_ip}:6443"
    node_ip     = "10.0.1.${20 + count.index}"
    node_label  = "node-role.kubernetes.io/kafka=true"
  })
}

resource "hcloud_server" "app_nodes" {
  count = var.app_node_count

  name         = "${var.cluster_name}-${var.environment}-app-${count.index}"
  server_type  = var.app_server_type
  image        = "ubuntu-24.04"
  location     = var.location
  ssh_keys     = [var.ssh_key_id]
  firewall_ids = [var.firewall_id]

  labels = merge(
    var.labels,
    {
      "node-role" = "app"
    }
  )

  public_net {
    # No public IP - app nodes are private only
    ipv4_enabled = false
    ipv6_enabled = false
  }

  network {
    network_id = var.network_id
    ip         = "10.0.1.${30 + count.index}"
  }

  user_data = var.app_user_data
}

resource "null_resource" "wait_for_k3s" {
  depends_on = [
    hcloud_server.control_plane,
    hcloud_server.kafka_nodes,
    hcloud_server.app_nodes
  ]

  provisioner "local-exec" {
    command = "sleep 60"
  }
}
