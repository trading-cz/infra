# Architecture Design - K3s Trading System

## System Overview

**Purpose**: Ephemeral Kubernetes cluster for algorithmic trading with Kafka-based data pipeline  
**Runtime**: Dev (2h/day), Production (10h/day, 5 days/week)  
**Team**: 2-person operation with automated deployment  
**Cost**: €23.89/month (production + development)

> **Detailed Implementation**: See [IMPLEMENTATION_DETAILS.md](IMPLEMENTATION_DETAILS.md) for step-by-step guides, code examples, and configuration details.

---

## Core Requirements

### Operational Constraints
1. **Ephemeral Clusters**: No persistence needed, destroyed after trading hours
2. **Data Backup**: Export Kafka topics to Hetzner Object Storage before destruction (JSON format)
3. **GitOps**: All configuration in Git, automated deployment via ArgoCD
4. **Environment Parity**: Dev and prod use identical Kafka/app configurations
5. **Approval Workflow**: Production deployments require review from either team member

### Runtime Parameters
- **Development**: 2h/day, 22 days/month = 6.0% uptime
- **Production**: 10h/day, 5 days/week = 30.1% uptime
- **Application Replicas**: 1 pod per service initially
- **Kafka Cluster**: 3 brokers (KRaft mode) in both environments

---

## Infrastructure Architecture

### Hardware Configuration (Hetzner Cloud)

**Production Cluster** (30.1% uptime: 10h/day, 5 days/week)


Discussed
kube control to interactive
amd instances are cheaper -> or intell -> 
kustomize vs helm  => ask R7 team what they use now or planning to use

garden IO

LogSeq


```yaml
Node 1-3: kafka-0, kafka-1, kafka-2
  Type: cpx31 (4 vCPU, 8GB RAM, 160GB SSD)
  Purpose: Kafka KRaft cluster (broker + controller) + monitoring
  JVM Heap: 2.5GB per broker
  Page Cache: 4.5GB per broker
  Workloads per node:
    - kafka-0: Broker+Controller + Prometheus (150MB)
    - kafka-1: Broker+Controller + Strimzi Operator (150MB)
    - kafka-2: Broker+Controller only
    - System reserve: 700-850MB per node
  Cost: €16.32/mo × 30.1% × 3 = €14.73/month

Node 4: k3s-control
  Type: cpx21 (3 vCPU, 4GB RAM, 80GB SSD)
  Purpose: K3s control plane + ArgoCD + Python apps
  Workloads:
    - K3s control plane: 300MB
    - ArgoCD (core): 200MB
    - Python ingestion: 800MB
    - Python strategies (2×): 1600MB
    - System reserve: 1100MB
  Total: 4000MB / 4GB
  Cost: €8.21/mo × 30.1% = €2.47/month
```

**Development Cluster** (6.0% uptime: 2h/day, 22 days/month)
- Same configuration as production
- Cost: €3.43/month (infrastructure only)

**Storage & Additional Services**
- Hetzner Object Storage (prod): €2.00/month (100GB for topic backups)
- Hetzner Object Storage (dev): €1.00/month (50GB)
- DNS (optional): €0.13/month

**Total Monthly Cost: €23.89**
- Production: €19.20/month
- Development: €4.56/month
- Storage: €3.00/month
- DNS: €0.13/month

### Why 3 Kafka Nodes (Not 2)?

**KRaft Quorum Requirement:**
- Minimum 3 nodes for fault tolerance
- Quorum = (N/2) + 1 = 2 nodes needed
- Survives 1 node failure, cluster remains operational
- 2 nodes = no fault tolerance (any failure = total outage)

### Cluster Topology

