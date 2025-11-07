# Workflow Split - Before vs After

## Summary of Changes

The `deploy-cluster.yml` workflow has been split into TWO workflows across TWO repositories:

### 1. Infrastructure Repository (`trading-cz/infra`)
**File**: `.github/workflows/deploy-cluster-infra-only.yml`
- Deploys Terraform infrastructure (VMs, networks, IPs)
- Installs K3s cluster
- Outputs kubeconfig as artifact
- **STOPS HERE** - no Kubernetes configs

### 2. Config Repository (`trading-cz/config`)
**File**: `.github/workflows/deploy-apps.yml`
- Downloads kubeconfig from infra deployment
- Installs Strimzi Operator
- Deploys Kafka cluster
- Installs ArgoCD
- Configures App-of-Apps
- **NEW**: Can skip Strimzi/ArgoCD if already installed

---

## Detailed Breakdown

### What Stayed in `infra` Repository

✅ **Kept (Lines 1-169 of original)**
```yaml
jobs:
  terraform:
    steps:
      - Checkout code
      - Setup Terraform
      - Create SSH keys
      - Terraform Init/Validate/Plan/Apply
      - Save Terraform outputs
      - Assign Primary IP to kafka-0
      - Fetch kubeconfig
      - Upload kubeconfig artifact
      - Verify cluster (kubectl get nodes)
      - Infrastructure summary
```

### What Moved to `config` Repository

✅ **Moved (Lines 199-367 of original)**
```yaml
jobs:
  post-setup:  # Now: deploy-configs job
    steps:
      - Install Strimzi Operator          → Moved
      - Apply Kafka Cluster               → Moved
      - Create application namespaces     → Moved
      - Install ArgoCD                    → Moved
      - Configure ArgoCD Repository       → Moved + Updated repo URL
      - Wait for ArgoCD Sync              → Moved
      - Cluster Ready Summary             → Moved + Updated
```

---

## Key Differences

### Repository URL Changes

**BEFORE** (in infra repo):
```yaml
source:
  repoURL: 'https://github.com/trading-cz/infra.git'
  targetRevision: main
  path: kubernetes/overlays/dev/app-of-apps
```

**AFTER** (in config repo):
```yaml
source:
  repoURL: 'https://github.com/trading-cz/config.git'  # ← Changed
  targetRevision: main
  path: overlays/dev/app-of-apps                       # ← Changed (no kubernetes/ prefix)
```

### Path Changes in Workflows

**BEFORE** (single repo):
```yaml
- name: Apply Kafka Cluster
  run: kubectl apply -k kubernetes/overlays/${{ inputs.environment }}/kafka
```

**AFTER** (config repo):
```yaml
- name: Apply Kafka Cluster Configuration
  run: kubectl apply -k overlays/${{ inputs.environment }}/kafka
  # No kubernetes/ prefix - it's now at root level
```

### Artifact Download (NEW)

**Config workflow must download kubeconfig from infra deployment:**
```yaml
- name: Download kubeconfig from infra deployment
  uses: actions/download-artifact@v4
  with:
    name: kubeconfig-${{ inputs.environment }}
    run-id: ${{ inputs.kubeconfig_run_id }}  # ← NEW INPUT PARAMETER
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### New Optional Features

**Config workflow allows skipping components:**
```yaml
inputs:
  skip_strimzi:
    description: 'Skip Strimzi installation (if already installed)'
    type: boolean
    default: false
  skip_argocd:
    description: 'Skip ArgoCD installation (if already installed)'
    type: boolean
    default: false
```

This is useful when:
- Re-deploying apps without reinstalling operators
- Testing Kafka configuration changes
- Updating ArgoCD applications only

---

## Deployment Flow Comparison

### BEFORE (Single Repo - Monolithic)

```
GitHub Actions: Deploy K3s Cluster
├─ Job: terraform (10 min)
│  ├─ Deploy infrastructure
│  ├─ Fetch kubeconfig
│  └─ Upload kubeconfig artifact
│
└─ Job: post-setup (5-10 min)
   ├─ Download kubeconfig
   ├─ Install Strimzi
   ├─ Deploy Kafka
   ├─ Install ArgoCD
   └─ Configure App-of-Apps

Total: ~15-20 minutes
Single workflow, single repo
```

### AFTER (Split - Two Repos)

```
STEP 1: Infrastructure Deployment
GitHub Actions: trading-cz/infra → Deploy K3s Cluster
└─ Job: terraform (10 min)
   ├─ Deploy infrastructure
   ├─ Fetch kubeconfig
   └─ Upload kubeconfig artifact ✅

