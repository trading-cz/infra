# Kubernetes Configuration Project Architecture Analysis

## Document Purpose
This document provides a comprehensive analysis of the STX.KUBE_CFG_RISK Kubernetes configuration repository structure for adaptation to a new project using Hetzner Cloud + K3s instead of Google Cloud + K8s/OpenShift.

## Project Overview

### Current Infrastructure
- **Platform**: Google Cloud Platform (GCP) with OpenShift/Kubernetes
- **Management Tool**: ArgoCD for GitOps-based deployment
- **Configuration Tool**: Kustomize for manifest templating
- **Branching Strategy**: Trunk-based with environment-specific deploy branches

### Target Infrastructure (New Project)
- **Platform**: Hetzner Cloud with K3s
- **Management Tool**: ArgoCD (retained)
- **Configuration Tool**: Kustomize (retained)
- **Branching Strategy**: Simplified - `main` (dev) and `production` branches only

---

## Core Architectural Patterns

### 1. App-of-Apps Pattern

The **App-of-Apps** pattern is the central orchestration mechanism using ArgoCD.

#### Concept
- A parent ArgoCD Application manages multiple child Applications
- Each child Application represents a microservice, infrastructure component, or Kafka topic set
- Located in: `overlay/{environment}/{cluster}/app-of-apps/`
- Each YAML file in app-of-apps directory defines one ArgoCD Application

#### Structure Example
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: 024-stx-amq-streams-kafka
  namespace: 004-stx-argocd  # ArgoCD installation namespace
spec:
  project: 024-stx-risk  # ArgoCD project name
  source:
    repoURL: https://github.deutsche-boerse.de/stx/STX.KUBE_CFG_RISK
    targetRevision: master  # Branch to track (dev uses master)
    path: overlay/development/g-dev-1/amq-streams-kafka  # Overlay path
  destination:
    namespace: 024-stx-risk-applications  # Target K8s namespace
    server: https://kubernetes.default.svc  # K8s API server
```

#### Key Components in App-of-Apps
1. **Application Name**: Unique identifier for the service/component
2. **Target Revision**: Git branch that ArgoCD tracks (environment-specific)
3. **Source Path**: Points to the environment/cluster overlay
4. **Destination Namespace**: Where resources are deployed
5. **Destination Server**: K8s cluster (typically in-cluster)

#### Environment-Specific Behavior
- **Development** (`master` branch): Latest changes auto-sync
- **Production** (`deploy/production/g-prd-1` branch): PR-based promotion

---

### 2. Kustomize Base-Overlay Pattern

#### Base Directory Structure
```
base/
├── amq-streams-kafka/          # Kafka cluster base configuration
│   ├── kustomization.yaml
│   ├── kafka-persistent.yaml   # Kafka CR (Strimzi)
│   ├── kafka-node-pool-*.yaml
│   ├── kafka-metrics.yaml
│   └── users/                  # Kafka users (auth)
│       ├── kafka-user.yaml
│       └── r7-kafka-user.yaml
├── color-server/               # Example application
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── route.yaml              # OpenShift Route (will need Ingress for K3s)
├── dp-r7-downloader/           # Application with ConfigMap
│   ├── kustomization.yaml
│   └── configmap-dp-r7-downloader.yaml
└── infra/                      # Infrastructure resources
    └── ansible-sa/             # ServiceAccounts, Roles, RoleBindings
```

#### Overlay Directory Structure
```
overlay/
├── development/
│   └── g-dev-1/                # Cluster-specific overlay
│       ├── amq-streams-kafka/
│       │   ├── kustomization.yaml      # References base + adds resources
│       │   ├── kafka-connect.yaml      # Environment-specific config
│       │   ├── network-policy.yaml
│       │   └── topics/                 # Dev-specific Kafka topics
│       │       └── dev-r7-events.yaml
│       ├── color-server/
│       │   └── kustomization.yaml      # Simple reference to base
│       ├── dp-r7-downloader/
│       │   ├── kustomization.yaml
│       │   ├── patch_configmap-*.yaml  # ConfigMap patches
│       │   └── sealedsecrets-*.yaml    # Environment secrets
│       └── app-of-apps/
│           ├── 024-stx-amq-streams-kafka.yaml
│           ├── 024-stx-color-server.yaml
│           └── ...
└── production/
    └── g-prd-1/                # Production cluster overlay
        └── [similar structure]
