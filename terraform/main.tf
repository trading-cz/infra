provider "hcloud" {
  token = var.hcloud_token
}

module "k3s" {
  source                     = "./modules/k3s"
  environment                = var.environment
  cluster_name                = var.cluster_name
  k3s_token                  = var.k3s_token
  control_plane_name          = "${var.cluster_name}-${var.environment}-control"
  control_plane_server_type   = var.control_plane_server_type
  control_plane_ip            = "10.0.1.10"
  control_plane_user_data     = templatefile("${path.module}/templates/control-plane-init.sh", {
    k3s_version = var.k3s_version
    k3s_token   = var.k3s_token
    node_ip     = "10.0.1.10"
    environment = var.environment
  })
  worker_user_data            = templatefile("${path.module}/templates/worker-init.sh", {
    k3s_version    = var.k3s_version
    k3s_token      = var.k3s_token
    k3s_url        = "https://10.0.1.10:6443"
    node_ip        = "10.0.1.20"
    node_label     = "node-role.kubernetes.io/kafka=true"
  })
  network_id                  = module.network.network_id
  firewall_id                 = module.network.firewall_id
  ssh_key_id                  = module.compute.ssh_key_id
  location                    = var.location
  kafka_node_count            = var.kafka_node_count
  kafka_server_type           = var.kafka_server_type
  labels                      = {
    environment = var.environment
    managed_by  = "terraform"
    cluster     = var.cluster_name
  }
}


module "network" {
  source           = "./modules/network"
  hcloud_token     = var.hcloud_token
  network_name     = "${var.cluster_name}-${var.environment}-network"
  network_ip_range = var.network_ip_range
  network_zone     = var.network_zone
  subnet_ip_range  = var.subnet_ip_range
  firewall_name    = "${var.cluster_name}-${var.environment}-firewall"
  firewall_rules   = [
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "22"
      source_ips  = ["0.0.0.0/0", "::/0"]
      description = "Allow SSH"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "6443"
      source_ips  = ["0.0.0.0/0", "::/0"]
      description = "Allow Kubernetes API"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "80"
      source_ips  = ["0.0.0.0/0", "::/0"]
      description = "Allow HTTP"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "443"
      source_ips  = ["0.0.0.0/0", "::/0"]
      description = "Allow HTTPS"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "30000-32767"
      source_ips  = ["0.0.0.0/0", "::/0"]
      description = "Allow NodePort range"
    },
    {
      direction   = "in"
      protocol    = "icmp"
      port        = null
      source_ips  = ["0.0.0.0/0", "::/0"]
      description = "Allow ICMP"
    }
  ]
  common_labels    = {
    environment = var.environment
    managed_by  = "terraform"
    cluster     = var.cluster_name
  }
}


module "compute" {
  source           = "./modules/compute"
  hcloud_token     = var.hcloud_token
  ssh_key_name     = "${var.cluster_name}-${var.environment}"
  ssh_public_key   = var.ssh_public_key
  common_labels    = {
    environment = var.environment
    managed_by  = "terraform"
    cluster     = var.cluster_name
  }
  network_id       = module.network.network_id
  firewall_id      = module.network.firewall_id
}

module "kafka" {
  source           = "./modules/kafka"
}

