output "server_id" {
  description = "ID of the Kafka server"
  value       = hcloud_server.kafka.id
}

output "ipv4_address" {
  description = "Public IPv4 address of the Kafka server"
  value       = hcloud_server.kafka.ipv4_address
}

output "ipv6_address" {
  description = "Public IPv6 address of the Kafka server"
  value       = hcloud_server.kafka.ipv6_address
}

output "private_ip" {
  description = "Private IP address of the Kafka server"
  value       = try(one(hcloud_server.kafka.network).ip, null)
}
