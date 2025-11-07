output "network_id" {
  value = hcloud_network.private.id
}

output "firewall_id" {
  value = hcloud_firewall.k3s.id
}

output "control_plane_primary_ip_id" {
  description = "ID of the control plane primary IP"
  value       = hcloud_primary_ip.control_plane.id
}

output "control_plane_primary_ip_address" {
  description = "Address of the control plane primary IP"
  value       = hcloud_primary_ip.control_plane.ip_address
}

output "kafka_external_primary_ip_id" {
  description = "ID of the Kafka external primary IP"
  value       = hcloud_primary_ip.kafka_external.id
}

output "kafka_external_primary_ip_address" {
  description = "Address of the Kafka external primary IP"
  value       = hcloud_primary_ip.kafka_external.ip_address
}
