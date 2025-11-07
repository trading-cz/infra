# Copilot Instructions: K3s Trading Infrastructure

## Project Identity

**Repository**: `trading-cz/infra` (Branch: `main` for dev, `production` for prod)  
**Purpose**: Ephemeral K3s clusters on Hetzner Cloud for algorithmic trading  
**Architecture**: Cost-optimized (58% savings), persistent IPs, ephemeral VMs  
**Stack**: K3s v1.34.1+k3s1, Kafka 4.0.0 (Strimzi), Terraform v1.13.4

### Core Concept
- Deploy K3s clusters during trading hours (2-10h/day)
- Destroy VMs after hours → massive cost savings
- Persistent Primary IPs (€1/month) maintain stable DNS
- Kafka streaming pipeline: market data → trading strategies
- **Cost**: €20/month (vs €106/month 24/7)

---

## Technology Stack

- **IaC**: Terraform v1.13.4 (modular: network, compute, k3s)
- **Kubernetes**: K3s v1.34.1+k3s1
- **Message Broker**: Kafka 4.0.0 (Strimzi, KRaft mode)
- **GitOps**: ArgoCD (planned), Kustomize overlays
- **Cloud**: Hetzner (Nuremberg), CPX21/CPX31 VMs
- **Network**: Private 10.0.1.0/24 + 2 Primary IPv4s (€1/mo)

---

## Architecture (4 nodes)

```
k3s-control (CPX21): Primary IP #1 + 10.0.1.10
├─ K3s control plane, ArgoCD, Python apps
└─ Firewall: disabled (testing)

kafka-0 (CPX31): Primary IP #2 + 10.0.1.20
├─ Kafka broker, Prometheus
└─ External Kafka access via NodePort 32100

kafka-1/kafka-2 (CPX31): 10.0.1.21-22 (private only)
└─ Kafka brokers (no public IP = cost saving)
```

**Network**:
- Private: 10.0.1.0/24 (all inter-VM traffic)
- Primary IPs: €1/month, persist across deployments
- IPv6: Disabled

**Kafka Listeners**:
- Internal (9092): `trading-cluster-kafka-bootstrap.kafka:9092` (pod access)
- External (32100): `<kafka-0-ip>:32100` (internet access)

**Why 3 Kafka brokers?** KRaft quorum needs (N/2)+1 = 3 minimum for fault tolerance.

---

## Repository Structure

```
terraform/
├── main.tf, variables.tf, outputs.tf  # Root module
├── environments/{dev,prod}.tfvars     # CPX21 vs CPX31 configs
├── modules/
│   ├── network/    # VPC, firewall, Primary IPs
│   ├── compute/    # SSH keys
│   └── k3s/        # VMs + cloud-init scripts
└── templates/*.sh  # K3s bootstrap scripts

kubernetes/
├── base/{kafka,apps}/              # Shared configs
├── overlays/{dev,prod}/            # Env-specific patches
└── app-of-apps/argocd/             # ArgoCD CRs (future)

.github/workflows/
├── deploy-cluster.yml        # Terraform → K3s → Kafka
├── hcloud-maintenance.yml    # list|destroy-cluster|destroy-all
└── review-terraform.yml      # PR validation
```

---

## Key Workflows

### Deploy Cluster (GitHub Actions)
**Trigger**: Actions → Deploy K3s Cluster  
**Inputs**: environment (dev|prod)  
**Secrets**: `HCLOUD_TOKEN`, `SSH_PRIVATE_KEY`, `SSH_PUBLIC_KEY`

**Steps** (~10 min):
1. Terraform creates/reuses network, Primary IPs, 4 VMs
2. Attaches Primary IP #1 to control plane (Terraform)
3. Assigns Primary IP #2 to kafka-0 (hcloud CLI)
4. Cloud-init installs K3s on all nodes
5. Deploys Strimzi + Kafka cluster
6. Outputs kubeconfig artifact

### Destroy Cluster (Daily)
**Trigger**: Actions → hcloud-maintenance  
**Actions**:
- `destroy-cluster`: Delete VMs, keep Primary IPs (recommended)
- `destroy-all`: Delete everything including IPs (permanent shutdown)
- `list`: Show all resources

