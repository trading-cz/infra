terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.54.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

// K3s module: main.tf
// This module provisions the K3s control plane and worker nodes

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

locals {
  k3s_token = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token.result
}

resource "hcloud_server" "control_plane" {
  name        = var.control_plane_name
  server_type = var.control_plane_server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = [var.ssh_key_id]
  firewall_ids = [var.firewall_id]

  labels = var.labels

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = var.network_id
    ip         = var.control_plane_ip
  }

  user_data = var.control_plane_user_data
}

resource "hcloud_server" "kafka_nodes" {
  count = var.kafka_node_count

  name        = "${var.cluster_name}-${var.environment}-kafka-${count.index}"
  server_type = var.kafka_server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = [var.ssh_key_id]
  firewall_ids = [var.firewall_id]

  labels = var.labels

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = var.network_id
    ip         = "10.0.1.${20 + count.index}"
  }

  user_data = var.worker_user_data
}

resource "null_resource" "wait_for_k3s" {
  depends_on = [
    hcloud_server.control_plane,
    hcloud_server.kafka_nodes
  ]

  provisioner "local-exec" {
    command = "sleep 60"
  }
}
