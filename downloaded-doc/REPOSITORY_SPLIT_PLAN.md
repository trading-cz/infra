# Repository Split Plan: Infra → Config Separation

**Date**: November 6, 2025  
**Current Repository**: `trading-cz/infra` (monorepo)  
**Target Repositories**:
- `trading-cz/infra` (infrastructure only - Terraform)
- `trading-cz/config` (Kubernetes configurations)

---

## 🎯 Objective

Split the current monorepo into two focused repositories:
1. **`infra`** - Infrastructure as Code (Terraform) for provisioning K3s clusters
2. **`config`** - Kubernetes configurations (manifests, Kustomize, ArgoCD apps)

This separation follows best practices:
- Clear separation of concerns (infrastructure vs application config)
- Independent versioning and release cycles
- Different teams can own different repos
- Easier RBAC and access control

---

## 📊 Current Repository Structure Analysis

### Current Directory Layout
```
infra/
├── .github/workflows/           # 4 workflows (mixed concerns)
│   ├── deploy-cluster.yml       # ⚠️ Does BOTH Terraform + K8s config
│   ├── hcloud-maintenance.yml   # ✅ Pure infrastructure
│   ├── review-terraform.yml     # ⚠️ Validates both Terraform + K8s
│   └── test-kubernetes-configs.yml  # ✅ Pure K8s config
├── terraform/                   # ✅ Infrastructure only
│   ├── main.tf, variables.tf, outputs.tf
│   ├── environments/
│   │   ├── dev.tfvars
│   │   └── prod.tfvars
│   ├── modules/
│   │   ├── network/
│   │   ├── compute/
│   │   ├── k3s/
│   │   └── kafka/
│   └── templates/
│       ├── control-plane-init.sh
│       └── worker-init.sh
├── kubernetes/                  # ✅ Application config only
│   ├── base/
│   │   ├── kafka/
│   │   └── apps/
│   ├── overlays/
│   │   ├── dev/
│   │   └── prod/
│   └── app-of-apps/
│       └── argocd/
├── scripts/                     # Empty
└── Documentation files (.md)    # ⚠️ Mixed content
```

### Key Dependencies Identified

1. **ArgoCD Source Repository References**
   - Location: `deploy-cluster.yml` lines 290-300
   - Current: Points to `github.com/trading-cz/infra.git`
   - Impact: Must change to `github.com/trading-cz/config.git`

2. **Workflow Cross-References**
   - `deploy-cluster.yml` references `kubernetes/` directory (line 238, 301)
   - `review-terraform.yml` validates both `terraform/` and `kubernetes/` (lines 6-8)
   - `test-kubernetes-configs.yml` only uses `kubernetes/` (lines 6, 14, 34+)

3. **Terraform Cloud-Init Scripts**
   - `templates/control-plane-init.sh` - Pure infrastructure
   - `templates/worker-init.sh` - Pure infrastructure
   - No K8s config dependencies

---

## 📋 Migration Plan

### Phase 1: Prepare New `config` Repository

#### 1.1 Create New Repository
```bash
# On GitHub
Create repository: trading-cz/config
Description: "Kubernetes configurations for trading infrastructure (Kafka, ArgoCD, apps)"
Visibility: Private (same as infra)
```

#### 1.2 Initial Structure (New `config` Repository)
```
config/
├── .github/
│   └── workflows/
│       ├── test-kustomize.yml          # NEW: Renamed from test-kubernetes-configs.yml
│       └── deploy-apps.yml             # NEW: ArgoCD sync trigger (future)
├── base/
│   ├── kafka/
│   │   ├── kafka-cluster.yaml
│   │   ├── kafka-metrics-config.yaml
│   │   ├── kustomization.yaml
│   │   └── users/
│   └── apps/
│       ├── alpaca-ingestion/
│       └── dummy-strategy/
├── overlays/
│   ├── dev/
│   │   ├── kafka/
│   │   ├── alpaca-ingestion/
│   │   ├── dummy-strategy/
│   │   └── app-of-apps/
│   └── prod/
│       ├── kafka/
│       ├── alpaca-ingestion/
│       ├── dummy-strategy/
│       └── app-of-apps/
├── app-of-apps/
│   └── argocd/
│       └── parent-app.yaml
├── README.md                           # NEW: Config-specific docs
├── DEPLOYMENT.md                       # NEW: How to deploy configs
└── STRUCTURE.md                        # NEW: Kustomize structure guide
```

