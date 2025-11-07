// Compute module for Hetzner Cloud VMs, SSH key, network, subnet, and firewall

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.54.0"
    }
  }
}



resource "hcloud_ssh_key" "default" {
  name       = var.ssh_key_name
  public_key = var.ssh_public_key
  labels     = var.common_labels
}

