variable "server_name" {
  description = "Name of the worker server"
  type        = string
}

variable "server_type" {
  description = "Server type (e.g., cx22, cx32)"
  type        = string
  default     = "cx22"
}

variable "image" {
  description = "OS image to use"
  type        = string
  default     = "ubuntu-22.04"
}

variable "location" {
  description = "Hetzner location"
  type        = string
  default     = "nbg1"
}

variable "ssh_key_ids" {
  description = "List of SSH key IDs"
  type        = list(string)
}

variable "network_id" {
  description = "ID of the network to attach"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet (for dependency)"
  type        = string
}

variable "private_ip" {
  description = "Private IP address"
  type        = string
  default     = null
}

variable "firewall_ids" {
  description = "List of firewall IDs"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels to apply to the server"
  type        = map(string)
  default     = {}
}

variable "k3s_server_ip" {
  description = "Private IP of the K3s control plane server for agent to join"
  type        = string
}