#### 1.3 Files to Move from `infra` to `config`
```
MOVE: kubernetes/* → config/ (entire directory, rename to root)
├── kubernetes/base/* → config/base/
├── kubernetes/overlays/* → config/overlays/
├── kubernetes/app-of-apps/* → config/app-of-apps/
├── kubernetes/IMPLEMENTATION_SUMMARY.md → config/docs/IMPLEMENTATION_SUMMARY.md
└── kubernetes/README.md → config/README.md (merge/update)
```

---

### Phase 2: Restructure `infra` Repository (Root-Level Terraform)

#### 2.1 New Structure (Updated `infra` Repository)
```
infra/
├── .github/
│   └── workflows/
│       ├── deploy-cluster.yml          # UPDATED: Terraform only
│       ├── hcloud-maintenance.yml      # UNCHANGED
│       └── terraform-validate.yml      # RENAMED: from review-terraform.yml
├── main.tf                             # MOVED: from terraform/main.tf
├── variables.tf                        # MOVED: from terraform/variables.tf
├── outputs.tf                          # MOVED: from terraform/outputs.tf
├── versions.tf                         # MOVED: from terraform/versions.tf
├── terraform.tfvars.example            # MOVED: from terraform/
├── environments/                       # MOVED: from terraform/environments/
│   ├── dev.tfvars
│   └── prod.tfvars
├── modules/                            # MOVED: from terraform/modules/
│   ├── network/
│   ├── compute/
│   ├── k3s/
│   └── kafka/
├── templates/                          # MOVED: from terraform/templates/
│   ├── control-plane-init.sh
│   └── worker-init.sh
├── docs/                               # NEW: Documentation folder
│   ├── ARCHITECTURE.md                 # MOVED: from root
│   ├── GETTING_STARTED.md              # MOVED: from root
│   └── SSH_KEY_SETUP.md                # MOVED: from root
├── README.md                           # UPDATED: Infra-focused
└── .gitignore                          # UPDATED: Terraform-specific
```

#### 2.2 Files to Move Within `infra`
```
MOVE TO ROOT:
terraform/main.tf → main.tf
terraform/variables.tf → variables.tf
terraform/outputs.tf → outputs.tf
terraform/versions.tf → versions.tf
terraform/terraform.tfvars.example → terraform.tfvars.example
terraform/environments/ → environments/
terraform/modules/ → modules/
terraform/templates/ → templates/
terraform/README.md → docs/TERRAFORM_README.md (archive)

DELETE:
kubernetes/ (moved to config repo)
terraform/ (flattened to root)
abc-doc-tmp/ (temporary research files)
scripts/ (empty)

REORGANIZE DOCS:
ARCHITECTURE_FINAL_CLEAN.md → docs/ARCHITECTURE.md
GETTING_STARTED.md → docs/GETTING_STARTED.md
SSH_KEY_SETUP.md → docs/SSH_KEY_SETUP.md
PROJECT_*.md → docs/ (archive)
TERRAFORM_*.md → docs/
VERIFICATION_RESULTS.md → docs/ (archive)
```

---

### Phase 3: Update GitHub Actions Workflows

#### 3.1 `infra` Repository Workflows