STEP 2: Configuration Deployment  
GitHub Actions: trading-cz/config → Deploy Applications
└─ Job: deploy-configs (5-10 min)
   ├─ Download kubeconfig from infra ⬇️
   ├─ Install Strimzi
   ├─ Deploy Kafka
   ├─ Install ArgoCD
   └─ Configure App-of-Apps

Total: ~15-20 minutes
Two workflows, two repos, better separation
```

---

## How to Use After Split

### Full Deployment (Fresh Cluster)

**Step 1**: Deploy Infrastructure
```
Repository: trading-cz/infra
Workflow: Deploy K3s Cluster (Infrastructure Only)
Inputs:
  - environment: dev
  
Output: kubeconfig-dev artifact + Run ID #123
```

**Step 2**: Deploy Configurations
```
Repository: trading-cz/config
Workflow: Deploy Applications
Inputs:
  - environment: dev
  - kubeconfig_run_id: 123  ← From Step 1
  - skip_strimzi: false
  - skip_argocd: false
```

### Update Kafka Configuration Only

**Skip infrastructure, just redeploy Kafka:**
```
Repository: trading-cz/config
Workflow: Deploy Applications
Inputs:
  - environment: dev
  - kubeconfig_run_id: 123  ← Existing cluster
  - skip_strimzi: true       ← Already installed
  - skip_argocd: true        ← Already installed
```

### GitOps Updates (No Manual Deployment)

After initial setup, ArgoCD handles updates:
```bash
# Just push changes to config repo
cd config/
git checkout main
# Edit overlays/dev/kafka/patches.yaml
git commit -m "feat: increase Kafka replicas"
git push

# ArgoCD auto-syncs within minutes ✨
```

---

## Summary Tables

### Infra Workflow Comparison

| Feature | Before | After |
|---------|--------|-------|
| **File** | `.github/workflows/deploy-cluster.yml` | `.github/workflows/deploy-cluster-infra-only.yml` |
| **Jobs** | 2 (terraform + post-setup) | 1 (terraform only) |
| **Lines** | 367 | ~220 |
| **Deploys** | Infrastructure + Configs | Infrastructure only |
| **Outputs** | kubeconfig artifact | kubeconfig artifact |
| **Duration** | 15-20 min | 10 min |

### Config Workflow (NEW)

| Feature | Details |
|---------|---------|
| **File** | `.github/workflows/deploy-apps.yml` (NEW) |
| **Repository** | `trading-cz/config` (NEW) |
| **Jobs** | 1 (deploy-configs) |
| **Lines** | ~280 |
| **Deploys** | Strimzi, Kafka, ArgoCD, Apps |
| **Requires** | kubeconfig from infra deployment |
| **Duration** | 5-10 min |
| **New Features** | Skip flags for reinstalls |

---

## Benefits of Split

✅ **Separation of Concerns**
- Infrastructure team owns `infra` repo
- Application team owns `config` repo

✅ **Faster Iterations**
- Update Kafka without redeploying infrastructure
- Test config changes without touching Terraform

✅ **Independent Versioning**
- Tag infrastructure releases separately
- Tag config releases separately

✅ **Better CI/CD**
- Infra changes trigger infrastructure tests only
- Config changes trigger Kustomize validation only
- No cross-validation needed

✅ **Clearer Workflow Names**
- "Deploy K3s Cluster" = infrastructure only
- "Deploy Applications" = configs only

✅ **Reusable Infrastructure**
- Same cluster, multiple config deployments
- Easy to test different Kafka configurations

---

## Migration Checklist

When moving to split workflow:

- [ ] Create `trading-cz/config` repository
- [ ] Copy `kubernetes/` directory to config repo root
- [ ] Update ArgoCD `repoURL` in all Application specs
- [ ] Update paths: `kubernetes/overlays/` → `overlays/`
- [ ] Add `deploy-apps.yml` workflow to config repo
- [ ] Update `deploy-cluster.yml` in infra repo (or create new `-infra-only.yml`)
- [ ] Test infrastructure deployment
- [ ] Test config deployment with kubeconfig download
- [ ] Verify ArgoCD syncs from new config repo
- [ ] Update documentation in both repos
- [ ] Archive old `deploy-cluster.yml` (or rename for rollback)

---

## Files Created

1. **`deploy-cluster-infra-only.yml`**
   - Location: `infra/.github/workflows/`
   - Purpose: Infrastructure-only deployment
   - Ready to use: ✅

2. **`WORKFLOW_CONFIG_DEPLOY_APPS.yml`**
   - Location: Will go to `config/.github/workflows/deploy-apps.yml`
   - Purpose: Kubernetes config deployment
   - Ready to use: ✅ (after repo split)

3. **`WORKFLOW_SPLIT_COMPARISON.md`** (this file)
   - Location: Documentation
   - Purpose: Migration guide and comparison
