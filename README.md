# K3s Trading Infrastructure on Hetzner Cloud

Automated K3s + Kafka (KRaft) infrastructure with ArgoCD GitOps for algorithmic trading applications.

## 🏗️ Modular Project Structure

This project uses a fully modular Terraform setup for infrastructure. All cloud resources are managed via modules:

```
terraform/
├── main.tf, variables.tf, outputs.tf, versions.tf
├── modules/
│   ├── network/   # Networking (VPC, subnets, firewall)
│   ├── compute/   # VMs, SSH keys
│   ├── k3s/       # K3s cluster resources
│   └── kafka/     # Kafka cluster (future)
├── environments/
│   ├── dev.tfvars
│   └── prod.tfvars
└── templates/     # VM initialization scripts
```

Kubernetes manifests are also organized for GitOps and environment overlays:

```
kubernetes/
├── base/           # Base configurations
│   ├── kafka/      # Kafka cluster
│   └── apps/       # Trading apps
├── overlays/       # Environment overrides
│   ├── dev/
│   └── prod/
└── app-of-apps/    # ArgoCD app-of-apps pattern
```

All changes are validated with CI/CD review gates for Terraform format, lint, and config validity.

## What You Get

- **K3s Cluster**: 1 control + 3 kafka workers on Hetzner Cloud
- **Kafka**: 3-broker KRaft cluster (Strimzi operator)
- **ArgoCD**: GitOps automation (`main` branch → dev, `production` branch → prod)
- **Ephemeral**: Create/destroy on-demand to save costs

## � Quick Start

### 1. Setup (One-Time)

**GitHub Secrets** (Settings → Secrets → Actions):
- `HCLOUD_TOKEN` - Hetzner API token ([get here](https://console.hetzner.cloud/))
- `SSH_PRIVATE_KEY` - Generate: `ssh-keygen -t ed25519 -f ./id_ed25519 -N ""`
- `SSH_PUBLIC_KEY` - Public key from above

### 2. Deploy Cluster

1. **Actions** tab → **Deploy K3s Cluster** → **Run workflow**
2. Choose **Environment** (dev/prod) and **Action** (create/destroy)
3. Wait ~10 minutes

### 3. Access Cluster

Download `kubeconfig-{env}` artifact, then:

```bash
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
kubectl get pods -A
```

## 🔄 GitOps Workflow

ArgoCD monitors your Git branches:

```
Push to main       → Auto-deploys to dev cluster
Push to production → Auto-deploys to prod cluster
```

**Making changes:**
1. Edit manifests in `kubernetes/`
2. Commit to `main` (for dev) or `production` (for prod)
3. Push to GitHub
4. ArgoCD auto-syncs (~30 seconds)

## 📁 Structure

```
kubernetes/
├── base/           # Base configurations
│   ├── kafka/      # Kafka cluster
│   └── apps/       # Your applications
├── overlays/       # Environment overrides
│   ├── dev/
│   └── prod/
└── app-of-apps/    # ArgoCD app-of-apps pattern
```

## 🔧 Common Tasks

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

### Deploy Your App

1. Add deployment to `kubernetes/base/apps/`
2. Update `kubernetes/base/apps/kustomization.yaml`
3. Commit and push → ArgoCD deploys automatically

### Kafka Connection String

**Internal**: `trading-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`  
**External**: `<NODE_IP>:32100` (any kafka node)

### Check ArgoCD Status

```bash
kubectl get applications -n argocd
kubectl describe application trading-system-dev -n argocd
```

## 💰 Costs

**Dev** (6% uptime): ~€3.43/month  
**Prod** (30% uptime): ~€17.20/month

💡 **Tip**: Destroy when not in use!

## 📚 Documentation

- [ARGOCD_SETUP.md](./ARGOCD_SETUP.md) - ArgoCD configuration & usage
- [TESTING_TUTORIAL.md](./TESTING_TUTORIAL.md) - Step-by-step testing guide
- [EXTENSIBILITY_GUIDE.md](./EXTENSIBILITY_GUIDE.md) - Add features (monitoring, storage)
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Command cheat sheet

## � Branch Strategy

| Branch | Environment | Auto-Deploy |
|--------|-------------|-------------|
| `main` | dev | ✅ Yes |
| `production` | prod | ✅ Yes |

**Best Practice**: Test in `main` → Merge to `production`

## 🐛 Troubleshooting

**Cluster not ready?** Check GitHub Actions logs  
**ArgoCD not syncing?** `kubectl get applications -n argocd -o yaml`  
**Kafka pods failing?** `kubectl logs -n kafka <pod-name>`

## ⚡ Advanced

- **Add monitoring**: See [EXTENSIBILITY_GUIDE.md](./EXTENSIBILITY_GUIDE.md)
- **Restrict firewall**: Edit `terraform/main.tf` firewall rules
- **Persistent storage**: Add Hetzner volumes (guide in extensibility doc)

---

**Resources**: [Hetzner](https://docs.hetzner.com/cloud/) • [K3s](https://docs.k3s.io/) • [Strimzi](https://strimzi.io/docs/) • [ArgoCD](https://argo-cd.readthedocs.io/)

## 📝 License

This infrastructure code is provided as-is for the trading-cz project.

---

## 🤝 Contributing

This is a private infrastructure repository. For questions or issues, contact the team.

---

**Happy Trading! 🚀📈**
