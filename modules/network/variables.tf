variable "hcloud_token" {}
variable "network_name" {}
variable "network_ip_range" {}
variable "network_zone" {}
variable "subnet_ip_range" {}
variable "firewall_name" {}
variable "firewall_rules" { type = list(any) }
variable "common_labels" { type = map(string) }

variable "datacenter" {
  description = "Datacenter for Primary IPs (must match server location)"
  type        = string
}
