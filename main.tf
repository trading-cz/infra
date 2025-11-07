provider "hcloud" {
  token = var.hcloud_token
}

# Generate K3s token if not provided
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

locals {
  k3s_token = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token.result
}

module "k3s" {
  source                      = "./modules/k3s"
  environment                 = var.environment
  cluster_name                = var.cluster_name
  k3s_version                 = var.k3s_version
  k3s_token                   = local.k3s_token
  control_plane_name          = "${var.cluster_name}-${var.environment}-control"
  control_plane_server_type   = var.control_plane_server_type
  control_plane_ip            = "10.0.1.10"
  control_plane_primary_ip_id = module.network.control_plane_primary_ip_id # Attach Primary IP #1
  control_plane_user_data = templatefile("${path.module}/templates/control-plane-init.sh", {
    k3s_version  = var.k3s_version
    k3s_token    = local.k3s_token
    node_ip      = "10.0.1.10"
    environment  = var.environment
    cluster_name = var.cluster_name
    public_ip    = module.network.control_plane_primary_ip_address # Pass public IP for TLS cert
    argocd_parent_app = templatefile("${path.module}/argocd/parent-app-bootstrap.yaml.tpl", {
      environment     = var.environment
      config_repo_url = var.config_repo_url
      target_revision = var.environment == "dev" ? "main" : "production"
    })
  })
  network_id        = module.network.network_id
  firewall_id       = module.network.firewall_id
  ssh_key_id        = module.compute.ssh_key_id
  location          = var.location
  kafka_node_count  = var.kafka_node_count
  kafka_server_type = var.kafka_server_type
  app_node_count    = var.app_node_count
  app_server_type   = var.app_server_type
  labels = {
    environment = var.environment
    managed_by  = "terraform"
    cluster     = var.cluster_name
  }
}


module "network" {
  source           = "./modules/network"
  network_name     = "${var.cluster_name}-${var.environment}-network"
  network_ip_range = var.network_ip_range
  network_zone     = var.network_zone
  subnet_ip_range  = var.subnet_ip_range
  firewall_name    = "${var.cluster_name}-${var.environment}-firewall"
  datacenter       = var.datacenter # Required for Primary IPs
  firewall_rules = [
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "22"
      source_ips  = ["0.0.0.0/0"]
      description = "Allow SSH"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "6443"
      source_ips  = ["0.0.0.0/0"]
      description = "Allow Kubernetes API (external)"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "6443"
      source_ips  = ["10.0.1.0/24"]
      description = "Allow Kubernetes API (internal network)"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "10250"
      source_ips  = ["10.0.1.0/24"]
      description = "Allow Kubelet (internal nodes)"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "2379-2380"
      source_ips  = ["10.0.1.0/24"]
      description = "Allow etcd (internal)"
    },
    {
      direction   = "in"
      protocol    = "udp"
      port        = "8472"
      source_ips  = ["10.0.1.0/24"]
      description = "Allow Flannel VXLAN (K3s CNI)"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "80"
      source_ips  = ["0.0.0.0/0"]
      description = "Allow HTTP"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "443"
      source_ips  = ["0.0.0.0/0"]
      description = "Allow HTTPS"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "9092-9094"
      source_ips  = ["0.0.0.0/0"]
      description = "Allow Kafka"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "30000-32767"
      source_ips  = ["0.0.0.0/0"]
      description = "Allow NodePort range"
    },
    {
      direction   = "in"
      protocol    = "icmp"
      port        = null
      source_ips  = ["0.0.0.0/0"]
      description = "Allow ICMP"
    }
  ]
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    cluster     = var.cluster_name
  }
}


module "compute" {
  source         = "./modules/compute"
  ssh_key_name   = "${var.cluster_name}-${var.environment}"
  ssh_public_key = var.ssh_public_key
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    cluster     = var.cluster_name
  }
}