```

#### How Kustomize Works in This Pattern

**Simple Application (color-server)**:
```yaml
# overlay/development/g-dev-1/color-server/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../../base/color-server  # Only references base, no changes
```

**Complex Application (amq-streams-kafka)**:
```yaml
# overlay/development/g-dev-1/amq-streams-kafka/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../../base/amq-streams-kafka  # Base Kafka cluster
  - topics                              # Dev-specific topics
  - kafka-connect.yaml                  # Dev-specific KafkaConnect
  - network-policy.yaml                 # Dev-specific network policy
```

**Application with Patches (dp-r7-downloader)**:
```yaml
# overlay/development/g-dev-1/dp-r7-downloader/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - sealedsecrets-dp-kafka-client-store.yaml  # Dev secrets
  - sealedsecrets-dp-kafka-client.yaml
  - ../../../../base/dp-r7-downloader
patches:
  - path: patch_configmap-dp-r7-downloader.yaml  # Override base ConfigMap values
```

The patch file merges with base ConfigMap:
```yaml
# patch_configmap-dp-r7-downloader.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dp-r7-downloader
  namespace: 024-stx-risk-applications
data:
  STORAGE_RAW_BUCKET_NAME: "dbg-bkt-stx-dev-..."  # Dev-specific bucket
  JOB_SCHEDULER_URL: "https://airflow-webserver-...dev..."
  KAFKA_TOPIC_EVENT: "dev-r7-events"
  IMAGE: "...dp-r7-downloader:2.1.13"
  # ... other environment-specific values
```

---

### 3. Kafka Configuration Pattern

#### Base Kafka Resources

**Kafka Cluster (Strimzi CRD)**:
```yaml
# base/amq-streams-kafka/kafka-persistent.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: dbamqkafkacluster
  namespace: 024-stx-amq-streams-kafka
  annotations:
    strimzi.io/node-pools: enabled
    strimzi.io/kraft: enabled
spec:
  kafka:
    version: 3.9.0
    authorization:
      type: simple
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
      - name: external
        port: 9094
        tls: true
        type: route  # OpenShift-specific (needs NodePort/LoadBalancer for K3s)
    config:
      auto.create.topics.enable: false  # Topics managed via CR
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      default.replication.factor: 3
      min.insync.replicas: 2
    resources:
      requests:
        cpu: 500m
        memory: 4Gi
      limits:
        cpu: 4000m
        memory: 16Gi
  entityOperator:
    topicOperator:
      watchedNamespace: 024-stx-amq-streams-kafka
    userOperator:
      watchedNamespace: 024-stx-amq-streams-kafka
```

**Kafka Users (Authentication)**:
```yaml
# base/amq-streams-kafka/users/kafka-user.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: kafka-user
  namespace: 024-stx-amq-streams-kafka
  labels:
    strimzi.io/cluster: dbamqkafkacluster
spec:
  authentication:
    type: tls  # mTLS authentication
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: '*'
          patternType: literal
        operations: [Read, Write, Create, Delete, Describe]
      - resource:
          type: group
          name: '*'
          patternType: literal
        operations: [Read, Describe]
```

#### Environment-Specific Kafka Resources

**Kafka Topics**:
```yaml
# overlay/development/g-dev-1/amq-streams-kafka/topics/dev-r7-events.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: dev-r7-events
  namespace: 024-stx-amq-streams-kafka
  labels:
    strimzi.io/cluster: dbamqkafkacluster
spec:
  partitions: 1
  replicas: 2
  config:
    min.insync.replicas: '2'
    retention.ms: 1209600000  # 14 days
    segment.bytes: 1073741824  # 1GB
  topicName: dev-r7-events  # Actual Kafka topic name
