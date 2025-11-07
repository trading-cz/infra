# Project Status & Structure Analysis

**Date**: November 6, 2025  
**Repository**: trading-cz/infra  
**Branch**: infra-tests

---

## Executive Summary

This is a **cost-optimized ephemeral Kubernetes infrastructure** for algorithmic trading on Hetzner Cloud. The system deploys temporary K3s clusters during trading hours and destroys them afterward, achieving **58% cost savings** compared to 24/7 operation.

**Total Monthly Cost**: ~€20.54 (vs €90.01 for 24/7)

---

## Technology Stack

### Core Components

| Component | Version | Purpose |
|-----------|---------|---------|
| **Kubernetes** | K3s v1.34.1+k3s1 | Lightweight cluster orchestration |
| **Message Broker** | Kafka 4.0.0 (Strimzi) | Data streaming (KRaft mode, no ZooKeeper) |
| **IaC** | Terraform v1.13.4 | Infrastructure provisioning |
| **GitOps** | ArgoCD | Application deployment (planned) |
| **Config Management** | Kustomize | Environment-specific overlays |
| **Cloud Provider** | Hetzner Cloud | VMs, networking (Nuremberg, Germany) |

### Infrastructure Resources

**Compute** (4 nodes):
- 1× CPX21 (3 vCPU, 4GB RAM) - Control plane
- 3× CPX31 (4 vCPU, 8GB RAM) - Kafka cluster (prod)
- 3× CPX21 (3 vCPU, 4GB RAM) - Kafka cluster (dev)

**Network**:
- Private network: 10.0.1.0/24 (all internal communication)
- 2× Primary IPv4 addresses (persistent, €0.50/month each)
- Firewall: Hetzner Cloud Firewall (public interfaces only)

**Storage**:
- Local VM storage (ephemeral)
- Hetzner Object Storage (planned for backups)

---

## Architecture

### Cluster Topology

```
┌─────────────────────────────────────────────────────────┐
│ Private Network: 10.0.1.0/24                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Node 1: k3s-control (CPX21)                           │
│  ├─ Public IP: Primary IP #1 (persistent)              │
│  ├─ Private IP: 10.0.1.10                              │
│  ├─ Workloads: K3s API, ArgoCD, Python apps            │
│  └─ Firewall: Disabled (testing)                       │
│                                                         │
│  Node 2: kafka-0 (CPX31)                               │
│  ├─ Public IP: Primary IP #2 (persistent)              │
│  ├─ Private IP: 10.0.1.20                              │
│  ├─ Workloads: Kafka broker, Prometheus                │
│  └─ Firewall: Disabled (testing)                       │
│                                                         │
│  Node 3: kafka-1 (CPX31)                               │
│  ├─ Public IP: None (cost optimization)                │
│  ├─ Private IP: 10.0.1.21                              │
│  ├─ Workloads: Kafka broker, Strimzi operator          │
│  └─ Firewall: Enabled (redundant - no public IP)       │
│                                                         │
│  Node 4: kafka-2 (CPX31)                               │
│  ├─ Public IP: None (cost optimization)                │
│  ├─ Private IP: 10.0.1.22                              │
│  ├─ Workloads: Kafka broker                            │
│  └─ Firewall: Enabled (redundant - no public IP)       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Kafka Listeners

**Internal Listener** (port 9092):
- DNS: `trading-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- Access: Private network only (K8s pods)
- Purpose: Python apps inside cluster

**External Listener** (port 9094 → NodePort 32100):
- DNS: `<kafka-0-public-ip>:32100`
- Access: Public internet via kafka-0's Primary IP #2
- Purpose: External producers/consumers, testing

### Why 3 Kafka Brokers?

KRaft quorum requires **(N/2) + 1** nodes for consensus:
- 3 brokers = 2-node quorum = survives 1 failure ✅
- 2 brokers = 2-node quorum = any failure = total outage ❌

---

## Repository Structure

### Terraform Modules

```
terraform/
├── main.tf                     # Root orchestration
├── variables.tf                # Variable declarations
├── outputs.tf                  # Exported values (IPs, IDs)
├── versions.tf                 # Provider constraints
├── environments/
│   ├── dev.tfvars             # CPX21 Kafka, shared vCPU
│   └── prod.tfvars            # CPX31 Kafka, dedicated vCPU
├── modules/
│   ├── network/               # VPC, firewall, Primary IPs
│   ├── compute/               # SSH keys
│   ├── k3s/                   # VMs + cloud-init scripts
│   └── kafka/                 # Empty (placeholder)
└── templates/
    ├── control-plane-init.sh  # K3s server bootstrap
    └── worker-init.sh         # K3s agent bootstrap
```

