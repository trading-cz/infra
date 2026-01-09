# ============================================
# Production Environment Configuration
# ============================================
# Use in GitHub Actions: terraform apply -var-file="environments/prod.tfvars"
# Credentials are set via environment variables (see variables.tf)

# ============================================
# Environment Settings
# ============================================
environment  = "prod"
cluster_name = "k3s-trading"
location     = "nbg1"
datacenter   = "nbg1-dc3" # Required for Primary IPs

# ============================================
# Production Instance Types (Performance)
# ============================================
control_plane_server_type = "cx23" # 4 vCPU, 8GB RAM - better for production
kafka_server_type         = "cx23" # 4 vCPU, 8GB RAM - better performance
kafka_node_count          = 3      # 3 nodes minimum for KRaft quorum

# ============================================
# Worker Node Configuration (Python Apps)
# ============================================
worker_server_type = "cx23" # 2 vCPU, 4GB RAM - budget for prod too
worker_node_count  = 1      # Start with 1, scale as needed

# ============================================
# Network Configuration
# ============================================
network_cidr             = "10.1.0.0/16"
subnet_cidr              = "10.1.1.0/24"
control_plane_private_ip = "10.1.1.10"

# ============================================
# K3s Configuration (Shared)
# ============================================
k3s_version = "v1.34.1+k3s1"

# ============================================
# Kafka Configuration (Shared)
# ============================================
kafka_version = "4.0.0"
