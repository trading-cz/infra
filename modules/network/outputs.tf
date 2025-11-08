output "network_id" {
  description = "ID of the created network"
  value       = hcloud_network.main.id
}

output "subnet_id" {
  description = "ID of the created subnet"
  value       = hcloud_network_subnet.subnet.id
}

output "firewall_id" {
  description = "ID of the created firewall"
  value       = hcloud_firewall.main.id
}
