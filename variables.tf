# ============================================
# Required Variables (GitHub Actions sets via TF_VAR_*)
# ============================================
# Set in GitHub Actions secrets:
#   TF_VAR_hcloud_token = ${{ secrets.HCLOUD_TOKEN }}
#   TF_VAR_ssh_public_key = ${{ secrets.SSH_PUBLIC_KEY }}

variable "hcloud_token" {
  description = "Hetzner Cloud API token (set via TF_VAR_hcloud_token)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for server access (set via TF_VAR_ssh_public_key)"
  type        = string
}

# Primary IP IDs (created in GitHub Actions, passed to Terraform)
variable "control_plane_primary_ip_id" {
  description = "Primary IP ID for control plane (created by GitHub Actions)"
  type        = string
  default     = ""
}

variable "kafka_primary_ip_id" {
  description = "Primary IP ID for kafka-0 external access (created by GitHub Actions)"
  type        = string
  default     = ""
}

# ============================================
# Environment Configuration
# ============================================

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "k3s-trading"
}

# ============================================
# Infrastructure Settings
# ============================================

variable "location" {
  description = "Hetzner location (nbg1, fsn1, hel1)"
  type        = string
  default     = "nbg1"
}

# Note: datacenter is for Primary IPs (persistent IPs)
# Will be used when we add Primary IP resources to main.tf
# Example: nbg1-dc3, fsn1-dc14, hel1-dc2
variable "datacenter" {
  description = "Hetzner datacenter (required for Primary IPs, e.g., nbg1-dc3)"
  type        = string
  default     = "nbg1-dc3"
}

# ============================================
# Server Types (differ by environment)
# ============================================

variable "control_plane_server_type" {
  description = "Server type for K3s control plane"
  type        = string
  default     = "cx22"
}

variable "kafka_server_type" {
  description = "Server type for Kafka nodes"
  type        = string
  default     = "cx22"
}

variable "kafka_node_count" {
  description = "Number of Kafka nodes (minimum 3 for KRaft quorum in production)"
  type        = number
  default     = 1
  validation {
    condition     = var.kafka_node_count >= 1
    error_message = "Must have at least 1 Kafka node."
  }
}

# ============================================
# Network Configuration
# ============================================

variable "network_cidr" {
  description = "CIDR block for the private network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "control_plane_private_ip" {
  description = "Private IP for K3s control plane"
  type        = string
  default     = "10.0.1.10"
}

# ============================================
# K3s Configuration
# ============================================

variable "k3s_version" {
  description = "K3s version to install (e.g., v1.34.1+k3s1 from stable channel)"
  type        = string
  default     = "v1.34.1+k3s1"
}

# ============================================
# Kafka Configuration
# ============================================

variable "kafka_version" {
  description = "Kafka/Strimzi version"
  type        = string
  default     = "4.0.0"
}