**`deploy-cluster.yml` - MAJOR CHANGES**
```yaml
name: Deploy K3s Cluster

# REMOVE: All post-setup job (Strimzi, Kafka, ArgoCD installation)
# KEEP: Only Terraform infrastructure deployment
# NEW: Output kubeconfig for manual/automated config deployment

jobs:
  terraform:
    # ... existing terraform job ...
    # REMOVE: Steps after "Verify cluster"
    # REMOVE: post-setup job entirely
    
  # NEW: Summary with next steps
  summary:
    needs: terraform
    steps:
      - name: Deployment Summary
        run: |
          echo "## ✅ Infrastructure Deployed" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Next Steps" >> $GITHUB_STEP_SUMMARY
          echo "1. Download kubeconfig from artifacts" >> $GITHUB_STEP_SUMMARY
          echo "2. Deploy Kafka: See trading-cz/config repository" >> $GITHUB_STEP_SUMMARY
          echo "3. Configure ArgoCD: kubectl apply -k github.com/trading-cz/config//overlays/${{ inputs.environment }}" >> $GITHUB_STEP_SUMMARY
```

**Changes Required**:
- Lines 200-367: DELETE entire `post-setup` job
- Lines 160-190: UPDATE summary to point to config repo
- Add link to config deployment instructions

**`terraform-validate.yml` (renamed from `review-terraform.yml`)**
```yaml
name: Terraform Validation

on:
  pull_request:
    paths:
      - '**/*.tf'           # CHANGED: from 'terraform/**'
      - 'environments/**'   # CHANGED: from 'terraform/environments/**'
      - '.github/workflows/deploy-cluster.yml'
      # REMOVED: - 'kubernetes/**'

jobs:
  lint:
    name: Terraform Lint & Format
    runs-on: ubuntu-latest
    steps:
      # ... same steps but with updated paths ...
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        # CHANGED: working-directory removed (now at root)
```

**`hcloud-maintenance.yml` - NO CHANGES**
- Already infrastructure-focused
- No K8s config dependencies

#### 3.2 `config` Repository Workflows

**`test-kustomize.yml` (renamed from `test-kubernetes-configs.yml`)**
```yaml
name: Test Kustomize Configurations

on:
  pull_request:
    paths:
      - 'base/**'           # CHANGED: from 'kubernetes/base/**'
      - 'overlays/**'       # CHANGED: from 'kubernetes/overlays/**'
      - 'app-of-apps/**'    # CHANGED: from 'kubernetes/app-of-apps/**'
      - '.github/workflows/**'
  push:
    branches: [main, production]

jobs:
  kustomize-validation:
    # ... same logic with updated paths ...
    
      - name: Validate Dev Kafka
        run: |
          kustomize build overlays/dev/kafka > /tmp/dev-kafka.yaml
          # CHANGED: path no longer has kubernetes/ prefix
```

**`deploy-apps.yml` - NEW WORKFLOW**
```yaml
name: Deploy Applications via ArgoCD

on:
  workflow_dispatch:
    inputs:
      cluster_name:
        description: 'Target cluster (dev|prod)'
        required: true
        type: choice
        options: [dev, prod]
      kubeconfig_artifact:
        description: 'Kubeconfig artifact name from infra deployment'
        required: true
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Download kubeconfig
        uses: actions/download-artifact@v4
        with:
          name: ${{ inputs.kubeconfig_artifact }}
          repository: trading-cz/infra
          github-token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Install Strimzi
        run: |
          export KUBECONFIG=./kubeconfig.yaml
          kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
          kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
          kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=300s
      
      - name: Deploy Kafka
        run: |
          kubectl apply -k overlays/${{ inputs.cluster_name }}/kafka
          kubectl wait kafka/trading-cluster --for=condition=Ready --timeout=600s -n kafka
      
      - name: Install ArgoCD
        run: |
          kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
          kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml
          kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s
      
      - name: Deploy App-of-Apps
        run: |
          BRANCH=$( [ "${{ inputs.cluster_name }}" == "dev" ] && echo "main" || echo "production" )
          cat <<EOF | kubectl apply -f -
          apiVersion: argoproj.io/v1alpha1
          kind: Application
          metadata:
            name: trading-system-${{ inputs.cluster_name }}
            namespace: argocd
          spec:
            project: default
            source:
              repoURL: 'https://github.com/trading-cz/config.git'  # CHANGED: new repo
              targetRevision: ${BRANCH}
              path: overlays/${{ inputs.cluster_name }}/app-of-apps
            destination:
              server: 'https://kubernetes.default.svc'
              namespace: default
            syncPolicy:
              automated: {prune: true, selfHeal: true}
              syncOptions: [CreateNamespace=true]
          EOF
```