**Key Features**:
- Modular design (4 modules: network, compute, k3s, kafka)
- Primary IPs persist independently from VMs
- Cloud-init scripts bootstrap K3s automatically
- No remote backend (local state only)

### Kubernetes Manifests

```
kubernetes/
├── base/                       # Environment-agnostic configs
│   ├── kafka/
│   │   ├── kafka-cluster.yaml # Strimzi Kafka CR
│   │   └── kafka-metrics-config.yaml
│   └── apps/
│       ├── ingestion-example.yaml
│       └── strategy-example.yaml
├── overlays/                   # Environment-specific patches
│   ├── dev/
│   │   ├── kafka/patches.yaml # Smaller JVM heap
│   │   └── apps/patches.yaml  # Fewer resources
│   └── prod/
│       ├── kafka/patches.yaml # Larger JVM heap
│       └── apps/patches.yaml  # More resources
└── app-of-apps/                # ArgoCD hierarchy
    ├── argocd/
    │   ├── parent-app.yaml
    │   └── apps/
    │       ├── kafka-app.yaml
    │       └── trading-apps.yaml
    └── overlays/{dev,prod}/
```

**Key Features**:
- Kustomize overlays for dev/prod differences
- App-of-Apps pattern (future ArgoCD usage)
- Currently deployed via `kubectl apply -k`

### GitHub Actions Workflows

```
.github/workflows/
├── deploy-cluster.yml         # Main deployment
│   ├── Inputs: environment (dev|prod)
│   ├── Steps: Terraform → IP assignment → K3s setup
│   └── Artifacts: kubeconfig-{env}.yaml
├── hcloud-maintenance.yml     # Cleanup workflow
│   ├── Actions: list, destroy-cluster, destroy-all
│   └── Purpose: Daily VM destruction
└── review-terraform.yml       # PR validation
    ├── Checks: fmt, validate, tflint
    └── Triggers: PR on terraform/** or kubernetes/**
```

### Documentation

```
ROOT/
├── README.md                   # Main guide (quickstart, workflows)
├── ARCHITECTURE_FINAL_CLEAN.md # Detailed design decisions
├── GETTING_STARTED.md          # First-time setup
├── SSH_KEY_SETUP.md            # SSH key generation
├── TERRAFORM_IPV4_OPTIMIZATION_PLAN.md # Primary IP strategy
├── VERIFICATION_RESULTS.md     # Testing reports
└── .github/copilot-instructions.md # AI agent instructions
```

---

## Key Workflows

### 1. Deploy Cluster (GitHub Actions)

**Trigger**: Actions → Deploy K3s Cluster → Run workflow  
**Inputs**: environment (dev|prod)  
**Duration**: ~10 minutes

**Steps**:
1. Terraform creates/reuses network, firewall, Primary IPs
2. Terraform creates 4 VMs, attaches Primary IP #1 to control plane
3. Cloud-init installs K3s on all nodes
4. GitHub Actions assigns Primary IP #2 to kafka-0 via `hcloud` CLI
5. Waits for cluster readiness
6. Deploys Strimzi operator + Kafka cluster
7. Uploads kubeconfig artifact

**Secrets Required**:
- `HCLOUD_TOKEN` - Hetzner API token
- `SSH_PRIVATE_KEY` - ED25519 private key
- `SSH_PUBLIC_KEY` - ED25519 public key

### 2. Destroy Cluster (Daily Cleanup)

**Trigger**: Actions → hcloud-maintenance → Run workflow  
**Inputs**: env (dev|prod), action (list|destroy-cluster|destroy-all)

**destroy-cluster** (Recommended):
- Deletes: VMs, networks, firewalls, SSH keys
- Keeps: Primary IPs (€1/month continues)
- Result: Stops VM billing, next deploy reuses IPs

**destroy-all** (Nuclear):
- Deletes: Everything including Primary IPs
- Result: Stops all billing
- Warning: Next deploy gets random new IPs

### 3. Deploy Applications (Manual)

**Current Method**:
```bash
kubectl apply -k kubernetes/overlays/dev
```

**Future Method** (ArgoCD):
- Push to `main` → syncs to dev
- Push to `production` → syncs to prod

### 4. Local Terraform Validation

