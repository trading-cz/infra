# K3s Trading Infrastructure - Terraform

Ephemeral K3s clusters on Hetzner Cloud with persistent Primary IPs for algorithmic trading workloads.

## � Core Concept

**Deploy clusters only during trading hours → Cost savings reasons **

- **Ephemeral VMs**: Created on-demand, destroyed after hours
- **Persistent IPs**: Remain assigned (€1/month total), maintain stable DNS
- **Automated Deployment**: GitHub Actions orchestrates everything
- **K3s + Kafka**: Streaming pipeline for market data → trading strategies

## 🏗️ Architecture

### Repository Separation
**Infrastructure (this repo: infra)** → Platform provisioning & operators
- Terraform: Hetzner resources (VMs, network, IPs)
- GitHub Actions: Deployment orchestration
- ArgoCD Operator installation (v0.15.0)
- ArgoCD instance deployment + parent app-of-apps
- Strimzi Operator deployment (via ArgoCD)

**Applications (config repo)** → Workload definitions (GitOps)
- Kustomize configurations for all environments
- ArgoCD Applications (app-of-apps pattern)
- Kafka cluster definitions (Strimzi CRs)
- Trading strategies deployments
- Topics, users, and configs

### Deployment Flow
```
Terraform → K3s → ArgoCD Operator → ArgoCD Instance → Parent App → Child Apps
                                                           ├─ kafka-cluster (Strimzi + Kafka)
                                                           └─ dummy-strategy (sample app)
```


### Infrastructure Components

