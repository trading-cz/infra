# The simplest and quickest way to set up
production-ready Kubernetes clusters on Hetzner Cloud.
What is this?
This is a CLI tool designed to make it incredibly fast and easy to create and manage Kubernetes clusters on Hetzner Cloud (referral link, we both receive some credits) using k3s, a lightweight Kubernetes distribution from Rancher. In a test run, I created a 500-node highly available cluster (3 masters, 497 worker nodes) in just under 11 minutes - though this was with only the public network, as private networks are limited to 100 instances per network. I think this might be a world record!

Hetzner Cloud is an awesome cloud provider that offers excellent service with the best performance-to-cost ratio available. They have data centers in Europe, USA and Singapore, making it a versatile choice.

k3s is my go-to Kubernetes distribution because it's lightweight, using far less memory and CPU, which leaves more resources for your workloads. It is also incredibly fast to deploy and upgrade because, thanks to being a single binary.

## Installation
Prerequisites
To use this tool, you will need a few things:

A Hetzner Cloud account.
A Hetzner Cloud token: To get this, create a project in the cloud console, then generate an API token with both read and write permissions (go to the sidebar > Security > API Tokens). Remember, you’ll only see the token once, so make sure to save it somewhere secure.
kubectl and Helm installed, as these are necessary for installing components in the cluster and performing k3s upgrades.

### Linux
NOTE: If you're using certain distributions like Fedora, you might run into a little issue when you try to run hetzner-k3s because of a different version of OpenSSL. The easiest way to fix this, for now, is to run these commands before starting hetzner-k3s:


export OPENSSL_CONF=/dev/null
export OPENSSL_MODULES=/dev/null
For example, you can define a function replacing hetzner-k3s in your .bashrc or .zshrc:


hetzner-k3s() {
OPENSSL_CONF=/dev/null OPENSSL_MODULES=/dev/null command hetzner-k3s "$@"
}
amd64

wget https://github.com/vitobotta/hetzner-k3s/releases/download/v2.4.1/hetzner-k3s-linux-amd64
chmod +x hetzner-k3s-linux-amd64
sudo mv hetzner-k3s-linux-amd64 /usr/local/bin/hetzner-k3s
arm

wget https://github.com/vitobotta/hetzner-k3s/releases/download/v2.4.1/hetzner-k3s-linux-arm64
chmod +x hetzner-k3s-linux-arm64
sudo mv hetzner-k3s-linux-arm64 /usr/local/bin/hetzner-k3s

Creating a cluster
The tool needs a basic configuration file, written in YAML format, to handle tasks like creating, upgrading, or deleting clusters. Below is an example where commented lines indicate optional settings:


---
hetzner_token: <your token>
cluster_name: test
kubeconfig_path: "./kubeconfig"
k3s_version: v1.30.3+k3s1

networking:
ssh:
port: 22
use_agent: false # set to true if your key has a passphrase
public_key_path: "~/.ssh/id_ed25519.pub"
private_key_path: "~/.ssh/id_ed25519"
allowed_networks:
ssh:
- 0.0.0.0/0
api: # this will firewall port 6443 on the nodes
- 0.0.0.0/0
# OPTIONAL: define extra inbound/outbound firewall rules.
# Each entry supports the following keys:
#   description (string, optional)
#   direction   (in | out, default: in)
#   protocol    (tcp | udp | icmp | esp | gre, default: tcp)
#   port        (single port "80", port range "30000-32767", or "any") – only relevant for tcp/udp
#   source_ips  (array of CIDR blocks) – required when direction is in
#   destination_ips (array of CIDR blocks) – required when direction is out
#
# IMPORTANT: Outbound traffic is allowed by default (implicit allow-all).
# If you add **any** outbound rule (direction: out), Hetzner Cloud switches
# the outbound chain to an implicit **deny-all**; only traffic matching your
# outbound rules will be permitted. Define outbound rules carefully to avoid
# accidentally blocking required egress (DNS, updates, etc.).
# NOTE: Hetzner Cloud Firewalls support **max 50 entries per firewall**. The built-
# in rules (SSH, ICMP, node-port ranges, etc.) use ~10 slots. If the sum of the
# default rules plus your custom ones exceeds 50, hetzner-k3s will abort with
# an error.
# custom_firewall_rules:
#   - description: "Allow HTTP from any IPv4"
#     direction: in
#     protocol: tcp
#     port: 80
#     source_ips:
#       - 0.0.0.0/0
#   - description: "UDP game servers (outbound)"
#     direction: out
#     protocol: udp
#     port: 60000-60100
#     destination_ips:
#       - 203.0.113.0/24
public_network:
ipv4: true
ipv6: true
# hetzner_ips_query_server_url: https://.. # for large clusters, see https://github.com/vitobotta/hetzner-k3s/blob/main/docs/Recommendations.md
# use_local_firewall: false # for large clusters, see https://github.com/vitobotta/hetzner-k3s/blob/main/docs/Recommendations.md
private_network:
enabled: true
subnet: 10.0.0.0/16
existing_network_name: ""
cni:
enabled: true
encryption: false
mode: flannel
cilium:
# Optional: specify a path to a custom values file for Cilium Helm chart
# When specified, this file will be used instead of the default values
# helm_values_path: "./cilium-values.yaml"
# chart_version: "v1.17.2"

# cluster_cidr: 10.244.0.0/16 # optional: a custom IPv4/IPv6 network CIDR to use for pod IPs
# service_cidr: 10.43.0.0/16 # optional: a custom IPv4/IPv6 network CIDR to use for service IPs. Warning, if you change this, you should also change cluster_dns!
# cluster_dns: 10.43.0.10 # optional: IPv4 Cluster IP for coredns service. Needs to be an address from the service_cidr range


# manifests:
#   cloud_controller_manager_manifest_url: "https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/download/v1.23.0/ccm-networks.yaml"
#   csi_driver_manifest_url: "https://raw.githubusercontent.com/hetznercloud/csi-driver/v2.12.0/deploy/kubernetes/hcloud-csi.yml"
#   system_upgrade_controller_deployment_manifest_url: "https://github.com/rancher/system-upgrade-controller/releases/download/v0.14.2/system-upgrade-controller.yaml"
#   system_upgrade_controller_crd_manifest_url: "https://github.com/rancher/system-upgrade-controller/releases/download/v0.14.2/crd.yaml"
#   cluster_autoscaler_manifest_url: "https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/hetzner/examples/cluster-autoscaler-run-on-master.yaml"
#   cluster_autoscaler_container_image_tag: "v1.32.0"

datastore:
mode: etcd # etcd (default) or external
external_datastore_endpoint: postgres://....
#  etcd:
#    # etcd snapshot configuration (optional)
#    snapshot_retention: 24
#    snapshot_schedule_cron: "0 * * * *"
#
#    # S3 snapshot configuration (optional)
#    s3_enabled: false
#    s3_endpoint: "" # Can also be set with ETCD_S3_ENDPOINT environment variable
#    s3_region: "" # Can also be set with ETCD_S3_REGION environment variable
#    s3_bucket: "" # Can also be set with ETCD_S3_BUCKET environment variable
#    s3_access_key: "" # Can also be set with ETCD_S3_ACCESS_KEY environment variable
#    s3_secret_key: "" # Can also be set with ETCD_S3_SECRET_KEY environment variable
#    s3_folder: ""
#    s3_force_path_style: false

schedule_workloads_on_masters: false

# image: rocky-9 # optional: default is ubuntu-24.04
# autoscaling_image: 103908130 # optional, defaults to the `image` setting
# snapshot_os: microos # optional: specified the os type when using a custom snapshot

masters_pool:
instance_type: cpx21
instance_count: 3 # for HA; you can also create a single master cluster for dev and testing (not recommended for production)
locations: # You can choose a single location for single master clusters or if you prefer to have all masters in the same location. For regional clusters (which are only available in the eu-central network zone), each master needs to be placed in a separate location.
- fsn1
- hel1
- nbg1

worker_node_pools:
- name: small-static
  instance_type: cpx21
  instance_count: 4
  location: hel1
  # image: debian-11
  # labels:
  #   - key: purpose
  #     value: blah
  # taints:
  #   - key: something
  #     value: value1:NoSchedule
- name: medium-autoscaled
  instance_type: cpx31
  location: fsn1
  autoscaling:
  enabled: true
  min_instances: 0
  max_instances: 3

# cluster_autoscaler:
#   scan_interval: "10s"                        # How often cluster is reevaluated for scale up or down
#   scale_down_delay_after_add: "10m"           # How long after scale up that scale down evaluation resumes
#   scale_down_delay_after_delete: "10s"        # How long after node deletion that scale down evaluation resumes
#   scale_down_delay_after_failure: "3m"        # How long after scale down failure that scale down evaluation resumes
#   max_node_provision_time: "15m"              # Maximum time CA waits for node to be provisioned

