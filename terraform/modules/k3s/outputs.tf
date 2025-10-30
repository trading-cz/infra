output "control_plane_id" {
  description = "ID of the K3s control plane server"
  value       = hcloud_server.control_plane.id
}

output "control_plane_ip" {
  description = "IP of the K3s control plane server"
  value       = [for n in hcloud_server.control_plane.network : n.ip][0]
}

output "kafka_node_ids" {
  description = "IDs of the Kafka worker nodes"
  value       = [for n in hcloud_server.kafka_nodes : n.id]
}

output "kafka_node_ips" {
  description = "IPs of the Kafka worker nodes"
  value       = [for s in hcloud_server.kafka_nodes : [for n in s.network : n.ip][0]]
}
