# Infra - K3s Trading Infrastructure

Terraform + GitHub Actions for ephemeral K3s clusters on Hetzner Cloud.

## Purpose

Deploy cost-optimized Kubernetes infrastructure for algorithmic trading:
- **Ephemeral clusters**: Spin up during trading hours, destroy after → ~58% cost savings
- **Persistent IPs**: Primary IPs survive VM destruction (€1/month) → stable DNS/connections
- **Kafka streaming**: Market data pipeline via Strimzi operator (KRaft mode)
- **GitOps**: ArgoCD syncs application configs from `config` repository

## Related Repositories

| Repository | Purpose |
|------------|---------|
| `trading-cz/infra` | Infrastructure provisioning (this repo) |
| `trading-cz/config` | K8s manifests synced by ArgoCD (Kafka CR, apps, operators) |
| `trading-cz/ingestion-alpaca` | Python app: reads Alpaca broker data → publishes to Kafka |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Hetzner Cloud (nbg1)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  k3s-control (cx23)              │ role=control-plane                       │
│  ├─ Primary IP #1 (Persistent)   │ Private: 10.0.1.10                       │
│  ├─ K3s server (control plane)   │ ArgoCD, Traefik, Strimzi Operator        │
│  └─ Reserved for: monitoring     │ NO application workloads                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  kafka-0 (cx23)          │  kafka-1 (cx23)       │  kafka-2 (cx23)          │
│  ├─ Primary IP #2        │  ├─ Ephemeral IP      │  ├─ Ephemeral IP         │
│  ├─ Private: 10.0.1.20   │  ├─ Private: .21      │  ├─ Private: .22         │
│  ├─ K3s agent            │  ├─ K3s agent         │  ├─ K3s agent            │
│  ├─ role=kafka           │  ├─ role=kafka        │  ├─ role=kafka           │
│  ├─ workload=mixed       │  ├─ workload=mixed    │  ├─ workload=mixed       │
│  └─ Kafka + apps overflow│  └─ Kafka + apps      │  └─ Kafka + apps         │
├─────────────────────────────────────────────────────────────────────────────┤
│  worker-0 (cx22)                                                            │
│  ├─ Ephemeral IP                 │ Private: 10.0.1.30                       │
│  ├─ K3s agent                    │ role=worker, workload=apps               │
│  └─ PRIMARY target for Python apps (strategies, ingestion)                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  Private Network: 10.0.1.0/24                                               │
│  All nodes communicate internally via private IPs                           │
│  kafka-0 has persistent IP for external access, others have ephemeral IPs   │
└─────────────────────────────────────────────────────────────────────────────┘
```

**External Access**:
- **ArgoCD**: `https://<control-plane-ip>:30443`
- **Kafka**: `<kafka-0-ip>:30002` (NodePort, only broker 0 externally accessible via persistent IP)

**Internal Access** (from pods):
- **Kafka Bootstrap**: `trading-cluster-kafka-bootstrap.kafka:9092`

## Cost Summary

| Resource | Type | Monthly Cost |
|----------|------|--------------|
| k3s-control | cx23 (2 vCPU, 4GB) | €7.49 |
| kafka-0,1,2 | cx23 x3 | €22.47 |
| worker-0 | cx22 (2 vCPU, 4GB) | €3.99 |
| Primary IPs | x2 (control + kafka-0) | €2.00 |
| **Total** | 5 VMs | **~€35.95/month** |

> **Note**: With ephemeral clusters (2-10h/day), actual costs are ~58% lower.

## Private Network IP Allocation

