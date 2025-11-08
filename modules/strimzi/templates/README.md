# Kafka Cluster Templates

These are **example/template** files for creating Kafka clusters using Strimzi.

## ⚠️ Important

These files are **NOT deployed by Terraform**. They are templates for you to:

1. **Copy to your `trading-apps` Git repository**
2. **Manage via ArgoCD** (GitOps)
3. **Customize** for your needs

## What Terraform Installs

Terraform only installs the **Strimzi Operator** - the "factory" that can create Kafka clusters.

```
Infrastructure (Terraform) → Installs Strimzi Operator
Application (ArgoCD)      → Uses operator to create Kafka clusters
```

## Usage

### Option 1: Manual Deployment (Testing)
```bash
# Download template
kubectl apply -f templates/dev.yaml

# Check status
kubectl get kafka -n kafka
```

### Option 2: ArgoCD (Recommended)
```yaml
# In your trading-apps repo: argocd/kafka-cluster.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kafka-cluster
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/trading-cz/trading-apps
    targetRevision: main
    path: kafka  # Contains your customized cluster yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: kafka
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Templates Available

- `dev.yaml` - 1 broker, ephemeral storage, 24h retention
- `prod.yaml` - 3 brokers, KRaft quorum, 7d retention

Both use Kafka 4.1.0 with KRaft mode (no Zookeeper).
