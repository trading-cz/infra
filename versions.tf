# Terraform and Provider Version Requirements
# Centralized version management for the root module

terraform {
  required_version = ">= 1.13"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.54"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}
