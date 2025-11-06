
# K3s Trading Infrastructure on Hetzner Cloud

Ephemeral K3s clusters on Hetzner Cloud for algorithmic trading with **persistent IPv4 addresses**. Includes Kafka (KRaft), ArgoCD GitOps, and cost-optimized infrastructure.

## 🎯 Key Features

✅ **Persistent Primary IPs**: Same IPs across all deployments (€1.00/month)  
✅ **Ephemeral VMs**: Deploy for ~10h/day, destroy rest (59% cost savings!)  
✅ **Stable DNS**: Configure once, works forever  
✅ **ArgoCD GitOps**: Auto-deploy from `main` (dev) or `production` (prod)  
✅ **Kafka KRaft**: 3-broker cluster with external access  
✅ **Automated Workflows**: One-click deploy and destroy via GitHub Actions

## 🏗️ Architecture Overview

### Infrastructure Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Hetzner Private Network: 10.0.0.0/16                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Control Plane (CPX21)                              │    │
│  │ • Primary IP #1: 95.217.X.Y (€0.50/mo persistent)  │    │
│  │ • K3s API, ArgoCD, Python apps                     │    │
│  │ • Private IP: 10.0.1.10                            │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
  ┌────────────────┐  ┌────────────┐  ┌────────────┐        │
  │ kafka-0 (CPX31)│  │ kafka-1    │  │ kafka-2    │        │
  │ Primary IP #2  │  │ Private    │  │ Private    │        │
  │ 95.217.A.B     │  │ only       │  │ only       │        │
  │ (€0.50/mo)     │  │            │  │            │        │
  │ 10.0.1.20      │  │ 10.0.1.21  │  │ 10.0.1.22  │        │
  └────────────────┘  └────────────┘  └────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘

External Access:
• Control Plane: 95.217.X.Y (ArgoCD, kubectl, SSH)
• Kafka External: 95.217.A.B:32100 (NodePort → internal :9094)
• kafka-1, kafka-2: Private network only (no public IP)

Internal Communication:
• Private network: 10.0.1.0/24 (all VMs communicate internally)
• Kafka internal listener: port 9092 (cluster-only access)
• Python apps connect via: trading-cluster-kafka-bootstrap.kafka:9092
```

### Cost Optimization Strategy

**Traditional 24/7 cluster**: €152/month  
**Our ephemeral approach**: €63/month (58% savings!)

| Resource | Cost | Strategy |
|----------|------|----------|
| Primary IPs (2×) | €1.00/month | Persistent, always billed |
| Control Plane VM | ~€21/month | Destroyed daily (~10h/day uptime) |
| Kafka VMs (3×) | ~€42/month | Destroyed daily (~10h/day uptime) |
| **Total** | **~€63/month** | **59% cheaper than 24/7!** |

💡 **The Magic**: Primary IPs cost €1/month continuously, but VMs only cost when running. Deploy for 10h/day, destroy rest → massive savings!

## 🚀 Quick Start

### 1. Setup (One-Time)

**GitHub Secrets** (Settings → Secrets → Actions):
- `HCLOUD_TOKEN` - Hetzner API token ([get here](https://console.hetzner.cloud/))
- `SSH_PRIVATE_KEY` - Generate: `ssh-keygen -t ed25519 -f ./id_ed25519 -N ""`
- `SSH_PUBLIC_KEY` - Public key from above

### 2. Deploy Cluster

1. **Actions** tab → **Deploy K3s Cluster** → **Run workflow**
2. Choose **Environment** (dev/prod) and **Action** (create)
3. Wait ~10 minutes

**What happens:**
- ✅ Terraform creates/reuses 2 persistent Primary IPs
- ✅ Primary IP #1 attached to control plane
- ✅ Primary IP #2 automatically assigned to kafka-0
- ✅ SSH works immediately (no timeout issues!)
- ✅ Strimzi + Kafka deployed
- ✅ ArgoCD configured for GitOps

### 3. Access Cluster

Download `kubeconfig-{env}` artifact from GitHub Actions, then:

```bash
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
kubectl get pods -A