```
10.0.1.0/24 Subnet Layout
═══════════════════════════════════════════════════════════════
Range                │ Purpose              │ Current Use
═══════════════════════════════════════════════════════════════
10.0.1.1   - .9      │ Reserved             │ Network/gateway
───────────────────────────────────────────────────────────────
10.0.1.10  - .19     │ CONTROL PLANE        │ .10 = k3s-control
                     │ (K3s servers)        │ .11-.19 = future HA
───────────────────────────────────────────────────────────────
10.0.1.20  - .29     │ KAFKA BROKERS        │ .20 = kafka-0 (public)
                     │ (workload=mixed)     │ .21 = kafka-1
                     │                      │ .22 = kafka-2
───────────────────────────────────────────────────────────────
10.0.1.30  - .49     │ WORKER NODES         │ .30 = worker-0 (apps)
                     │ (workload=apps)      │ .31-.49 = future workers
───────────────────────────────────────────────────────────────
10.0.1.50  - .99     │ INFRASTRUCTURE       │ Future: monitoring,
                     │ SERVICES             │ logging, bastion
───────────────────────────────────────────────────────────────
10.0.1.100 - .199    │ EXPANSION            │ Reserved
───────────────────────────────────────────────────────────────
10.0.1.200 - .254    │ DHCP / DYNAMIC       │ Not used
═══════════════════════════════════════════════════════════════
```

## Node Labels & Workload Scheduling

| Node Type | Labels | Workloads |
|-----------|--------|----------|
| control | `role=control-plane` | ArgoCD, Traefik, Strimzi operator, monitoring |
| kafka-N | `role=kafka`, `workload=mixed` | Kafka brokers + overflow apps |
| worker-N | `role=worker`, `workload=apps` | Python strategies, ingestion apps (primary) |

**Scheduling Strategy**:
- Apps prefer `role=worker` nodes (dedicated resources)
- Apps can fall back to `role=kafka` nodes (`workload=mixed`)
- Control plane excluded from app scheduling

**Example Deployment Selector** (for Python strategies):
```yaml
spec:
  template:
    spec:
      nodeSelector:
        role: worker  # Primary target
      # OR for flexibility:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: role
                operator: In
                values: [worker]
          - weight: 50
            preference:
              matchExpressions:
              - key: workload
                operator: In
                values: [mixed]
```

## Tech Stack

| Component | Version | Notes |
|-----------|---------|-------|
| Terraform | >= 1.13 | Hetzner provider ~> 1.54 |
| K3s | v1.34.1+k3s1 | Lightweight Kubernetes |
| Kafka | 4.0.0 | Strimzi operator, KRaft (no ZooKeeper) |
| ArgoCD | v0.15.0-1 | Operator-based deployment |
| Strimzi | 0.48.0 | Kafka operator |

### Strimzi Upgrade Notes

**Current Version**: 0.48.0 (pinned for stability)

**0.49.0 Assessment** (as of Nov 2025): **Not recommended yet**
- Introduces breaking `v1` API (requires CR migration)
- Deprecates OAuth, Keycloak auth, `.spec.kafka.resources`
- Benefits (Kafka 4.0.1/4.1.1, better deletion handling) not critical for this project
- Upgrade when: need Kafka 4.1.x, or after 0.50+ proves stable

## Repository Structure

```
infra/
├── main.tf                 # Root module: network, k3s-server, kafka-server, worker-server
├── variables.tf            # All configurable variables
├── outputs.tf              # Cluster IPs, SSH commands, summary
├── versions.tf             # Terraform/provider versions
├── environments/
│   ├── dev.tfvars          # Dev: 3 kafka nodes + 1 worker (cx22)
│   └── prod.tfvars         # Prod: 3 kafka nodes + 1 worker (cx22)
├── modules/
│   ├── network/            # VPC, subnet, firewall rules
│   ├── k3s-server/         # Control plane + cloud-init (K3s, Helm, Traefik)
│   ├── kafka-server/       # K3s agent nodes (role=kafka, workload=mixed)
│   ├── worker-server/      # K3s agent nodes for Python apps (role=worker, workload=apps)
│   └── strimzi/            # Strimzi Helm values (reference only)
└── .github/
    ├── workflows/              # GitHub Actions workflow definitions
    │   ├── deploy-cluster.yml          # Main orchestrator
    │   ├── hcloud-maintenance.yml      # List/destroy resources
    │   ├── 01-reusable-provision-infra.yml
    │   ├── 02-reusable-verify-cluster.yml
    │   ├── 03-reusable-deploy-argocd.yml
    │   ├── 04-reusable-deploy-strimzi.yml
    │   └── 05-reusable-verify-access.yml
    └── scripts/                # Scripts used by GitHub Actions (if any)
```