---

### Phase 4: Update ArgoCD Configuration

#### 4.1 Files Requiring Repository URL Changes

**`app-of-apps/argocd/parent-app.yaml`**
```yaml
# BEFORE:
source:
  repoURL: 'https://github.com/trading-cz/infra.git'
  targetRevision: main
  path: kubernetes/overlays/dev/app-of-apps

# AFTER:
source:
  repoURL: 'https://github.com/trading-cz/config.git'  # CHANGED
  targetRevision: main
  path: overlays/dev/app-of-apps                       # CHANGED
```

**`overlays/dev/app-of-apps/*.yaml`** (all 3 files)
```yaml
# Example: kafka.yaml
# BEFORE:
source:
  repoURL: https://github.com/trading-cz/infra.git
  path: kubernetes/overlays/dev/kafka

# AFTER:
source:
  repoURL: https://github.com/trading-cz/config.git    # CHANGED
  path: overlays/dev/kafka                             # CHANGED
```

Files to update:
- `overlays/dev/app-of-apps/alpaca-ingestion.yaml`
- `overlays/dev/app-of-apps/dummy-strategy.yaml`
- `overlays/dev/app-of-apps/kafka.yaml`
- `overlays/prod/app-of-apps/*.yaml` (if they exist)

#### 4.2 Kubernetes Manifest Path References
No changes needed - Kustomize uses relative paths within the repo.

---

### Phase 5: Update Documentation

#### 5.1 `infra` Repository Documentation

**README.md** - Focus on infrastructure
```markdown
# Infrastructure as Code - K3s Trading Platform

Terraform modules for deploying ephemeral K3s clusters on Hetzner Cloud with persistent IPv4 addresses.

## 🚀 Quick Start

1. Deploy infrastructure: `terraform apply -var-file=environments/dev.tfvars`
2. Download kubeconfig from GitHub Actions artifacts
3. Deploy applications: See [trading-cz/config](https://github.com/trading-cz/config)

## 🏗️ What This Deploys

- K3s cluster (1 control plane + 3 kafka nodes)
- Private network (10.0.1.0/24)
- 2 Persistent Primary IPs (€1/month total)
- SSH keys, firewalls, compute instances

## 📦 Repository Structure

- `main.tf` - Root Terraform configuration
- `modules/` - Reusable Terraform modules
- `environments/` - Environment-specific variables
- `templates/` - Cloud-init scripts

## 🔗 Related Repositories

- [config](https://github.com/trading-cz/config) - Kubernetes configurations
```

**docs/ARCHITECTURE.md** - Infrastructure-focused
- Move from `ARCHITECTURE_FINAL_CLEAN.md`
- Remove Kafka/ArgoCD deployment details (move to config repo)
- Focus on network, VMs, IPs, Terraform modules

#### 5.2 `config` Repository Documentation

**README.md** - NEW
```markdown
# Kubernetes Configurations - Trading Platform

Kustomize-based Kubernetes configurations for the trading platform, including Kafka, ingestion services, and strategies.

## 🎯 Prerequisites

1. K3s cluster running (deploy via [trading-cz/infra](https://github.com/trading-cz/infra))
2. Kubeconfig with cluster access

## 🚀 Deployment

### Manual Deployment
```bash
# Deploy Kafka
kubectl apply -k overlays/dev/kafka

