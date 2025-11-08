# Strimzi Operator Installation - Implementation Summary

## ✅ What Was Implemented

### 1. Module Structure Created

```
modules/strimzi/
├── README.md                      # Full documentation
├── IMPLEMENTATION.md              # This file - implementation summary
├── VERSION                        # 0.48.0 (latest)
├── values.yaml                    # Helm chart configuration reference
└── templates/                     # ⚠️ TEMPLATES ONLY - not deployed by Terraform
    ├── README.md                  # How to use templates
    ├── dev.yaml                   # Example: 1 broker (copy to trading-apps repo)
    └── prod.yaml                  # Example: 3 brokers (copy to trading-apps repo)
```

**Important**: Terraform only installs the Strimzi **operator**. The actual Kafka clusters are deployed later via ArgoCD from your `trading-apps` repository.

### 2. Installation Method

**Approach**: Cloud-Init (Option 3)

**Why?**
- ✅ Declarative (cloud-init YAML)
- ✅ Matches ephemeral cluster philosophy
- ✅ No Terraform Helm provider complexity
- ✅ Operator ready when `terraform apply` completes

**Location**: `modules/k3s-server/cloud-init.yaml`

**What It Does**:
1. Installs Helm 3
2. Adds Strimzi Helm repository
3. Installs Strimzi operator v0.48.0 to `kafka` namespace
4. Configures operator to watch all namespaces
5. Sets resource limits (128Mi-512Mi RAM, 100m-500m CPU)
6. Verifies installation (pods + CRDs)

**New in 0.48.0**:
- ✅ Kafka 4.1.0 support
- ✅ KRaft mode enabled by default (no Zookeeper needed)
- ✅ Kafka Node Pools enabled by default
- ⚠️ Removed support for Kafka 3.9.x

### 3. Separation of Concerns

```
┌─────────────────────────────────────────────────────────┐
│ INFRASTRUCTURE LAYER (Terraform + Cloud-Init)           │
├─────────────────────────────────────────────────────────┤
│ • VMs, networking, firewall                             │
│ • K3s cluster installation                              │
│ • Strimzi OPERATOR installation ONLY ← NEW              │
│   └─ Installs the "factory" (operator + CRDs)           │
│   └─ Does NOT create any Kafka clusters yet             │
└─────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────┐
│ APPLICATION LAYER (ArgoCD + trading-apps Git repo)      │
├─────────────────────────────────────────────────────────┤
│ • Kafka cluster CR (uses Strimzi operator)              │
│ • Kafka topics (KafkaTopic CR)                          │
│ • Kafka users (KafkaUser CR)                            │
│ • Trading applications (your Python apps)               │
└─────────────────────────────────────────────────────────┘
```

**Key Point**: The `templates/` folder contains examples you copy to your `trading-apps` repository, NOT deployed by this infrastructure repo.

## 📝 Kafka Cluster Deployment (Via ArgoCD)

**⚠️ Important**: Kafka clusters are NOT created by Terraform. They are managed by ArgoCD from your `trading-apps` repository.

### Workflow:

1. **Terraform** installs Strimzi operator (this repo)
2. **You copy** `templates/dev.yaml` to your `trading-apps` repo
3. **ArgoCD** deploys the Kafka cluster from `trading-apps` repo

### Example Templates Available:

#### Development (1 broker) - `templates/dev.yaml`
**Specs:**
- **Kafka version**: 4.1.0 (KRaft mode)
- 1 Kafka broker (no replication)
- Ephemeral storage (data lost on restart)
- Internal listener: `9092`
- External NodePort: `33333` (via kafka-0 Primary IP)
- Resources: 1-2Gi RAM, 500m-1000m CPU
- Log retention: 24 hours

#### Production (3 brokers) - `templates/prod.yaml`
**Specs:**
- **Kafka version**: 4.1.0 (KRaft mode)
- 3 Kafka brokers (KRaft quorum, 2/3 consensus)
- Replication factor: 3, min ISR: 2
- Ephemeral storage (matches ephemeral cluster design)
- Internal listener: `9092`
- External NodePort: `33333` (via kafka-0 Primary IP)
- Resources: 2-4Gi RAM, 1000m-2000m CPU
- Log retention: 7 days
- Pod anti-affinity (spread brokers across nodes)

**Usage**: See `templates/README.md` for how to use these in your trading-apps repository.

## 🔍 Verification After Deployment

