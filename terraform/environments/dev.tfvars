# Development Environment Configuration
environment   = "dev"
cluster_name  = "k3s-trading"
location      = "nbg1"

# Development instances
control_plane_server_type = "cx22"  # 2 vCPU, 4GB RAM - cheaper for dev
kafka_server_type         = "cx32"  # 4 vCPU, 8GB RAM - cheaper for dev
kafka_node_count          = 3       # Still need 3 for KRaft quorum

# K3s version
k3s_version = "v1.30.5+k3s1"

# Network settings (same as prod)
network_zone    = "eu-central"
network_ip_range = "10.0.0.0/16"
subnet_ip_range  = "10.0.1.0/24"
