
output "control_plane_ip" {
  description = "IP of the K3s control plane server"
  value       = module.k3s.control_plane_ip
}

output "kafka_nodes_private_ips" {
  description = "Private IPs of Kafka nodes"
  value       = module.k3s.kafka_node_ips
}

output "network_id" {
  description = "ID of the private network"
  value       = module.network.network_id
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
