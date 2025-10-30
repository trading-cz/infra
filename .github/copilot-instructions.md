# AI Agent Instructions: K3s Trading Infrastructure

## What This Repo Does
Ephemeral K3s clusters on **Hetzner Cloud** for algorithmic trading with Kafka-based data pipelines. Clusters are created fresh and destroyed after use (no state persistence).

## Cloud Provider
**Hetzner Cloud** - See [../doc/hetzner-terraform.md](../doc/hetzner-terraform.md)

## Main Components

### Infrastructure (Terraform)
- **1 control plane node**: K3s control + ArgoCD + Python apps
- **3 Kafka worker nodes**: Kafka KRaft cluster (3 nodes required for quorum)
- See [../doc/hetzner-terraform-articles-1.md](../doc/hetzner-terraform-articles-1.md) and [../doc/k3s-hetzner.md](../doc/k3s-hetzner.md)

### Technologies Stack
- **Kubernetes**: K3s - See [../doc/k3s-introduction.md](../doc/k3s-introduction.md)
- **Kafka**: Strimzi Operator + KRaft mode (no ZooKeeper) - See [../doc/strimzi.md](../doc/strimzi.md)
- **GitOps**: ArgoCD with App-of-Apps pattern - See [../doc/apps-of-all-app.md](../doc/apps-of-all-app.md)
- **IaC**: Terraform + Kustomize (NOT Helm)

## Environment Design
Two identical environments with different branches:
- **Dev**: `main` branch, cheaper shared vCPU instances
- **Prod**: `production` branch, dedicated vCPU instances

Configuration in `kubernetes/overlays/{dev|prod}/` overrides base configs in `kubernetes/base/`.

## Key Workflows
- **Deploy cluster**: GitHub Actions (`.github/workflows/deploy-cluster.yml`)
- **Destroy cluster**: Delete VMs directly in Hetzner Console (NOT Terraform destroy)
- **Deploy apps**: Push to `main` or `production` branch → ArgoCD auto-syncs

## File Structure
- `terraform/`: Infrastructure as code (Hetzner VMs, networking)
- `kubernetes/base/`: Base Kubernetes manifests (Kafka, apps)
- `kubernetes/overlays/`: Environment-specific patches (dev/prod)
- `kubernetes/app-of-apps/`: ArgoCD parent app configuration
- `doc/`: Detailed documentation for each technology

## Documentation
- `README.md`: Quick start guide
- `ARCHITECTURE_FINAL_CLEAN.md`: Full architecture and design decisions

## Troubleshooting & Recent Context
- **Local Terraform Usage**: You can use a local Terraform executable (e.g., `terraform.exe validate`) to check configuration before pushing changes. Example:
	- `C:\projects\apps\terraform_1.13.4\terraform.exe validate`

- **CI/CD Validation**: All infrastructure changes are validated and deployed via GitHub Actions. Local validation is optional but recommended for troubleshooting.
