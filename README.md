
# K3s Trading Infrastructure on Hetzner Cloud

**Ephemeral K3s clusters** on Hetzner Cloud for algorithmic trading with **persistent IPv4 addresses**. Infrastructure as Code (Terraform) + GitOps (ArgoCD).

---

## 📚 Documentation

- **This Repo (Infra)**: Terraform, VMs, K3s cluster, ArgoCD bootstrap
- **Config Repo**: [trading-cz/config](https://github.com/trading-cz/config) - All Kubernetes manifests
- **📖 Config Setup Guide**: [CONFIG_REPO_SETUP_GUIDE.md](CONFIG_REPO_SETUP_GUIDE.md) - **START HERE for app deployments**
- **Namespace Design**: [NAMESPACE_DESIGN.md](NAMESPACE_DESIGN.md) - Architecture and best practices

---

## 🎯 Key Features

✅ **Persistent Primary IPs**: Same IPs across all deployments (€1.00/month)  
✅ **Ephemeral VMs**: Deploy for ~10h/day, destroy rest (58% cost savings!)  
✅ **Stable DNS**: Configure once, works forever  
✅ **ArgoCD GitOps**: Auto-deploy from `main` (dev) or `production` (prod)  
✅ **Kafka KRaft**: 3-broker cluster (v4.0.0) with external access  
✅ **Automated Workflows**: One-click deploy and destroy via GitHub Actions

## 📦 Technology Stack

- **Kubernetes**: K3s v1.34.1+k3s1 (lightweight, production-ready)
- **Message Broker**: Apache Kafka 4.0.0 via Strimzi Operator (KRaft mode, no ZooKeeper)
- **GitOps**: ArgoCD with App-of-Apps pattern
- **Infrastructure as Code**: Terraform v1.13.4 (modular design)
- **Configuration Management**: Kustomize overlays (base + dev/prod patches)
- **Cloud Provider**: Hetzner Cloud (Nuremberg, Germany)

## 🏗️ Architecture Overview

### Infrastructure Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Hetzner Private Network: 10.0.0.0/16                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Control Plane (CAX21 - ARM64)                      │    │
│  │ • Primary IP #1: 95.217.X.Y (€0.50/mo persistent)  │    │
│  │ • K3s API Server + ArgoCD only                     │    │
│  │ • Private IP: 10.0.1.10                            │    │
│  │ • Public access: kubectl, ArgoCD UI, SSH           │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌────────────────┐  ┌────────────┐  ┌────────────┐        │
│  │ kafka-0 (CX22) │  │ kafka-1    │  │ kafka-2    │        │
│  │ Primary IP #2  │  │ Private    │  │ Private    │        │
│  │ 95.217.A.B     │  │ only       │  │ only       │        │
│  │ (€0.50/mo)     │  │            │  │            │        │
│  │ 10.0.1.20      │  │ 10.0.1.21  │  │ 10.0.1.22  │        │
│  │ External Kafka │  │            │  │            │        │
│  └────────────────┘  └────────────┘  └────────────┘        │
│                                                             │
│  ┌────────────────┐                                         │
│  │ app-0 (CX22)   │  ← Python Applications                 │
│  │ Private only   │                                         │
│  │ 10.0.1.30      │  • alpaca-ingestion                    │
│  │ No public IP   │  • dummy-strategy                      │
│  └────────────────┘  • future trading apps                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘

External Access:
• Control Plane: 95.217.X.Y (ArgoCD UI, kubectl, SSH)
• Kafka External: 95.217.A.B:32100 (NodePort → internal :9094)
• kafka-1, kafka-2, app-0: Private network only (no public IP)

Internal Communication:
• Private network: 10.0.1.0/24 (all VMs communicate internally)
• Kafka internal listener: port 9092 (cluster-only access)
• Python apps connect via: trading-cluster-kafka-bootstrap.kafka:9092

Node Roles:
• Control plane: node-role.kubernetes.io/control-plane=true
• Kafka nodes: node-role.kubernetes.io/kafka=true
• App nodes: node-role.kubernetes.io/app=true
```

### Cost Optimization Strategy

**Traditional 24/7 cluster**: ~€56/month  
**Our ephemeral approach**: ~€11/month (80% savings!)

| Resource | Cost | Strategy |
|----------|------|----------|
| Primary IPs (2×) | €1.00/month | Persistent, always billed |
| Control Plane VM (CAX21) | ~€1.22/month | Destroyed daily (~10h/day, 22 days) |
| Kafka VMs (3× CX22) | ~€5.25/month | Destroyed daily (~10h/day, 22 days) |
| App VM (1× CX22) | ~€1.75/month | Destroyed daily (~10h/day, 22 days) |
| **Total (Prod)** | **~€9.22/month** | **84% cheaper than 24/7!** |

💡 **The Magic**: Primary IPs cost €1/month continuously, but VMs only cost when running. Deploy for 10h/day, destroy rest → massive savings!

**Detailed Breakdown**:

**Production** (10h/day × 22 days = 30% uptime):
- CAX21 (Control, ARM64): €4.05/month × 30% = €1.22/month
- CX22 (Kafka × 3): €5.83/month × 3 × 30% = €5.25/month
- CX22 (App × 1): €5.83/month × 30% = €1.75/month
- Primary IPs (2×): €1.00/month
- **Prod Total**: €9.22/month

**Dev** (2h/day × 22 days = 6% uptime):
- CAX21 (Control): €4.05/month × 6% = €0.25/month
- CX22 (Kafka × 3): €5.83/month × 3 × 6% = €1.05/month
- CX22 (App × 1): €5.83/month × 6% = €0.35/month
- **Dev Total**: €1.65/month

**Combined Total**: **~€11/month** (prod + dev + Primary IPs)

## 🚀 Quick Start

### 1. Setup (One-Time)

**GitHub Secrets** (Settings → Secrets → Actions):
- `HCLOUD_TOKEN` - Hetzner API token ([get here](https://console.hetzner.cloud/))
- `SSH_PRIVATE_KEY` - Generate: `ssh-keygen -t ed25519 -f ./id_ed25519 -N ""`
- `SSH_PUBLIC_KEY` - Public key from above

### 2. Deploy Cluster

1. **Actions** tab → **Deploy K3s Cluster** → **Run workflow**
2. Choose **Environment** (dev/prod) and **Action** (create)
3. Wait ~10 minutes

**What happens:**
- ✅ Terraform creates/reuses 2 persistent Primary IPs
- ✅ Primary IP #1 attached to control plane
- ✅ Primary IP #2 automatically assigned to kafka-0
- ✅ SSH works immediately (no timeout issues!)
- ✅ Strimzi + Kafka deployed
- ✅ ArgoCD configured for GitOps

### 3. Access Cluster

Download `kubeconfig-{env}` artifact from GitHub Actions, then:

```bash
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
kubectl get pods -A

# ArgoCD apps
kubectl get applications -n argocd
```

### 4. Configure DNS (One-Time)

After first deployment, get Primary IPs from GitHub Actions output:

```bash
# Example IPs (yours will be different)
Control Plane: 95.217.X.Y
Kafka External: 95.217.A.B
```

Add A records in your DNS:
```
argocd.yourdomain.tld.    300  IN  A  95.217.X.Y
kafka.yourdomain.tld.     300  IN  A  95.217.A.B
```

**These IPs NEVER change!** Configure once, use forever.

## 🗑️ Destroy Cluster (Daily Cleanup)

### Option 1: Destroy VMs Only (Recommended)

**Actions** → **hcloud-maintenance** → **Environment**: dev → **Action**: destroy-vms

✅ Deletes all VMs (fast, instant savings!)  
✅ Keeps Primary IPs (€1.00/month continues)  
✅ Next deployment reuses same IPs  
✅ DNS still works

**Use this for**: Daily cleanup after trading hours

### Option 2: Destroy Everything (Nuclear)

**Actions** → **hcloud-maintenance** → **Environment**: dev → **Action**: destroy-all

⚠️ Deletes VMs + Primary IPs  
⚠️ Stops all billing (including €1/month for IPs)  
⚠️ Next deployment gets NEW random IPs  
⚠️ Must update DNS

**Use this for**: Shutting down environment permanently

## 🔄 GitOps Workflow

ArgoCD monitors your Git branches in the **config repository** (https://github.com/trading-cz/config):

```
Push to main       → Auto-deploys to dev cluster
Push to production → Auto-deploys to prod cluster
```

**Making changes:**
1. Edit manifests in **config repo** (`overlays/dev/` or `overlays/prod/`)
2. Commit to `main` (for dev) or `production` (for prod)
3. Push to GitHub
4. ArgoCD auto-syncs (~30 seconds)

**Repository separation:**
- **Infra repo** (this repo): Terraform, VMs, network, K3s cluster, ArgoCD bootstrap
- **Config repo** (trading-cz/config): All Kubernetes manifests, Kustomize overlays, applications

## �️ Node Labels & Pod Scheduling

### Node Labels Configuration

Each node type is automatically labeled during creation to control where pods can run:

| Node Type | Labels | Taint | Purpose |
|-----------|--------|-------|---------|
| **Control Plane** | `node-role.kubernetes.io/control-plane=true` (auto) | `NoSchedule` | K3s API + ArgoCD + system pods only |
| **Kafka Nodes** | `node-role.kubernetes.io/kafka=true` | None | Kafka brokers only |
| **App Nodes** | `node-role.kubernetes.io/app=true` | None | Python trading applications |

### How It Works

**1. Labels are set during node initialization:**

```bash
# Kafka nodes (kafka-0, kafka-1, kafka-2)
k3s agent --node-label="node-role.kubernetes.io/kafka=true"

# App nodes (app-0, app-1, ...)
k3s agent --node-label="node-role.kubernetes.io/app=true"

# Control plane gets labeled automatically + tainted
kubectl taint nodes control-plane node-role.kubernetes.io/control-plane=true:NoSchedule
```

**2. Pods use nodeSelector to target specific nodes:**

```yaml
# Example: Python app deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpaca-ingestion
spec:
  template:
    spec:
      nodeSelector:
        node-role.kubernetes.io/app: "true"  # Only run on app nodes
      containers:
        - name: alpaca-ingestion
          image: ghcr.io/trading-cz/alpaca-ingestion:latest
```

**3. Kafka pods (managed by Strimzi) use affinity/tolerations:**

Strimzi automatically schedules Kafka pods on nodes labeled `kafka=true`.

### Pod Scheduling Rules

| Workload Type | nodeSelector | Runs On |
|---------------|--------------|---------|
| **Kafka Pods** | `node-role.kubernetes.io/kafka=true` | kafka-0, kafka-1, kafka-2 |
| **Python Apps** | `node-role.kubernetes.io/app=true` | app-0 (and app-1+ when scaled) |
| **ArgoCD** | Tolerates control-plane taint | Control plane |
| **System Pods** | Tolerates control-plane taint | Control plane |

### Verify Node Labels

```bash
# Check all node labels
kubectl get nodes --show-labels

# Expected output:
# NAME                             STATUS   LABELS
# k3s-trading-dev-control          Ready    node-role.kubernetes.io/control-plane=true,...
# k3s-trading-dev-kafka-0          Ready    node-role.kubernetes.io/kafka=true,...
# k3s-trading-dev-kafka-1          Ready    node-role.kubernetes.io/kafka=true,...
# k3s-trading-dev-kafka-2          Ready    node-role.kubernetes.io/kafka=true,...
# k3s-trading-dev-app-0            Ready    node-role.kubernetes.io/app=true,...

# Check where pods are running
kubectl get pods -A -o wide
```

### Adding nodeSelector to Your Apps

**In your `config` repo** (https://github.com/trading-cz/config):

```yaml
# overlays/dev/alpaca-ingestion/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpaca-ingestion
spec:
  template:
    spec:
      nodeSelector:
        node-role.kubernetes.io/app: "true"  # ADD THIS!
```

**Apply via Kustomize:**
```yaml
# overlays/dev/alpaca-ingestion/kustomization.yaml
patches:
  - path: deployment-patch.yaml
```

### Scaling App Nodes

To add more app workers:

```hcl
# environments/prod.tfvars
app_node_count = 3  # Scale from 1 to 3
```

This creates:
- `app-0`: 10.0.1.30
- `app-1`: 10.0.1.31
- `app-2`: 10.0.1.32

All automatically labeled with `node-role.kubernetes.io/app=true`

## 📦 Namespace Strategy

### Design Philosophy

**Purpose-based separation** aligned with:
1. **Business Priority**: Critical path (ingestion) vs optional (monitoring)
2. **Resource Isolation**: Prevent noisy neighbors (strategies don't starve ingestion)
3. **Security Boundaries**: Different RBAC policies per component
4. **Deployment Cadence**: Frequent strategy updates vs stable infrastructure

### Namespace Overview

| Namespace | Purpose | Priority | Node Affinity | Resource Quota |
|-----------|---------|----------|---------------|----------------|
| **kafka** | Message broker infrastructure (Strimzi + brokers) | **CRITICAL** | `kafka=true` | 80% of kafka nodes |
| **ingestion** | Market data ingestion (Alpaca, IEX, etc.) | **HIGH** | `app=true` | 50% of app nodes |
| **strategies** | Trading strategies (multiple can run) | **MEDIUM** | `app=true` | 40% of app nodes |
| **monitoring** | Prometheus, Grafana, alerts | **LOW** | `app=true` OR control | 10% of app nodes |
| **argocd** | GitOps controllers | **CRITICAL** | control-plane | Unlimited (system) |
| **kube-system** | K3s system components | **CRITICAL** | control-plane | Unlimited (system) |

### Why This Design?

**✅ Follows Kubernetes Best Practices:**
- **Separation of Concerns**: Infrastructure (kafka) vs data pipeline (ingestion) vs business logic (strategies)
- **Least Privilege**: Each namespace gets minimal RBAC permissions
- **Resource Isolation**: Quotas prevent strategies from starving ingestion
- **Blast Radius Containment**: Bug in strategy doesn't crash data ingestion

**✅ Aligns with Trading System Priorities:**
```
Priority 1: INGESTION (market data must flow)
  ├─ Dedicated namespace with guaranteed resources
  ├─ High CPU/memory quota (50% of app nodes)
  └─ PriorityClass: trading-high (preempts strategies if needed)

Priority 2: STRATEGIES (multiple experiments)
  ├─ Separate namespace for easy scaling/deletion
  ├─ Medium quota (40% of app nodes)
  └─ PriorityClass: trading-medium (can be evicted)

Priority 3: MONITORING (nice to have)
  ├─ Low quota (10% of app nodes)
  └─ PriorityClass: trading-low (least important)
```

**✅ Industry Standards:**
- **Single Responsibility**: Each namespace has ONE job (Netflix, Uber patterns)
- **Environment Parity**: Same namespaces in dev/prod (GitOps best practice)
- **Observable**: Clear boundaries for metrics/logging (Datadog, Prometheus)

### Namespace Naming Convention

**Current Design** (Recommended):
```
kafka        ← Infrastructure (noun: what it is)
ingestion    ← Functional area (noun: what it does)
strategies   ← Functional area (plural: many can run)
monitoring   ← Cross-cutting concern (noun: observability)
```

**Alternative** (Not Recommended):
```
❌ trading-apps     ← Too generic, groups different priorities
❌ data-pipeline    ← Doesn't distinguish ingestion vs strategies
❌ app-tier         ← Too vague, hard to apply RBAC
```

### How Namespaces + Labels Work Together

Kubernetes namespaces provide **logical separation** for workloads, while node labels provide **physical separation**. You need BOTH for proper resource isolation.

### How Namespaces + Labels Work Together

```
┌─────────────────────────────────────────────────────────────┐
│ NAMESPACE: kafka (CRITICAL - Infrastructure)                │
│ ├─ strimzi-cluster-operator (Deployment)                    │
│ ├─ kafka-0 (StatefulSet Pod)                                │
│ ├─ kafka-1 (StatefulSet Pod)                                │
│ └─ kafka-2 (StatefulSet Pod)                                │
│                                                              │
│ nodeSelector: node-role.kubernetes.io/kafka: "true"         │
│ Runs on: kafka-0, kafka-1, kafka-2 VMs (dedicated)         │
│ Resource Quota: 6 CPU, 24GB RAM (80% of 3×CX22)            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ NAMESPACE: ingestion (HIGH - Critical data path)            │
│ ├─ alpaca-ingestion (Deployment) - PRIORITY                 │
│ ├─ iex-ingestion (future)                                   │
│ └─ market-data-validator (future)                           │
│                                                              │
│ nodeSelector: node-role.kubernetes.io/app: "true"           │
│ Runs on: app-0 (scales to app-1, app-2...)                 │
│ Resource Quota: 1 CPU, 2GB RAM (50% of 1×CX22)             │
│ PriorityClass: trading-high (preempts strategies)          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ NAMESPACE: strategies (MEDIUM - Business logic)             │
│ ├─ dummy-strategy (Deployment)                              │
│ ├─ momentum-strategy (future)                               │
│ ├─ mean-reversion-strategy (future)                         │
│ └─ [many more strategies...]                                │
│                                                              │
│ nodeSelector: node-role.kubernetes.io/app: "true"           │
│ Runs on: app-0 (shared with ingestion)                     │
│ Resource Quota: 0.8 CPU, 1.6GB RAM (40% of 1×CX22)         │
│ PriorityClass: trading-medium (evictable)                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ NAMESPACE: monitoring (LOW - Observability)                 │
│ ├─ prometheus (StatefulSet)                                 │
│ ├─ grafana (Deployment)                                     │
│ └─ alertmanager (Deployment)                                │
│                                                              │
│ nodeSelector: node-role.kubernetes.io/app: "true"           │
│ Runs on: app-0 OR control-plane (flexible)                 │
│ Resource Quota: 0.2 CPU, 400MB RAM (10% of 1×CX22)         │
│ PriorityClass: trading-low (lowest priority)               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ NAMESPACE: argocd (CRITICAL - System)                       │
│ ├─ argocd-application-controller                            │
│ ├─ argocd-repo-server                                       │
│ └─ argocd-server                                            │
│                                                              │
│ Tolerations: control-plane taint                            │
│ Runs on: control-plane VM (CAX21)                          │
│ Resource Quota: Unlimited (system component)               │
└─────────────────────────────────────────────────────────────┘
```

### Why Both Are Needed

**Namespaces alone (without nodeSelector):**
```bash
# ❌ BAD - Pods can run anywhere, resource chaos!
NAMESPACE      POD                 NODE         PROBLEM
kafka          kafka-0             app-0        Kafka on app node - I/O contention!
ingestion      alpaca-ingestion    kafka-1      Data pipeline on Kafka - CPU starvation!
strategies     dummy-strategy      kafka-0      Strategy stealing Kafka RAM!
```

**Namespaces + nodeSelector + quotas:**
```bash
# ✅ GOOD - Predictable placement, guaranteed resources!
NAMESPACE      POD                 NODE         GUARANTEED BY
kafka          kafka-0             kafka-0      nodeSelector: kafka=true
kafka          kafka-1             kafka-1      nodeSelector: kafka=true
ingestion      alpaca-ingestion    app-0        nodeSelector: app=true + high priority
strategies     dummy-strategy      app-0        nodeSelector: app=true + medium priority
```

### Current Configuration

**In this repo (infra):** ArgoCD bootstrap template points to config repo
```yaml
# argocd/parent-app-bootstrap.yaml.tpl
source:
  repoURL: '${config_repo_url}'  # → https://github.com/trading-cz/config.git
  targetRevision: ${target_revision}  # → main (dev) or production (prod)
  path: overlays/${environment}/app-of-apps
```

**In config repo (trading-cz/config):** All Kubernetes manifests live here
```yaml
# config/overlays/dev/app-of-apps/alpaca-ingestion.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: alpaca-ingestion
  namespace: argocd
spec:
  destination:
    namespace: ingestion  # ← HIGH priority namespace

# config/overlays/dev/app-of-apps/dummy-strategy.yaml
destination:
  namespace: strategies  # ← MEDIUM priority namespace

# config/overlays/dev/app-of-apps/kafka.yaml
destination:
  namespace: kafka  # ← CRITICAL infrastructure namespace
```

**See**: `CONFIG_REPO_SETUP_GUIDE.md` for complete config repo implementation guide

**In config repo deployments:** Must add nodeSelector + resource limits
```yaml
# config/overlays/dev/ingestion/alpaca-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpaca-ingestion
  namespace: ingestion
spec:
  replicas: 1
  template:
    spec:
      priorityClassName: trading-high  # ← Preempts lower priority pods
      nodeSelector:
        node-role.kubernetes.io/app: "true"  # ← Physical placement
      containers:
        - name: alpaca-ingestion
          resources:
            requests:
              cpu: "500m"      # ← Guaranteed 0.5 CPU
              memory: "1Gi"    # ← Guaranteed 1GB RAM
            limits:
              cpu: "1000m"     # ← Max 1 CPU burst
              memory: "2Gi"    # ← Max 2GB RAM

---
# config/overlays/dev/strategies/dummy-strategy-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dummy-strategy
  namespace: strategies
spec:
  replicas: 1
  template:
    spec:
      priorityClassName: trading-medium  # ← Can be evicted by ingestion
      nodeSelector:
        node-role.kubernetes.io/app: "true"
      containers:
        - name: dummy-strategy
          resources:
            requests:
              cpu: "200m"      # ← Guaranteed 0.2 CPU
              memory: "512Mi"  # ← Guaranteed 512MB
            limits:
              cpu: "400m"      # ← Max 0.4 CPU
              memory: "1Gi"    # ← Max 1GB
```

### Resource Quotas (Recommended - Prevents Resource Starvation)

**Create quotas to enforce priorities:**

```yaml
# config/base/ingestion/resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ingestion-quota
  namespace: ingestion
spec:
  hard:
    requests.cpu: "1"          # 50% of CX22 (2 vCPU)
    requests.memory: 2Gi       # 50% of CX22 (4GB RAM)
    limits.cpu: "2"            # Can burst to full node
    limits.memory: 4Gi         # Can burst to full RAM
    pods: "5"                  # Max 5 ingestion pods

---
# config/base/strategies/resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: strategies-quota
  namespace: strategies
spec:
  hard:
    requests.cpu: "800m"       # 40% of CX22
    requests.memory: 1600Mi    # 40% of CX22
    limits.cpu: "1600m"        # Can burst to 80%
    limits.memory: 3200Mi      # Can burst to 80%
    pods: "20"                 # Many strategies can run

---
# config/base/monitoring/resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: monitoring-quota
  namespace: monitoring
spec:
  hard:
    requests.cpu: "200m"       # 10% of CX22
    requests.memory: 400Mi     # 10% of CX22
    limits.cpu: "400m"
    limits.memory: 800Mi
    pods: "10"
```

**Why these quotas work:**
- **Ingestion**: 50% guaranteed → Always has resources for market data
- **Strategies**: 40% guaranteed → Can run multiple strategies, but won't starve ingestion
- **Monitoring**: 10% guaranteed → Observability runs, but lowest priority
- **Total**: 100% reserved, but limits allow bursting (Kubernetes overcommit)

### PriorityClasses (Recommended - Eviction Order)

**Define which pods get evicted first under resource pressure:**

```yaml
# config/base/priority-classes.yaml
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: trading-high
value: 1000
globalDefault: false
description: "Critical data ingestion - never evict"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: trading-medium
value: 500
globalDefault: false
description: "Trading strategies - evictable if ingestion needs resources"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: trading-low
value: 100
globalDefault: false
description: "Monitoring/observability - evict first"
```

**Behavior under resource pressure:**
```
CX22 app-0 running at 100% CPU:
1. Evict monitoring pods (PriorityClass: 100)
2. Evict strategy pods (PriorityClass: 500)
3. Keep ingestion pods (PriorityClass: 1000)
```

### Network Policies (Future)

Restrict inter-namespace communication:

```yaml
# Example: Only allow trading-apps to access kafka
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-kafka-access
  namespace: kafka
spec:
  podSelector: {}
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: trading-apps
```

### Verify Namespace Configuration

```bash
# List all namespaces
kubectl get namespaces

# Expected output:
# NAME           STATUS   AGE
# kafka          Active   10m
# ingestion      Active   10m
# strategies     Active   10m
# monitoring     Active   5m
# argocd         Active   10m
# kube-system    Active   15m
# default        Active   15m

# Check pods per namespace with node + priority info
kubectl get pods -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
PRIORITY:.spec.priorityClassName,\
CPU-REQ:.spec.containers[*].resources.requests.cpu,\
MEM-REQ:.spec.containers[*].resources.requests.memory

# Expected output:
# NAMESPACE    NAME                    NODE      PRIORITY        CPU-REQ  MEM-REQ
# kafka        kafka-0-xyz             kafka-0   <none>          1        4Gi
# kafka        kafka-1-xyz             kafka-1   <none>          1        4Gi
# kafka        kafka-2-xyz             kafka-2   <none>          1        4Gi
# ingestion    alpaca-ingestion-abc    app-0     trading-high    500m     1Gi
# strategies   dummy-strategy-def      app-0     trading-medium  200m     512Mi
# monitoring   prometheus-ghi          app-0     trading-low     100m     200Mi
# argocd       argocd-server-jkl       control   <none>          250m     256Mi

# Verify resource quotas exist
kubectl get resourcequota -A

# Expected output:
# NAMESPACE    NAME                 AGE   REQUEST                         LIMIT
# ingestion    ingestion-quota      5m    requests.cpu: 500m/1, ...
# strategies   strategies-quota     5m    requests.cpu: 400m/800m, ...
# monitoring   monitoring-quota     5m    requests.cpu: 100m/200m, ...

# Check if ingestion pods have priority
kubectl get pods -n ingestion -o yaml | grep priorityClassName
# Output: priorityClassName: trading-high

# Verify nodeSelector is applied
kubectl get pods -n ingestion -o yaml | grep -A2 nodeSelector
# Output:
#   nodeSelector:
#     node-role.kubernetes.io/app: "true"
```

### ⚠️ ACTION REQUIRED: Update Config Repo

The infra repo creates the infrastructure and namespace definitions. You MUST update your **config repo** (https://github.com/trading-cz/config):

**1. Update ArgoCD Application destinations:**
```yaml
# config/overlays/dev/app-of-apps/alpaca-ingestion.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: alpaca-ingestion
  namespace: argocd
spec:
  destination:
    namespace: ingestion  # ← Change from trading-apps to ingestion
    server: https://kubernetes.default.svc

# config/overlays/dev/app-of-apps/dummy-strategy.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dummy-strategy
  namespace: argocd
spec:
  destination:
    namespace: strategies  # ← Change from trading-apps to strategies
    server: https://kubernetes.default.svc
```

**2. Add nodeSelector + priorityClass to deployments:**
```yaml
# config/overlays/dev/ingestion/alpaca-deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpaca-ingestion
spec:
  template:
    spec:
      priorityClassName: trading-high  # ← ADD: High priority
      nodeSelector:
        node-role.kubernetes.io/app: "true"  # ← ADD: Run on app nodes
      containers:
        - name: alpaca-ingestion
          resources:  # ← ADD: Resource limits
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "1000m"
              memory: "2Gi"
```

**3. Create PriorityClasses and ResourceQuotas:**
```bash
# Create priority classes (one-time setup)
kubectl apply -f config/base/priority-classes.yaml

# Create resource quotas per namespace
kubectl apply -f config/base/ingestion/resource-quota.yaml
kubectl apply -f config/base/strategies/resource-quota.yaml
kubectl apply -f config/base/monitoring/resource-quota.yaml
```

**Without these changes in config repo:**
- ❌ Pods will schedule randomly (no nodeSelector)
- ❌ Strategies can starve ingestion (no resource quotas)
- ❌ Critical pods get evicted first (no priorityClass)

## �️ Project Structure

## 🏗️ Project Structure

### Terraform (Infrastructure as Code)

This project uses a fully modular Terraform setup for infrastructure. All cloud resources are managed via modules:

```
terraform/
├── main.tf, variables.tf, outputs.tf, versions.tf
├── modules/
│   ├── network/   # Networking, firewall, Primary IPs
│   ├── compute/   # SSH keys
│   ├── k3s/       # K3s cluster VMs
│   └── kafka/     # (reserved for future use)
├── environments/
│   ├── dev.tfvars   # Dev config (shared vCPU)
│   └── prod.tfvars  # Prod config (dedicated vCPU)
└── templates/       # VM init scripts
```

**Key Changes (Nov 2025)**:
- ✨ Added **persistent Primary IPs** in network module
- ✨ Control plane uses Primary IP #1 (attached via Terraform)
- ✨ kafka-0 uses Primary IP #2 (assigned via GitHub Actions)
- ✨ kafka-1, kafka-2 use private network only (save €1/month)
- ✨ Disabled IPv6 (not needed - private network handles internal comms)
- ✨ Fixed Terraform outputs to return public IPs (solves SSH timeout!)

### Repository Structure

**This repo (infra):** Infrastructure as Code only
```
infra/
├── terraform/
│   ├── main.tf, variables.tf, outputs.tf
│   ├── modules/
│   │   ├── network/     # VPC, firewall, Primary IPs
│   │   ├── compute/     # SSH keys
│   │   └── k3s/         # VMs + cloud-init scripts
│   └── environments/
│       ├── dev.tfvars
│       └── prod.tfvars
├── templates/
│   ├── control-plane-init.sh  # K3s master + ArgoCD bootstrap
│   └── worker-init.sh          # K3s agent with node labels
├── argocd/
│   └── parent-app-bootstrap.yaml.tpl  # ArgoCD bootstrap template
└── .github/workflows/
    ├── deploy-cluster.yml       # Terraform → K3s → ArgoCD
    └── hcloud-maintenance.yml   # Cluster lifecycle management
```

**Config repo (trading-cz/config):** All Kubernetes manifests
```
config/
├── base/
│   ├── priority-classes.yaml  # Pod eviction priorities
│   ├── kafka/                 # Kafka cluster (Strimzi)
│   ├── ingestion/             # Market data ingestion
│   ├── strategies/            # Trading strategies
│   └── monitoring/            # Prometheus, Grafana
├── overlays/
│   ├── dev/                   # Dev-specific configs
│   │   ├── app-of-apps/       # ArgoCD Application CRs
│   │   ├── kafka/
│   │   ├── ingestion/
│   │   └── strategies/
│   └── prod/                  # Prod-specific configs
└── README.md
```

**See**: `CONFIG_REPO_SETUP_GUIDE.md` for complete config repo implementation guide

### GitHub Actions Workflows

```
.github/workflows/
├── deploy-cluster.yml       # Main deployment workflow
├── hcloud-maintenance.yml   # VM/IP cleanup workflow
└── review-terraform.yml     # PR validation
```

## � Common Tasks

### View Current Resources

**Actions** → **hcloud-maintenance** → **Action**: list

Shows:
- ✅ Primary IPs (persistent, always visible)
- ✅ Servers (VMs)
- ✅ Networks, firewalls, SSH keys

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

### Deploy Your Trading App

1. Add deployment to `kubernetes/base/apps/your-app.yaml`
2. Update `kubernetes/base/apps/kustomization.yaml` to include your app
3. Commit and push to `main` (dev) or `production` (prod)
4. ArgoCD deploys automatically (~30 seconds)

### Kafka Connection Strings

**Internal** (from pods in cluster):
```bash
# Python apps use this (via KAFKA_BOOTSTRAP_SERVERS env variable)
trading-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
```
- Uses Kafka **internal listener** (port 9092)
- Resolves to private network IPs: 10.0.1.11, 10.0.1.12, 10.0.1.13
- All 3 brokers accessible via single DNS name
- No public IP needed - stays on private network

**External** (from internet):
```bash
# Connect from outside K8s cluster
<kafka-0-public-ip>:32100
# Or with DNS: kafka.yourdomain.tld:32100
```
- Uses Kafka **external listener** (port 9094, exposed via NodePort 32100)
- Routes to kafka-0 via Primary IP #2 (95.217.A.B)
- All 3 brokers still accessible (Kafka handles routing)

### Check ArgoCD Status

```bash
kubectl get applications -n argocd
kubectl describe application trading-system-dev -n argocd

# View sync status
kubectl get app -n argocd -o jsonpath='{.items[*].status.sync.status}'
```

## 💰 Detailed Cost Breakdown

### Monthly Costs (Production Environment, 10h/day uptime, 22 days/month)

| Resource | Hourly Rate | Daily (10h) | Monthly (22 days) | Notes |
|----------|-------------|-------------|-------------------|-------|
| Control Plane (CAX21) | €0.0056 | €0.056 | ~€1.23 | 4 vCPU, 8GB RAM, ARM64 |
| kafka-0 (CX22) | €0.0081 | €0.081 | ~€1.78 | 2 vCPU, 4GB RAM, public IP |
| kafka-1 (CX22) | €0.0081 | €0.081 | ~€1.78 | 2 vCPU, 4GB RAM, private |
| kafka-2 (CX22) | €0.0081 | €0.081 | ~€1.78 | 2 vCPU, 4GB RAM, private |
| app-0 (CX22) | €0.0081 | €0.081 | ~€1.78 | 2 vCPU, 4GB RAM, private |
| Primary IP #1 | - | - | €0.50 | Persistent (24/7) |
| Primary IP #2 | - | - | €0.50 | Persistent (24/7) |
| **Production Total** | - | **~€0.380** | **~€9.35** | **84% cheaper than 24/7!** |

**Development Environment** (2h/day, 22 days/month = 44 hours/month):
- Control Plane (CAX21): €4.05/month × 6% = €0.25/month
- Kafka (3× CX22): €5.83/month × 3 × 6% = €1.05/month
- App (1× CX22): €5.83/month × 6% = €0.35/month
- **Dev Total**: ~€1.65/month

**Combined Total**: €9.35 (prod) + €1.65 (dev) + €1.00 (Primary IPs) = **~€12.00/month**

**vs 24/7 operation**: 
- Prod 24/7: €4.05 + (€5.83 × 4) = €27.37/month
- Dev 24/7: €4.05 + (€5.83 × 4) = €27.37/month
- Total 24/7: €54.74/month + €1.00 (IPs) = €55.74/month
- **Savings: €43.74/month (78% cheaper!)**
- **Savings: €69.47/month (77% reduction!)**

### Cost Optimization Tips

1. **Daily destroy**: Use `hcloud-maintenance → destroy-vms` after trading hours
2. **Weekend shutdowns**: Destroy Friday evening, deploy Monday morning
3. **Dev vs Prod**: Run dev only when testing (1-2h/day instead of 10h)
4. **Keep Primary IPs**: €1/month is trivial vs manual DNS updates

## 🐛 Troubleshooting

### SSH Timeout During Deployment

**Fixed!** Terraform now outputs public IP from Primary IP #1.

If you still see issues:
```bash
# Check Terraform outputs
cd terraform
terraform output control_plane_ip  # Should show 95.217.X.Y (not 10.0.1.10)
```

### ArgoCD Not Syncing

```bash
kubectl get applications -n argocd -o yaml
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Kafka Pods Failing

```bash
kubectl logs -n kafka <pod-name>
kubectl describe pod -n kafka <pod-name>

# Check Strimzi operator
kubectl logs -n kafka -l name=strimzi-cluster-operator
```

### Primary IP Not Assigned to kafka-0

Check GitHub Actions logs for "Assign Primary IP to kafka-0" step. Should show:
```
✅ Primary IP #2 successfully assigned to kafka-0!
   Kafka external IP: 95.217.A.B
```

If failed, manually assign:
```bash
# Get IDs from Hetzner console or hcloud-maintenance list
hcloud server poweroff <kafka-0-id>
hcloud primary-ip assign <primary-ip-id> <kafka-0-id>
hcloud server poweron <kafka-0-id>
```

## ⚡ Advanced Topics

### Add Monitoring

See [ARCHITECTURE_FINAL_CLEAN.md](./ARCHITECTURE_FINAL_CLEAN.md) for Prometheus/Grafana setup

### Restrict Firewall

Edit `terraform/main.tf` firewall rules to limit source IPs:

```hcl
{
  direction   = "in"
  protocol    = "tcp"
  port        = "22"
  source_ips  = ["YOUR.IP.ADDRESS/32"]  # Restrict SSH
  description = "Allow SSH from office"
}
```

### Persistent Storage

Add Hetzner volumes for stateful workloads (databases, etc.)

### Change Datacenter

Edit `terraform/environments/{dev|prod}.tfvars`:
```hcl
location   = "fsn1"        # Falkenstein
datacenter = "fsn1-dc14"   # Must match location!
```

⚠️ **Warning**: Changing datacenter requires new Primary IPs (different IPs, update DNS)

⚠️ **Warning**: Changing datacenter requires new Primary IPs (different IPs, update DNS)

## 📚 Documentation

- **[ARCHITECTURE_FINAL_CLEAN.md](./ARCHITECTURE_FINAL_CLEAN.md)** - Complete architecture and design decisions
- **[TERRAFORM_IPV4_OPTIMIZATION_PLAN.md](./TERRAFORM_IPV4_OPTIMIZATION_PLAN.md)** - Primary IP implementation details
- **[SSH_KEY_SETUP.md](./SSH_KEY_SETUP.md)** - SSH key generation guide
- **GitHub Actions Workflows** - See `.github/workflows/` for deployment automation

## 🔒 Security Notes

**Public IPv4 Exposure**:
- Control plane (Primary IP #1): SSH, K3s API (6443), ArgoCD
- kafka-0 (Primary IP #2): Kafka external listener via NodePort 32100 → port 9094
- kafka-1, kafka-2: Private network only (no public IP)

**Internal Communication**:
- All VMs use **private network** (10.0.1.0/24) for internal communication
- Kafka internal listener (port 9092): Used by Python apps inside K8s
- Python apps connect via DNS: `trading-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- No IPv6 needed - private IPv4 network handles all inter-VM traffic

### Firewall Configuration (Testing Phase)

**Current Setup** (for unrestricted testing):
- ❌ **Control plane**: NO firewall (has public IPv4)
- ❌ **kafka-0**: NO firewall (has public IPv4)
- ✅ **kafka-1**: Firewall enabled (no public IPv4 anyway - redundant)
- ✅ **kafka-2**: Firewall enabled (no public IPv4 anyway - redundant)

**Key Points**:
- ✅ Hetzner firewall **only affects public interfaces** - private network (10.0.1.0/24) is NEVER blocked
- ✅ All 4 nodes communicate freely on private network regardless of firewall settings
- ✅ Kafka cluster (3 brokers) communicates internally without restrictions
- ✅ Python apps can access all Kafka nodes via internal network
- ⚠️ Public internet access is unrestricted on control-plane and kafka-0 for testing

**After Testing** - Enable firewall protection:
1. Edit `terraform/modules/k3s/main.tf`
2. Uncomment control plane firewall: `firewall_ids = [var.firewall_id]`
3. Change kafka-0 to use firewall: `firewall_ids = [var.firewall_id]`
4. Restrict source IPs in `terraform/main.tf` firewall rules (see below)

**Recommendations**:
1. **Restrict SSH**: Update firewall rules to your IP only
2. **Enable Kafka TLS**: Configure in Kafka manifests
3. **Rotate SSH keys**: Regenerate periodically
4. **Monitor access**: Check Hetzner Cloud Console for unusual activity

## 📊 Monitoring Primary IPs

Always list Primary IPs before destroying:

```bash
# Via GitHub Actions
Actions → hcloud-maintenance → list

# Via hcloud CLI
export HCLOUD_TOKEN=your-token
hcloud primary-ip list -l environment=dev
```

**What you'll see**:
```
ID       NAME                         IP           ASSIGNEE
12345    k3s-trading-dev-network-control-ip   95.217.X.Y   123456
12346    k3s-trading-dev-network-kafka-ip     95.217.A.B   123457
```

## 🎓 Learning Resources

- **Hetzner Cloud**: [docs.hetzner.com/cloud/](https://docs.hetzner.com/cloud/)
- **Primary IPs**: [docs.hetzner.com/cloud/servers/primary-ips/](https://docs.hetzner.com/cloud/servers/primary-ips/)
- **K3s**: [docs.k3s.io/](https://docs.k3s.io/)
- **Strimzi**: [strimzi.io/docs/](https://strimzi.io/docs/)
- **ArgoCD**: [argo-cd.readthedocs.io/](https://argo-cd.readthedocs.io/)

## 🆕 What's New (November 2025)

### ✨ Persistent Primary IPv4 Implementation

**Version Information**:
- Terraform: v1.13.4
- K3s: v1.34.1+k3s1
- Kafka (Strimzi): 4.0.0
- Hetzner Cloud Provider

**Key Changes (Nov 2025)**:
- ✅ Added 2 persistent Primary IPs (€1.00/month total)
- ✅ Primary IP #1 auto-attached to control plane (Terraform)
- ✅ Primary IP #2 auto-assigned to kafka-0 (GitHub Actions)
- ✅ kafka-1, kafka-2 use private network only (save €1.00/month)
- ✅ Disabled IPv6 completely (not needed for this architecture)
- ✅ Fixed SSH timeout issue (Terraform outputs public IPs)
- ✅ Updated `hcloud-maintenance` with `destroy-cluster` and `destroy-all` options
- ✅ Added Kafka ports (9092-9094) to firewall
- ✅ Kafka listeners: internal (9092) + external (9094 via NodePort 32100)

**Benefits**:
- 🎯 **Stable DNS**: Same IPs across all deployments
- 💰 **Cost Optimized**: 50% savings on IPv4 costs (€2.00 → €1.00/month)
- 🚀 **Automated**: No manual IP assignment needed
- 📈 **Scalable**: Perfect for ephemeral daily deployments

**Migration Path**:
If you have existing deployments:
1. Current auto-assigned IPs will be replaced by Primary IPs on next deployment
2. Update DNS to new Primary IP addresses (one-time, from GitHub Actions output)
3. Subsequent deployments reuse same IPs forever

---

**Resources**: [Hetzner](https://docs.hetzner.com/cloud/) • [K3s](https://docs.k3s.io/) • [Strimzi](https://strimzi.io/docs/) • [ArgoCD](https://argo-cd.readthedocs.io/)

## 📝 License

This infrastructure code is provided as-is for the trading-cz project.

---

## 🤝 Contributing

This is a private infrastructure repository. For questions or issues, contact the team.

---

**Happy Trading! 🚀📈**