# Deploy Apps
kubectl apply -k overlays/dev/alpaca-ingestion
kubectl apply -k overlays/dev/dummy-strategy
```

### ArgoCD (GitOps)
```bash
# Install ArgoCD
kubectl apply -k base/argocd

# Deploy parent app
kubectl apply -f app-of-apps/argocd/parent-app.yaml
```

## 📁 Structure

```
base/               # Base Kustomize configurations
overlays/dev/       # Dev environment patches
overlays/prod/      # Prod environment patches
app-of-apps/        # ArgoCD app-of-apps pattern
```

## 🔗 Related Repositories

- [infra](https://github.com/trading-cz/infra) - Terraform infrastructure
```

**DEPLOYMENT.md** - NEW
```markdown
# Deployment Guide

## Full Stack Deployment

1. Deploy Infrastructure (trading-cz/infra)
2. Install Strimzi Operator
3. Deploy Kafka Cluster
4. Install ArgoCD
5. Deploy Applications

## Kafka Configuration
- 3 brokers (KRaft mode)
- Internal: 9092, External: 32100
- Metrics enabled

## Applications
- Alpaca Ingestion: Real-time market data
- Dummy Strategy: Example trading strategy
```

---

### Phase 6: Update Git Configuration

#### 6.1 `.gitignore` Updates

**`infra` repository**
```gitignore
# Terraform
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl
terraform.tfvars
*.tfvars
!terraform.tfvars.example
!environments/*.tfvars

# SSH Keys
.ssh/
*.pem
*.key

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db
```

**`config` repository** - NEW
```gitignore
# Kustomize outputs
*-generated.yaml

# Kubeconfig
kubeconfig*.yaml
*.kubeconfig

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db
```

#### 6.2 `.github/copilot-instructions.md`

**`infra` repository** - UPDATE
```markdown
# Copilot Instructions: K3s Infrastructure

**Repository**: trading-cz/infra
**Purpose**: Terraform infrastructure for K3s clusters on Hetzner
**Related**: [config](https://github.com/trading-cz/config) for K8s manifests

## Technology Stack
- Terraform v1.13.4
- K3s v1.34.1+k3s1
- Hetzner Cloud

## Directory Structure
- `main.tf` - Root module
- `modules/` - Network, compute, K3s modules
- `environments/` - dev.tfvars, prod.tfvars

## Deployment
Use GitHub Actions: Deploy K3s Cluster workflow
```

**`config` repository** - NEW
```markdown
# Copilot Instructions: Kubernetes Configurations

**Repository**: trading-cz/config
**Purpose**: Kubernetes configurations for trading platform
**Related**: [infra](https://github.com/trading-cz/infra) for infrastructure

## Technology Stack
- Kustomize
- Kafka 4.0.0 (Strimzi)
- ArgoCD

## Directory Structure
- `base/` - Base configurations
- `overlays/dev/` - Dev patches
- `overlays/prod/` - Prod patches
- `app-of-apps/` - ArgoCD parent apps

## Deployment
See DEPLOYMENT.md for full guide
```

---

## 🚀 Migration Execution Steps

### Step-by-Step Process

#### 1️⃣ Prepare Config Repository (No Breaking Changes Yet)
```bash
# Create new repository on GitHub
# Clone it locally
git clone git@github.com:trading-cz/config.git
cd config

# Copy kubernetes content from infra repo
cp -r ../infra/kubernetes/* .
mv IMPLEMENTATION_SUMMARY.md docs/
mv README.md docs/OLD_README.md

# Create new documentation
# (Create README.md, DEPLOYMENT.md, STRUCTURE.md as per Phase 5.2)

# Update ArgoCD repo URLs (Phase 4)
# Find and replace: trading-cz/infra.git → trading-cz/config.git
# Find and replace: path: kubernetes/ → path: 

# Update paths in workflows
mv .github/workflows/test-kubernetes-configs.yml .github/workflows/test-kustomize.yml
# Edit test-kustomize.yml: update all kubernetes/ paths to remove prefix

# Create new workflow
# (Create .github/workflows/deploy-apps.yml as per Phase 3.2)

# Initial commit
git add .
git commit -m "feat: initial config repository with Kubernetes manifests

- Migrated from trading-cz/infra repository
- Updated ArgoCD source URLs to point to config repo
- Renamed workflows and updated paths
- Added deployment documentation
"
git push origin main
```

