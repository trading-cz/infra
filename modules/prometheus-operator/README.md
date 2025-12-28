# Prometheus Operator

Prometheus Operator provides Kubernetes native deployment and management of Prometheus and related monitoring components.

## Overview

**Purpose**: Automate metrics collection from K3s cluster, Kafka, and application services.

**Helm Chart**: `prometheus-community/kube-prometheus-stack` v0.77.0

**Namespace**: `monitoring`

**Installation**: Cloud-init (automatic during K3s bootstrap)

## Components Installed

- **Prometheus Operator** (v0.77.0) - Manages Prometheus instances via CRDs
- **kube-state-metrics** - K3s object metrics (pod status, node conditions, etc.)
- **node-exporter** - Host-level metrics (CPU, memory, disk, network I/O)
- **CRDs**: Prometheus, ServiceMonitor, PodMonitor, PrometheusRule, AlertManager

## Metrics Sources

| Source | Metrics | Scrape Target |
|--------|---------|----------------|
| **K3s kubelet** | Pod CPU/memory/network, node metrics | ServiceMonitor: kube-state-metrics |
| **Kafka (via Strimzi)** | Broker size, replicas, consumer lag | ServiceMonitor: kafka-jmx (JMX exporter) |
| **Applications** | Custom business metrics (bars, latency, etc.) | ServiceMonitor: app-services |

## Storage Configuration

- **Size**: 20Gi PersistentVolume
- **Retention**: 30 days (before purge)
- **Location**: `/prometheus-storage`
- **Adequate for**: 50+ strategies with full metrics history

## Deployment Architecture

```
provision → verify_cluster → verify_monitoring ✅
                                           ↓
     ✅ Prometheus Operator pod running
     ✅ CRDs registered (ServiceMonitor, PrometheusRule, etc.)
     ✅ kube-state-metrics & node-exporter collecting
                                           ↓
                        deploy_strimzi → deploy_argocd
                                           ↓
              ArgoCD syncs config/base/monitoring/:
              - Prometheus instance (CR)
              - ServiceMonitors (scrape targets)
              - PrometheusRules (alerts, recording rules)
```

## Custom Resources (CRDs)

| Resource | Purpose | Managed By |
|----------|---------|------------|
| `Prometheus` | Prometheus instance configuration | ArgoCD (config/base/monitoring/) |
| `ServiceMonitor` | Scrape Kubernetes services dynamically | ArgoCD (config/base/monitoring/) |
| `PodMonitor` | Scrape pods directly | ArgoCD (config/base/monitoring/) |
| `PrometheusRule` | Recording & alerting rules | ArgoCD (config/base/monitoring/) |
| `AlertManager` | Alert routing & notifications | Optional (not deployed yet) |

## Helm Installation Parameters

See `operators-reference.yaml` for complete Helm command. Key settings:

```bash
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false
```

## Troubleshooting

```bash
# Check operator
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-operator
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator

# Check metrics storage
kubectl get pvc -n monitoring
kubectl get pv

# Access Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Visit: http://localhost:9090
```

## Version

**Current**: 0.77.0 (see `VERSION` file)

**Upgrade**: Destroy and redeploy cluster (update `VERSION` and `cloud-init.yaml`)

## Documentation

- [prometheus-operator.dev](https://prometheus-operator.dev/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- `operators-reference.yaml` - Helm installation reference
- `config/base/monitoring/` - Prometheus CR configuration (ArgoCD managed)
