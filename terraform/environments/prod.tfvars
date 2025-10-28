# Production Environment Configuration
environment   = "prod"
cluster_name  = "k3s-trading"
location      = "nbg1"

# Production-grade instances
control_plane_server_type = "cpx21"  # 3 vCPU, 4GB RAM
kafka_server_type         = "cpx31"  # 4 vCPU, 8GB RAM
kafka_node_count          = 3        # KRaft quorum

# K3s version
k3s_version = "v1.30.5+k3s1"

# Network settings
network_zone    = "eu-central"
network_ip_range = "10.0.0.0/16"
subnet_ip_range  = "10.0.1.0/24"