```

**Kafka Connect**:
```yaml
# overlay/development/g-dev-1/amq-streams-kafka/kafka-connect.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnect
metadata:
  name: dbamqkafkacluster-kafka
  namespace: 024-stx-amq-streams-kafka
spec:
  image: stx-app-docker-prod.artifactory.dbgcloud.io/kafka-connect-custom:2.9.0_3
  replicas: 3
  bootstrapServers: dbamqkafkacluster-kafka-bootstrap.024-stx-amq-streams-kafka.svc.cluster.local:9093
  config:
    group.id: kafka-connect
    offset.storage.topic: kafka-connect-offsets
    config.storage.topic: kafka-connect-configs
    status.storage.topic: kafka-connect-status
  tls:
    trustedCertificates:
      - secretName: dbamqkafkacluster-cluster-ca-cert
        certificate: ca.crt
  authentication:
    type: tls
    certificateAndKey:
      secretName: kafka-user  # References KafkaUser secret
      certificate: user.crt
      key: user.key
```

---

### 4. Application Deployment Pattern

#### Base Application Definition

**Deployment**:
```yaml
# base/color-server/deployment.yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: color-server
  namespace: 024-stx-risk-applications
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color-server
  template:
    metadata:
      labels:
        app: color-server
    spec:
      containers:
        - name: color-server
          image: 'stx-app-docker-prod.artifactory.dbgcloud.io/color-server:20250319'
          ports:
            - containerPort: 8080
          env:
            - name: COLOR
              value: orange
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

**Service**:
```yaml
# base/color-server/service.yaml
kind: Service
apiVersion: v1
metadata:
  name: color-server
  namespace: 024-stx-risk-applications
spec:
  selector:
    app: color-server
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
```

**Route** (OpenShift):
```yaml
# base/color-server/route.yaml
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: color-server
  namespace: 024-stx-risk-applications
spec:
  to:
    kind: Service
    name: color-server
  tls:
    termination: edge
```

**For K3s**: Replace Route with Ingress:
```yaml
# base/color-server/ingress.yaml (NEW for K3s)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: color-server
  namespace: 024-stx-risk-applications
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # If using cert-manager
spec:
  ingressClassName: traefik  # K3s default
  rules:
    - host: color-server.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: color-server
                port:
                  number: 8080
  tls:
    - hosts:
        - color-server.yourdomain.com
      secretName: color-server-tls
```

#### Application with ConfigMap Pattern

Applications like `dp-r7-downloader` use ConfigMaps for configuration:

**Base ConfigMap**:
```yaml
# base/dp-r7-downloader/configmap-dp-r7-downloader.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dp-r7-downloader
  namespace: 024-stx-risk-applications
data:
  # Environment-agnostic defaults
  STORAGE_PROVIDER: "gs://"
  STORAGE_CHUNK_ROTATION_SIZE_BYTES: "104857600"
  KAFKA_KEY_DESERIALIZER_CONSUMER_DATA: "org.apache.kafka.common.serialization.ByteArrayDeserializer"
  # ... many more config keys
```

**Environment Patch**:
```yaml
# overlay/development/g-dev-1/dp-r7-downloader/patch_configmap-dp-r7-downloader.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dp-r7-downloader
  namespace: 024-stx-risk-applications
data:
  # Override/add environment-specific values
  STORAGE_RAW_BUCKET_NAME: "dbg-bkt-stx-dev-sin-private-dev_dpr00003_r7_raw"
  JOB_SCHEDULER_URL: "https://airflow-webserver-...apps.g-dev-1.cool.dev.gcp.dbgcloud.io/api/v1"
  KAFKA_TOPIC_EVENT: "dev-r7-events"
  IMAGE: "stx-app-docker-prod.artifactory.dbgcloud.io/dp-r7-downloader:2.1.13"
  REQUESTS: "{'cpu': '1m', 'memory': '1Mi'}"
  LIMITS: "{'cpu': '2000m', 'memory': '2.5Gi'}"
```

The patch **merges** with the base ConfigMap, overriding matching keys.

