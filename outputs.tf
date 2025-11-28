# ============================================
# Network Outputs
# ============================================

output "network_id" {
  description = "ID of the private network"
  value       = module.network.network_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = module.network.subnet_id
}

output "firewall_id" {
  description = "ID of the firewall"
  value       = module.network.firewall_id
}

# ============================================
# K3s Control Plane Outputs
# ============================================

output "k3s_control_public_ip" {
  description = "Public IPv4 address of K3s control plane (same as Primary IP)"
  value       = module.k3s_control.ipv4_address
}

output "k3s_control_private_ip" {
  description = "Private IP address of K3s control plane"
  value       = module.k3s_control.private_ip
}

output "k3s_control_server_id" {
  description = "Server ID of K3s control plane"
  value       = module.k3s_control.server_id
}

# ============================================
# Kafka Server Outputs
# ============================================

output "kafka_0_public_ip" {
  description = "Public IPv4 address of kafka-0 (external access via NodePort)"
  value       = length(module.kafka_server) > 0 ? module.kafka_server[0].ipv4_address : null
}

output "kafka_server_public_ips" {
  description = "Public IPv4 addresses of Kafka servers (only kafka-0 has public IP)"
  value       = [for server in module.kafka_server : server.ipv4_address]
}

output "kafka_server_private_ips" {
  description = "Private IP addresses of Kafka servers"
  value       = [for server in module.kafka_server : server.private_ip]
}

output "kafka_server_ids" {
  description = "Server IDs of Kafka servers"
  value       = [for server in module.kafka_server : server.server_id]
}

# ============================================
# Access Information
# ============================================

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig from K3s control plane"
  value       = "ssh root@${module.k3s_control.ipv4_address} cat /etc/rancher/k3s/k3s.yaml"
}

output "ssh_access" {
  description = "SSH access information"
  value = {
    k3s_control = "ssh root@${module.k3s_control.ipv4_address}"
    kafka_nodes = [for ip in module.kafka_server : "ssh root@${ip.ipv4_address}"]
  }
}

# ============================================
# Cluster Summary
# ============================================

output "cluster_summary" {
  description = "Summary of deployed cluster"
  value = {
    environment        = var.environment
    cluster_name       = var.cluster_name
    location           = var.location
    network_cidr       = var.network_cidr
    k3s_version        = var.k3s_version
    kafka_node_count   = var.kafka_node_count
    control_plane_type = var.control_plane_server_type
    kafka_server_type  = var.kafka_server_type
  }
}
