variable "ssh_key_name" {
  description = "Name of the SSH key"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
}

variable "common_labels" {
  description = "Common labels for all resources"
  type        = map(string)
}