```bash
# 1. Check Strimzi operator
kubectl get pods -n kafka
# Expected: strimzi-cluster-operator-xxx   Running

# 2. Check CRDs installed
kubectl get crd | grep kafka
# Expected: kafkas.kafka.strimzi.io, kafkatopics.kafka.strimzi.io, etc.

# 3. Check operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator

# 4. Deploy Kafka cluster (manual testing - normally via ArgoCD)
kubectl apply -f modules/strimzi/templates/dev.yaml

# 5. Check Kafka cluster status
kubectl get kafka -n kafka
# Expected: trading-cluster   Ready

# 6. Check Kafka pods
kubectl get pods -n kafka
# Expected: trading-cluster-kafka-0   Running

# 7. Test Kafka (produce/consume)
kubectl -n kafka run kafka-producer-test --rm -i --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-4.1.0 \
  -- /bin/bash -c "echo 'test' | /opt/kafka/bin/kafka-console-producer.sh \
     --bootstrap-server trading-cluster-kafka-bootstrap:9092 --topic test"

kubectl -n kafka run kafka-consumer-test --rm -i --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-4.1.0 \
  -- /opt/kafka/bin/kafka-console-consumer.sh \
     --bootstrap-server trading-cluster-kafka-bootstrap:9092 \
     --topic test --from-beginning --max-messages 1
```

## 🔄 Upgrade Process

Since we use ephemeral clusters, upgrading is simple:

1. Update `modules/strimzi/VERSION` (e.g., `0.49.0`)
2. Update version in `modules/k3s-server/cloud-init.yaml`:
   ```yaml
   --version 0.49.0 \
   ```
3. Check Strimzi release notes for breaking changes:
   - [GitHub Releases](https://github.com/strimzi/strimzi-kafka-operator/releases)
   - [Supported Kafka versions](https://strimzi.io/docs/operators/latest/overview.html#supported-kafka-versions)
4. Update `modules/strimzi/kafka-cluster-examples/*.yaml` with new Kafka version if needed
5. Update `modules/strimzi/values.yaml` if needed
6. Destroy and redeploy cluster:
   ```bash
   # Via GitHub Actions
   Actions → hcloud-maintenance → destroy-cluster
   Actions → Deploy K3s Cluster → dev
   ```

**Version History:**
- **0.48.0** (current): Kafka 4.1.0, KRaft default, Node Pools default
- **0.40.0** (previous): Kafka 4.0.0, KRaft optional

## 📊 Resource Usage

### Strimzi Operator
- **Requests**: 128Mi RAM, 100m CPU
- **Limits**: 512Mi RAM, 500m CPU
- **Namespace**: `kafka`
- **Replicas**: 1

### Kafka Cluster (Dev)
- **Broker**: 1-2Gi RAM, 500m-1000m CPU
- **Entity Operator**: 256Mi RAM, 200m CPU (topic + user management)
- **Kafka Exporter**: 128Mi RAM, 100m CPU (Prometheus metrics)

### Kafka Cluster (Prod)
- **Per Broker**: 2-4Gi RAM, 1000m-2000m CPU (×3 brokers)
- **Entity Operator**: 512Mi RAM, 500m CPU
- **Kafka Exporter**: 256Mi RAM, 200m CPU

## 🎯 Next Steps

1. ✅ **Done**: Strimzi operator 0.48.0 installation via cloud-init
2. ✅ **Done**: GitHub Actions workflow with validation steps
3. ⏳ **Next**: Deploy cluster and test Kafka cluster creation
4. ⏳ **Then**: Create Kafka topics (market-data, trading-signals)
5. ⏳ **Finally**: Integrate with ArgoCD for GitOps workflow
6. ⏳ **Future**: Add Prometheus + Grafana monitoring

## 📋 GitHub Actions Workflow Structure

The deployment workflow is organized into two main sections:

### 1️⃣ **Infrastructure Provisioning** (Steps 1-7)
- Setup tools (Terraform, kubectl, hcloud)
- Create/reuse Primary IPs
- Terraform apply (VMs, network, K3s)
- Verify servers accessible
- Verify cloud-init completed
- Verify K3s cluster operational
- Verify system pods running

### 2️⃣ **Services Installation & Validation** (Steps 8-10)
- ✅ Verify Strimzi operator installed
- ✅ Verify Strimzi CRDs available
- ✅ Verify Helm 3 installed
- ⏳ (Future) Verify Prometheus installed
- ⏳ (Future) Verify Grafana installed

Each step includes validation to ensure the service is ready before proceeding.

## 📚 References

- [Strimzi Documentation](https://strimzi.io/docs/operators/latest/overview.html)
- [Kafka CRD Reference](https://strimzi.io/docs/operators/latest/configuring.html#type-Kafka-reference)
- [Helm Chart Values](https://github.com/strimzi/strimzi-kafka-operator/tree/main/helm-charts/helm3/strimzi-kafka-operator)
