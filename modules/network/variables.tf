variable "network_name" {
  description = "Name of the Hetzner network"
  type        = string
}

variable "network_cidr" {
  description = "CIDR block for the network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "firewall_name" {
  description = "Name of the firewall"
  type        = string
}

variable "labels" {
  description = "Labels to apply to network resources"
  type        = map(string)
  default     = {}
}
