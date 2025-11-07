variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (dev or prod)"
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

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
}

# Server configurations
variable "control_plane_server_type" {
  description = "Hetzner server type for control plane"
  type        = string
  default     = "cax21" # 4 vCPU, 8GB RAM, ARM64
}

variable "kafka_server_type" {
  description = "Hetzner server type for Kafka nodes"
  type        = string
  default     = "cx23" # 2 vCPU, 4GB RAM, x86_64 (consider cax21 ARM for upgrade)
}

variable "kafka_node_count" {
  description = "Number of Kafka nodes (must be odd for KRaft quorum)"
  type        = number
  default     = 3
  validation {
    condition     = var.kafka_node_count % 2 == 1 && var.kafka_node_count >= 3
    error_message = "Kafka node count must be odd and at least 3 for quorum."
  }
}

variable "app_server_type" {
  description = "Hetzner server type for application worker nodes"
  type        = string
  default     = "cx23" # 2 vCPU, 4GB RAM, x86_64 - cheapest available
}

variable "app_node_count" {
  description = "Number of application worker nodes for Python apps"
  type        = number
  default     = 0
}

# Network configuration
variable "network_zone" {
  description = "Network zone for private network"
  type        = string
  default     = "eu-central"
}

variable "network_ip_range" {
  description = "IP range for private network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_ip_range" {
  description = "IP range for subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Location configuration
variable "location" {
  description = "Default location for servers"
  type        = string
  default     = "nbg1" # Nuremberg
}

variable "datacenter" {
  description = "Datacenter for Primary IPs (must match server location)"
  type        = string
  default     = "nbg1-dc3" # Nuremberg datacenter 3
}

# K3s configuration
variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.30.5+k3s1"
}

variable "k3s_token" {
  description = "K3s cluster token for node joining"
  type        = string
  sensitive   = true
  default     = "" # Will be generated if empty
}

# ArgoCD configuration
variable "config_repo_url" {
  description = "URL to the config repository for ArgoCD"
  type        = string
  default     = "https://github.com/trading-cz/config.git"
}
