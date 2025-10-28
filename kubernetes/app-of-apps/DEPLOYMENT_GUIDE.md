# App of Apps Deployment Guide

## Overview

This repository implements the **App of Apps pattern** - a GitOps best practice for managing multiple applications as a single unit.

## 🎯 What is App of Apps?

The App of Apps pattern organizes applications hierarchically:
- **Parent Application**: Manages all child applications
- **Child Applications**: Individual components (Kafka, services, monitoring)

## 📁 Structure

```
kubernetes/
├── base/                          # Base configurations
│   ├── kafka/                     # Kafka cluster base
│   └── apps/                      # Application services base
├── overlays/                      # Environment-specific configs
│   ├── dev/                       # Dev overrides
│   └── prod/                      # Prod overrides
└── app-of-apps/                   # App of Apps pattern
    ├── base/                      # All apps together
    ├── overlays/
    │   ├── dev/                   # Deploy all to dev
    │   └── prod/                  # Deploy all to prod
    └── argocd/                    # ArgoCD configs (optional)
        ├── parent-app.yaml        # ArgoCD parent
        └── apps/                  # ArgoCD child apps
```

## 🚀 Deployment Methods

### Method 1: Simple kubectl (Current - Recommended for Start)

Deploy everything with one command:

```bash
# Download kubeconfig from GitHub Actions artifacts
export KUBECONFIG=./kubeconfig.yaml

# Deploy all apps to dev
kubectl apply -k kubernetes/app-of-apps/overlays/dev

# Deploy all apps to prod
kubectl apply -k kubernetes/app-of-apps/overlays/prod
```

**What gets deployed:**
- ✅ Kafka cluster (3 brokers)
- ✅ Example ingestion service
- ✅ Example strategy service
- ✅ All namespaces

**Benefits:**
- Simple and fast
- No additional tools needed
- Direct control over deployment

---

### Method 2: Individual Components (Granular Control)

Deploy components separately:

```bash
# Deploy only Kafka
kubectl apply -k kubernetes/overlays/dev/kafka

# Deploy only apps
kubectl apply -k kubernetes/overlays/dev/apps

# Deploy only monitoring (when you add it)
kubectl apply -k kubernetes/overlays/dev/monitoring
```

**When to use:**
- Testing individual components
- Debugging specific services
- Gradual rollout

---

### Method 3: ArgoCD GitOps (Future - Automated)

Once ArgoCD is installed:

```bash
# Install ArgoCD first
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy the parent app (manages everything)
kubectl apply -f kubernetes/app-of-apps/argocd/parent-app.yaml
```

**What happens:**
1. ArgoCD creates the parent application
2. Parent app discovers all child apps
3. ArgoCD automatically deploys and syncs everything
4. Any Git changes trigger automatic updates

**Benefits:**
- Fully automated GitOps
- Self-healing (auto-fix drift)
- Audit trail (who changed what)
- Easy rollbacks

---

## 📊 Comparison

| Method | Complexity | Automation | Best For |
|--------|------------|------------|----------|
| **kubectl (App of Apps)** | ⭐☆☆☆☆ | Manual | Starting out, testing |
| **kubectl (Individual)** | ⭐⭐☆☆☆ | Manual | Debugging, granular control |
| **ArgoCD** | ⭐⭐⭐☆☆ | Automatic | Production, teams, GitOps |

---

## 🔧 Current Workflow Integration

The GitHub Actions workflow currently deploys components individually. You can easily switch to App of Apps:

### Option A: Keep Current (Recommended for Now)

```yaml
# .github/workflows/deploy-cluster.yml
# Current approach - works fine!
- name: Apply Kafka Cluster
  run: kubectl apply -k kubernetes/overlays/${{ inputs.environment }}/kafka
```

### Option B: Use App of Apps (One-Command Deploy)

```yaml
# .github/workflows/deploy-cluster.yml
# Deploy everything at once
- name: Deploy All Applications
  run: kubectl apply -k kubernetes/app-of-apps/overlays/${{ inputs.environment }}
```

---

