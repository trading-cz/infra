# Production Environment Configuration
environment  = "prod"
cluster_name = "k3s-trading"
location     = "nbg1"
datacenter   = "nbg1-dc3" # Required for Primary IPs

# Production-grade instances
control_plane_server_type = "cx22"  #
kafka_server_type         = "cx22"  # upgrade to cax21 ARM if needed
kafka_node_count          = 3       # KRaft quorum
app_server_type           = "cx22"  # 2 vCPU, 4GB RAM, x86_64 - cheapest available
app_node_count            = 1       # Start with 1 worker for apps

# K3s version
k3s_version = "v1.34.1+k3s1"

# Network settings
network_zone     = "eu-central"
network_ip_range = "10.0.0.0/16"
subnet_ip_range  = "10.0.1.0/24"
