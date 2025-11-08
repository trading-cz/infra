output "server_id" {
  description = "ID of the K3s server"
  value       = hcloud_server.k3s.id
}

output "ipv4_address" {
  description = "Public IPv4 address of the K3s server"
  value       = hcloud_server.k3s.ipv4_address
}

output "ipv6_address" {
  description = "Public IPv6 address of the K3s server"
  value       = hcloud_server.k3s.ipv6_address
}

output "private_ip" {
  description = "Private IP address of the K3s server"
  value       = try(one(hcloud_server.k3s.network).ip, null)
}
