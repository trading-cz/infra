variable "k3s_token" {
  description = "K3s cluster token"
  type        = string
  default     = ""
}

variable "control_plane_name" {
  description = "Name of the control plane server"
  type        = string
}

variable "control_plane_server_type" {
  description = "Type of control plane server"
  type        = string
}

variable "control_plane_ip" {
  description = "IP address for control plane"
  type        = string
}

variable "control_plane_user_data" {
  description = "User data for control plane initialization"
  type        = string
}

variable "worker_user_data" {
  description = "User data for worker initialization"
  type        = string
}

variable "network_id" {
  description = "Network ID for servers"
  type        = string
}

variable "firewall_id" {
  description = "Firewall ID for servers"
  type        = string
}

variable "ssh_key_id" {
  description = "SSH key ID for servers"
  type        = string
}

variable "location" {
  description = "Hetzner location"
  type        = string
}

variable "labels" {
  description = "Common labels for servers"
  type        = map(string)
}

variable "cluster_name" {
  description = "Cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kafka_node_count" {
  description = "Number of Kafka worker nodes"
  type        = number
}

variable "kafka_server_type" {
  description = "Type of Kafka worker server"
  type        = string
}
