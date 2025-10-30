output "network_id" {
  value = hcloud_network.private.id
}

output "firewall_id" {
  value = hcloud_firewall.k3s.id
}
