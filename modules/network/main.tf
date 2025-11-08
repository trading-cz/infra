# Network module for Hetzner Cloud infrastructure
# Creates VPC, subnet, and firewall rules

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

resource "hcloud_network" "main" {
  name     = var.network_name
  ip_range = var.network_cidr
  
  labels = var.labels
}

resource "hcloud_network_subnet" "subnet" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central" # Hardcoded: all Hetzner locations (nbg1, fsn1, hel1) are in eu-central zone
  ip_range     = var.subnet_cidr
}

resource "hcloud_firewall" "main" {
  name   = var.firewall_name
  labels = var.labels

  # SSH access
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Kubernetes API access
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS access
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