**2-Node Dev Cluster:**
- **k3s-control** (Primary IP #1): K3s control plane + ArgoCD + apps
- **kafka-0** (Primary IP #2): Kafka broker (NodePort 33333 for external access)

**4-Node Prod Cluster** (future):
- **k3s-control** (Primary IP #1): K3s control plane + ArgoCD
- **kafka-0, kafka-1, kafka-2** (Primary IP #2 on kafka-0): Kafka cluster (3 brokers)

### Network Architecture

```
┌────────────────────────────────────────────────────────────┐
│       Hetzner K3S cluster                                  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Primary IP #1 (€0.50/month) → k3s-control (10.0.1.10)  │ │
│ │   ├─ K3s Control Plane (API: 6443)                     │ │
│ │   ├─ ArgoCD (GitOps)                                   │ │
│ │   └─ Trading Apps (Python)                             │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Primary IP #2 (€0.50/month) → kafka-0 (10.0.1.20)      │ │
│ │   ├─ Kafka Broker (Internal: 9092)                     │ │
│ │   └─ Kafka External Access (NodePort: 33333)           │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │     
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Private Network: 10.0.1.0/24                           │ │
│ │   ├─ Control Plane ↔ Kafka (internal communication)    │ │
│ │   └─ All pods communicate via private IPs              │ │
│ └────────────────────────────────────────────────────────┘ │ 
└────────────────────────────────────────────────────────────┘
```

### Key Features

- ✅ **Primary IPs persist** between deployments (same IPs every time)
- ✅ **No manual VM management** (all automated via GitHub Actions)
- ✅ **GitOps deployment** (ArgoCD manages applications)
- ✅ **Label-based cleanup** (maintenance workflow finds resources by labels)

## 📁 Structure

```
infra/
├── main.tf                    # Root module - infrastructure orchestration
├── variables.tf               # All variable declarations
├── outputs.tf                 # All outputs
├── terraform.tfvars.example   # Credentials template
├── environments/
│   ├── dev.tfvars            # Dev-specific settings
│   └── prod.tfvars           # Prod-specific settings
└── modules/
    ├── network/              # VPC, subnet, firewall
    ├── k3s-server/           # K3s control plane
    └── kafka-server/         # Kafka nodes
```

## 🚀 Deployment Process (GitHub Actions - RECOMMENDED)

### Prerequisites

1. **GitHub Secrets Setup** (Settings → Secrets and variables → Actions):
   ```
   HCLOUD_TOKEN      - Hetzner API token (Read & Write)
   SSH_PUBLIC_KEY    - SSH public key for server access
   SSH_PRIVATE_KEY   - SSH private key (optional, for manual SSH)
   ```

2. **Generate SSH Key** (if you don't have one):
   ```powershell
   ssh-keygen -t ed25519 -f ./id_ed25519 -N ""
   # Add id_ed25519.pub content to SSH_PUBLIC_KEY secret
   # Add id_ed25519 content to SSH_PRIVATE_KEY secret
   ```

### Deployment Steps

#### Step 1: Deploy Cluster

1. Go to: **Actions** → **Deploy K3s Cluster**
2. Click **Run workflow**
3. Select:
   - Branch: `master` (or your working branch)
   - Environment: `dev` or `prod`
4. Click **Run workflow**

**What happens (~10 minutes):**
```
1. Provision Infrastructure (01-reusable-provision-infra.yml)
   ├─ Create/reuse Primary IPs (2 IPs, idempotent)
   ├─ Terraform: Network, Firewall, SSH Key, VMs
   ├─ Cloud-init: K3s installation on all nodes
   └─ Output: Control plane IP, kubeconfig artifact

2. Verify Cluster (02-reusable-verify-cluster.yml)
   ├─ SSH connectivity check
   ├─ Cloud-init completion (/root/k3s-ready.txt)
   ├─ K3s cluster health (nodes, pods)
   └─ Network connectivity tests

3. Deploy ArgoCD (03-reusable-deploy-argocd.yml)
   ├─ Install ArgoCD Operator v0.15.0
   ├─ Deploy ArgoCD instance (trading-argocd)
   ├─ Configure admin password
   ├─ Verify UI accessibility (http://<ip>:<nodeport>)
   ├─ Deploy parent app-of-apps (trading-system)
   └─ Verify child applications syncing

4. Deploy Strimzi & Kafka (04-reusable-deploy-strimzi.yml)
   ├─ Verify Strimzi operator (deployed via ArgoCD)
   ├─ Verify kafka-cluster Application syncing
   ├─ Wait for Kafka CR (trading-cluster) creation
   ├─ Check Kafka pods running
   └─ Test external access (NodePort 33333)
```

#### Step 2: Access Cluster

1. **Download kubeconfig** from GitHub Actions artifacts:
   - Go to workflow run → Artifacts → Download `kubeconfig-<env>`
   - Extract `kubeconfig.yaml`

2. **Use kubectl**:
   ```powershell
   $env:KUBECONFIG = ".\kubeconfig.yaml"
   kubectl get nodes
   kubectl get pods -A
   ```

3. **Access ArgoCD**:
   ```powershell
   # Get ArgoCD NodePort
   kubectl get svc -n argocd trading-argocd-server
   # Note the NodePort (e.g., 31168)
   
   # Get admin password
   kubectl -n argocd get secret trading-argocd-cluster -o jsonpath="{.data.admin\\.password}" | base64 -d
   
   # Open: http://<control-plane-ip>:<nodeport>
   # Login: admin / <password>
   ```

4. **Verify Kafka Deployment**:
   ```powershell
   # Check ArgoCD applications
   kubectl get applications -n argocd
   # Should show: trading-system, kafka-cluster, dummy-strategy
   
   # Check Kafka cluster
   kubectl get kafka -n kafka
   # Should show: trading-cluster
   
   # Check Kafka pods
   kubectl get pods -n kafka
   
   # Get external Kafka address
   kubectl get svc -n kafka trading-cluster-kafka-external-bootstrap
   # External: <control-plane-ip>:33333
   ```

#### Step 3: Daily Cleanup (Cost Optimization)

1. Go to: **Actions** → **Hetzner Cloud Maintenance**
2. Click **Run workflow**
3. Select:
   - Branch: `from-scratch-2`
   - Environment: `dev`
   - Action: **`destroy-cluster`**
4. Click **Run workflow**

**What happens (~30 seconds):**
```
✅ Deletes: VMs, Networks, Firewalls, SSH Keys
✅ Keeps: Primary IPs (€1/month billing continues)
✅ Result: Next deployment reuses same IPs
```

#### Step 4: Complete Teardown (Permanent)

**⚠️ WARNING: Deletes Primary IPs - cannot be recovered!**

Use action: **`destroy-all`** to delete everything including Primary IPs.

## 🔑 GitHub Actions Workflows

### Main Workflows
- **deploy-cluster.yml**: Orchestrates full deployment (calls 01-04 reusable workflows)
- **hcloud-maintenance.yml**: List, destroy cluster, or destroy all resources

### Reusable Workflows (Called by deploy-cluster.yml)
1. **01-reusable-provision-infra.yml**: Terraform deployment + Primary IP management
2. **02-reusable-verify-cluster.yml**: K3s cluster health checks
3. **03-reusable-deploy-argocd.yml**: ArgoCD operator + instance + parent app deployment
4. **04-reusable-deploy-strimzi.yml**: Verify Strimzi & Kafka via ArgoCD

### Key Improvements (Recent)
- ✅ ArgoCD UI accessibility verification (actual NodePort testing)
- ✅ Automatic parent app-of-apps deployment (enables GitOps automation)
- ✅ ArgoCD Applications sync status monitoring
- ✅ Kafka cluster deployment verification via ArgoCD
- ✅ Kafka external access testing (NodePort 33333)

## 🛠️ Manual Deployment (Local Terraform)

### 1. Setup Credentials

```powershell
# Set environment variables (do NOT create terraform.tfvars file)
$env:TF_VAR_hcloud_token = "your-hetzner-token"
$env:TF_VAR_ssh_public_key = "ssh-ed25519 AAAAC3Nza..."
$env:TF_VAR_control_plane_primary_ip_id = "12345"  # From hcloud primary-ip list
$env:TF_VAR_kafka_primary_ip_id = "67890"          # From hcloud primary-ip list
```

### 2. Deploy

```powershell
# Initialize Terraform
C:\projects\apps\terraform_1.13.4\terraform.exe init

# Plan deployment
C:\projects\apps\terraform_1.13.4\terraform.exe plan -var-file="environments/dev.tfvars"

# Apply
C:\projects\apps\terraform_1.13.4\terraform.exe apply -var-file="environments/dev.tfvars"
```

### 3. Post-Deployment Manual Steps

**⚠️ IMPORTANT: Local Terraform cannot handle token distribution!**

After Terraform completes:

```powershell
# 1. Get control plane IP
CONTROL_IP=$(terraform output -raw k3s_control_public_ip)

# 2. Wait for K3s to be ready
ssh root@$CONTROL_IP "tail -f /root/cloud-init.log"
# Wait for: "K3s control plane setup complete"

# 3. Get K3s token
K3S_TOKEN=$(ssh root@$CONTROL_IP "cat /var/lib/rancher/k3s/server/node-token")

# 4. Push token to worker node
KAFKA_IP=$(terraform output -json kafka_server_public_ips | jq -r '.[0]')
ssh root@$KAFKA_IP "echo '$K3S_TOKEN' > /tmp/k3s-token && chmod 600 /tmp/k3s-token"

# 5. Monitor worker join
ssh root@$KAFKA_IP "tail -f /root/cloud-init.log"
# Wait for: "K3s agent setup complete"

# 6. Verify cluster
ssh root@$CONTROL_IP "kubectl get nodes"
# Should show: 2 nodes (control-plane, kafka-0)
```

## 📊 Environment Comparison

| Setting | Dev | Prod |
|---------|-----|------|
| **Environment** | dev | prod |
| **Network** | 10.0.1.0/24 | 10.1.1.0/24 |
| **Control Plane** | cx22 (2 vCPU, 4GB) | cx32 (4 vCPU, 8GB) |
| **Kafka Nodes** | 1x cx22 | 3x cx32 |
| **Running Hours** | 8h/day | 10h/day |
| **Monthly Cost** | €12.90 (58% savings) | €48.60 (58% savings) |
| **Primary IPs** | €1.00/month | €1.00/month |
| **Purpose** | Testing | Production |

**Shared Settings:**
- K3s channel: `stable` (currently v1.33.5+k3s1)
- Kafka version: 4.0.0 (Strimzi)
- Location: nbg1 (Nuremberg)
- Datacenter: nbg1-dc3

## 🔧 How It Works

### Primary IP Architecture

**Problem Solved:** Hetzner cannot assign Primary IPs during server creation if Terraform manages both resources simultaneously (chicken-egg problem).

**Solution:** GitHub Actions creates Primary IPs BEFORE Terraform runs:

```
GitHub Actions Workflow:
1. Check if Primary IPs exist (by name)
2. If not → Create unassigned Primary IPs
3. If exists → Get their IDs
4. Pass IDs to Terraform via TF_VAR_* environment variables
5. Terraform assigns IPs during server creation (no reboot!)
```

**Benefits:**
- ✅ IPs created once, reused forever
- ✅ No manual VM shutdown/restart needed
- ✅ Idempotent (safe to run multiple times)
- ✅ Same IPs across deployments (DNS stable)

### Cloud-Init Pattern

**Problem Solved:** Hetzner Ubuntu 22.04 has broken `runcmd` module - commands don't execute.

**Solution:** `write_files` + `runcmd` pattern:

```yaml
#cloud-config

write_files:
  - path: /root/setup.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Your setup commands here
      
runcmd:
  - /root/setup.sh  # Just execute the script
```

**Why this works:**
- ✅ `write_files` always works (creates script on disk)
- ✅ Single simple `runcmd` command
- ✅ Proper bash script with error handling
- ✅ All output to `/root/cloud-init.log` for debugging

### K3s Token Distribution

**Problem Solved:** Worker nodes cannot SSH to control plane (no private key, no trust).

**Solution:** GitHub Actions acts as orchestrator:

```
1. Control plane installs K3s → creates token at /var/lib/rancher/k3s/server/node-token
2. GitHub Actions (has SSH private key):
   - SSH to control plane → retrieve token
   - SSH to worker node → push token to /tmp/k3s-token
3. Worker node cloud-init:
   - Waits for /tmp/k3s-token file
   - Installs K3s agent with token
   - Joins cluster
```

**Benefits:**
- ✅ No inter-node SSH needed
- ✅ No private key distribution
- ✅ Synchronization built-in
- ✅ Clean separation of concerns

### Resource Labeling

**Problem:** Old resources without labels couldn't be cleaned up by maintenance workflow.

**Solution:** All resources get labels:

```hcl
labels = {
  environment = "dev"
  cluster     = "k3s-trading"
  role        = "control-plane" | "kafka"
}
```

**Cleanup becomes simple:**
```bash
hcloud server list -l environment=dev -o columns=id | xargs hcloud server delete
hcloud network list -l environment=dev -o columns=id | xargs hcloud network delete
# etc.
```

## 🎯 Key Benefits of This Structure

### 1. DRY (Don't Repeat Yourself)
- Single `main.tf` for all environments
- No code duplication
- Changes apply to all environments

### 2. Environment Isolation
- Separate `.tfvars` files
- Different server types per environment
- Independent state files (use workspaces or separate backends)

### 3. Easy to Maintain
- Update K3s version in one place
- Modify infrastructure once
- Clear separation of config vs code

### 4. Scalable
- Add new environments easily
- Adjust resources per environment
- Flexible Kafka node count

## 💡 Usage Examples

### Deploy with Custom Settings

```powershell
# Override specific variables
terraform apply -var-file="environments/dev.tfvars" -var="kafka_node_count=2"

# Use different K3s version
terraform apply -var-file="environments/dev.tfvars" -var="k3s_version=v1.35.0+k3s1"
```

### Using Workspaces (Recommended)

```powershell
# Create dev workspace
terraform workspace new dev
terraform apply -var-file="environments/dev.tfvars"

# Create prod workspace
terraform workspace new prod
terraform apply -var-file="environments/prod.tfvars"

# Switch between environments
terraform workspace select dev
terraform workspace select prod
```

### Separate State Files

```powershell
# Dev with separate state
terraform apply -var-file="environments/dev.tfvars" -state="dev.tfstate"

# Prod with separate state
terraform apply -var-file="environments/prod.tfvars" -state="prod.tfstate"
```

## 📝 Configuration Variables

### Required (in terraform.tfvars)
- `hcloud_token` - Hetzner Cloud API token
- `ssh_public_key` - SSH public key

### Environment-Specific (in environments/*.tfvars)
- `environment` - "dev" or "prod"
- `control_plane_server_type` - Server type for K3s
- `kafka_server_type` - Server type for Kafka
- `kafka_node_count` - Number of Kafka nodes
- `network_cidr` - Network CIDR block

### Shared (same across environments)
- `k3s_version` - K3s version
- `kafka_version` - Kafka version
- `cluster_name` - Cluster name
- `location` - Hetzner location

## � Troubleshooting

### Cloud-Init Not Executing

**Symptom:** `cloud-init status` shows "done" but no logs in `/root/cloud-init.log`

**Cause:** Hetzner Ubuntu 22.04 + cloud-init v25.1.4 has broken `runcmd` module

**Solution:** Already implemented - see `write_files` + `runcmd` pattern above

**Debug:**
```bash
# Check user-data received
ssh root@<ip> "cat /var/lib/cloud/instance/user-data.txt"

# Check cloud-init output
ssh root@<ip> "cat /var/log/cloud-init-output.log | tail -100"

# Check cloud-init status
ssh root@<ip> "cloud-init status --long"

# Check setup script exists
ssh root@<ip> "ls -la /root/setup*.sh"

# Manually run script
ssh root@<ip> "/root/setup-k3s.sh"
```

### Worker Node Not Joining Cluster

**Symptom:** Control plane has 1 node, worker stuck at "Retrieving K3s token"

**Cause:** Worker cannot SSH to control plane (no private key)

**Solution:** Already implemented - GitHub Actions pushes token

**Verify:**
```bash
# Check if token file exists on worker
ssh root@<kafka-ip> "cat /tmp/k3s-token"

# Check worker cloud-init log
ssh root@<kafka-ip> "tail -f /root/cloud-init.log"

# Manually push token (if GitHub Actions failed)
CONTROL_IP="<control-ip>"
KAFKA_IP="<kafka-ip>"
K3S_TOKEN=$(ssh root@$CONTROL_IP "cat /var/lib/rancher/k3s/server/node-token")
ssh root@$KAFKA_IP "echo '$K3S_TOKEN' > /tmp/k3s-token && chmod 600 /tmp/k3s-token"
```

### Primary IP Not Assigned

**Symptom:** Server created but has temporary IP, not Primary IP

**Cause:** Primary IP ID not passed correctly to Terraform

**Debug:**
```bash
# Check Primary IPs
hcloud primary-ip list

# Check if IDs are set
echo $TF_VAR_control_plane_primary_ip_id
echo $TF_VAR_kafka_primary_ip_id

# Check Terraform plan
terraform plan -var-file="environments/dev.tfvars"
# Should show: ipv4 = <primary-ip-id>
```

### Resource Already Exists (Uniqueness Error)

**Symptom:** Terraform fails with "SSH key not unique" or "name is already used"

**Cause:** Old resources without labels from previous deployment

**Solution:** Run manual cleanup workflow:
1. Go to Actions → Manual Cleanup
2. Select environment
3. Run workflow
4. Retry deployment

**Manual cleanup:**
```bash
# List resources
hcloud ssh-key list
hcloud network list
hcloud firewall list

# Delete by ID
hcloud ssh-key delete <id>
hcloud network delete <id>
hcloud firewall delete <id>
```

### Cluster Verification Failed

**Symptom:** Workflow fails at "Verify K3s cluster operational"

**Check:**
```bash
# SSH to control plane
ssh root@<control-ip>

# Check K3s status
systemctl status k3s

# Check nodes
kubectl get nodes

# Check pods
kubectl get pods -A

# Check logs
journalctl -u k3s -n 100
```

## 🔒 Security Best Practices

- ✅ Use GitHub Secrets for credentials (never commit to repo)
- ✅ Rotate SSH keys quarterly
- ✅ Use separate Hetzner tokens for dev/prod
- ✅ Enable firewall rules (already configured)
- ✅ Primary IPs only for control plane + kafka-0 (minimize attack surface)
- ✅ Private network for inter-node communication (10.0.1.0/24)
- ⚠️ Firewall currently disabled for testing (re-enable in production!)

## 📚 Documentation

### Project Documentation
- [CLOUD_INIT_TROUBLESHOOTING.md](./CLOUD_INIT_TROUBLESHOOTING.md) - Detailed cloud-init issue analysis
- [PRIMARY_IP_ARCHITECTURE.md](./PRIMARY_IP_ARCHITECTURE.md) - Primary IP implementation details
- [VALIDATION_CHECKLIST.md](./VALIDATION_CHECKLIST.md) - Testing and validation guide

### External Resources
- [Hetzner Cloud Docs](https://docs.hetzner.com/cloud/)
- [K3s Documentation](https://docs.k3s.io/)
- [Strimzi Kafka Operator](https://strimzi.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## 🎓 Key Design Decisions

### 1. Parent App-of-Apps Pattern
**Critical**: Parent app (`trading-system`) must be deployed to trigger GitOps automation. Without it:
- ❌ ArgoCD is installed but has no applications
- ❌ Kafka cluster is never created
- ✅ Workflow 03 now automatically deploys parent app after ArgoCD installation

### 2. Workflow Orchestration
**4-stage deployment** ensures proper dependency order:
1. Infrastructure (Terraform + K3s)
2. Verification (cluster health)
3. ArgoCD (operator + instance + parent app)
4. Strimzi verification (operator + Kafka cluster via ArgoCD)

### 3. Verification Strategy
Each stage validates before proceeding:
- HTTP accessibility tests (ArgoCD UI, Kafka)
- Sync status monitoring (ArgoCD Applications)
- Resource existence checks (CRDs, pods, services)
- External connectivity tests (NodePort reachability)

### 4. Primary IP Management

### 4. Primary IP Management
GitHub Actions creates Primary IPs **before** Terraform runs:
- IDs passed via `TF_VAR_*` environment variables
- Terraform assigns during server creation (no reboot)
- Same IPs across all deployments (DNS stable)

### 5. Cloud-Init Pattern
`write_files` + `runcmd` pattern (Hetzner Ubuntu 22.04 has broken `runcmd`):
```yaml
write_files:
  - path: /root/setup.sh
    content: |
      #!/bin/bash
      # Setup commands
runcmd:
  - /root/setup.sh
```

### 6. K3s Token Distribution
GitHub Actions orchestrates token sharing:
1. Control plane creates token
2. GitHub Actions retrieves token via SSH
3. GitHub Actions pushes token to worker nodes
4. Workers join cluster using token

## 🎓 Lessons Learned

1. **App-of-Apps Deployment**: Must deploy parent app to activate GitOps (was missing!)
2. **Verification Importance**: HTTP/TCP tests catch issues early (ArgoCD UI, Kafka NodePort)
3. **Primary IPs**: Cannot be assigned during server creation if Terraform manages both → Create IPs first
4. **Cloud-Init**: `runcmd` broken on Hetzner Ubuntu 22.04 → Use `write_files` + script pattern
5. **K3s Token**: Worker nodes can't SSH to control plane → GitHub Actions orchestrates distribution
6. **Resource Labels**: Essential for automated cleanup → Always add environment/cluster/role labels
7. **Idempotency**: Check resource existence before creating → Safe to re-run workflows
8. **ArgoCD Sync Monitoring**: Wait for Applications to sync before assuming deployment complete

## 📈 Roadmap

### Phase 1: Core Infrastructure (✅ Complete)
- ✅ Primary IP architecture
- ✅ K3s cluster with ArgoCD
- ✅ Cloud-init automation
- ✅ GitHub Actions workflows
- ✅ Comprehensive documentation

### Phase 2: Application Deployment (✅ Complete)
- ✅ ArgoCD Operator v0.15.0 automated installation
- ✅ Parent app-of-apps pattern (trading-system)
- ✅ Strimzi Kafka Operator (deployed via ArgoCD)
- ✅ Kafka cluster (1 broker for dev, external NodePort 33333)
- ✅ Automated verification workflows
- ✅ UI accessibility and sync status checks

### Phase 3: Monitoring (Planned)
- 📋 Prometheus + Grafana
- 📋 K3s metrics
- 📋 Kafka metrics
- 📋 Custom dashboards

### Phase 4: Production Hardening (Planned)
- 📋 Enable firewall rules
- 📋 TLS certificates (Let's Encrypt)
- 📋 Backup strategy
- 📋 Disaster recovery procedures

