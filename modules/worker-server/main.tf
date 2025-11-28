# Worker server module
# Creates a Hetzner Cloud server for running Python applications/strategies
# Joins K3s cluster as an agent node with label role=worker

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

resource "hcloud_server" "worker" {
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
    # Worker nodes need public IP for internet access during cloud-init
    # No Primary IP needed - ephemeral is fine for workers
    ipv4_enabled = true
    ipv6_enabled = false
  }

  labels = var.labels

  # Ensure subnet exists before creating server
  depends_on = [var.subnet_id]
}