> **Convention**: All scripts related to GitHub Actions should be stored under `.github/scripts/` 
> to clearly indicate they are used by CI/CD pipelines and not for local development.

## GitHub Actions Workflows

### Deploy Cluster (`deploy-cluster.yml`)
**Trigger**: Manual → Actions → "Deploy K3s Cluster" → Select environment

Pipeline:
1. `verify_clean` - Ensures no existing resources
2. `provision` - Terraform creates VMs with Primary IPs
3. `verify_cluster` - Waits for K3s ready, distributes tokens to agents
4. `deploy_strimzi` - Installs Strimzi operator
5. `deploy_argocd` - Installs ArgoCD operator, bootstraps from `config` repo
6. `verify_access` - Tests ArgoCD UI and Kafka connectivity

### Maintenance (`hcloud-maintenance.yml`)
**Actions**:
- `list` - Show all Hetzner resources by environment
- `destroy-cluster` - Delete VMs, keep Primary IPs (daily scheduled at 23:30 UTC)
- `destroy-all` - Delete everything including IPs
- `check-clean` - Pre-flight validation before deploy

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `HCLOUD_TOKEN` | Hetzner Cloud API token (Read+Write) |
| `SSH_PUBLIC_KEY` | ED25519 public key for server access |
| `SSH_PRIVATE_KEY` | ED25519 private key for workflows |
| `TOKEN_GIT_REPO_CONFIG` | PAT for ArgoCD to access `config` repo |
| `GHCR_TOKEN` | GitHub PAT with `read:packages` scope for pulling private container images |
| `ARGOCD_ADMIN_PASSWORD` | (Optional) ArgoCD admin password |

### GHCR_TOKEN Setup

The `GHCR_TOKEN` is required for K3s nodes to pull private container images from GitHub Container Registry (ghcr.io).

**Why it's needed**:
- Container images in `ghcr.io/trading-cz/*` are private by default
- K3s nodes (external VMs) cannot authenticate to GHCR without credentials
- Even with "Internal" visibility, external servers need a token

**Create the token**:
1. Go to https://github.com/settings/tokens/new (Classic token)
2. Note: `GHCR_TOKEN`
3. Select scope: ✅ `read:packages` - Download packages from GitHub Package Registry
4. Generate and copy the token
5. Add to repository secrets: Settings → Secrets → Actions → `GHCR_TOKEN`

**How it works**:
- Workflow creates a `docker-registry` secret named `ghcr-secret` in each app namespace
- Deployments reference this secret via `imagePullSecrets: [{name: ghcr-secret}]`

## Access Endpoints

After deployment:
- **ArgoCD UI**: `https://<control-plane-ip>:30443`
- **Kafka Bootstrap**: `<kafka-0-ip>:30002` (external, only kafka-0)
- **Kafka Internal**: `trading-cluster-kafka-bootstrap.kafka:9092` (from pods)
- **K8s API**: `<control-plane-ip>:6443`
- **SSH**: `ssh root@<control-plane-ip>`

## Local Development

```powershell
# Validate changes before committing
C:\projects\apps\terraform_1.13.4\terraform.exe fmt -recursive
C:\projects\apps\terraform_1.13.4\terraform.exe validate

# Plan with credentials (optional)
$env:TF_VAR_hcloud_token = "your-token"
$env:TF_VAR_ssh_public_key = "ssh-ed25519 AAAA..."
$env:TF_VAR_control_plane_primary_ip_id = "12345"
$env:TF_VAR_kafka_primary_ip_id = "67890"
C:\projects\apps\terraform_1.13.4\terraform.exe plan -var-file="environments/dev.tfvars"
```

