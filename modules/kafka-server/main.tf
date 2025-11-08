# Kafka server module
# Creates a Hetzner Cloud server reserved for future Kafka/Strimzi workloads

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

resource "hcloud_server" "kafka" {
  name        = var.server_name
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = var.ssh_key_ids
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    k3s_server_ip = var.k3s_server_ip
  })

  network {
    network_id = var.network_id
    ip         = var.private_ip
  }

  firewall_ids = var.firewall_ids

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
    ipv4         = var.primary_ipv4_id # Attach persistent Primary IP (only for kafka-0)
  }

  labels = var.labels

  # Ensure subnet exists before creating server
  depends_on = [var.subnet_id]
}
