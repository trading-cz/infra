# K3s Trading Infrastructure - Terraform

Ephemeral K3s clusters on Hetzner Cloud with persistent Primary IPs for algorithmic trading workloads.

## � Core Concept

**Deploy clusters only during trading hours → Massive cost savings (58%)**

- **Ephemeral VMs**: Created on-demand, destroyed after hours
- **Persistent IPs**: Remain assigned (€1/month total), maintain stable DNS
- **Automated Deployment**: GitHub Actions orchestrates everything
- **K3s + Kafka**: Streaming pipeline for market data → trading strategies

**Cost Comparison:**
- Dev: €12.90/month (8h/day) vs €28.80 (24/7) = **55% savings**
- Prod: €48.60/month (10h/day) vs €114.40 (24/7) = **58% savings**

## 🏗️ Architecture

### Infrastructure Components

**2-Node Cluster (dev) / 4-Node Cluster (prod):**
- **Control Plane**: K3s server + ArgoCD + Python apps (Primary IP #1)
- **Kafka-0**: Kafka broker with external access (Primary IP #2)
- **Kafka-1, Kafka-2** (prod only): Additional Kafka brokers (temporary IPs)

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
1. Create/Find Primary IPs (2 IPs, idempotent)
   ├─ Control Plane IP: Created if not exists, reused if exists
   └─ Kafka-0 IP: Created if not exists, reused if exists

2. Terraform Plan & Apply
   ├─ Create Private Network (10.0.1.0/24)
   ├─ Create Firewall (SSH, K3s API, HTTPS)
   ├─ Create SSH Key
   ├─ Create Control Plane VM (attach Primary IP #1)
   └─ Create Kafka Node(s) (attach Primary IP #2 to kafka-0)

3. Cloud-Init Installation (Control Plane)
   ├─ Install K3s server (stable channel)
   ├─ Install ArgoCD
   └─ Create marker file: /root/k3s-ready.txt

4. Token Distribution (GitHub Actions)
   ├─ Retrieve K3s token from control plane
   └─ Push token to worker node(s)

5. Cloud-Init Installation (Worker Nodes)
   ├─ Wait for K3s control plane API (port 6443)
   ├─ Wait for token file (/tmp/k3s-token)
   ├─ Install K3s agent
   ├─ Join cluster
   └─ Create marker file: /root/k3s-agent-ready.txt

6. Verification Steps
   ├─ SSH accessibility
   ├─ Cloud-init completion
   ├─ K3s cluster (2+ nodes)
   ├─ System pods running
   ├─ ArgoCD deployed
   ├─ Traefik ingress controller
   └─ Network connectivity

7. Upload kubeconfig artifact
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
   # Port forward
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   
   # Get admin password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   
   # Open: https://localhost:8080
   # Login: admin / <password>
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

**⚠️ WARNING: This deletes Primary IPs - cannot be recovered!**

1. Go to: **Actions** → **Hetzner Cloud Maintenance**
2. Click **Run workflow**
3. Select:
   - Action: **`destroy-all`**
4. Wait for 10-second warning, then confirm

**What happens:**
```
❌ Deletes EVERYTHING including Primary IPs
❌ Next deployment gets new random IPs
❌ DNS must be updated to new IPs
```

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

## 🎓 Lessons Learned

1. **Primary IPs**: Cannot be assigned during server creation if Terraform manages both → Create IPs first in GitHub Actions
2. **Cloud-Init**: `runcmd` broken on Hetzner Ubuntu 22.04 → Use `write_files` + script pattern
3. **K3s Token**: Worker nodes can't SSH to control plane → GitHub Actions orchestrates token distribution
4. **Resource Labels**: Essential for automated cleanup → Always add environment/cluster/role labels
5. **Idempotency**: GitHub Actions checks if resources exist before creating → Safe to re-run workflows
6. **Validation**: Add comprehensive verification steps → Catch issues early in deployment
7. **Logging**: Redirect all cloud-init output to `/root/cloud-init.log` → Essential for debugging

## 📈 Roadmap

### Phase 1: Core Infrastructure (✅ Complete)
- ✅ Primary IP architecture
- ✅ K3s cluster with ArgoCD
- ✅ Cloud-init automation
- ✅ GitHub Actions workflows
- ✅ Comprehensive documentation

### Phase 2: Kafka Deployment (In Progress)
- ⏳ Deploy Strimzi Kafka Operator via ArgoCD
- ⏳ Create Kafka cluster custom resource
- ⏳ Configure external access (NodePort 33333)
- ⏳ Test Kafka producer/consumer

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