## Key Design Decisions

1. **Primary IPs over Floating IPs**: Attached during VM creation (no reboot needed)
2. **Cloud-init for provisioning**: K3s install, agent join, Helm setup in `modules/*/cloud-init.yaml`
3. **ArgoCD bootstraps from config repo**: `config/overlays/minimal` applied during deploy
4. **Strimzi pinned version**: Uses `https://strimzi.io/install/0.48.0` (version tracked in `modules/strimzi/VERSION`)
5. **NodePort services**: ArgoCD (30443), Kafka (30002) - no LoadBalancer needed
6. **3-node Kafka cluster**: KRaft quorum requires minimum 3 brokers for HA
7. **Only kafka-0 has public IP**: kafka-1 and kafka-2 are internal-only (no public IP)
8. **Worker nodes for apps**: Dedicated cx22 nodes for Python strategies (role=worker, workload=apps)
9. **Kafka nodes allow apps**: Kafka nodes labeled `workload=mixed` for overflow app scheduling
10. **Control plane reserved**: No application workloads on control plane (reserved for ArgoCD + future monitoring)

## Scaling Kafka Clusters

### Current Architecture

The infrastructure supports a 3-node Kafka cluster with KRaft (no ZooKeeper):
- **kafka-0**: Primary IP #2 (persistent) + Private IP (10.0.1.20) - external access via NodePort 30002
- **kafka-1**: Ephemeral public IP + Private IP (10.0.1.21) - internal Kafka only
- **kafka-2**: Ephemeral public IP + Private IP (10.0.1.22) - internal Kafka only

### How to Change Kafka Node Count

**Step 1: Update Terraform Configuration**

Edit `environments/dev.tfvars` or `environments/prod.tfvars`:

```hcl
# Minimum 3 for KRaft quorum (recommended)
kafka_node_count = 3

# Can scale up to 10 nodes (IP range 10.0.1.20-29)
kafka_node_count = 5
```

**Step 2: Update Kafka CR in Config Repo**

Edit `config/base/kafka/kafka.yaml` to match replica count:

```yaml
spec:
  kafka:
    replicas: 3  # Must match kafka_node_count
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      min.insync.replicas: 2
  kraft:
    replicas: 3  # KRaft controller quorum
```

**Step 3: Deploy via GitHub Actions**

Run the "Deploy K3s Cluster" workflow. The workflow will:
1. Create VMs (kafka-0 gets persistent Primary IP, others get ephemeral IPs)
2. Distribute K3s tokens (kafka-0 direct, others via jump host)
3. All nodes join the cluster with `workload=kafka` label

### IP Address Allocation

| Node | Public IP | Private IP | Access |
|------|-----------|------------|--------|
| kafka-0 | Primary IP #2 (persistent) | 10.0.1.20 | External (NodePort 30002) + Internal |
| kafka-1 | Ephemeral (changes on recreate) | 10.0.1.21 | Internal only (Kafka replication) |
| kafka-2 | Ephemeral (changes on recreate) | 10.0.1.22 | Internal only (Kafka replication) |
| kafka-N | Ephemeral | 10.0.1.2N | Internal only |

### Important Constraints

1. **Only 2 Primary IPs**: One for ArgoCD (control plane), one for Kafka external (kafka-0)
2. **All nodes have public IPs**: Required for cloud-init (K3s download from internet)
3. **kafka-1, kafka-2 IPs are ephemeral**: Change on VM recreate, but that's OK (internal only)
4. **KRaft minimum**: 3 nodes for quorum (can survive 1 node failure)
5. **IP range limit**: 10.0.1.20-29 (10 Kafka nodes maximum)