embedded_registry_mirror:
enabled: false # Enables fast p2p distribution of container images between nodes for faster pod startup. Check if your k3s version is compatible before enabling this option. You can find more information at https://docs.k3s.io/installation/registry-mirror

# addons:
#   csi_driver:
#     enabled: true   # Hetzner CSI driver (default true). Set to false to skip installation.
#   traefik:
#     enabled: false  # built-in Traefik ingress controller. Disabled by default.
#   servicelb:
#     enabled: false  # built-in ServiceLB. Disabled by default.
#   metrics_server:
#     enabled: false  # Kubernetes metrics-server addon. Disabled by default.
#   cloud_controller_manager:
#     enabled: true   # Hetzner Cloud Controller Manager (default true). Disabling stops automatic LB provisioning for Service objects.
#   cluster_autoscaler:
#     enabled: true   # Cluster Autoscaler addon (default true). Set to false to omit autoscaling.

protect_against_deletion: true

create_load_balancer_for_the_kubernetes_api: false # Just a heads up: right now, we can’t limit access to the load balancer by IP through the firewall. This feature hasn’t been added by Hetzner yet.

k3s_upgrade_concurrency: 1 # how many nodes to upgrade at the same time

# additional_packages:
# - somepackage

# additional_pre_k3s_commands:
# - apt update
# - apt upgrade -y

# additional_post_k3s_commands:
# - apt autoremove -y
# For more advanced usage like resizing the root partition for use with Rook Ceph, see [Resizing root partition with additional post k3s commands](./Resizing_root_partition_with_post_create_commands.md)

# kube_api_server_args:
# - arg1
# - ...
# kube_scheduler_args:
# - arg1
# - ...
# kube_controller_manager_args:
# - arg1
# - ...
# kube_cloud_controller_manager_args:
# - arg1
# - ...
# kubelet_args:
# - arg1
# - ...
# kube_proxy_args:
# - arg1
# - ...
# api_server_hostname: k8s.example.com # optional: DNS for the k8s API LoadBalancer. After the script has run, create a DNS record with the address of the API LoadBalancer.
Most settings are straightforward and easy to understand. To see a list of available k3s releases, you can run the command hetzner-k3s releases.

If you prefer not to include the Hetzner token directly in the config file—perhaps for use with CI or to safely commit the config to a repository—you can use the HCLOUD_TOKEN environment variable instead. This variable takes precedence over the config file.

When setting masters_pool.instance_count, keep in mind that if you set it to 1, the tool will create a control plane that is not highly available. For production clusters, it’s better to set this to a number greater than 1. To avoid split brain issues with etcd, this number should be odd, and 3 is the recommended value. Additionally, for production environments, it’s a good idea to configure masters in different locations using the masters_pool.locations setting.

You can define any number of worker node pools, either static or autoscaled, and create pools with nodes of different specifications to handle various workloads.

Hetzner Cloud init settings, such as additional_packages, additional_pre_k3s_commands, and additional_post_k3s_commands, can be specified at the root level of the configuration file or for each individual pool if different settings are needed. If these settings are configured at the pool level, they will override any settings defined at the root level.

additional_pre_k3s_commands: Commands executed before k3s installation
additional_post_k3s_commands: Commands executed after k3s is installed and configured
For an example of using additional_post_k3s_commands to resize the root partition for use with storage solutions like Rook Ceph, see Resizing root partition with additional post k3s commands.

Currently, Hetzner Cloud offers six locations: two in Germany (nbg1 in Nuremberg and fsn1 in Falkenstein), one in Finland (hel1 in Helsinki), two in the USA (ash in Ashburn, Virginia and hil in Hillsboro, Oregon), and one in Singapore (sin). Be aware that not all instance types are available in every location, so it’s a good idea to check the Hetzner site and their status page for details.

To explore the available instance types and their specifications, you can either check them manually when adding an instance within a project or run the following command with your Hetzner token:


curl -H "Authorization: Bearer $API_TOKEN" 'https://api.hetzner.cloud/v1/server_types'
To create the cluster run:


hetzner-k3s create --config cluster_config.yaml | tee create.log
This process will take a few minutes, depending on how many master and worker nodes you have.

Disabling public IPs (IPv4 or IPv6 or both) on nodes
To improve security and save on IPv4 address costs, you can disable the public interface for all nodes by setting enable_public_net_ipv4: false and enable_public_net_ipv6: false. These settings are global and will apply to all master and worker nodes. If you disable public IPs, make sure to run hetzner-k3s from a machine that has access to the same private network as the nodes, either directly or through a VPN.

Additional networking setup is required via cloud-init, so it’s important that the machine you use to run hetzner-k3s has internet access and DNS configured correctly. Otherwise, the cluster creation process will get stuck after creating the nodes. For more details and instructions, you can refer to this discussion.

Using alternative OS images
By default, the image used for all nodes is ubuntu-24.04, but you can specify a different default image by using the root-level image config option. You can also set different images for different static node pools by using the image config option within each node pool. For example, if you have node pools with ARM instances, you can specify the correct OS image for ARM. To do this, set image to 103908130 with the specific image ID.

However, for autoscaling, there’s a current limitation in the Cluster Autoscaler for Hetzner. You can’t specify different images for each autoscaled pool yet. For now, if you want to use a different image for all autoscaling pools, you can set the autoscaling_image option to override the default image setting.

To see the list of available images, run the following:


export API_TOKEN=...

curl -H "Authorization: Bearer $API_TOKEN" 'https://api.hetzner.cloud/v1/images?per_page=100'
Besides the default OS images, you can also use a snapshot created from an existing instance. When using custom snapshots, make sure to specify the ID of the snapshot or image, not the description you assigned when creating the template instance.

I’ve tested snapshots with openSUSE MicroOS, but other options might work as well. You can easily create a MicroOS snapshot using this Terraform-based tool. The process only takes a few minutes. Once the snapshot is ready, you can use it with hetzner-k3s by setting the image configuration option to the ID of the snapshot and snapshot_os to microos.

Keeping a Project per Cluster
If you plan to create multiple clusters within the same project, refer to the section on Configuring Cluster-CIDR and Service-CIDR. Ensure that each cluster has its own unique Cluster-CIDR and Service-CIDR. Overlapping ranges will cause issues. However, I still recommend separating clusters into different projects. This makes it easier to clean up resources—if you want to delete a cluster, simply delete the entire project.

Configuring Cluster-CIDR and Service-CIDR
Cluster-CIDR and Service-CIDR define the IP ranges used for pods and services, respectively. In most cases, you won’t need to change these values. However, advanced setups might require adjustments to avoid network conflicts.

Changing the Cluster-CIDR (Pod IP Range): To modify the Cluster-CIDR, uncomment or add the cluster_cidr option in your cluster configuration file and specify a valid CIDR notation for the network. Make sure this network is not a subnet of your private network.

Changing the Service-CIDR (Service IP Range): To adjust the Service-CIDR, uncomment or add the service_cidr option in your configuration file and provide a valid CIDR notation. Again, ensure this network is not a subnet of your private network. Also, uncomment the cluster_dns option and provide a single IP address from the service_cidr range. This sets the IP address for the coredns service.

Sizing the Networks: The networks you choose should have enough space for your expected number of pods and services. By default, /16 networks are used. Select an appropriate size, as changing the CIDR later is not supported.

Autoscaler Configuration
The cluster autoscaler automatically manages the number of worker nodes in your cluster based on resource demands. When you enable autoscaling for a worker node pool, you can also configure various timing parameters to fine-tune its behavior.

Basic Autoscaling Configuration

worker_node_pools:
- name: autoscaled-pool
  instance_type: cpx31
  location: fsn1
  autoscaling:
  enabled: true
  min_instances: 1
  max_instances: 10
  Advanced Timing Configuration
  You can customize the autoscaler's behavior with these optional parameters at the root level of your configuration:


cluster_autoscaler:
scan_interval: "2m"                      # How often cluster is reevaluated for scale up or down
scale_down_delay_after_add: "10m"        # How long after scale up that scale down evaluation resumes
scale_down_delay_after_delete: "10s"     # How long after node deletion that scale down evaluation resumes
scale_down_delay_after_failure: "15m"    # How long after scale down failure that scale down evaluation resumes
max_node_provision_time: "15m"           # Maximum time CA waits for node to be provisioned

worker_node_pools:
- name: autoscaled-pool
  instance_type: cpx31
  location: fsn1
  autoscaling:
  enabled: true
  min_instances: 1
  max_instances: 10
  Parameter Descriptions
  scan_interval: Controls how frequently the cluster autoscaler evaluates whether scaling is needed. Shorter intervals mean faster response to load changes but more API calls.
  Default: 10s

scale_down_delay_after_add: Prevents the autoscaler from immediately scaling down after adding nodes. This helps avoid thrashing when workloads are still starting up.

Default: 10m

scale_down_delay_after_delete: Adds a delay before considering more scale-down operations after a node deletion. This ensures the cluster stabilizes before further changes.

Default: 10s

