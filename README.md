# K3s Trading Infrastructure (Hetzner Cloud)

Ephemeral K3s clusters for algorithmic trading. Persistent IPv4s, cost-optimized, automated via Terraform and GitHub Actions.

## Key Features
- Persistent Primary IPs for stable DNS
- VMs are created and destroyed directly (no cluster-level destroy), on a daily basis—no state is kept between runs
- Automated deploy/destroy via GitHub Actions
- GitOps-ready (ArgoCD planned)

## Infrastructure Layout
```
┌───────────────────────────────────────────────────────┐
│ Hetzner Private Network: 10.0.1.0/24                  │
├───────────────────────────────────────────────────────┤
│                                                       │
│    ┌────────────────────────────────────────────┐     │
│    │ Control Plane (CPX21)                      │     │
│    │ • Primary IP #1: public (ArgoCD, SSH)      │     │
│    │ • Private IP: 10.0.1.10                    │     │
│    │ • Runs ArgoCD, K3S                         │     │
│    └────────────────────────────────────────────┘     │
│                                                       │
│    ┌────────────────────────────────────────────┐     │
│    │ Kafka-0 (CPX21)                            │     │
│    │ • Primary IP #2: public (Kafka NodePort)   │     │
│    │ • Private IP: 10.0.1.20                    │     │
│    │ • Kafka broker, Prometheus                 │     │
│    └────────────────────────────────────────────┘     │
│                                                       │
│    ┌────────────┐  ┌────────────┐                     │
│    │ Kafka-1    │  │ Kafka-2    │                     │
│    │ Private IP │  │ Private IP │                     │
│    │ 10.0.1.21  │  │ 10.0.1.22  │                     │
│    │ Kafka only │  │ Kafka only │                     │
│    └────────────┘  └────────────┘                     │
│                                                       │
│    ┌─────────────────────────────┐                    │
│    │ Python App VMs (1-N)        │                    │
│    │ Private IPs: 10.0.1.30+     │                    │
│    │ Trading strategies, scalable│                    │
│    └─────────────────────────────┘                    │
└───────────────────────────────────────────────────────┘


All nodes: private IPv4 only, no IPv6, no public access except Primary IPs.
```


### Namespace Overview
| Namespace | Purpose | Priority | Node Affinity |
|-----------|---------|----------|---------------|
| **kafka** | Message broker infrastructure (Strimzi + brokers) | **CRITICAL** | `kafka=true` |
| **ingestion** | Market data ingestion (Alpaca, IEX, etc.) | **HIGH** | `app=true` |
| **strategies** | Trading strategies (multiple can run) | **MEDIUM** | `app=true` |
| **monitoring** | Prometheus, Grafana, alerts | **LOW** | `app=true` OR control |
| **argocd** | GitOps controllers | **CRITICAL** | control-plane |
| **kube-system** | K3s system components | **CRITICAL** | control-plane |


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

## Node Labeling
Nodes are labeled for scheduling (e.g., control-plane, kafka, app) to ensure workloads run on appropriate VMs.

**Expected Namespaces + nodeSelector + quotas:**
```bash
NAMESPACE      POD                 NODE         GUARANTEED BY
kafka          kafka-0             kafka-0      nodeSelector: kafka=true
kafka          kafka-1             kafka-1      nodeSelector: kafka=true
ingestion      alpaca-ingestion    app-0        nodeSelector: app=true + high priority
strategies     dummy-strategy      app-0        nodeSelector: app=true + medium priority
```

## Technology Stack
K3s v1.34.1+k3s1 · Kafka 4.0.0 (Strimzi) · Terraform v1.13.4 · Hetzner Cloud

### Deploy Cluster

1. **Actions** tab → **Deploy K3s Cluster** → **Run workflow**
2. Choose **Environment** (dev/prod) and **Action** (create)
3. Wait ~15 minutes

**What happens:**
- ✅ Terraform creates/reuses 2 persistent Primary IPs
- ✅ Primary IP #1 attached to control plane
- ✅ Primary IP #2 automatically assigned to kafka-0
- ✅ SSH works immediately (no timeout issues!)
- ✅ Strimzi + Kafka deployed
- ✅ ArgoCD configured for GitOps

# Expected output:
# NAME                             STATUS   LABELS
# k3s-trading-dev-control          Ready    node-role.kubernetes.io/control-plane=true,...
# k3s-trading-dev-kafka-0          Ready    node-role.kubernetes.io/kafka=true,...
# k3s-trading-dev-kafka-1          Ready    node-role.kubernetes.io/kafka=true,...
# k3s-trading-dev-kafka-2          Ready    node-role.kubernetes.io/kafka=true,...
# k3s-trading-dev-app-0            Ready    node-role.kubernetes.io/app=true,...


## License
For details see LICENSE file

---