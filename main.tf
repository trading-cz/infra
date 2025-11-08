# K3s Trading Infrastructure - Root Module
# Single source of truth for both dev and prod environments
# Use: terraform apply -var-file="environments/dev.tfvars"
# GitHub Actions: Set TF_VAR_hcloud_token, TF_VAR_ssh_public_key env vars

provider "hcloud" {
  token = var.hcloud_token
}

# SSH Key for all servers
resource "hcloud_ssh_key" "main" {
  name       = "${var.environment}-${var.cluster_name}-ssh-key"
  public_key = var.ssh_public_key

  labels = {
    environment = var.environment
    cluster     = var.cluster_name
  }
}

# ============================================
# Primary IPs - Managed by GitHub Actions
# ============================================
# Primary IPs are created in GitHub Actions workflow BEFORE Terraform runs
# Terraform only receives the IP IDs as variables and assigns them to servers
# This avoids chicken-egg problems with IP assignment during server creation

# Network Module - Private VPC
module "network" {
  source = "./modules/network"

  network_name  = "${var.environment}-${var.cluster_name}-net"
  network_cidr  = var.network_cidr
  subnet_cidr   = var.subnet_cidr
  firewall_name = "${var.environment}-${var.cluster_name}-fw"

  labels = {
    environment = var.environment
    cluster     = var.cluster_name
  }
}

# K3s Control Plane Server
# Primary IP assigned during creation (no reboot needed)
module "k3s_control" {
  source = "./modules/k3s-server"

  server_name     = "${var.environment}-${var.cluster_name}-control"
  server_type     = var.control_plane_server_type
  location        = var.location
  ssh_key_ids     = [hcloud_ssh_key.main.id]
  network_id      = module.network.network_id
  subnet_id       = module.network.subnet_id
  firewall_ids    = [module.network.firewall_id]
  private_ip      = var.control_plane_private_ip
  primary_ipv4_id = var.control_plane_primary_ip_id != "" ? var.control_plane_primary_ip_id : null

  labels = {
    environment = var.environment
    cluster     = var.cluster_name
    role        = "control-plane"
  }
}

# Kafka Server(s)
# Only kafka-0 gets Primary IP for external access
module "kafka_server" {
  source = "./modules/kafka-server"
  count  = var.kafka_node_count

  server_name     = "${var.environment}-${var.cluster_name}-kafka-${count.index}"
  server_type     = var.kafka_server_type
  location        = var.location
  ssh_key_ids     = [hcloud_ssh_key.main.id]
  network_id      = module.network.network_id
  subnet_id       = module.network.subnet_id
  firewall_ids    = [module.network.firewall_id]
  private_ip      = cidrhost(var.subnet_cidr, 20 + count.index) # 10.0.1.20, 10.0.1.21, etc.
  primary_ipv4_id = count.index == 0 && var.kafka_primary_ip_id != "" ? var.kafka_primary_ip_id : null
  k3s_server_ip   = var.control_plane_private_ip # Control plane private IP for K3s agent join

  labels = {
    environment = var.environment
    cluster     = var.cluster_name
    role        = "kafka"
    kafka_id    = tostring(count.index)
  }
}