```
┌─────────────────────────────────────────────────────┐
│ Hetzner Private Network (10.0.0.0/16)              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  k3s-control (cpx21) - 10.0.1.1                    │
│  ├─ K3s API Server, etcd, scheduler                │
│  ├─ ArgoCD (200MB) - GitOps automation             │
│  └─ Python Apps (ingestion + strategies)           │
│                                                     │
│         ┌──────────┬──────────┬──────────           │
│         ↓          ↓          ↓                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ kafka-0  │ │ kafka-1  │ │ kafka-2  │            │
│  │ (cpx31)  │ │ (cpx31)  │ │ (cpx31)  │            │
│  │          │ │          │ │          │            │
│  │ Broker 0 │ │ Broker 1 │ │ Broker 2 │            │
│  │ Ctrl 0   │ │ Ctrl 1   │ │ Ctrl 2   │            │
│  │ 2.5GB JVM│ │ 2.5GB JVM│ │ 2.5GB JVM│            │
│  │ 4.5GB PG │ │ 4.5GB PG │ │ 4.5GB PG │            │
│  │          │ │          │ │          │            │
│  │Prometheus│ │ Strimzi  │ │          │            │
│  │ 150MB    │ │ 150MB    │ │          │            │
│  └──────────┘ └──────────┘ └──────────┘            │
│       ↑            ↑            ↑                   │
│       └────────────┴────────────┘                   │
│         KRaft Quorum (3 voters)                     │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Resource Distribution Rationale:**
- **Prometheus on kafka-0**: Collects metrics from all Kafka brokers via JMX
- **Strimzi Operator on kafka-1**: Manages Kafka cluster lifecycle
- **Python apps on k3s-control**: Isolated from Kafka for performance
- **ArgoCD on k3s-control**: Central GitOps management

---

## Technology Stack

### Kubernetes Layer
- **K3s**: v1.30+ (lightweight Kubernetes distribution)
- **Kustomize**: Built-in (base + overlays for dev/prod)
- **Namespaces**: kafka, ingestion, strategies

### Kafka Ecosystem
- **Strimzi Operator**: v0.48+ (Kafka management on Kubernetes)
- **Kafka**: v4.0 (KRaft mode, no ZooKeeper)
- **Configuration**:
  - 3 brokers (combined broker+controller)
  - Replication factor: 3
  - Min in-sync replicas: 2
  - Retention: 3 days (72 hours)
  - Auto-create topics: enabled
  - Compression: lz4
  - Storage: ephemeral (emptyDir)

### Automation & Operations
- **ArgoCD**: Core mode (200MB RAM) on k3s-control
  - GitOps continuous deployment
  - Auto-sync from Git repository
  - UI for manual operations and rollback
  - *Details*: See [IMPLEMENTATION_DETAILS.md](IMPLEMENTATION_DETAILS.md#argocd-implementation)
  
- **Prometheus**: Core only (150MB RAM) on kafka-0
  - Metrics collection from Kafka (JMX) and Python apps
  - Built-in UI (no Grafana for 2-person team)
  - 7-day retention
  - Alert rules for consumer lag, latency
  - *Details*: See [IMPLEMENTATION_DETAILS.md](IMPLEMENTATION_DETAILS.md#prometheus-implementation)

- **Strimzi Operator**: (150MB RAM) on kafka-1
  - Manages Kafka cluster lifecycle
  - Automates Kafka configuration and updates

### Application Platform
- **Container Registry**: GitHub Container Registry (ghcr.io)
- **Image Naming**: `ghcr.io/trading-cz/{service-type}-{app-name}:{version}`
  - `ingestion-alpaca-stockstream-api:v1.0.0`
  - `strategy-dummy:v1.0.0`
  
- **Python Apps**:
  - Ingestion: Stock/crypto data streams to Kafka
  - Strategies: Trading algorithms consuming from Kafka
  - Metrics: prometheus-client library

### Data Management
- **Topic Backup**: Pre-destruction JSON export via Python script
- **Storage**: Hetzner Object Storage (S3-compatible)
- **Topic Naming**: Dynamic with business date (e.g., `stock-stream-2025-10-14`)
- **Retention**: Automatic cleanup after 3 days

---

## Namespace & Resource Strategy

### Kubernetes Namespaces

```yaml
kafka:
  Purpose: Kafka cluster isolation
  Resources: 3 Kafka broker pods (StatefulSet)
  
ingestion:
  Purpose: Data ingestion applications
  Resources: Stock/crypto stream pods
  Kafka Access: kafka-bootstrap.kafka.svc.cluster.local:9092
  
strategies:
  Purpose: Trading strategy algorithms
  Resources: Strategy pods (1 per strategy initially)
  Kafka Access: Consumer groups per strategy
```

### Resource Allocation

**Kafka Brokers (per pod):**
```yaml
requests:
  memory: 2Gi
  cpu: 1000m
limits:
  memory: 2500Mi
  cpu: 2000m
jvmOptions:
  -Xms: 2048m
  -Xmx: 2048m
```

**Python Applications (per pod):**
```yaml
requests:
  memory: 600Mi
  cpu: 300m
limits:
  memory: 800Mi
  cpu: 500m