---

### 5. Infrastructure Components Pattern

Infrastructure resources (ServiceAccounts, Roles, RoleBindings) are managed similarly:

```yaml
# base/infra/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ansible-sa/024-stx-risk-applications-role.yaml
  - ansible-sa/024-stx-risk-applications-rb.yaml
  - ansible-sa/ansible-sa.yaml
  - ansible-sa/ansible-secret.yaml
```

```yaml
# overlay/development/g-dev-1/infra/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../../base/infra  # Just reference base, no overrides
```

This pattern keeps RBAC definitions centralized while allowing environment-specific additions if needed.

---

## Branching and Deployment Workflow

### Current Model (Multi-Environment)

```
master (trunk)
  ↓ (continuous)
Development Environment (g-dev-1)
  ↓ (PR to deploy/acceptance/g-tst-1)
Acceptance Environment (g-tst-1)
  ↓ (PR to deploy/production/g-prd-1)
Production Environment (g-prd-1)
```

**Branch Naming Convention**:
- Trunk: `master`
- Deploy branches: `deploy/{environment}/{cluster-name}`
  - Example: `deploy/production/g-prd-1`

**ArgoCD Target Revisions**:
- Development: Tracks `master` branch
- Acceptance: Tracks `deploy/acceptance/g-tst-1` branch
- Production: Tracks `deploy/production/g-prd-1` branch

**Deployment Process**:
1. Developer merges to `master` → Auto-deploys to Development
2. Create PR from `master` to `deploy/acceptance/g-tst-1`
3. Team reviews and approves → Merge
4. Team manually syncs ArgoCD Application
5. Repeat for production

### Simplified Model (Two-Environment)

For your new project with only `dev` and `production`:

```
main (trunk)
  ↓ (continuous)
Development Environment
  ↓ (PR to production)
Production Environment
```

**Branch Naming**:
- Trunk: `main`
- Deploy branch: `production`

**ArgoCD Target Revisions**:
- Development: `main`
- Production: `production`

**Directory Structure**:
```
overlay/
├── development/
│   └── hetzner-k3s-dev/
│       ├── kafka/
│       ├── my-python-app/
│       └── app-of-apps/
└── production/
    └── hetzner-k3s-prod/
        ├── kafka/
        ├── my-python-app/
        └── app-of-apps/
```

---

## Secrets Management

### Current Approach: Sealed Secrets

The project uses **Bitnami Sealed Secrets**:

```bash
# overlay/development/g-dev-1/create-sealedsecrets.sh
# Script to create sealed secrets for the environment
```

**Sealed Secrets Workflow**:
1. Plain secret created locally (not committed)
2. Encrypted using `kubeseal` CLI with cluster-specific public key
3. Encrypted SealedSecret committed to Git
4. Sealed Secret Controller in cluster decrypts and creates Secret

**Example**:
```yaml
# overlay/development/g-dev-1/dp-r7-downloader/sealedsecrets-dp-kafka-client.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: dp-kafka-client
  namespace: 024-stx-risk-applications
spec:
  encryptedData:
    KAFKA_BOOTSTRAP_SERVERS: AgC8... # Encrypted value
    KAFKA_SSL_TRUSTSTORE: AgBw...
    # ... more encrypted keys
```

---

## Adaptations for Hetzner Cloud + K3s

### 1. Replace OpenShift Routes with Ingress

**Current** (OpenShift Route):
```yaml
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: color-server
spec:
  to:
    kind: Service
    name: color-server
  tls:
    termination: edge
```

**New** (K3s Ingress with Traefik):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: color-server
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  rules:
    - host: color-server.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: color-server
                port:
                  number: 8080
  tls:
    - hosts:
        - color-server.yourdomain.com
      secretName: color-server-tls
```

### 2. Kafka External Access

**Current**: Uses OpenShift Routes for external Kafka access
```yaml
listeners:
  - name: external
    port: 9094
    type: route  # OpenShift-specific