#### 2️⃣ Test Config Repository
```bash
# Validate Kustomize builds
kustomize build overlays/dev/kafka
kustomize build overlays/dev/alpaca-ingestion
kustomize build overlays/dev/dummy-strategy
kustomize build overlays/prod/kafka

# Run GitHub Actions
# Trigger: test-kustomize.yml workflow
```

#### 3️⃣ Update Infra Repository (BREAKING CHANGES)
```bash
cd ../infra
git checkout -b feature/flatten-terraform

# Move Terraform to root
mv terraform/* .
mv terraform/.terraform.lock.hcl . 2>/dev/null || true
rmdir terraform

# Update workflow paths
# Edit .github/workflows/deploy-cluster.yml (remove post-setup job)
# Edit .github/workflows/review-terraform.yml → terraform-validate.yml
#   - Update paths: terraform/** → **/*.tf
#   - Remove kubernetes/** trigger
#   - Remove working-directory: ./terraform

# Reorganize docs
mkdir docs
mv ARCHITECTURE_FINAL_CLEAN.md docs/ARCHITECTURE.md
mv GETTING_STARTED.md docs/
mv SSH_KEY_SETUP.md docs/
mv PROJECT_*.md docs/archive/
mv TERRAFORM_*.md docs/
mv VERIFICATION_RESULTS.md docs/archive/

# Delete kubernetes directory
rm -rf kubernetes/

# Delete temporary files
rm -rf abc-doc-tmp/
rm -rf scripts/  # empty

# Update README.md (as per Phase 5.1)
# Update .github/copilot-instructions.md

# Commit
git add .
git commit -m "refactor: flatten Terraform to root, split K8s configs to separate repo

BREAKING CHANGES:
- Moved all terraform/* to repository root
- Removed kubernetes/ directory (moved to trading-cz/config)
- Updated workflows to reflect new structure
- deploy-cluster.yml now only deploys infrastructure
- K8s config deployment moved to trading-cz/config repository

Migration Guide:
- Infrastructure: Use root-level Terraform files
- K8s configs: See https://github.com/trading-cz/config
- Workflows updated with new paths
"
git push origin feature/flatten-terraform
```

#### 4️⃣ Create Pull Request & Review
- Create PR for `feature/flatten-terraform`
- Review all changes
- Test workflows (they will validate new structure)
- Get approval
- Merge to main

#### 5️⃣ Update Branch Protection & Secrets
```bash
# Ensure both repos have required secrets:
# - HCLOUD_TOKEN
# - SSH_PRIVATE_KEY
# - SSH_PUBLIC_KEY

# Set branch protection:
# - main branch (dev)
# - production branch (prod)
```

#### 6️⃣ Test End-to-End Deployment
```bash
# 1. Deploy infrastructure
# GitHub Actions → Deploy K3s Cluster → dev
# Download kubeconfig artifact

# 2. Deploy configs
# GitHub Actions → Deploy Applications → dev
# Verify Kafka, ArgoCD, apps

# 3. Verify GitOps
# Push change to config repo → ArgoCD auto-syncs
```

---

## 🔧 Terraform Path Updates Reference

### Before (Monorepo)
```bash
# Working directory
cd terraform/

# Commands
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply

# Workflow paths
working-directory: ./terraform
```

### After (Flattened)
```bash
# Working directory
cd .  # Repository root

# Commands (same)
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply

# Workflow paths
# No working-directory needed (default is root)
```

---

## 📝 Workflow Changes Summary