## 📝 Adding New Applications

### 1. Create Base Configuration

```bash
# Create new app directory
mkdir -p kubernetes/base/my-new-app

# Create manifests
cat > kubernetes/base/my-new-app/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-new-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-new-app
  template:
    metadata:
      labels:
        app: my-new-app
    spec:
      containers:
      - name: app
        image: my-image:latest
EOF

# Create kustomization
cat > kubernetes/base/my-new-app/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
EOF
```

### 2. Add to App of Apps

Edit `kubernetes/app-of-apps/base/kustomization.yaml`:

```yaml
resources:
  - ../../base/kafka
  - ../../base/apps
  - ../../base/my-new-app  # Add this line
```

### 3. Create Environment Overrides (Optional)

```bash
# Dev override
mkdir -p kubernetes/overlays/dev/my-new-app
cat > kubernetes/overlays/dev/my-new-app/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../base/my-new-app
patches:
  - target:
      kind: Deployment
      name: my-new-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
EOF
```

### 4. Deploy

```bash
# Deploy all apps (including new one)
kubectl apply -k kubernetes/app-of-apps/overlays/dev
```

---

## 🎯 Best Practices

### 1. Start Simple
- ✅ Use App of Apps with kubectl first
- ✅ Get comfortable with the structure
- ✅ Add ArgoCD later when you need automation

### 2. Organize by Component
```
base/
├── infrastructure/     # Kafka, databases
├── services/           # Your apps
└── monitoring/         # Prometheus, Grafana
```

### 3. Use Labels Consistently
```yaml
commonLabels:
  app.kubernetes.io/part-of: trading-system
  app.kubernetes.io/managed-by: kustomize
  environment: dev
```

### 4. Version Control Everything
- All configs in Git
- No manual kubectl edits
- Use PRs for changes

---

## 🔍 Validation

### Test App of Apps Locally

```bash
# Render manifests without applying
kubectl kustomize kubernetes/app-of-apps/overlays/dev > /tmp/dev-manifests.yaml

# Review what will be deployed
cat /tmp/dev-manifests.yaml

# Check for errors
kubectl apply --dry-run=client -f /tmp/dev-manifests.yaml
```

### Verify Deployment

```bash
# Check all resources
kubectl get all -A

# Check specific namespaces
kubectl get all -n kafka
kubectl get all -n ingestion
kubectl get all -n strategies
```

---

## 🚀 Migration Path

### Current State → App of Apps → ArgoCD

**Phase 1 (Now):** Individual component deployment
```bash
kubectl apply -k kubernetes/overlays/dev/kafka
kubectl apply -k kubernetes/overlays/dev/apps
```

**Phase 2 (Next):** App of Apps with kubectl
```bash
kubectl apply -k kubernetes/app-of-apps/overlays/dev
```

**Phase 3 (Future):** ArgoCD automation
```bash
kubectl apply -f kubernetes/app-of-apps/argocd/parent-app.yaml
# Everything else is automatic!
```

**No breaking changes** - all three methods work with the same config structure!

---

## 💡 When to Use What

### Use kubectl + App of Apps when:
- ✅ Starting new project
- ✅ Learning Kubernetes
- ✅ Ephemeral clusters (spin up/down often)
- ✅ Small team (1-3 people)

### Switch to ArgoCD when:
- ✅ Running 24/7 clusters
- ✅ Multiple teams/developers
- ✅ Need audit trail
- ✅ Want automatic sync from Git
- ✅ Need rollback capabilities

---

## 📚 Further Reading

- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [GitOps Principles](https://www.gitops.tech/)

---

## ✅ Summary

You now have:
- ✅ App of Apps structure ready
- ✅ Works with current kubectl workflow
- ✅ ArgoCD configs prepared for future
- ✅ Easy to add new applications
- ✅ Environment-specific overrides
- ✅ No breaking changes to existing setup

**Next steps:**
1. Test app-of-apps deployment locally
2. Update GitHub workflow (optional)
3. Add new applications as needed
4. Consider ArgoCD when cluster runs 24/7