scale_down_delay_after_failure: When a scale-down operation fails, this parameter controls how long to wait before attempting another scale-down.

Default: 3m

max_node_provision_time: Sets the maximum time the autoscaler will wait for a new node to become ready. This is particularly useful for clusters with private networks where provisioning might take longer.

Default: 15m
These settings apply globally to all autoscaling worker node pools in your cluster.

Idempotency
The create command can be run multiple times with the same configuration without causing issues, as the process is idempotent. If the process gets stuck or encounters errors (e.g., due to Hetzner API unavailability or timeouts), you can stop the command and rerun it with the same configuration to continue where it left off. Note that the kubeconfig will be overwritten each time you rerun the command.

Limitations:
Using a snapshot instead of a default image will take longer to create instances compared to regular images.
The networking.allowed_networks.api setting specifies which networks can access the Kubernetes API, but this currently only works with single-master clusters. Multi-master HA clusters can optionally use a load balancer for the API, but Hetzner’s firewalls do not yet support load balancers.
If you enable autoscaling for a nodepool, avoid changing this setting later, as it can cause issues with the autoscaler.
Autoscaling is only supported with Ubuntu or other default images, not snapshots.
SSH keys with passphrases can only be used if you set networking.ssh.use_ssh_agent to true and use an SSH agent to access your key. For example, on macOS, you can start an agent like this:

eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/<private key>

## Setting Up a Cluster
This guide will walk you through creating a fully functional Kubernetes cluster on Hetzner Cloud using hetzner-k3s, complete with ingress controller and a sample application.

Prerequisites
Before starting, ensure you have:

Hetzner Cloud Account with project and API token
kubectl installed on your local machine
Helm installed on your local machine
hetzner-k3s installed (see Installation Guide)
SSH Key Pair for accessing cluster nodes
Instructions
Installation of a "hello-world" project
For testing, we’ll use this "hello-world" app: hello-world app

Install kubectl on your computer: kubectl installation
Install Helm on your computer: Helm installation
Install hetzner-k3s on your computer: Installation
Create a file called hetzner-k3s_cluster_config.yaml with the following configuration. This setup is for a Highly Available (HA) cluster with 3 master nodes and 3 worker nodes. You can use 1 master and 1 worker for testing:

hetzner_token: ...
cluster_name: hello-world
kubeconfig_path: "./kubeconfig"  # or /cluster/kubeconfig if you are going to use Docker
k3s_version: v1.32.0+k3s1

networking:
ssh:
port: 22
use_agent: false
public_key_path: "~/.ssh/id_rsa.pub"
private_key_path: "~/.ssh/id_rsa"
allowed_networks:
ssh:
- 0.0.0.0/0
api:
- 0.0.0.0/0

masters_pool:
instance_type: cpx21
instance_count: 3
locations:
- fsn1
- hel1
- nbg1

worker_node_pools:
- name: small
  instance_type: cpx21
  instance_count: 4
  location: hel1
- name: big
  instance_type: cpx31
  location: fsn1
  autoscaling:
  enabled: true
  min_instances: 0
  max_instances: 3
  For more details on all the available settings, refer to the full config example in Creating a cluster.

Create the cluster: hetzner-k3s create --config hetzner-k3s_cluster_config.yaml
hetzner-k3s automatically generates a kubeconfig file for the cluster in the directory where you run the tool. You can either copy this file to ~/.kube/config if it’s the only cluster or run export KUBECONFIG=./kubeconfig in the same directory to access the cluster. After this, you can interact with your cluster using kubectl installed in step 1.
TIP: If you don’t want to run kubectl apply ... every time, you can store all your configuration files in a folder and then run kubectl apply -f /path/to/configs/ -R.

Create a file: touch ingress-nginx-annotations.yaml
Add annotations to the file: nano ingress-nginx-annotations.yaml

# INSTALLATION
# 1. Install Helm: https://helm.sh/docs/intro/install/
# 2. Add ingress-nginx Helm repo: helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# 3. Update information of available charts: helm repo update
# 4. Install ingress-nginx:
# helm upgrade --install \
# ingress-nginx ingress-nginx/ingress-nginx \
# --set controller.ingressClassResource.default=true \ # Remove this line if you don’t want Nginx to be the default Ingress Controller
# -f ./ingress-nginx-annotations.yaml \
# --namespace ingress-nginx \
# --create-namespace

# LIST of all ANNOTATIONS: https://github.com/hetznercloud/hcloud-cloud-controller-manager/blob/master/internal/annotation/load_balancer.go

controller:
kind: DaemonSet
service:
annotations:
# Germany:
# - nbg1 (Nuremberg)
# - fsn1 (Falkenstein)
# Finland:
# - hel1 (Helsinki)
# USA:
# - ash (Ashburn, Virginia)
# Without this, the load balancer won’t be provisioned and will stay in "pending" state.
# You can check this state using "kubectl get svc -n ingress-nginx"
load-balancer.hetzner.cloud/location: nbg1

      # Name of the load balancer. This name will appear in your Hetzner cloud console under "Your project -> Load Balancers".
      # NOTE: This is NOT the load balancer created automatically for HA clusters. You need to specify a different name here to create a separate load balancer for ingress Nginx.
      load-balancer.hetzner.cloud/name: WORKERS_LOAD_BALANCER_NAME

      # Ensures communication between the load balancer and cluster nodes happens through the private network.
      load-balancer.hetzner.cloud/use-private-ip: "true"

      # [ START: Use these annotations if you care about seeing the actual client IP ]
      # "uses-proxyprotocol" enables the proxy protocol on the load balancer so that the ingress controller and applications can see the real client IP.
      # "hostname" is needed if you use cert-manager (LetsEncrypt SSL certificates). It fixes HTTP01 challenges for cert-manager (https://cert-manager.io/docs/).
      # Check this link for more details: https://github.com/compumike/hairpin-proxy
      # In short: the easiest fix provided by some providers (including Hetzner) is to configure the load balancer to use a hostname instead of an IP.
      load-balancer.hetzner.cloud/uses-proxyprotocol: 'true'

      # 1. "yourDomain.com" must be correctly configured in DNS to point to the Nginx load balancer; otherwise, certificate provisioning won’t work.
      # 2. If you use multiple domains, specify any one.
      load-balancer.hetzner.cloud/hostname: yourDomain.com
      # [ END: Use these annotations if you care about seeing the actual client IP ]

      load-balancer.hetzner.cloud/http-redirect-https: 'false'
Replace yourDomain.com with your actual domain.
Replace WORKERS_LOAD_BALANCER_NAME with a name of your choice.

Add the ingress-nginx Helm repo: helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

Update the Helm repo: helm repo update
Install ingress-nginx:

helm upgrade --install \
ingress-nginx ingress-nginx/ingress-nginx \
--set controller.ingressClassResource.default=true \
-f ./ingress-nginx-annotations.yaml \
--namespace ingress-nginx \
--create-namespace
The --set controller.ingressClassResource.default=true flag configures this as the default Ingress Class for your cluster. Without this, you’ll need to specify an Ingress Class for every Ingress object you deploy, which can be tedious. If no default is set and you don’t specify one, Nginx will return a 404 Not Found page because it won’t "pick up" the Ingress.

TIP: To delete it: helm uninstall ingress-nginx -n ingress-nginx. Be careful, as this will delete the current Hetzner load balancer, and installing a new ingress controller may create a new load balancer with a different public IP.

After a few minutes, check that the "EXTERNAL-IP" column shows an IP instead of "pending": kubectl get svc -n ingress-nginx

The load-balancer.hetzner.cloud/uses-proxyprotocol: "true" annotation requires use-proxy-protocol: "true" for ingress-nginx. To set this up, create a file: touch ingress-nginx-configmap.yaml

Add the following content to the file: nano ingress-nginx-configmap.yaml

apiVersion: v1
kind: ConfigMap
metadata:
# Do not change the name - this is required by the Nginx Ingress Controller
name: ingress-nginx-controller
namespace: ingress-nginx
data:
use-proxy-protocol: "true"
Apply the ConfigMap: kubectl apply -f ./ingress-nginx-configmap.yaml
Open your Hetzner cloud console, go to "Your project -> Load Balancers," and find the PUBLIC IP of the load balancer with the name you used in the load-balancer.hetzner.cloud/name: WORKERS_LOAD_BALANCER_NAME annotation. Copy or note this IP.
Download the hello-world app: curl https://raw.githubusercontent.com/vitobotta/hetzner-k3s/refs/heads/main/sample-deployment.yaml --output hello-world.yaml
Edit the file to add the annotation and set the hostname:

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
name: hello-world
annotations:                       # <<<--- Add annotation
kubernetes.io/ingress.class: nginx  # <<<--- Add annotation
spec:
rules:
- host: hello-world.IP_FROM_STEP_12.nip.io # <<<--- Replace `IP_FROM_STEP_12` with the IP from step 16.
  ....
  Install the hello-world app: kubectl apply -f hello-world.yaml
  Open http://hello-world.IP_FROM_STEP_12.nip.io in your browser. You should see the Rancher "Hello World!" page. The host.IP_FROM_STEP_12.nip.io (the .nip.io part is key) is a quick way to test things without configuring DNS. A query to a hostname ending in .nip.io returns the IP address in the hostname itself. If you enabled the proxy protocol as shown earlier, your public IP address should appear in the X-Forwarded-For header, meaning the application can "see" it.