```

---

## Deployment & Operations

### GitOps Workflow

**Repository Structure:**
```
k8s/
├── base/
│   ├── kafka/
│   │   ├── namespace.yaml
│   │   ├── kafka-cluster.yaml
│   │   └── kafka-service.yaml
│   ├── ingestion/
│   │   ├── namespace.yaml
│   │   └── deployments/
│   └── strategies/
│       ├── namespace.yaml
│       └── deployments/
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
└── argocd/
    └── applications/
```

### Branch Strategy
- **master**: Development environment (auto-deploy)
- **production**: Production environment (requires PR + approval)

### GitHub Environments
```yaml
dev:
  Protection: None (auto-deploy on push)
  Reviewers: Not required
  
production:
  Protection: Required reviewers (1 of 2 team members)
  Reviewers: Any team member can approve
  Branch: production only
```

### Deployment Flow

**Development:**
1. Push to `master` branch
2. GitHub Actions triggers
3. ArgoCD auto-syncs within 3 minutes
4. Changes deployed to dev cluster

**Production:**
1. Create PR: `master` → `production`
2. Team member reviews and approves
3. Merge PR
4. ArgoCD syncs to production cluster
5. Manual verification in ArgoCD UI

### Bootstrap Sequence

**One-time cluster setup (GitHub Actions):**
1. Create Hetzner VMs (k3s-control + kafka-0,1,2)
2. Install K3s on control node
3. Install Strimzi Operator (Kafka CRDs)
4. Install Prometheus Operator
5. Install ArgoCD
6. Bootstrap ArgoCD applications (point to Git repo)

**Ongoing deployments (ArgoCD):**
- All application changes via Git commits
- ArgoCD monitors repo every 3 minutes
- Auto-sync or manual sync via UI
- Strimzi Operator reconciles Kafka cluster changes

---

## Monitoring & Observability

**Prometheus** (150MB RAM on kafka-0):
- Metrics collection from Kafka brokers (JMX) and Python apps
- Built-in UI for PromQL queries and alerting
- 7-day retention
- No Grafana (ephemeral clusters + 2-person team)

**Key Metrics:**
- Kafka consumer lag
- Trade processing latency (P95)
- Broker throughput
- Pod restarts

> **Implementation Guide**: See [IMPLEMENTATION_DETAILS.md](IMPLEMENTATION_DETAILS.md#prometheus-implementation) for installation steps, configuration examples, and PromQL queries.

---

## Operational Summary

### Key Design Decisions

✅ **Namespaces**: Service-oriented (kafka, ingestion, strategies)  
✅ **Kafka**: 3 brokers in dev and prod (environment parity)  
✅ **Container Registry**: Separate images per app (ingestion-*, strategy-*)  
✅ **Topic Backup**: Pre-destruction JSON export (Python + Hetzner S3)  
✅ **Topic Creation**: Runtime with business day, 3-day retention  
✅ **GitHub Deployments**: Environments with 2-person approval for prod  
✅ **Monitoring**: Prometheus UI only (no Grafana, 150MB RAM)  
✅ **Secrets**: GitHub Secrets → kubectl create secret in workflow  
✅ **Cloud**: Hetzner-only (compute, storage, networking)  
✅ **ArgoCD**: Core mode for auto-sync, rollback, pod orchestration (200MB RAM)  
✅ **Total Overhead**: 350MB RAM (Prometheus 150MB + ArgoCD 200MB)

### Why This Architecture?

**Distributed Monitoring & Operations:**
- Prometheus on kafka-0: Close to Kafka metrics source
- Strimzi on kafka-1: Load balancing operator responsibilities
- ArgoCD on k3s-control: Central control plane integration
- Python apps isolated: Prevents interference with Kafka performance

**Cost Optimization:**
- Reduced page cache on Kafka nodes (4.5GB vs 5.5GB) to fit monitoring
- Python apps on control node instead of dedicated worker
- 1GB system reserve provides buffer for operations

**Production Ready:**
- 3-node KRaft quorum: Survives 1 node failure
- Resource limits: Prevents cascading failures
- GitOps workflow: Audit trail and easy rollback
- Ephemeral by design: Clean state every trading day

---

## Next Steps

For detailed implementation including:
- Complete GitHub Actions workflows
- Prometheus installation and configuration
- ArgoCD setup and bootstrap
- Python app metrics integration
- Backup/restore procedures
- Implementation timeline

**See**: [IMPLEMENTATION_DETAILS.md](IMPLEMENTATION_DETAILS.md)