```

**New**: Use NodePort or LoadBalancer for K3s
```yaml
listeners:
  - name: external
    port: 9094
    type: nodeport  # Or loadbalancer if Hetzner LB available
    configuration:
      bootstrap:
        nodePort: 32094
      brokers:
        - broker: 0
          nodePort: 32095
        - broker: 1
          nodePort: 32096
        - broker: 2
          nodePort: 32097
```

### 3. Storage Classes

**Current**: GCP storage classes
```yaml
storageClassName: standard-rwo  # GCP-specific
```

**New**: Hetzner CSI driver
```yaml
storageClassName: hcloud-volumes  # Hetzner Cloud CSI
```

### 4. Remove GCP-Specific Resources

**Remove**:
- Google Cloud Storage bucket references
- GCP service account configurations
- Dataproc Spark job configurations

**Replace with**:
- S3-compatible storage (if needed) - Hetzner Object Storage or MinIO
- Local storage or Hetzner volumes
- Alternative job runners (Kubernetes Jobs, Argo Workflows)

### 5. Python Images Instead of Scala

**Current**:
```yaml
image: 'stx-app-docker-prod.artifactory.dbgcloud.io/kafka-connect-custom:2.9.0_3'
```

**New**:
```yaml
image: 'your-registry.com/your-python-app:1.0.0'
```

The containerization approach remains the same. ConfigMaps for Python apps:
```yaml
data:
  PYTHON_ENV: "production"
  LOG_LEVEL: "INFO"
  KAFKA_BOOTSTRAP_SERVERS: "kafka-cluster-kafka-bootstrap:9092"
```

---

## Key Concepts Summary for LLM Agent

### 1. **Three-Layer Architecture**
- **Base Layer**: Common, reusable Kubernetes manifests
- **Overlay Layer**: Environment/cluster-specific customizations
- **App-of-Apps Layer**: ArgoCD orchestration definitions

### 2. **GitOps Flow**
- All configuration in Git
- ArgoCD watches specific branches for each environment
- Changes to Git trigger deployment (auto-sync or manual)
- PR-based promotion between environments

### 3. **Kustomize Patterns**
- **Simple Reference**: Overlay just points to base
- **Resource Addition**: Overlay adds environment-specific resources
- **Patching**: Overlay patches base resources (ConfigMaps, Deployments)
- **Strategic Merge**: Patches merge intelligently (lists append, maps override)

### 4. **Kafka as Code**
- Kafka clusters defined as Kubernetes CRs (Strimzi)
- Topics, users, connectors managed via CRs
- Environment-specific topics in overlays
- Base cluster configuration shared across environments

### 5. **Namespace Strategy**
- `004-stx-argocd`: ArgoCD installation namespace
- `024-stx-risk-applications`: Application workload namespace
- `024-stx-amq-streams-kafka`: Kafka cluster namespace
- Clear separation of concerns

### 6. **Secret Management**
- Sealed Secrets for GitOps-friendly secret storage
- Environment-specific sealed secrets in overlays
- Decryption happens in-cluster by controller
- Never commit plain secrets to Git

### 7. **Application Structure**
```
my-app/
├── base/
│   ├── kustomization.yaml      # Lists resources
│   ├── deployment.yaml         # Base deployment
│   ├── service.yaml            # Base service
│   ├── configmap.yaml          # Default config (optional)
│   └── ingress.yaml            # Base ingress (for K3s)
└── overlay/
    ├── development/
    │   └── cluster-name/
    │       ├── kustomization.yaml
    │       ├── patch-deployment.yaml    # Dev-specific patches
    │       ├── configmap-patch.yaml     # Dev-specific config
    │       └── sealedsecret.yaml        # Dev secrets
    └── production/
        └── cluster-name/
            ├── kustomization.yaml
            ├── patch-deployment.yaml    # Prod-specific patches
            ├── configmap-patch.yaml     # Prod-specific config
            └── sealedsecret.yaml        # Prod secrets
```

### 8. **App-of-Apps Registration**
For each new application, create:
```yaml
# overlay/{env}/{cluster}/app-of-apps/{app-name}.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {app-name}
  namespace: argocd-namespace