To connect your actual domain, follow these steps:

Assign the IP address from step 12 to your domain in your DNS settings.
Change - host: hello-world.IP_FROM_STEP_12.nip.io to - host: yourDomain.com.
Run kubectl apply -f hello-world.yaml.
Wait until DNS records are updated.
If you need LetsEncrypt
Add the LetsEncrypt Helm repo: helm repo add jetstack https://charts.jetstack.io
Update the Helm repo: helm repo update
Install the LetsEncrypt certificates issuer:

helm upgrade --install \
--namespace cert-manager \
--create-namespace \
--set crds.enabled=true \
cert-manager jetstack/cert-manager
Create a file called lets-encrypt.yaml with the following content:

apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
name: letsencrypt-prod
namespace: cert-manager
spec:
acme:
email: [REDACTED]
server: https://acme-v02.api.letsencrypt.org/directory
privateKeySecretRef:
name: letsencrypt-prod-account-key
solvers:
- http01:
ingress:
class: nginx
Apply the file: kubectl apply -f ./lets-encrypt.yaml
Edit hello-world.yaml and add the settings for TLS encryption:

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
name: hello-world
annotations:
cert-manager.io/cluster-issuer: "letsencrypt-prod"  # <<<--- Add annotation
kubernetes.io/tls-acme: "true"                      # <<<--- Add annotation
spec:
rules:
- host: yourDomain.com  # <<<---- Your actual domain
  tls: # <<<---- Add this block
- hosts:
    - yourDomain.com
      secretName: yourDomain.com-tls # <<<--- Add reference to secret
      ....
      TIP: If you didn’t configure Nginx as the default Ingress Class, you’ll need to add the spec.ingressClassName: nginx annotation.

Apply the changes: kubectl apply -f ./hello-world.yaml
FAQs
1. Can I use MetalLB instead of Hetzner's Load Balancer?
   Yes, you can use MetalLB with floating IPs in Hetzner Cloud, but I wouldn’t recommend it. The setup with Hetzner's standard load balancers is much simpler. Plus, load balancers aren’t significantly more expensive than floating IPs, so in my opinion, there’s no real benefit to using MetalLB in this case.

2. How do I create and push Docker images to a repository, and how can Kubernetes work with these images? (GitLab example)
   On the machine where you create the image:

Start by logging in to the Docker registry: docker login registry.gitlab.com.
Build the Docker image: docker build -t registry.gitlab.com/COMPANY_NAME/REPO_NAME:IMAGE_NAME -f /some/path/to/Dockerfile ..
Push the image to the registry: docker push registry.gitlab.com/COMPANY_NAME/REPO_NAME:IMAGE_NAME.
On the machine running Kubernetes:

Generate a secret to allow Kubernetes to access the images: kubectl create secret docker-registry gitlabcreds --docker-server=https://registry.gitlab.com --docker-username=MYUSER --docker-password=MYPWD --docker-email=MYEMAIL -n NAMESPACE_OF_YOUR_APP -o yaml > docker-secret.yaml.
Apply the secret: kubectl apply -f docker-secret.yaml -n NAMESPACE_OF_YOUR_APP.
3. How can I check the resource usage of nodes or pods?
   First, install the metrics-server from this GitHub repository: https://github.com/kubernetes-sigs/metrics-server. After installation, you can use either kubectl top nodes or kubectl top pods -A to view resource usage.

4. What is Ingress?
   There are two types of "ingress" to understand: Ingress Controller and Ingress Resources.

In the case of Nginx:

The Ingress Controller is Nginx itself (defined as kind: Ingress), while Ingress Resources are services (defined as kind: Service).
The Ingress Controller has various annotations (rules). You can use these annotations in kind: Ingress to make them "global" or in kind: Service to make them "local" (specific to that service).
The Ingress Controller consists of a Pod and a Service. The Pod runs the Controller, which continuously monitors the /ingresses endpoint in your cluster’s API server for updates to available Ingress Resources.
5. How can I configure autoscaling to automatically set up IP routes for new nodes to use a NAT server?
   First, you’ll need a NAT server, as described in this Hetzner community tutorial.

Then, use additional_post_k3s_commands to run commands after k3s installation:


additional_packages:
- ifupdown
  additional_post_k3s_commands:
- apt update
- apt upgrade -y
- apt autoremove -y
- ip route add default via [REDACTED]  # Replace this with your gateway IP
  You can also use additional_pre_k3s_commands to run commands before k3s installation if needed.

Useful Commands

kubectl get service [serviceName] -A or -n [nameSpace]
kubectl get ingress [ingressName] -A or -n [nameSpace]
kubectl get pod [podName] -A or -n [nameSpace]
kubectl get all -A
kubectl get events -A
helm ls -A
helm uninstall [name] -n [nameSpace]
kubectl -n ingress-nginx get svc
kubectl describe ingress -A
kubectl describe svc -n ingress-nginx
kubectl delete configmap nginx-config -n ingress-nginx
kubectl rollout restart deployment -n NAMESPACE_OF_YOUR_APP
kubectl get all -A` does not include "ingress", so use `kubectl get ing -A

## Important Upgrade Notes
OpenSSH Upgrade Notice - Friday, August 1, 2025
Critical Information
Due to a recent OpenSSH upgrade made available for Ubuntu, there is a significant risk that cluster nodes created with a version of hetzner-k3s prior to 2.3.4 might become unreachable via SSH once OpenSSH gets upgraded and the nodes are rebooted.

The Problem
The OpenSSH upgrade changes systemd socket configuration behavior, which can cause SSH connectivity issues if the socket configuration file /etc/systemd/system/ssh.socket.d/listen.conf is not properly configured to handle IPv6 binding.

Solution for Reachable Nodes
If the nodes in your cluster are still reachable via SSH, you can fix this issue by running the following command:


hetzner-k3s run --config <your-config-file> --script fix-ssh.sh
This command will automatically fix the contents of /etc/systemd/system/ssh.socket.d/listen.conf to ensure SSH connectivity continues working after the OpenSSH server upgrade.

The script is available at the root of this project's repository and will: - Create a backup of the original configuration file with a timestamp - Properly configure the socket file to handle both IPv4 and IPv6 connections - Preserve all existing ListenStream configurations - Restart the SSH socket to apply changes

Workaround for Unreachable Nodes
If your nodes are no longer reachable via SSH due to OpenSSH already having been upgraded, there is a manual workaround available:

Run the kube-shell script from the project's repository (in the bin directory)
Specify the name of a node to fix as the first and only argument
This will open an SSH-like session on the node via kubectl using a temporary privileged pod
Within this session, manually modify /etc/systemd/system/ssh.socket.d/listen.conf to append the line:

BindIPv6Only=default
Important: This manual method must be performed for each node individually Exercise caution when modifying system configuration files.

Affected Versions
Fixed in: hetzner-k3s 2.3.5 and later
Affected: All versions prior to 2.3.5
Recommendation
We strongly recommend upgrading to hetzner-k3s 2.3.5 or later and running the fix script proactively before any OpenSSH upgrades occur to prevent any connectivity issues.

## Recommendations
This page provides best practices and recommendations for different cluster sizes and use cases with hetzner-k3s.

Small to Medium Clusters (1-50 nodes)
The default configuration works well for small to medium-sized clusters, providing a simple, reliable setup with minimal configuration required.

Key Considerations
Private Network: Enabled by default for better security
CNI: Flannel for simplicity or Cilium for advanced features
Storage: hcloud-volumes for persistence
Load Balancers: Hetzner Load Balancers for production workloads
High Availability: 3 master nodes for production clusters
Recommended Configuration

hetzner_token: <your token>
cluster_name: my-cluster
kubeconfig_path: "./kubeconfig"
k3s_version: v1.32.0+k3s1

networking:
ssh:
port: 22
use_agent: false
public_key_path: "~/.ssh/id_ed25519.pub"
private_key_path: "~/.ssh/id_ed25519"
allowed_networks:
ssh:
- 0.0.0.0/0
api:
- 10.0.0.0/16  # Restrict to private network
public_network:
ipv4: true
ipv6: true
private_network:
enabled: true
subnet: 10.0.0.0/16
cni:
enabled: true
encryption: false
mode: flannel

masters_pool:
instance_type: cpx21
instance_count: 3  # For HA
locations:
- nbg1

worker_node_pools:
- name: workers
  instance_type: cpx31
  instance_count: 3
  location: nbg1
  autoscaling:
  enabled: true
  min_instances: 1
  max_instances: 5