# ArgoCD apps
kubectl get applications -n argocd
```

### 4. Configure DNS (One-Time)

After first deployment, get Primary IPs from GitHub Actions output:

```bash
# Example IPs (yours will be different)
Control Plane: 95.217.X.Y
Kafka External: 95.217.A.B
```

Add A records in your DNS:
```
argocd.yourdomain.tld.    300  IN  A  95.217.X.Y
kafka.yourdomain.tld.     300  IN  A  95.217.A.B
```

**These IPs NEVER change!** Configure once, use forever.

## 🗑️ Destroy Cluster (Daily Cleanup)

### Option 1: Destroy VMs Only (Recommended)

**Actions** → **hcloud-maintenance** → **Environment**: dev → **Action**: destroy-vms

✅ Deletes all VMs (fast, instant savings!)  
✅ Keeps Primary IPs (€1.00/month continues)  
✅ Next deployment reuses same IPs  
✅ DNS still works

**Use this for**: Daily cleanup after trading hours

### Option 2: Destroy Everything (Nuclear)

**Actions** → **hcloud-maintenance** → **Environment**: dev → **Action**: destroy-all

⚠️ Deletes VMs + Primary IPs  
⚠️ Stops all billing (including €1/month for IPs)  
⚠️ Next deployment gets NEW random IPs  
⚠️ Must update DNS

**Use this for**: Shutting down environment permanently

## 🔄 GitOps Workflow

ArgoCD monitors your Git branches:

```
Push to main       → Auto-deploys to dev cluster
Push to production → Auto-deploys to prod cluster
```

**Making changes:**
1. Edit manifests in `kubernetes/`
2. Commit to `main` (for dev) or `production` (for prod)
3. Push to GitHub
4. ArgoCD auto-syncs (~30 seconds)

## 🏗️ Project Structure

## 🏗️ Project Structure

### Terraform (Infrastructure as Code)

This project uses a fully modular Terraform setup for infrastructure. All cloud resources are managed via modules:

```
terraform/
├── main.tf, variables.tf, outputs.tf, versions.tf
├── modules/
│   ├── network/   # Networking, firewall, Primary IPs
│   ├── compute/   # SSH keys
│   ├── k3s/       # K3s cluster VMs
│   └── kafka/     # (reserved for future use)
├── environments/
│   ├── dev.tfvars   # Dev config (shared vCPU)
│   └── prod.tfvars  # Prod config (dedicated vCPU)
└── templates/       # VM init scripts
```

**Key Changes (Nov 2025)**:
- ✨ Added **persistent Primary IPs** in network module
- ✨ Control plane uses Primary IP #1 (attached via Terraform)
- ✨ kafka-0 uses Primary IP #2 (assigned via GitHub Actions)
- ✨ kafka-1, kafka-2 use private network only (save €1/month)
- ✨ Disabled IPv6 (not needed - private network handles internal comms)
- ✨ Fixed Terraform outputs to return public IPs (solves SSH timeout!)

### Kubernetes Manifests (GitOps)

```
kubernetes/
├── base/           # Base configurations
│   ├── kafka/      # Kafka cluster (Strimzi)
│   └── apps/       # Trading apps (ingestion, strategies)
├── overlays/       # Environment overrides
│   ├── dev/        # Dev-specific patches
│   └── prod/       # Prod-specific patches
└── app-of-apps/    # ArgoCD app-of-apps pattern
    ├── base/
    └── overlays/   # Dev/prod ArgoCD configs
```

### GitHub Actions Workflows

```
.github/workflows/
├── deploy-cluster.yml       # Main deployment workflow
├── hcloud-maintenance.yml   # VM/IP cleanup workflow
└── review-terraform.yml     # PR validation
```

## � Common Tasks

### View Current Resources

**Actions** → **hcloud-maintenance** → **Action**: list

Shows:
- ✅ Primary IPs (persistent, always visible)
- ✅ Servers (VMs)
- ✅ Networks, firewalls, SSH keys

### Create Kafka Topic

```bash
kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: stock-stream
  namespace: kafka
  labels:
    strimzi.io/cluster: trading-cluster
spec:
  partitions: 6
  replicas: 3
