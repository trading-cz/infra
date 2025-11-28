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
┌─────────────────────────────────────────────────────────────┐
│                    Hetzner Cloud (nbg1)                     │
├─────────────────────────────────────────────────────────────┤
│  k3s-control (cx23)           │  kafka-0 (cx23)             │
│  ├─ Primary IP #1             │  ├─ Primary IP #2           │
│  ├─ K3s server                │  ├─ K3s agent (role=kafka)  │
│  ├─ Traefik (30080/30443)     │  └─ Kafka NodePort (30001)  │
│  ├─ ArgoCD Operator           │                             │
│  └─ Strimzi Operator          │                             │
├─────────────────────────────────────────────────────────────┤
│  Private Network: 10.0.1.0/24                               │
│  ├─ control: 10.0.1.10                                      │
│  └─ kafka-0: 10.0.1.20                                      │
└─────────────────────────────────────────────────────────────┘
```

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
                     │                      │ .21 = kafka-1
                     │                      │ .22 = kafka-2
───────────────────────────────────────────────────────────────
10.0.1.30  - .49     │ INFRASTRUCTURE       │ Future: monitoring,
                     │ SERVICES             │ logging, bastion
───────────────────────────────────────────────────────────────
10.0.1.50  - .99     │ EXPANSION            │ Reserved
───────────────────────────────────────────────────────────────
10.0.1.100 - .199    │ APPLICATIONS         │ .100 = app-0
                     │ (100 slots)          │ .101 = app-1, etc.
───────────────────────────────────────────────────────────────
10.0.1.200 - .254    │ DHCP / DYNAMIC       │ Not used
═══════════════════════════════════════════════════════════════
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
├── main.tf                 # Root module: network, k3s-server, kafka-server
├── variables.tf            # All configurable variables
├── outputs.tf              # Cluster IPs, SSH commands, summary
├── versions.tf             # Terraform/provider versions
├── environments/
│   ├── dev.tfvars          # Dev: 1 kafka node, cx23 instances
│   └── prod.tfvars         # Prod: 3 kafka nodes (KRaft quorum)
├── modules/
│   ├── network/            # VPC, subnet, firewall rules
│   ├── k3s-server/         # Control plane + cloud-init (K3s, Helm, Traefik)
│   ├── kafka-server/       # K3s agent nodes + cloud-init
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
| `ARGOCD_ADMIN_PASSWORD` | (Optional) ArgoCD admin password |

## Access Endpoints

After deployment:
- **ArgoCD UI**: `https://<control-plane-ip>:30443`
- **Kafka Bootstrap**: `<kafka-0-ip>:30001`
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
5. **NodePort services**: ArgoCD (30443), Kafka (30001) - no LoadBalancer needed

