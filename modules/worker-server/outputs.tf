output "server_id" {
  description = "ID of the worker server"
  value       = hcloud_server.worker.id
}

output "ipv4_address" {
  description = "Public IPv4 address of the worker server"
  value       = hcloud_server.worker.ipv4_address
}

output "private_ip" {
  description = "Private IP address of the worker server"
  value       = try(one(hcloud_server.worker.network).ip, null)
}
