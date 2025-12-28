# Grafana Operator

Grafana Operator provides Kubernetes native deployment and management of Grafana instances, datasources, and dashboards as Custom Resources.

## Overview

**Purpose**: Manage Grafana visualization layer as code (dashboards, datasources, folders via Git).

**Helm Chart**: `grafana/grafana-operator` v5.21.3

**Namespace**: `monitoring`

**Installation**: Cloud-init (automatic during K3s bootstrap)

## Components Installed

- **Grafana Operator** (v5.21.3) - Manages Grafana instances and configurations via CRDs
- **Webhook** - Validates Grafana CRs before applying
- **CRDs**: Grafana, GrafanaDatasource, GrafanaDashboard, GrafanaFolder, GrafanaContact

## Architecture

```
Prometheus Data Source
  └─ URL: http://prometheus-operated:9090
  └─ Managed via GrafanaDatasource CR

          ↓
          
Grafana Instance
  ├─ Port: 3000
  ├─ UI: Dashboards, datasources, alerts
  └─ Managed via Grafana CR

          ↓
          
Dashboards (Defined as Code)
  ├─ K3s Cluster Health
  ├─ Kafka Broker Status
  ├─ Ingestion Pipeline Performance
  └─ Per-Strategy Performance (scalable to 50+)
  
Managed via GrafanaDashboard CRs (stored in Git, synced by ArgoCD)
```

## Custom Resources (CRDs)

| Resource | Purpose | Location |
|----------|---------|----------|
| `Grafana` | Grafana instance config | `config/base/monitoring/grafana/grafana-cr.yaml` |
| `GrafanaDatasource` | Data source (Prometheus, Loki, etc.) | `config/base/monitoring/grafana/datasources/` |
| `GrafanaDashboard` | Dashboard definition (JSON, URL, ConfigMap) | `config/base/monitoring/grafana/dashboards/` |
| `GrafanaFolder` | Dashboard folder organization | `config/base/monitoring/grafana/folders/` |
| `GrafanaContact` | Alert notification targets | Future (not deployed yet) |

## Dashboard Management

### Supported Formats

**1. JSON Definition** - Full dashboard JSON embedded in CR
```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: custom-dashboard
spec:
  json: |
    {"title": "My Dashboard", "panels": [...]}
```

**2. External URL** - Reference Grafana.com dashboard by ID
```yaml
spec:
  grafanaCom:
    id: 1234
    revision: 5
```

**3. ConfigMap Reference** - Reference dashboard JSON in ConfigMap
```yaml
spec:
  configMapRef:
    name: dashboard-definition
    key: dashboard.json
```

## Datasources

### Prometheus Example
```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: prometheus
spec:
  datasource:
    name: Prometheus
    type: prometheus
    url: http://prometheus-operated:9090
    isDefault: true
    access: proxy
```

## Access Methods

### 1. Port-Forward (Development)
```bash
kubectl port-forward -n monitoring svc/grafana-service 3000:3000
# Visit: http://localhost:3000
# Login: admin (password from Grafana CR)
```

### 2. Traefik Ingress (Production)
```
https://<control-plane-ip>:30443/grafana
```

### 3. Internal Kubernetes
```
http://grafana-service.monitoring.svc.cluster.local:3000
```

## Deployment Architecture

```
provision → verify_cluster → verify_monitoring ✅
                                           ↓
     ✅ Grafana Operator pod running
     ✅ CRDs registered (GrafanaDashboard, GrafanaDatasource)
     ✅ Webhook ready for CR validation
                                           ↓
              deploy_strimzi → deploy_argocd
                                           ↓
          ArgoCD syncs config/base/monitoring/grafana/:
          - Grafana instance (CR)
          - GrafanaDatasource → Prometheus
          - GrafanaDashboards (as code, in Git)
          - GrafanaFolders (organization)
```

## Helm Installation Parameters

See `operators-reference.yaml` for complete Helm command:

```bash
helm install grafana-operator grafana/grafana-operator \
  --namespace monitoring \
  --version 5.21.3 \
  --wait --timeout 5m
```

**Note**: Operator installed with defaults. Instance configuration in Grafana CR.

## Storage

- **Type**: Grafana database (SQLite or external)
- **Persistence**: Configured via Grafana CR
- **Dashboards**: Source of truth is Git (config/base/monitoring/)
- **Survival**: Dashboards survive cluster destroy (stored in Git)

## Scaling to 50+ Strategies

```
config/base/monitoring/grafana/dashboards/
├─ cluster-health.yaml           # K3s cluster
├─ kafka-health.yaml             # Kafka brokers
├─ ingestion-pipeline.yaml       # Ingestion service
└─ strategies/
    ├─ strategy-001.yaml         # Strategy #1
    ├─ strategy-002.yaml         # Strategy #2
    └─ ...
    └─ strategy-050.yaml         # Strategy #50
```

Dashboards use Prometheus variables to filter by strategy labels.

## Troubleshooting

```bash
# Check operator
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana-operator
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana-operator

# Check Grafana instance
kubectl get grafana -n monitoring
kubectl get pods -n monitoring -l grafana=main

# Check datasources & dashboards
kubectl get grafanadatasource -n monitoring
kubectl get grafanadashboard -n monitoring

# Access UI
kubectl port-forward -n monitoring svc/grafana-service 3000:3000
```

## Version

**Current**: 5.21.3 (see `VERSION` file)

**Upgrade**: Destroy and redeploy cluster (update `VERSION` and `cloud-init.yaml`)

## Documentation

- [grafana.github.io/grafana-operator](https://grafana.github.io/grafana-operator/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- `operators-reference.yaml` - Helm installation reference
- `config/base/monitoring/grafana/` - Grafana CR configuration (ArgoCD managed)
