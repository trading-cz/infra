
output "control_plane_ip" {
  description = "Public IPv4 of control plane (Primary IP #1 - persistent)"
  value       = module.network.control_plane_primary_ip_address
}

output "control_plane_private_ip" {
  description = "Private IP of control plane (internal network)"
  value       = module.k3s.control_plane_private_ip
}

output "kafka_external_ip" {
  description = "Public IPv4 for Kafka (Primary IP #2 - persistent)"
  value       = module.network.kafka_external_primary_ip_address
}

output "kafka_external_primary_ip_id" {
  description = "ID of Kafka external Primary IP (for GitHub Actions assignment)"
  value       = module.network.kafka_external_primary_ip_id
}

output "kafka_node_0_id" {
  description = "Server ID of kafka-0 (for Primary IP assignment by GitHub Actions)"
  value       = module.k3s.kafka_node_0_id
}

output "kafka_nodes_private_ips" {
  description = "Private IPs of Kafka nodes"
  value       = module.k3s.kafka_node_ips
}

output "app_nodes_private_ips" {
  description = "Private IPs of application worker nodes"
  value       = module.k3s.app_node_ips
}

output "network_id" {
  description = "ID of the private network"
  value       = module.network.network_id
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