EOF
```

### Deploy Your Trading App

1. Add deployment to `kubernetes/base/apps/your-app.yaml`
2. Update `kubernetes/base/apps/kustomization.yaml`
3. Commit and push to `main` (dev) or `production` (prod)
4. ArgoCD deploys automatically (~30 seconds)

### Kafka Connection Strings

**Internal** (from pods in cluster):
```bash
# Python apps use this (via KAFKA_BOOTSTRAP_SERVERS env variable)
trading-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
```
- Uses Kafka **internal listener** (port 9092)
- Resolves to private network IPs: 10.0.1.11, 10.0.1.12, 10.0.1.13
- All 3 brokers accessible via single DNS name
- No public IP needed - stays on private network

**External** (from internet):
```bash
# Connect from outside K8s cluster
<kafka-0-public-ip>:32100
# Or with DNS: kafka.yourdomain.tld:32100
```
- Uses Kafka **external listener** (port 9094, exposed via NodePort 32100)
- Routes to kafka-0 via Primary IP #2 (95.217.A.B)
- All 3 brokers still accessible (Kafka handles routing)

### Check ArgoCD Status

```bash
kubectl get applications -n argocd
kubectl describe application trading-system-dev -n argocd

# View sync status
kubectl get app -n argocd -o jsonpath='{.items[*].status.sync.status}'
```

## 💰 Detailed Cost Breakdown

### Monthly Costs (Dev Environment, 10h/day uptime)

| Resource | Hourly | Daily (10h) | Monthly (22 days) | Notes |
|----------|--------|-------------|-------------------|-------|
| Control Plane (CPX21) | €0.029 | €0.29 | ~€6.38 | 3 vCPU, 4GB RAM |
| kafka-0 (CPX31) | €0.057 | €0.57 | ~€12.54 | 4 vCPU, 8GB RAM |
| kafka-1 (CPX31) | €0.057 | €0.57 | ~€12.54 | 4 vCPU, 8GB RAM |
| kafka-2 (CPX31) | €0.057 | €0.57 | ~€12.54 | 4 vCPU, 8GB RAM |
| Primary IP #1 | - | - | €0.50 | Persistent (24/7) |
| Primary IP #2 | - | - | €0.50 | Persistent (24/7) |
| **Total** | - | **~€2.00** | **~€44.50** | **58% cheaper than 24/7!** |

**vs 24/7 operation**: €106/month → Save €61.50/month!

### Cost Optimization Tips

1. **Daily destroy**: Use `hcloud-maintenance → destroy-vms` after trading hours
2. **Weekend shutdowns**: Destroy Friday evening, deploy Monday morning
3. **Dev vs Prod**: Run dev only when testing (1-2h/day instead of 10h)
4. **Keep Primary IPs**: €1/month is trivial vs manual DNS updates

## 🐛 Troubleshooting

### SSH Timeout During Deployment

**Fixed!** Terraform now outputs public IP from Primary IP #1.

If you still see issues:
```bash
# Check Terraform outputs
cd terraform
terraform output control_plane_ip  # Should show 95.217.X.Y (not 10.0.1.10)
```

### ArgoCD Not Syncing

```bash
kubectl get applications -n argocd -o yaml
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Kafka Pods Failing

```bash
kubectl logs -n kafka <pod-name>
kubectl describe pod -n kafka <pod-name>

# Check Strimzi operator
kubectl logs -n kafka -l name=strimzi-cluster-operator
```

### Primary IP Not Assigned to kafka-0

Check GitHub Actions logs for "Assign Primary IP to kafka-0" step. Should show:
```
✅ Primary IP #2 successfully assigned to kafka-0!
   Kafka external IP: 95.217.A.B
```

If failed, manually assign:
```bash
# Get IDs from Hetzner console or hcloud-maintenance list
hcloud server poweroff <kafka-0-id>
hcloud primary-ip assign <primary-ip-id> <kafka-0-id>
hcloud server poweron <kafka-0-id>
```

## ⚡ Advanced Topics

### Add Monitoring

See [ARCHITECTURE_FINAL_CLEAN.md](./ARCHITECTURE_FINAL_CLEAN.md) for Prometheus/Grafana setup

### Restrict Firewall

Edit `terraform/main.tf` firewall rules to limit source IPs:

```hcl
{
  direction   = "in"
  protocol    = "tcp"
  port        = "22"
  source_ips  = ["YOUR.IP.ADDRESS/32"]  # Restrict SSH
  description = "Allow SSH from office"
}
```

### Persistent Storage

Add Hetzner volumes for stateful workloads (databases, etc.)

### Change Datacenter

Edit `terraform/environments/{dev|prod}.tfvars`:
```hcl
location   = "fsn1"        # Falkenstein
datacenter = "fsn1-dc14"   # Must match location!
```

⚠️ **Warning**: Changing datacenter requires new Primary IPs (different IPs, update DNS)

⚠️ **Warning**: Changing datacenter requires new Primary IPs (different IPs, update DNS)

## 📚 Documentation