### Deploy Apps
**Current**: `kubectl apply -k kubernetes/overlays/{dev|prod}`  
**Future**: Push to `main`/`production` → ArgoCD auto-syncs

### Local Validation (PowerShell)
```powershell
$env:TF_VAR_ssh_public_key = Get-Content -Raw '.ssh/key.pub'
$env:TF_VAR_hcloud_token = Get-Content -Raw '.ssh/token'
$env:TF_VAR_environment = 'dev'
cd terraform; terraform.exe validate
```

---

## Configuration

### Terraform Secrets (GitHub Actions)
- `HCLOUD_TOKEN`: Hetzner API token
- `SSH_PRIVATE_KEY`: ED25519 private key (full with headers)
- `SSH_PUBLIC_KEY`: ED25519 public key

### Environment Configs (dev.tfvars vs prod.tfvars)
```hcl
# Dev: shared vCPU
kafka_server_type = "cpx21"  # €8.21/mo × 3

# Prod: dedicated vCPU
kafka_server_type = "cpx31"  # €16.32/mo × 3

k3s_version = "v1.34.1+k3s1"  # Both envs
```

### Kafka Config (kafka-cluster.yaml)
```yaml
version: 4.0.0
replicas: 3  # KRaft quorum minimum
listeners:
  - name: plain, port: 9092, type: internal
  - name: external, port: 9094, type: nodeport, nodePort: 32100
```

### Firewall (Testing - Currently Disabled on control/kafka-0)
```
22 (SSH), 6443 (K8s API), 80/443 (HTTP), 9092-9094 (Kafka), 30000-32767 (NodePort)
Source: 0.0.0.0/0 (TODO: restrict to your IP)
```
**Note**: Firewall only affects public IPs; private network always open.

---

## Troubleshooting

**SSH Timeout**: Fixed! Terraform outputs Primary IPs (not private IPs)
```bash
terraform output control_plane_ip  # Should show 95.217.X.Y
```

**Primary IP Not Assigned**: Check GitHub Actions logs → "Assign Primary IP to kafka-0"
```bash
hcloud server poweroff <kafka-0-id>
hcloud primary-ip assign <ip-id> <server-id>
hcloud server poweron <kafka-0-id>
```

**Kafka Pods Not Scheduling**: Check node labels
```bash
kubectl get nodes --show-labels | grep kafka  # Should see node-role.kubernetes.io/kafka=true
```

**ArgoCD Not Syncing**: Not actively used yet (manual kubectl apply)

---

## Cost Breakdown

**Primary IPs**: €1.00/mo (2× €0.50, 24/7 billing, enables DNS stability)

**VMs** (billed per hour):
- **Dev** (2h/day × 22d = 6% uptime): €0.49 + €1.48 = €1.97/mo
- **Prod** (10h/day × 22d = 30% uptime): €2.46 + €14.69 = €17.15/mo

**Total**: €20.12/mo vs €106/mo (24/7) = **58% savings**

---

## Development Guidelines

**Terraform**:
- Validate locally before committing
- Never run `terraform destroy` (use hcloud-maintenance workflow)
- Update both dev.tfvars and prod.tfvars
- Test in dev first

**Kubernetes**:
- Use Kustomize overlays for env-specific changes
- Keep base configs minimal
- Validate: `kubectl apply -k --dry-run=client`

**GitHub Actions**:
- Test in feature branch (review-terraform.yml validates)
- Never hardcode secrets
- Use `terraform fmt` before committing

---

## Quick Commands

```bash
# Access cluster (download kubeconfig from GitHub Actions artifacts)
export KUBECONFIG=./kubeconfig-dev.yaml
kubectl get nodes

# List resources
hcloud server list -l environment=dev
hcloud primary-ip list -l environment=dev

# Create Kafka topic
kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: stock-stream
  namespace: kafka
  labels: {strimzi.io/cluster: trading-cluster}
spec: {partitions: 6, replicas: 3}
EOF

# Test Kafka
# Internal: trading-cluster-kafka-bootstrap.kafka:9092
# External: <kafka-0-ip>:32100
```

**Resources**:
- Hetzner: https://console.hetzner.cloud/
- GitHub Actions: https://github.com/trading-cz/infra/actions
- Docs: K3s, Strimzi, Hetzner Primary IPs