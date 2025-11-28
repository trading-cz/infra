# ============================================
# Development Environment Configuration
# ============================================
# Use in GitHub Actions: terraform apply -var-file="environments/dev.tfvars"
# Credentials are set via environment variables (see variables.tf)

# ============================================
# Environment Settings
# ============================================
environment  = "dev"
cluster_name = "k3s-trading"
location     = "nbg1"
datacenter   = "nbg1-dc3" # Required for Primary IPs

# ============================================
# Development Instance Types (Budget)
# ============================================
control_plane_server_type = "cx23" # 2 vCPU, 4GB RAM - minimum for K3s
kafka_server_type         = "cx23" # 2 vCPU, 4GB RAM - budget option
kafka_node_count          = 3      # 3 nodes for KRaft quorum (matching prod)

# ============================================
# Network Configuration
# ============================================
network_cidr             = "10.0.0.0/16"
subnet_cidr              = "10.0.1.0/24"
control_plane_private_ip = "10.0.1.10"

# ============================================
# K3s Configuration (Shared)
# ============================================
k3s_version = "v1.34.1+k3s1"

# ============================================
# Kafka Configuration (Shared)
# ============================================
kafka_version = "4.0.0"
