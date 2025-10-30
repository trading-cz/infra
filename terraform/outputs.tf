output "control_plane_ip" {
  description = "Public IP of the control plane server"
  value       = hcloud_server.control_plane.ipv4_address
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane server"
  value       = element([for n in hcloud_server.control_plane.network : n.ip], 0)
}

output "kafka_nodes_public_ips" {
  description = "Public IPs of Kafka nodes"
  value       = hcloud_server.kafka_nodes[*].ipv4_address
}

output "kafka_nodes_private_ips" {
  description = "Private IPs of Kafka nodes"
  value       = [for s in hcloud_server.kafka_nodes : element([for n in s.network : n.ip], 0)]
}

output "k3s_token" {
  description = "K3s cluster token"
  value       = local.k3s_token
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${hcloud_server.control_plane.ipv4_address}:6443"
}

output "ssh_command_control" {
  description = "SSH command to connect to control plane"
  value       = "ssh root@${hcloud_server.control_plane.ipv4_address}"
}

output "ssh_command_kafka_nodes" {
  description = "SSH commands to connect to Kafka nodes"
  value       = [for node in hcloud_server.kafka_nodes : "ssh root@${node.ipv4_address}"]
}

output "network_id" {
  description = "ID of the private network"
  value       = hcloud_network.private.id
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
