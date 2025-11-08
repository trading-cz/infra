Objectives
1. Provision Infrastructure Declaratively
Manage all Hetzner resources (servers, networks, firewalls, volumes) via Terraform.
Keep infrastructure state versioned and environment-specific.



2. Bootstrap K3s Clusters Automatically
Install K3s via cloud-init for simplicity and reproducibility.
Output a working kubeconfig file for each environment.

   
3. Prepare for Future GitOps Management
Install Argo CD (base deployment) to allow later GitOps control.
Create a secondary VM for future Kafka/Strimzi workloads.

   
---

🏗️ Architecture Overview

Phase 1: Terraform (this stage)
Terraform creates and configures:
Hetzner network, SSH keys, and firewalls

2 VMs per environment:
vm-k3s → runs K3s and ArgoCD (bootstrap)
vm-kafka → reserved for future Strimzi/Kafka workloads
Installs K3s and ArgoCD on vm-k3s using cloud-init

Phase 2: GitOps (next stage)
Argo CD will later:
Manage Prometheus, Grafana, and Kafka deployments
Reconcile Git state into the cluster continuously
---

🧱 Infrastructure Design
Component	Dev	Prod	Purpose
Network	dev-net	prod-net	Private cluster communication
K3s Node	dev-k3s	prod-k3s	Control plane & Argo CD
Kafka Node	dev-kafka	prod-kafka	Future Kafka workloads
Firewall	dev-fw	prod-fw	SSH (22), HTTPS (443), K3s (6443)
SSH Key	Shared	Shared	Used for provisioning access


| Names  | Status | Labels |
|--------|--------|--------|
| k3s-trading-dev-control  | Ready |   node-role.kubernetes.io/control-plane=true,... |
| k3s-trading-dev-kafka-0  | Ready |   node-role.kubernetes.io/kafka=true,... |


---

📁 Repository Structure

infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── modules/
│   ├── network/
│   │   └── main.tf
│   ├── k3s-server/
│   │   ├── main.tf
│   │   ├── cloud-init.yaml
│   │   └── variables.tf
│   └── kafka-server/
│       ├── main.tf
│       ├── cloud-init.yaml
│       └── variables.tf
└── README.md


---

⚙️ Terraform Implementation Plan
1. Providers & Backend

Use:
hcloud provider (Hetzner)
Optional: remote backend (Terraform Cloud, S3-compatible, or local)
Manage state separately per environment

Example in each environment:

terraform {
required_providers {
hcloud = {
source  = "hetznercloud/hcloud"
version = "~> 1.45.0"
}
}
backend "local" {
path = "terraform.tfstate"
}
}


---

2. Networking & Firewall

Define in modules/network/main.tf:

resource "hcloud_network" "main" {
name     = var.network_name
ip_range = var.network_cidr
}

resource "hcloud_network_subnet" "subnet" {
network_id   = hcloud_network.main.id
type         = "cloud"
network_zone = "eu-central"
ip_range     = var.subnet_cidr
}

resource "hcloud_firewall" "main" {
name = var.firewall_name

rule {
direction  = "in"
protocol   = "tcp"
port       = "22"
source_ips = ["0.0.0.0/0", "::/0"]
}

rule {
direction  = "in"
protocol   = "tcp"
port       = "6443"
source_ips = ["0.0.0.0/0", "::/0"]
}

rule {
direction  = "in"
protocol   = "tcp"
port       = "443"
source_ips = ["0.0.0.0/0", "::/0"]
}
}


---

3. K3s Node with Argo CD (cloud-init)

In modules/k3s-server/cloud-init.yaml:

#cloud-config
runcmd:
- apt-get update -y
- apt-get install -y curl
- curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init" sh -
# Install ArgoCD
- kubectl create namespace argocd
- kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

And the Terraform definition:

resource "hcloud_server" "k3s" {
name        = "${var.env}-k3s"
server_type = "cx23"
image       = "ubuntu-22.04"
location    = var.location
ssh_keys    = [hcloud_ssh_key.main.id]
networks    = [hcloud_network.main.id]
user_data   = file("${path.module}/cloud-init.yaml")
}


---

4. Kafka VM (future use)

In modules/kafka-server/main.tf:

resource "hcloud_server" "kafka" {
name        = "${var.env}-kafka"
server_type = "cx23"
image       = "ubuntu-22.04"
location    = var.location
ssh_keys    = [hcloud_ssh_key.main.id]
networks    = [hcloud_network.main.id]
}


---

5. Outputs

Each environment outputs relevant details:

output "k3s_ip" {
value = hcloud_server.k3s.ipv4_address
}

output "kafka_ip" {
value = hcloud_server.kafka.ipv4_address
}

output "kubeconfig" {
value = "Run 'ssh root@${hcloud_server.k3s.ipv4_address} cat /etc/rancher/k3s/k3s.yaml' to get kubeconfig"
}


---

🧪 Usage Workflow
Bootstrap environment

cd infra/environments/dev
terraform init
terraform apply

Verify K3s
ssh root@<k3s_ip>
kubectl get nodes
kubectl get pods -A

Argo CD should already be running under the argocd namespace.
Future steps
Add ArgoCD bootstrap repo.
Use ArgoCD Applications to deploy Strimzi, Kafka CRs, Prometheus, and Grafana.

---

✅ Expected Outcome

After this phase:
Two environments (dev, prod) provisioned in Hetzner.
Each has:

A running K3s cluster with ArgoCD installed.
A secondary VM for future Kafka setup.

All configuration is declarative and stored in Git.

Terraform state separated per environment.

Next steps:
Introduce Argo CD “app-of-apps” pattern.
Manage Strimzi operator and Kafka clusters via GitOps.

Add monitoring stack (Prometheus, Grafana).