variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "network_ip_range" {
  description = "IP range for the VPC (CIDR)"
  type        = string
}

variable "network_zone" {
  description = "Network zone (e.g., eu-central)"
  type        = string
}

variable "subnet_ip_range" {
  description = "IP range for the subnet (CIDR)"
  type        = string
}

variable "firewall_name" {
  description = "Name of the firewall"
  type        = string
}

variable "firewall_rules" {
  description = "List of firewall rules"
  type        = list(any)
}

variable "common_labels" {
  description = "Common labels for all resources"
  type        = map(string)
}

variable "datacenter" {
  description = "Datacenter for Primary IPs (must match server location)"
  type        = string
}