- **[ARCHITECTURE_FINAL_CLEAN.md](./ARCHITECTURE_FINAL_CLEAN.md)** - Complete architecture and design decisions
- **[TERRAFORM_IPV4_OPTIMIZATION_PLAN.md](./TERRAFORM_IPV4_OPTIMIZATION_PLAN.md)** - Primary IP implementation details
- **[SSH_KEY_SETUP.md](./SSH_KEY_SETUP.md)** - SSH key generation guide
- **GitHub Actions Workflows** - See `.github/workflows/` for deployment automation

## 🔒 Security Notes

**Public IPv4 Exposure**:
- Control plane (Primary IP #1): SSH, K3s API (6443), ArgoCD
- kafka-0 (Primary IP #2): Kafka external listener via NodePort 32100 → port 9094
- kafka-1, kafka-2: Private network only (no public IP)

**Internal Communication**:
- All VMs use **private network** (10.0.1.0/24) for internal communication
- Kafka internal listener (port 9092): Used by Python apps inside K8s
- Python apps connect via DNS: `trading-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- No IPv6 needed - private IPv4 network handles all inter-VM traffic

**Recommendations**:
1. **Restrict SSH**: Update firewall rules to your IP only
2. **Enable Kafka TLS**: Configure in Kafka manifests
3. **Rotate SSH keys**: Regenerate periodically
4. **Monitor access**: Check Hetzner Cloud Console for unusual activity

## 📊 Monitoring Primary IPs

Always list Primary IPs before destroying:

```bash
# Via GitHub Actions
Actions → hcloud-maintenance → list

# Via hcloud CLI
export HCLOUD_TOKEN=your-token
hcloud primary-ip list -l environment=dev
```

**What you'll see**:
```
ID       NAME                         IP           ASSIGNEE
12345    k3s-trading-dev-network-control-ip   95.217.X.Y   123456
12346    k3s-trading-dev-network-kafka-ip     95.217.A.B   123457
```

## 🎓 Learning Resources

- **Hetzner Cloud**: [docs.hetzner.com/cloud/](https://docs.hetzner.com/cloud/)
- **Primary IPs**: [docs.hetzner.com/cloud/servers/primary-ips/](https://docs.hetzner.com/cloud/servers/primary-ips/)
- **K3s**: [docs.k3s.io/](https://docs.k3s.io/)
- **Strimzi**: [strimzi.io/docs/](https://strimzi.io/docs/)
- **ArgoCD**: [argo-cd.readthedocs.io/](https://argo-cd.readthedocs.io/)

## 🆕 What's New (November 2025)

### ✨ Persistent Primary IPv4 Implementation

**Key Changes (Nov 2025)**:
- ✅ Added 2 persistent Primary IPs (€1.00/month total)
- ✅ Primary IP #1 auto-attached to control plane (Terraform)
- ✅ Primary IP #2 auto-assigned to kafka-0 (GitHub Actions)
- ✅ kafka-1, kafka-2 use private network only (save €1.00/month)
- ✅ Disabled IPv6 completely (not needed for this architecture)
- ✅ Fixed SSH timeout issue (Terraform outputs public IPs)
- ✅ Updated `hcloud-maintenance` with `destroy-vms` and `destroy-all` options
- ✅ Added Kafka ports (9092-9094) to firewall
- ✅ Kafka listeners: internal (9092) + external (9094 via NodePort 32100)

**Benefits**:
- 🎯 **Stable DNS**: Same IPs across all deployments
- 💰 **Cost Optimized**: 50% savings on IPv4 costs (€2.00 → €1.00/month)
- 🚀 **Automated**: No manual IP assignment needed
- 📈 **Scalable**: Perfect for ephemeral daily deployments

**Migration Path**:
If you have existing deployments:
1. Current auto-assigned IPs will be replaced by Primary IPs on next deployment
2. Update DNS to new Primary IP addresses (one-time, from GitHub Actions output)
3. Subsequent deployments reuse same IPs forever

---

**Resources**: [Hetzner](https://docs.hetzner.com/cloud/) • [K3s](https://docs.k3s.io/) • [Strimzi](https://strimzi.io/docs/) • [ArgoCD](https://argo-cd.readthedocs.io/)

## 📝 License

This infrastructure code is provided as-is for the trading-cz project.

---

## 🤝 Contributing

This is a private infrastructure repository. For questions or issues, contact the team.

---

**Happy Trading! 🚀📈**