protect_against_deletion: true
create_load_balancer_for_the_kubernetes_api: true
Large Clusters (50+ nodes)
For larger clusters, the default setup has some limitations that need to be addressed.

Limitations of Default Setup
Hetzner's private networks, used in hetzner-k3s' default configuration, only support up to 100 nodes. If your cluster is going to grow beyond that, you need to disable the private network in your configuration.

Large Cluster Architecture (Since v2.2.8)
Support for large clusters has significantly improved since version 2.2.8. The main changes include:

Custom Firewall: Instead of using Hetzner's firewall (which is slow to update), a custom firewall solution was implemented
IP Query Server: A simple container that checks the Hetzner API every 30 seconds to get the list of all node IPs
Automatic Updates: Firewall rules are automatically updated without manual intervention
Setting Up Large Clusters
Step 1: Set Up IP Query Server
The IP query server runs as a simple container. You can easily set it up on any Docker-enabled server using the docker-compose.yml file in the ip-query-server folder of this repository.


# docker-compose.yml
version: '3.8'
services:
ip-query-server:
build: ./ip-query-server
ports:
- "8080:80"
environment:
- HETZNER_TOKEN=your_token_here
caddy:
image: caddy:2
ports:
- "80:80"
- "443:443"
volumes:
- ./Caddyfile:/etc/caddy/Caddyfile
depends_on:
- ip-query-server
Replace example.com in the Caddyfile with your actual domain name and mail@example.com with your email address for Let's Encrypt certificates.

Step 2: Update Cluster Configuration

hetzner_token: <your token>
cluster_name: large-cluster
kubeconfig_path: "./kubeconfig"
k3s_version: v1.32.0+k3s1

networking:
ssh:
port: 22
use_agent: true  # Recommended for large clusters
public_key_path: "~/.ssh/id_ed25519.pub"
private_key_path: "~/.ssh/id_ed25519"
allowed_networks:
ssh:
- 0.0.0.0/0  # Required for public network access
api:
- 0.0.0.0/0  # Required when private network is disabled
public_network:
ipv4: true
ipv6: true
# Use custom IP query server for large clusters
hetzner_ips_query_server_url: https://ip-query.example.com
use_local_firewall: true  # Enable custom firewall
private_network:
enabled: false  # Disable private network for >100 nodes
cni:
enabled: true
encryption: true  # Enable encryption for public network
mode: cilium  # Better for large scale deployments

# Larger cluster CIDR ranges
cluster_cidr: 10.244.0.0/15  # Larger range for more pods
service_cidr: 10.96.0.0/16   # Larger range for more services
cluster_dns: 10.96.0.10

datastore:
mode: etcd  # or external for very large clusters
# external_datastore_endpoint: postgres://...

masters_pool:
instance_type: cpx31
instance_count: 3
locations:
- nbg1
- hel1
- fsn1

worker_node_pools:
- name: compute
  instance_type: cpx41
  location: nbg1
  autoscaling:
  enabled: true
  min_instances: 5
  max_instances: 50
- name: storage
  instance_type: cpx51
  location: hel1
  autoscaling:
  enabled: true
  min_instances: 3
  max_instances: 20

embedded_registry_mirror:
enabled: true  # Recommended for large clusters

protect_against_deletion: true
create_load_balancer_for_the_kubernetes_api: true
k3s_upgrade_concurrency: 2  # Can upgrade more nodes simultaneously
Additional Large Cluster Considerations
Network Configuration
CIDR Sizing: Use larger cluster and service CIDR ranges to accommodate more pods and services
Encryption: Enable CNI encryption when using public networks
Firewall: The custom firewall automatically manages allowed IPs without opening ports to the public
High Availability Setup
For production large clusters, consider:

Multiple IP Query Servers: Set up 2-3 instances behind a load balancer for better availability
External Datastore: Use PostgreSQL instead of etcd for better scalability
Distributed Master Nodes: Place masters in different locations
Multiple Node Pools: Different instance types for different workloads
Cluster Sizing Guidelines
Development/Tiny Clusters (< 5 nodes)

masters_pool:
instance_type: cpx11
instance_count: 1  # Single master for testing
worker_node_pools:
- name: workers
  instance_type: cpx11
  instance_count: 1
  Small Production Clusters (5-20 nodes)

masters_pool:
instance_type: cpx21
instance_count: 3  # HA masters
locations:
- fsn1
- hel1
- nbg1
worker_node_pools:
- name: workers
  instance_type: cpx31
  instance_count: 3
  autoscaling:
  enabled: true
  min_instances: 1
  max_instances: 5
  Medium Production Clusters (20-50 nodes)

masters_pool:
instance_type: cpx31
instance_count: 3
locations:
- fsn1
- hel1
- nbg1
worker_node_pools:
- name: web
  instance_type: cpx31
  location: nbg1
  autoscaling:
  enabled: true
  min_instances: 3
  max_instances: 10
- name: backend
  instance_type: cpx41
  location: hel1
  autoscaling:
  enabled: true
  min_instances: 2
  max_instances: 8
  Large Production Clusters (50-200+ nodes)
  Use the large cluster configuration shown above with: - Multiple node pools for different workloads - Custom firewall and IP query server - Larger instance types for masters - External datastore if needed

Performance Optimization
Embedded Registry Mirror
In v2.0.0, there's a new option to enable the embedded registry mirror in k3s. You can find more details here. This feature uses Spegel to enable peer-to-peer distribution of container images across cluster nodes.

Benefits: - Faster pod startup times - Reduced external registry calls - Better reliability when external registries are inaccessible - Cost savings on egress bandwidth

Configuration:


embedded_registry_mirror:
enabled: true
Note: Ensure your k3s version supports this feature before enabling.

Storage Selection
Use hcloud-volumes for:
Production databases where the app does not take care of replication already
Persistent application data
Content that must survive pod restarts
Applications requiring high availability
Use local-path for:
High-performance caching (Redis, Memcached)
High-performance databases (Postgres, MySQL) where the app takes care of replication already
Temporary file storage
Applications that can tolerate data loss
Maximum IOPS performance
CNI Selection
Flannel
Pros: Simple, lightweight, good for small clusters
Cons: Limited features, doesn't scale well to very large clusters
Best for: Small to medium clusters, simplicity
Cilium
Pros: Advanced features, better performance scales well
Cons: More complex setup, higher resource usage
Best for: Medium to large clusters, advanced networking needs
Security Recommendations
Network Security
Restrict SSH and API Access: Use CIDR restrictions in allowed_networks.api and allowed_networks.ssh
Use Private Networks: When possible, use private networks for cluster communication
Monitor Network Traffic: Implement network policies and monitoring
SSH Security
Use SSH Keys: hetzner-k3s configures nodes with SSH keys by default
SSH Agent: Enable use_agent: true for passphrase-protected keys
Key Rotation: Regularly rotate SSH keys if needed
Access Logs: Monitor SSH access logs
Cluster Security
RBAC: Implement proper role-based access control
Network Policies: Use Kubernetes network policies
Pod Security: Implement pod security standards
Regular Updates: Keep k3s and components updated
Cost Optimization
Instance Selection
Right-size Instances: Start smaller and scale up as needed
Use Autoscaling: Only pay for what you use
Storage Optimization
Clean Up Volumes: Regularly delete unused volumes
Use Local Storage: For temporary data where appropriate
Monitor Usage: Set up monitoring to identify unused storage
Network Optimization
Use Private Networks: Reduce egress costs
Optimize Images: Use smaller container images
Registry Mirror: Reduce registry egress costs
Monitoring and Observability
Essential Monitoring
Node Resources: CPU, memory, disk usage
Cluster Health: Node readiness, pod status
Network Traffic: Bandwidth usage, connection counts
Storage Performance: I/O operations, latency
Recommended Tools
Prometheus + Grafana: For metrics and dashboards
Loki: For log aggregation
Alertmanager: For alerting
Node Exporter: For node metrics

## Maintenance
Adding Nodes
To add one or more nodes to a node pool, simply update the instance count in the configuration file for that node pool and run the create command again.

Scaling Down a Node Pool
To reduce the size of a node pool:

Lower the instance count in the configuration file to ensure the extra nodes are not recreated in the future.
Drain and delete the additional nodes from Kubernetes. These are typically the last nodes when sorted alphabetically by name (kubectl drain Node followed by kubectl delete node <name>).
Remove the corresponding instances from the cloud console if the Cloud Controller Manager doesn’t handle this automatically. Make sure you delete the correct ones!
Replacing a Problematic Node
Drain and delete the node from Kubernetes (kubectl drain <name> followed by kubectl delete node <name>).
Delete the correct instance from the cloud console.
Run the create command again. This will recreate the missing node and add it to the cluster.
Converting a Non-HA Cluster to HA
Converting a single-master, non-HA cluster to a multi-master HA cluster is straightforward. Increase the masters instance count and rerun the create command. This will set up a load balancer for the API server (if enabled) and update the kubeconfig to direct API requests through the load balancer or one of the master contexts. For production clusters, it’s also a good idea to place the masters in different locations (refer to this page for more details).