| Workflow | Before | After | Changes |
|----------|--------|-------|---------|
| `deploy-cluster.yml` | Deploys infra + K8s | Deploys infra only | Remove post-setup job, update summary |
| `review-terraform.yml` | Validates both | Validates Terraform | Rename, remove K8s paths, update working-directory |
| `test-kubernetes-configs.yml` | In infra repo | In config repo | Rename, update paths |
| `hcloud-maintenance.yml` | Unchanged | Unchanged | No changes |
| `deploy-apps.yml` | N/A | NEW in config repo | Deploys Strimzi, Kafka, ArgoCD |

---

## ⚠️ Risks & Mitigation

### Risk 1: ArgoCD Points to Wrong Repo
**Impact**: ArgoCD won't sync after migration  
**Mitigation**:
- Update all ArgoCD Application specs before deploying
- Test with temporary test cluster
- Keep old infra repo until verified

### Risk 2: Workflow Path Breakage
**Impact**: CI/CD failures  
**Mitigation**:
- Test workflows in feature branch
- Use GitHub Actions path filters carefully
- Validate both repos before merging

### Risk 3: Lost Git History
**Impact**: Can't trace changes pre-migration  
**Mitigation**:
- Don't squash commits during migration
- Document migration date and commit SHAs
- Keep both repos with full history

### Risk 4: Missing Secrets/Config
**Impact**: Deployments fail  
**Mitigation**:
- Copy all GitHub secrets to both repos
- Verify kubeconfig artifact download works cross-repo
- Test with dry-run deployments

---

## 📊 Success Criteria

- [ ] Config repo created and tested
- [ ] All Kustomize builds work in config repo
- [ ] Infra repo flattened to root level
- [ ] Terraform validates at root level
- [ ] All workflows pass in both repos
- [ ] ArgoCD deploys from config repo successfully
- [ ] End-to-end deployment (infra → config) works
- [ ] Documentation updated in both repos
- [ ] Old kubernetes/ directory removed from infra
- [ ] Both repos have proper .gitignore
- [ ] Copilot instructions updated

---

## 📅 Timeline Estimate

- **Phase 1**: Prepare config repo - **2 hours**
- **Phase 2**: Restructure infra repo - **1 hour**
- **Phase 3**: Update workflows - **2 hours**
- **Phase 4**: Update ArgoCD configs - **1 hour**
- **Phase 5**: Update documentation - **2 hours**
- **Phase 6**: Testing & validation - **3 hours**

**Total**: ~11 hours (can be done over 2-3 days)

---

## 🎯 Post-Migration Benefits

1. **Clear Separation**: Infrastructure vs Configuration
2. **Independent Versioning**: Tag releases separately
3. **Simplified CI/CD**: Faster workflows (less to validate)
4. **Better Access Control**: Different teams, different repos
5. **Cleaner Root**: No nested terraform/ directory
6. **Standard Layout**: Matches industry best practices
7. **Easier Onboarding**: New developers find files faster

---

## 📚 Reference Links

- Terraform Root Module Best Practices: https://developer.hashicorp.com/terraform/language/modules#the-root-module
- Kustomize Multi-Repo: https://kubectl.docs.kubernetes.io/references/kustomize/
- ArgoCD Multi-Repo: https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/
- GitHub Monorepo Split: https://docs.github.com/en/get-started/using-git/splitting-a-subfolder-out-into-a-new-repository

---

## 🆘 Rollback Plan

If migration fails:

1. **Keep old infra repo untouched until verified**
2. **Revert changes**: `git revert <commit-sha>`
3. **Delete config repo if not working**: Can recreate
4. **Use old workflow**: Deploy from infra/kubernetes/ until fixed
5. **Document issues**: Create GitHub issues for problems found

**Important**: Don't delete the old kubernetes/ directory until end-to-end deployment succeeds!

---

**Status**: READY FOR EXECUTION  
**Next Step**: Create config repository and begin Phase 1