spec:
  project: {project-name}
  source:
    repoURL: {git-repo-url}
    targetRevision: {branch-name}  # main for dev, production for prod
    path: overlay/{env}/{cluster}/{app-name}
  destination:
    namespace: {app-namespace}
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:  # Optional: auto-sync
      prune: true
      selfHeal: true
```

---

## Migration Checklist for New Project

### Phase 1: Repository Setup
- [ ] Create Git repository with `base/` and `overlay/` structure
- [ ] Define two environments: `development/` and `production/`
- [ ] Create cluster-specific subdirectories (e.g., `hetzner-k3s-dev`, `hetzner-k3s-prod`)
- [ ] Set up branching: `main` (dev) and `production` branches

### Phase 2: Kafka Setup
- [ ] Install Strimzi Operator in K3s cluster
- [ ] Create `base/kafka/` with cluster definition
- [ ] Adapt Kafka listeners for K3s (NodePort/LoadBalancer)
- [ ] Update storage classes to Hetzner CSI
- [ ] Define Kafka users in `base/kafka/users/`
- [ ] Create environment-specific topics in overlays

### Phase 3: Application Templates
- [ ] Create `base/{app-name}/` for each Python application
- [ ] Define Deployment, Service, Ingress (not Route)
- [ ] Create ConfigMaps for app configuration
- [ ] Define resource requests/limits appropriate for Hetzner

### Phase 4: Overlay Configuration
- [ ] Create overlay kustomization files
- [ ] Add environment-specific ConfigMap patches
- [ ] Configure Sealed Secrets for each environment
- [ ] Adjust image tags per environment

### Phase 5: ArgoCD Integration
- [ ] Install ArgoCD in K3s cluster
- [ ] Create ArgoCD Project
- [ ] Set up `app-of-apps/` directory per environment
- [ ] Create Application CR for each component
- [ ] Configure sync policies (auto vs. manual)

### Phase 6: Infrastructure
- [ ] Replace OpenShift-specific resources (Routes → Ingress)
- [ ] Set up cert-manager for TLS (if needed)
- [ ] Configure Traefik IngressController (K3s default)
- [ ] Remove GCP-specific storage/compute references
- [ ] Set up Hetzner-specific storage classes

### Phase 7: CI/CD
- [ ] Set up image build pipeline for Python apps
- [ ] Configure image registry
- [ ] Create PR workflow for production promotion
- [ ] Document deployment procedures

---

## Example: Adding a New Python Application

### Step 1: Create Base Resources
```bash
mkdir -p base/my-python-app
```

```yaml
# base/my-python-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - configmap.yaml
```

```yaml
# base/my-python-app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-python-app
  namespace: applications
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-python-app
  template:
    metadata:
      labels:
        app: my-python-app
    spec:
      containers:
        - name: my-python-app
          image: registry.example.com/my-python-app:latest
          ports:
            - containerPort: 8000
          envFrom:
            - configMapRef:
                name: my-python-app-config
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

```yaml
# base/my-python-app/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-python-app
  namespace: applications
spec:
  selector:
    app: my-python-app
  ports:
    - port: 8000
      targetPort: 8000
```

```yaml
# base/my-python-app/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-python-app
  namespace: applications
spec:
  ingressClassName: traefik
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-python-app
                port:
                  number: 8000
```

```yaml
# base/my-python-app/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-python-app-config
  namespace: applications
data:
  LOG_LEVEL: "INFO"
  KAFKA_BOOTSTRAP_SERVERS: "kafka-cluster-kafka-bootstrap:9092"
```

### Step 2: Create Development Overlay
```bash
mkdir -p overlay/development/hetzner-k3s-dev/my-python-app
```

```yaml
# overlay/development/hetzner-k3s-dev/my-python-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../../base/my-python-app
  - sealedsecret-db-creds.yaml
patches:
  - path: patch-configmap.yaml
  - path: patch-ingress.yaml
```

