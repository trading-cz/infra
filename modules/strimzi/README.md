# Strimzi Kafka Operator

## What is Strimzi?

Strimzi is a Kubernetes operator that simplifies Kafka deployment and management on Kubernetes. It uses **Custom Resources (CRDs)** to define Kafka clusters declaratively.

## Why Strimzi?

- ✅ **Declarative**: Define Kafka clusters as YAML manifests
- ✅ **Kubernetes-native**: Integrates with K8s RBAC, networking, storage
- ✅ **Production-ready**: Handles upgrades, scaling, monitoring
- ✅ **KRaft mode**: Kafka 4.1.0 without Zookeeper (enabled by default)
- ✅ **Node Pools**: Advanced broker management (enabled by default in 0.48.0)

## Current Version

**Operator**: 0.48.0 (see `VERSION` file)  
**Supported Kafka**: 4.1.0  
**Mode**: KRaft (no Zookeeper needed)

**What's New in 0.48.0:**
- ✅ Kafka 4.1.0 support
- ✅ KRaft mode enabled by default
- ✅ Kafka Node Pools enabled by default
- ⚠️ Removed support for Kafka 3.9.x

## Installation Method

The Strimzi operator is installed automatically during K3s control plane bootstrap via **cloud-init** (see `modules/k3s-server/cloud-init.yaml`).

```bash
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka \
  --create-namespace \
  --version 0.48.0 \
  --set watchAnyNamespace=true
```

## Upgrade Process

Since we use ephemeral clusters:

1. Check Strimzi release notes: https://github.com/strimzi/strimzi-kafka-operator/releases
2. Update `VERSION` file with new version
3. Update version in `modules/k3s-server/cloud-init.yaml`
4. Update Kafka version in `kafka-cluster-examples/*.yaml` if needed
5. Update `values.yaml` if configuration changed
6. Destroy and redeploy cluster via GitHub Actions

## Custom Resources Created

After operator installation, these CRDs are available:

- `Kafka` - Kafka cluster definition
- `KafkaTopic` - Topic management
- `KafkaUser` - User & ACL management
- `KafkaConnect` - Kafka Connect clusters
- `KafkaMirrorMaker2` - Cross-cluster replication

## Usage

Kafka clusters are deployed via ArgoCD using manifests in `kafka-cluster-examples/`.

### Dev Environment (1 broker)
```bash
kubectl apply -f kafka-cluster-examples/dev.yaml
```

### Prod Environment (3 brokers)
```bash
kubectl apply -f kafka-cluster-examples/prod.yaml
```

## Verify Installation

```bash
# Check operator is running
kubectl get pods -n kafka
# Expected: strimzi-cluster-operator-xxx Running

# Check CRDs are installed
kubectl get crd | grep kafka
# Expected: kafkas.kafka.strimzi.io, kafkatopics.kafka.strimzi.io, etc.

# Check operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator
```

## Configuration Reference

See `values.yaml` for all available Helm chart options. These are translated to command-line flags in cloud-init.

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/operators/latest/overview.html)
- [Kafka CR Reference](https://strimzi.io/docs/operators/latest/configuring.html#type-Kafka-reference)
- [GitHub Repository](https://github.com/strimzi/strimzi-kafka-operator)