Upgrading to a New Version of k3s
Step 1: Initiate the Upgrade
For the first upgrade of your cluster, simply run the following command to update to a newer version of k3s:


hetzner-k3s upgrade --config cluster_config.yaml --new-k3s-version v1.27.1-rc2+k3s1
Specify the new k3s version as an additional parameter, and the configuration file will be updated automatically during the upgrade. To view available k3s releases, run the command hetzner-k3s releases.

Note: For single-master clusters, the API server will be briefly unavailable during the control plane upgrade.

Step 2: Monitor the Upgrade Process
After running the upgrade command, you must monitor the upgrade jobs in the system-upgrade namespace to ensure all nodes are successfully upgraded:


# Watch the upgrade progress for all nodes
watch kubectl get nodes -owide

# Monitor upgrade jobs and plans
watch kubectl get jobs,pods -n system-upgrade

# Check upgrade plans status
kubectl get plan -n system-upgrade -o wide

# Check upgrade job logs
kubectl logs -n system-upgrade -f job/<upgrade-job-name>
You will see the masters upgrading one at a time, followed by the worker nodes. The upgrade process creates upgrade jobs in the system-upgrade namespace that handle the actual node upgrades.

Step 3: Verify Upgrade Completion
Before proceeding, ensure all upgrade jobs have completed successfully and all nodes are running the new k3s version:


# Check that all upgrade jobs are completed
kubectl get jobs -n system-upgrade

# Verify all nodes are ready and running the new version
kubectl get nodes -o wide

# Check for any failed or pending jobs
kubectl get jobs -n system-upgrade --field-selector status.failed=1
kubectl get jobs -n system-upgrade --field-selector status.active=1
✅ Upgrade Completion Checklist:

All upgrade jobs in system-upgrade namespace have completed
All nodes show Ready status
All nodes display the new k3s version in kubectl get nodes -owide
No active or failed upgrade jobs remain
Step 4: Run Create Command (CRITICAL)
Once all upgrade jobs have completed and all nodes have been successfully updated to the new k3s version, you MUST run the create command:


hetzner-k3s create --config cluster_config.yaml
Why This Step is Essential:
The upgrade command automatically updates the k3s version in your cluster configuration file, but this step is crucial because:

Updates Masters Configuration: Ensures that any new master nodes provisioned in the future will use the correct (new) k3s version instead of the previous version
Updates Worker Node Templates: Updates the worker node pool configurations to ensure new worker nodes are created with the upgraded k3s version
Synchronizes Cluster State: Ensures the actual cluster state matches the desired state defined in your configuration file
Prevents Version Mismatch: Without this step, new nodes added to the cluster would be created with the old k3s version and would need to be upgraded again by the system upgrade controller, causing unnecessary delays and potential issues
If you skip this step and add new nodes to the cluster later, they will first be created with the old k3s version and then need to be upgraded again, which is inefficient and can cause compatibility issues.

What to Do If the Upgrade Doesn’t Go Smoothly
If the upgrade stalls or doesn’t complete for all nodes:

Clean up existing upgrade plans and jobs, then restart the upgrade controller:

kubectl -n system-upgrade delete job --all
kubectl -n system-upgrade delete plan --all

kubectl label node --all plan.upgrade.cattle.io/k3s-server- plan.upgrade.cattle.io/k3s-agent-

kubectl -n system-upgrade rollout restart deployment system-upgrade-controller
kubectl -n system-upgrade rollout status deployment system-upgrade-controller
You can also check the logs of the system upgrade controller’s pod:


kubectl -n system-upgrade \
logs -f $(kubectl -n system-upgrade get pod -l pod-template-hash -o jsonpath="{.items[0].metadata.name}")
If the upgrade stalls after upgrading the masters but before upgrading the worker nodes, simply cleaning up resources might not be enough. In this case, run the following to mark the masters as upgraded and allow the upgrade to continue for the workers:


kubectl label node <master1> <master2> <master2> plan.upgrade.cattle.io/k3s-server=upgraded
Once all the nodes have been upgraded, remember to re-run the hetzner-k3s create command. This way, new nodes will be created with the new version right away. If you don’t, they will first be created with the old version and then upgraded by the system upgrade controller.

Upgrading the OS on Nodes
Consider adding a temporary node during the process if your cluster doesn’t have enough spare capacity.
Drain one node.
Update the OS and reboot the node.
Uncordon the node.
Repeat for the next node.
To automate this process, you can install the Kubernetes Reboot Daemon ("Kured"). For Kured to work effectively, ensure the OS on your nodes has unattended upgrades enabled, at least for security updates. For example, if the image is Ubuntu, add this to the configuration file before running the create command:


additional_packages:
- unattended-upgrades
- update-notifier-common
  additional_post_k3s_commands:
- sudo systemctl enable unattended-upgrades
- sudo systemctl start unattended-upgrades
  Refer to the Kured documentation for additional configuration options, such as maintenance windows.
## Deleting a Cluster
Basic Deletion
To delete a cluster, you need to run the following command:


hetzner-k3s delete --config cluster_config.yaml
This command will remove all the resources in the Hetzner Cloud project that were created by hetzner-k3s.

Important Considerations
Protection Against Deletion
Additionally, to delete a cluster, you must ensure that protect_against_deletion is set to false. When you execute the delete command, you'll also need to enter the cluster's name to confirm the deletion. These steps are in place to avoid accidentally deleting a cluster you intended to keep.

Resources Not Automatically Deleted
Keep in mind that the following resources created by your applications will not be deleted automatically. You'll need to remove those manually:

Load Balancers: Load balancers created by your applications (via Services of type LoadBalancer)
Persistent Volumes: Persistent volumes and their underlying storage
Floating IPs: Any floating IPs you've manually attached to instances
Snapshots: Any snapshots created from instances
This behavior is by design to prevent accidental data loss. These resources might be improved in future updates.

Manual Cleanup Steps
Before Deleting the Cluster
Backup Important Data: Ensure you have backups of any important data stored in persistent volumes
Export Application Configurations: Save any Kubernetes manifests, Helm values, or configurations you might need later
Note Load Balancer IPs: If you have applications with public IPs, note them down as they might change if you recreate the cluster
After Deleting the Cluster
Manual Cleanup
You can easily delete any remaining resources using the Hetzner Cloud Console:

Log in to your Hetzner Cloud Console
Navigate to your project
Delete remaining resources from the left sidebar:
Load Balancers → Select and delete any application load balancers
Volumes → Select and delete any persistent volumes
Floating IPs → Select and delete any unused floating IPs
Snapshots → Select and delete any unnecessary snapshots
This visual approach is recommended as it's easier to identify which resources belong to your cluster and avoid accidental deletions.

Troubleshooting Deletion Issues
Cluster Still Protected
If you get an error about the cluster being protected:

Check Configuration: Ensure protect_against_deletion: false is set in your config file
Verify Cluster Name: Make sure you're entering the correct cluster name when prompted
Check kubeconfig: Sometimes the cluster name is read from the kubeconfig location
Resources Stuck in Deletion
If some resources are stuck and not being deleted:

Check Hetzner Console: Log in to the Hetzner Cloud Console to see the current state
Wait and Retry: Sometimes there's a delay in API updates, wait a few minutes and retry
Network Resources Not Deleted
If networks, firewall rules, or other network resources remain:

Check Dependencies: Make sure no instances are still using the network, load balancer or firewall
Delete Manually: Use the Hetzner Console or API to clean up remaining network resources
Alternative: Delete Entire Project
If your cluster is the only thing in the Hetzner Cloud project, you might find it easier to delete the entire project instead:

Go to Hetzner Cloud Console
Navigate to your project
Click on "Settings"
Select "Delete Project"
This will delete everything in the project, including any resources you might have forgotten about.

Warning: This is irreversible! Only do this if you're certain you don't need anything in the project.

Best Practices
Planning for Deletion
When setting up your cluster, consider:

Use Projects Wisely: Consider creating separate projects for different clusters or environments
Document Dependencies: Keep track of external resources that depend on your cluster
Post-Deletion Checklist
After deleting your cluster, verify:

No instances are running
No load balancers are active
No volumes are attached
No floating IPs are allocated
Network usage has stopped
Billing reflects the changes
Cost Monitoring
Monitor your Hetzner Cloud billing dashboard for a few days after deletion to ensure:

No unexpected charges appear
All compute resources have been properly terminated
Network and storage costs stop accumulating
If you see unexpected charges, check for orphaned resources that might need manual cleanup.

## Storage
hetzner-k3s provides integrated storage solutions for your Kubernetes workloads. The Hetzner CSI Driver is automatically installed during cluster creation, enabling seamless integration with Hetzner's block storage services. If you prefer not to use the driver, you can disable its installation by setting addons.csi_driver.enabled to false in the cluster configuration file. Keep in mind that the minimum size for a volume is 10 Gi.

Overview
Two storage classes are available:

hcloud-volumes (default): Uses Hetzner's block storage based on Ceph, providing replicated and highly available storage
local-path: Uses local node storage for maximum IOPS performance (disabled by default)
Hetzner Block Storage (hcloud-volumes)
Features
Replicated: Based on Ceph, ensuring data is replicated across multiple disks
Highly Available: Redundant storage with no single point of failure
Minimum Size: 10Gi (smaller requests will be automatically rounded up)
Maximum Size: 10Ti per volume
Dynamic Provisioning: Volumes are automatically created and attached when needed
Basic Usage
Create a Persistent Volume Claim (PVC) using the default storage class:


apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: my-data-pvc
spec:
accessModes:
- ReadWriteOnce
resources:
requests:
storage: 10Gi
This will automatically provision a 10Gi Hetzner volume and attach it to the pod that uses this PVC.

Example: WordPress with Persistent Storage

---
# Persistent Volume Claim for WordPress
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: wordpress-pvc
labels:
app: wordpress
spec:
accessModes:
- ReadWriteOnce
resources:
requests:
storage: 20Gi
---
# Persistent Volume Claim for MySQL
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: mysql-pvc
labels:
app: mysql
spec:
accessModes:
- ReadWriteOnce
resources:
requests:
storage: 10Gi
---
# MySQL Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
name: mysql
labels:
app: mysql
spec:
selector:
matchLabels:
app: mysql
template:
metadata:
labels:
app: mysql
spec:
containers:
- name: mysql
image: mysql:8.0
env:
- name: MYSQL_ROOT_PASSWORD
value: "rootpassword"
- name: MYSQL_DATABASE
value: "wordpress"
- name: MYSQL_USER
value: "wordpress"
- name: MYSQL_PASSWORD
value: "wordpress"
ports:
- containerPort: 3306
volumeMounts:
- name: mysql-storage
mountPath: /var/lib/mysql
volumes:
- name: mysql-storage
persistentVolumeClaim:
claimName: mysql-pvc
---
# WordPress Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
name: wordpress
labels:
app: wordpress
spec:
selector:
matchLabels:
app: wordpress
template:
metadata:
labels:
app: wordpress
spec:
containers:
- name: wordpress
image: wordpress:latest
env:
- name: WORDPRESS_DB_HOST
value: "mysql"
- name: WORDPRESS_DB_USER
value: "wordpress"
- name: WORDPRESS_DB_PASSWORD
value: "wordpress"
- name: WORDPRESS_DB_NAME
value: "wordpress"
ports:
- containerPort: 80
volumeMounts:
- name: wordpress-storage
mountPath: /var/www/html
volumes:
- name: wordpress-storage
persistentVolumeClaim:
claimName: wordpress-pvc
Local Path Storage
Overview
The Local Path storage class uses the node's local disk storage directly, providing higher IOPS and lower latency compared to network-attached storage. This is ideal for:

High-performance databases (Redis, MongoDB, PostgreSQL)
Caching systems
Temporary storage
Applications requiring maximum storage performance
Enabling Local Path Storage
To enable the local-path storage class, add this to your cluster configuration:


local_path_storage_class:
enabled: true
Usage Example

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: redis-cache-pvc
spec:
storageClassName: local-path
accessModes:
- ReadWriteOnce
resources:
requests:
storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
name: redis
spec:
selector:
matchLabels:
app: redis
template:
metadata:
labels:
app: redis
spec:
containers:
- name: redis
image: redis:alpine
ports:
- containerPort: 6379
volumeMounts:
- name: redis-data
mountPath: /data
volumes:
- name: redis-data
persistentVolumeClaim:
claimName: redis-cache-pvc
Important Considerations
Advantages of Local Path Storage: - Higher Performance: No network overhead, direct disk access - Lower Latency: Faster read/write operations - Reduced Cost: No additional costs for network storage

Limitations of Local Path Storage: - Not Highly Available: Data is tied to specific nodes - No Replication: Data loss occurs if node fails, so it works best when the application takes care of replication already - Limited to Single Node: Pod can only be scheduled on the node where data resides - Manual Migration: Data must be manually migrated when moving pods

Storage Class Comparison
Feature	hcloud-volumes	local-path
High Availability	✅ Yes	❌ No
Data Replication	✅ Yes	❌ No
Performance	Good (Network)	Excellent (Local)
Maximum Size	10Ti	Limited by node disk
Cost	Volume pricing	Included in instance
Use Case	Persistent data	Caching, temporary data, high-performance apps
Pod Migration	✅ Easy	❌ Manual
Advanced Storage Features
Volume Expansion
You can expand existing volumes online without downtime:


apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: my-expandable-pvc
spec:
accessModes:
- ReadWriteOnce
resources:
requests:
storage: 10Gi
To expand the volume:


# Edit the PVC to increase the size
kubectl edit pvc my-expandable-pvc

# Change storage: 10Gi to storage: 20Gi
The CSI driver will automatically resize the filesystem if supported.

Storage Best Practices
1. Choose the Right Storage Type
   Use hcloud-volumes for:
   Production databases
   Persistent application data
   Content that must survive pod restarts
   Applications requiring high availability

Use local-path for:

Caching layers (Redis, Memcached) and databases (Postgres, MySQL)
Temporary file storage
High-performance computing workloads
Applications that can tolerate data loss
2. Monitor Storage Usage

# Check PVC usage
kubectl get pvc -A
kubectl describe pvc <pvc-name>

# Check actual disk usage on nodes
kubectl get nodes -o wide
ssh root@<node-ip> 'df -h'
3. Set Resource Limits

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: monitored-pvc
spec:
accessModes:
- ReadWriteOnce
resources:
requests:
storage: 10Gi
# Optional: Set resource limits (enforced by storage class)
limits:
storage: 20Gi
4. Use Storage Classes Appropriately

# Explicitly specify storage class
spec:
storageClassName: hcloud-volumes  # or local-path
5. Implement Backup Strategies
   Application-level Backups: Implement regular backups using tools like velero, restic, or application-specific backup solutions
   Off-server Backups: Ensure critical data is backed up to external storage or cloud storage
   Monitoring: Set up alerts for storage usage and disk space
   Troubleshooting Storage Issues
   PVC Stuck in Pending
   Check Storage Class:


kubectl get sc
Verify PVC Definition:


kubectl describe pvc <pvc-name>
Check CSI Driver Status:


kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system <csi-pod-name>
Volume Mount Failures
Check Volume Attachment:


kubectl get pv
kubectl describe pv <pv-name>
Verify Pod Definition:


kubectl describe pod <pod-name>
Check Node Capacity:


kubectl describe node <node-name>
Performance Issues
Monitor I/O:


kubectl exec -it <pod-name> -- iostat -x 1
Check Storage Type: Ensure you're using the right storage class for your workload

Consider Local Storage: For high-performance workloads, consider switching to local-path

Cost Optimization
hcloud-volumes Costs
Monthly Charge: Based on volume size (€0.04/GB per month)
Optimization Strategies
Right-size Volumes: Start with smaller sizes and expand as needed
Use Local Storage: For temporary or high-performance data
Monitor Usage: Identify and reclaim unused storage
Monitoring Commands

# Check storage usage across all namespaces
kubectl get pvc -A --no-headers | awk '{print $4, $5}'

# List all storage classes
kubectl get sc

# Check CSI driver pods
kubectl get pods -n kube-system | grep -E '(csi|storage)'

# Check volume health
kubectl get pv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.spec.capacity.storage,STORAGE-CLASS:.spec.storageClassName

## Floating IP egress
To allow for a unique IP for every call getting from your Cluster, enable Cilim egress


networking:
cni:
enabled: true
mode: cilium
cilium_egress_gateway: true
Also add a node that will be the middle man


worker_node_pools:
- name: egress
  instance_type: cax21
  location: hel1
  instance_count: 1
  autoscaling:
  enabled: false
  labels:
    - key: node.kubernetes.io/role
      value: "egress"
      taints:
    - key: node.kubernetes.io/role
      value: egress:NoSchedule
      Then assign a floating IP to that node.


apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
name: egress-global
spec:
selectors:
- podSelector: {}

destinationCIDRs:
- "0.0.0.0/0"
excludedCIDRs:
- "10.0.0.0/8"

egressGateway:
nodeSelector:
matchLabels:
node.kubernetes.io/role: egress
egressIP: YOUR_FLOATING_IP
That policy makes it so the outgoing traffic goes from YOUR_FLOATING_IP

## The 'run' Command
The hetzner-k3s run command allows you to execute a single command or an entire script on either all nodes in your cluster or on a specific instance. This is particularly useful for maintenance tasks, configuration updates, and automated operations across your cluster.

Command Overview

hetzner-k3s run --config <config-file> [options]
Required Parameters
--config, -c: The path to your cluster configuration YAML file
Execution Modes
1. Running Commands
   Execute a single command on all cluster nodes:


hetzner-k3s run --config cluster.yaml --command "sudo apt update && sudo apt upgrade -y"
Execute a single command on a specific instance:


hetzner-k3s run --config cluster.yaml --command "hostname" --instance "worker-node-1"
2. Running Scripts
   Execute a script file on all cluster nodes:


hetzner-k3s run --config cluster.yaml --script fix-ssh.sh
Execute a script file on a specific instance:


hetzner-k3s run --config cluster.yaml --script fix-ssh.sh --instance "master-node-1"
Option Parameters
--command: The shell command to execute
--script: The path to a script file to execute
--instance: The name of a specific instance to run the command/script on (if not specified, runs on all instances)
Note: You must specify exactly one of either --command or --script.

Examples
Example 1: Check system information on all nodes

hetzner-k3s run --config my-cluster.yaml --command "uname -a && df -h"
Example 2: Update packages on a specific worker node

hetzner-k3s run --config my-cluster.yaml --command "sudo apt update && sudo apt list --upgradable" --instance worker-1
Example 3: Run the SSH fix script on all nodes

hetzner-k3s run --config my-cluster.yaml --script fix-ssh.sh
Example 4: Run a custom maintenance script on master node only

hetzner-k3s run --config my-cluster.yaml --script maintenance.sh --instance master-1
How It Works
Command Execution
When using --command, hetzner-k3s: 1. Connects to each instance via SSH 2. Executes the specified command directly 3. Captures and displays the output 4. Returns the command completion status

Script Execution
When using --script, hetzner-k3s: 1. Validates the script file exists and is readable 2. Uploads the script to /tmp/<script-name> on each instance 3. Makes the script executable 4. Executes the script 5. Captures and displays the output 6. Automatically cleans up by removing the uploaded script file

Parallel Execution
The run command executes operations in parallel across all instances, significantly reducing the time required for cluster-wide operations. Each instance's output is displayed separately for clarity.

User Confirmation
Before execution, the command displays: - A summary of instances that will be affected - The command or script to be executed - A confirmation prompt requiring you to type "continue" to proceed

Error Handling
The command handles various error scenarios:

SSH Connection Issues: If SSH connection fails, the error is displayed and execution continues on other instances
Script File Not Found: If the specified script file doesn't exist, the command exits with an error
Permission Issues: If the script file is not readable, the command exits with an error
Instance Not Found: If a specific instance name doesn't exist in the cluster, the command exits with an error
Output Format
Output is organized by instance, making it easy to identify which node produced which output:


Found 3 instances in the cluster
Command to execute: hostname

Nodes that will be affected:
- master-1 (192.168.1.100)
- worker-1 (192.168.1.101)
- worker-2 (192.168.1.102)

Type 'continue' to execute this command on all nodes: continue

=== Instance: master-1 (192.168.1.100) ===
master-1
Command completed successfully

=== Instance: worker-1 (192.168.1.101) ===
worker-1
Command completed successfully

=== Instance: worker-2 (192.168.1.102) ===
worker-2
Command completed successfully
Security Considerations
Commands and scripts are executed with the permissions of the SSH user
Use sudo within commands/scripts when root privileges are required
Scripts are uploaded to /tmp/ and executed from there, then automatically cleaned up
Ensure your script files have appropriate permissions and are secure
Use Cases
Maintenance Operations
System updates: --command "sudo apt update && sudo apt upgrade -y"
Log cleanup: --command "sudo journalctl --vacuum-time=7d"
Service restarts: --command "sudo systemctl restart docker"
Configuration Management
Apply configuration changes across all nodes
Deploy configuration files using scripts
Update system settings
Troubleshooting
Check system status: --command "systemctl status"
Examine logs: --command "journalctl -u k3s-agent -n 50"
Verify network connectivity: --command "ping -c 3 google.com"
Security Updates
Apply security patches cluster-wide
Update SSH configurations (like the fix-ssh.sh script)
Modify firewall rules
Tips and Best Practices
Test on a single instance first: Use --instance to test commands/scripts on one node before applying to all nodes
Use idempotent operations: Design commands/scripts to be safe to run multiple times
Capture output: For long-running operations, consider redirecting output to files
Handle errors gracefully: Include error handling in your scripts when appropriate
Use absolute paths: In scripts, prefer absolute paths to avoid path-related issues
Integration with Cluster Operations
The run command is particularly powerful when combined with other hetzner-k3s operations:

Use after cluster creation to apply initial configurations
Run pre-upgrade checks before upgrading cluster components
Execute post-upgrade verification commands
Apply security patches across the entire cluster efficiently

## Troubleshooting
Common Issues and Solutions
SSH Connection Problems
If the tool stops working after creating instances and you experience timeouts, the issue might be related to your SSH key. This can happen if you're using a key with a passphrase or an older key, as newer operating systems may no longer support certain encryption methods.

Solutions: 1. Enable SSH Agent: Set networking.ssh.use_agent to true in your configuration file. This lets the SSH agent manage the key.

For macOS:


eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/<private key>
For Linux:


eval "$(ssh-agent -s)"
ssh-add ~/.ssh/<private key>
Test SSH Manually: Verify you can SSH to the instances manually:


ssh -i ~/.ssh/your_private_key root@<server_ip>
Check Key Permissions: Ensure your private key has correct permissions:


chmod 600 ~/.ssh/your_private_key
Enable Debug Mode
You can run hetzner-k3s with the DEBUG environment variable set to true for more detailed output:


DEBUG=true hetzner-k3s create --config cluster_config.yaml
This will provide more detailed output, which can help you identify the root of the problem.

Cluster Creation Fails after Node Creation
Symptoms: Instances are created but cluster setup fails.

Possible Causes: - Network connectivity issues between nodes - Firewall blocking communication - Hetzner API rate limits

Solutions: 1. Check Network Connectivity: Verify nodes can communicate with each other 2. Review Firewall Rules: Ensure necessary ports are open 3. Wait and Retry: If it's a rate limit issue, wait a few minutes and retry

Load Balancer Issues
Symptoms: Load balancer stuck in "pending" state

Solutions: 1. Check Annotations: Ensure proper annotations are set on your services 2. Verify Location: Make sure the load balancer location matches your node locations 3. Check DNS Configuration: If using hostname annotation, ensure DNS is properly configured

Node Not Ready
Symptoms: Nodes show up as NotReady status

Solutions: 1. Check Node Status:


kubectl describe node <node-name>
kubectl get nodes -o wide
Check Kubelet:


ssh -i ~/.ssh/your_private_key root@<node-ip>
systemctl status k3s-agent  # for workers
systemctl status k3s-server  # for masters
journalctl -u k3s-agent -f
Restart K3s:


ssh -i ~/.ssh/your_private_key root@<node-ip>
systemctl restart k3s-agent  # or k3s-server
Pod Stuck in Pending State
Symptoms: Pods remain in Pending state indefinitely

Solutions: 1. Check Resource Availability:


kubectl describe pod <pod-name> -n <namespace>
Look for events indicating insufficient resources.
Add More Nodes: If nodes are at capacity, either scale up existing node pools or add new nodes

Check Taints and Tolerations: Ensure pods have tolerations for any node taints

Storage Issues
Symptoms: PVCs stuck in Pending state, pods can't mount volumes

Solutions: 1. Check Storage Classes:


kubectl get sc
Describe PVC:


kubectl describe pvc <pvc-name> -n <namespace>
Check CSI Driver:


kubectl get pods -n kube-system | grep csi
Network Plugin Issues
Symptoms: Pods can't communicate with each other, DNS resolution fails

Solutions: 1. Check CNI Pods:


kubectl get pods -n kube-system | grep -E '(flannel|cilium)'
Restart CNI: Restart the relevant CNI pods
Upgrade Issues
Symptoms: Cluster upgrade process gets stuck

Solutions: 1. Clean up Upgrade Resources:


kubectl -n system-upgrade delete job --all
kubectl -n system-upgrade delete plan --all
Remove Labels:


kubectl label node --all plan.upgrade.cattle.io/k3s-server- plan.upgrade.cattle.io/k3s-agent-
Restart Upgrade Controller:


kubectl -n system-upgrade rollout restart deployment system-upgrade-controller
Getting Help
If you're still experiencing issues after trying these solutions:

Check GitHub Issues: Search existing issues at github.com/vitobotta/hetzner-k3s/issues
Create New Issue: If your issue hasn't been reported, create a new issue with:
Your configuration file (redacted)
Full debug output (DEBUG=true hetzner-k3s ...)
Operating system and Hetzner-k3s version
Steps to reproduce the issue
GitHub Discussions: For general questions and discussions, use GitHub Discussions
Useful Commands for Troubleshooting

# Check cluster status
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check events
kubectl get events -A --sort-by='.metadata.creationTimestamp'

# Check specific pod details
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Check node details
kubectl describe node <node-name>

# Check network connectivity
kubectl run test-pod --image=busybox -- sleep 3600
kubectl exec -it test-pod -- nslookup kubernetes.default
kubectl exec -it test-pod -- ping <other-pod-ip>