```yaml
# overlay/development/hetzner-k3s-dev/my-python-app/patch-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-python-app-config
  namespace: applications
data:
  LOG_LEVEL: "DEBUG"  # Override for dev
  ENVIRONMENT: "development"
  KAFKA_TOPIC: "dev-events"
```

```yaml
# overlay/development/hetzner-k3s-dev/my-python-app/patch-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-python-app
  namespace: applications
spec:
  rules:
    - host: app-dev.example.com  # Dev hostname
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-python-app
                port:
                  number: 8000
```

### Step 3: Create Production Overlay
```bash
mkdir -p overlay/production/hetzner-k3s-prod/my-python-app
```

```yaml
# overlay/production/hetzner-k3s-prod/my-python-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../../base/my-python-app
  - sealedsecret-db-creds.yaml
patches:
  - path: patch-deployment.yaml
  - path: patch-configmap.yaml
  - path: patch-ingress.yaml
```

```yaml
# overlay/production/hetzner-k3s-prod/my-python-app/patch-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-python-app
  namespace: applications
spec:
  replicas: 3  # Scale up for production
  template:
    spec:
      containers:
        - name: my-python-app
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 2000m
              memory: 2Gi
```

```yaml
# overlay/production/hetzner-k3s-prod/my-python-app/patch-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-python-app-config
  namespace: applications
data:
  LOG_LEVEL: "WARNING"
  ENVIRONMENT: "production"
  KAFKA_TOPIC: "prod-events"
```

### Step 4: Register in App-of-Apps
```yaml
# overlay/development/hetzner-k3s-dev/app-of-apps/my-python-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-python-app
  namespace: argocd
spec:
  project: my-project
  source:
    repoURL: https://github.com/yourorg/yourrepo
    targetRevision: main  # Dev tracks main branch
    path: overlay/development/hetzner-k3s-dev/my-python-app
  destination:
    namespace: applications
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

```yaml
# overlay/production/hetzner-k3s-prod/app-of-apps/my-python-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-python-app
  namespace: argocd
spec:
  project: my-project
  source:
    repoURL: https://github.com/yourorg/yourrepo
    targetRevision: production  # Prod tracks production branch
    path: overlay/production/hetzner-k3s-prod/my-python-app
  destination:
    namespace: applications
    server: https://kubernetes.default.svc
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
  # Note: No automated sync for production (manual approval)
```

---

## Platform-Specific Differences Summary

| Aspect | Current (GCP + OpenShift) | New (Hetzner + K3s) |
|--------|---------------------------|---------------------|
| **Ingress** | OpenShift Route | Kubernetes Ingress (Traefik) |
| **Storage** | GCP Persistent Disk | Hetzner Cloud Volumes (CSI) |
| **Kafka External** | Route listener | NodePort/LoadBalancer listener |
| **TLS Certificates** | OpenShift cert injection | cert-manager + Let's Encrypt |
| **Image Registry** | Artifactory (corporate) | Your choice (Docker Hub, GitHub, etc.) |
| **Cloud Storage** | Google Cloud Storage (GCS) | Hetzner Object Storage or MinIO |
| **Service Mesh** | Istio (optional) | May not need for K3s |
| **Namespace Limits** | ResourceQuotas | Same (standard K8s) |

---

## Conclusion

This architecture provides:
1. **Separation of Concerns**: Base vs. environment-specific config
2. **DRY Principle**: Reusable base resources across environments
3. **GitOps-Native**: All config in Git, ArgoCD for deployment
4. **Scalability**: Easy to add new environments or applications
5. **Security**: Secrets encrypted in Git via Sealed Secrets
6. **Kafka as Code**: Declarative Kafka management via Strimzi CRs

**For the new Hetzner + K3s project**:
- Retain the three-layer architecture (base/overlay/app-of-apps)
- Simplify to two environments (dev/prod)
- Replace OpenShift Routes with Ingress
- Adapt Kafka external listeners for K3s
- Use Python images instead of Scala
- Remove Airflow, PostgreSQL, ControlM components
- Keep Kafka, app-of-apps, and general application patterns

The agent should replicate this structure with platform-appropriate adaptations.
