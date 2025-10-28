# App of Apps Pattern

This directory implements the "App of Apps" pattern, which is compatible with:
- **Current setup**: Simple `kubectl apply -k` deployment
- **Future setup**: ArgoCD GitOps workflow

## Concept

The App of Apps pattern organizes applications in a hierarchical structure:
- **Root application** → Points to all child applications
- **Child applications** → Individual components (Kafka, apps, monitoring, etc.)

## Current Structure

```
app-of-apps/
├── base/
│   └── root-app.yaml          # Root kustomization (all apps)
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml  # Dev environment apps
│   └── prod/
│       └── kustomization.yaml  # Prod environment apps
└── argocd/                     # ArgoCD-specific (optional)
    ├── parent-app.yaml         # ArgoCD parent application
    └── apps/
        ├── kafka-app.yaml      # ArgoCD app for Kafka
        ├── ingestion-app.yaml  # ArgoCD app for ingestion
        └── strategies-app.yaml # ArgoCD app for strategies
```

## Usage

### Option 1: Simple Deployment (Current)

Deploy all applications at once:

```bash
# Deploy everything to dev
kubectl apply -k kubernetes/app-of-apps/overlays/dev

# Deploy everything to prod
kubectl apply -k kubernetes/app-of-apps/overlays/prod
```

### Option 2: ArgoCD Deployment (Future)

Once ArgoCD is installed:

```bash
# Install the parent app (manages all child apps)
kubectl apply -f kubernetes/app-of-apps/argocd/parent-app.yaml

# ArgoCD will automatically deploy and sync all child apps
```

## Benefits

1. **Single command deployment**: Deploy entire stack with one command
2. **Modular**: Easy to add/remove applications
3. **Environment-specific**: Different apps for dev/prod
4. **ArgoCD-ready**: Can switch to GitOps without restructuring
5. **DRY principle**: Reuse base configurations

## Adding New Applications

1. Create app manifests in `kubernetes/base/your-app/`
2. Add to `kubernetes/app-of-apps/base/root-app.yaml`
3. Override settings in `overlays/dev/` or `overlays/prod/` if needed
4. Optionally create ArgoCD app in `argocd/apps/your-app.yaml`
