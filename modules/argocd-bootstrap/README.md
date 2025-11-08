# ArgoCD Bootstrap

## Overview

This module contains the initial ArgoCD configuration to bootstrap the GitOps workflow after cluster deployment.

## What It Does

1. **Repository Connection**: Configures ArgoCD to access `trading-cz/config` repository
2. **Parent App Deployment**: Deploys the App-of-Apps parent application
3. **GitOps Activation**: ArgoCD starts managing all applications from the config repo

## Files

- `repository-secret.yaml.template` - Template for repository credentials
- `parent-app.yaml` - Parent Application (App-of-Apps pattern)
- `apply.sh` - Script to apply bootstrap configuration

## Usage

### After Cluster Deployment

```bash
# 1. Configure repository credentials
export GITHUB_TOKEN="ghp_your_token_here"
envsubst < repository-secret.yaml.template > repository-secret.yaml

# 2. Apply bootstrap configuration
./apply.sh

# 3. Verify ArgoCD is syncing
kubectl get applications -n argocd
```

### GitHub Token Requirements

Create a GitHub Personal Access Token with:
- `repo` scope (for private repos)
- Or use deploy keys (read-only access)

### What Happens Next

1. ArgoCD reads `parent-app.yaml` → points to `trading-cz/config` repo
2. Parent app creates child apps from `overlays/dev/app-of-apps/`
3. Each child app deploys its resources (Kafka, ingestion, strategies)
4. GitOps is fully operational - push to config repo = auto-deploy

## Integration with Cloud-Init

The cloud-init script already installs ArgoCD. This bootstrap module is applied **after** cluster deployment to connect ArgoCD to the config repository.

**Option 1**: Manual (recommended for first deployment)
```bash
# SSH to control plane
ssh root@<control-plane-ip>
# Apply bootstrap (credentials stored as sealed secrets)
```

**Option 2**: Automated (add to cloud-init)
```yaml
# In cloud-init.yaml, after ArgoCD installation:
- Store sealed secret for repo access
- Apply parent-app.yaml from this module
```

## Security Considerations

**DO NOT commit `repository-secret.yaml`** (contains GitHub token)
- Use `.gitignore` to exclude it
- Use Sealed Secrets or External Secrets Operator for production
- For dev: can use GitHub Deploy Keys (read-only, repo-specific)