```powershell
$env:TF_VAR_ssh_public_key = Get-Content -Raw '.ssh/hetzner_k3s_ed25519.pub'
$env:TF_VAR_hcloud_token = Get-Content -Raw '.ssh/hcloud_token'
$env:TF_VAR_environment = 'dev'
cd terraform
terraform.exe init -backend=false
terraform.exe validate
```

---

## Cost Analysis

### Primary IPs (Persistent, 24/7)
- 2× IPv4 Primary IPs: €1.00/month (€0.50 each)
- Justification: DNS stability, no IP churn, faster deployments

### VMs (Billed Per Hour)

**Production** (10h/day × 22 days = 220h/month = 30% uptime):
- Control plane: €8.21/mo × 30% = €2.46/mo
- Kafka (3×): €16.32/mo × 3 × 30% = €14.69/mo
- **Subtotal**: €17.15/mo

**Development** (2h/day × 22 days = 44h/month = 6% uptime):
- Control plane: €8.21/mo × 6% = €0.49/mo
- Kafka (3×): €8.21/mo × 3 × 6% = €1.48/mo
- **Subtotal**: €1.97/mo

### Total Costs

| Environment | VMs | Primary IPs | Total |
|-------------|-----|-------------|-------|
| Production | €17.15 | - | €17.15 |
| Development | €1.97 | - | €1.97 |
| Infrastructure | - | €1.00 | €1.00 |
| **TOTAL** | **€19.12** | **€1.00** | **€20.12/month** |

**vs 24/7 Operation**:
- Prod 24/7: €57.17/month
- Dev 24/7: €32.84/month
- Total 24/7: €90.01/month
- **Savings: €69.89/month (77% reduction!)**

---

## Current State & Issues

### ✅ Implemented
- Persistent Primary IPs (€1/month)
- Automated deployment via GitHub Actions
- Modular Terraform infrastructure
- Kafka dual-listener setup (internal + external)
- Kustomize overlays for dev/prod
- Cost-optimized architecture (58% savings)

### 🚧 In Progress
- ArgoCD GitOps (configured but not actively used)
- Hetzner Object Storage integration (planned)

### ⚠️ Known Issues
- Firewall temporarily disabled on control-plane and kafka-0 (testing)
- No remote Terraform backend (local state only)
- ArgoCD not syncing yet (manual kubectl apply)

### 📋 TODO
1. Re-enable firewall on control-plane and kafka-0 after testing
2. Restrict SSH access to specific IPs (currently 0.0.0.0/0)
3. Implement Terraform remote backend (S3/Hetzner Object Storage)
4. Activate ArgoCD auto-sync for GitOps workflow
5. Set up Hetzner Object Storage for Kafka topic backups
6. Configure monitoring (Prometheus/Grafana)
7. Implement alerting for cluster health

---

## Quick Reference

### Access Cluster
```bash
# Download kubeconfig from GitHub Actions artifacts
export KUBECONFIG=./kubeconfig-dev.yaml
kubectl get nodes
kubectl get pods -A
```

### Kafka Connection Strings

**Internal** (from K8s pods):
```
trading-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
```

**External** (from internet):
```
<kafka-0-public-ip>:32100
```

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

### List Resources
```bash
hcloud server list -l environment=dev
hcloud primary-ip list -l environment=dev
```

---

## Important URLs

- **Hetzner Console**: https://console.hetzner.cloud/
- **GitHub Actions**: https://github.com/trading-cz/infra/actions
- **Strimzi Docs**: https://strimzi.io/docs/operators/latest/overview
- **K3s Docs**: https://docs.k3s.io/
- **Hetzner Primary IPs**: https://docs.hetzner.com/cloud/servers/primary-ips/

---

## Development Guidelines

### When Modifying Terraform
1. ✅ Validate locally before committing
2. ❌ Never run `terraform destroy` manually (use workflow)
3. ✅ Update both dev.tfvars and prod.tfvars
4. ✅ Test in dev environment first

### When Modifying Kubernetes Manifests
1. ✅ Use Kustomize overlays for env-specific changes
2. ✅ Keep base configs minimal and generic
3. ✅ Validate with `kubectl apply -k --dry-run=client`

### When Modifying GitHub Actions
1. ✅ Test in feature branch first
2. ❌ Never hardcode secrets
3. ✅ Document new inputs/secrets

---

**Last Updated**: November 6, 2025  
**Maintained By**: trading-cz team
