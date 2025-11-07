# Terraform IPv4 Optimization Plan

## Executive Summary

**Goal**: Fix GitHub Actions SSH timeout issue and optimize IPv4 costs while maintaining ArgoCD and Kafka external access.

**Current Problem**: 
- GitHub Actions workflow fails with 60 SSH retry attempts
- Terraform outputs **private IP** (10.0.1.10) instead of public IP
- GitHub Actions cannot reach control plane from internet
- All 4 VMs have auto-assigned IPv4 (€2.00/month wasteful spending)

**Root Cause**: 
- `terraform/modules/k3s/outputs.tf` returns private network IP
- Servers have public IPs auto-assigned by Hetzner (not exposed in outputs)
- No persistent IPs strategy for ephemeral clusters

**Final Solution**:
- Use **2× persistent Primary IPv4** (€1.00/month total, 50% cost reduction)
- Primary IPs survive cluster destruction and are reused automatically
- Fix Terraform outputs to expose public IPs
- Semi-automatic Primary IP assignment via GitHub Actions (no manual steps)
- Maintenance script destroys VMs only (keeps Primary IPs by default)
- Enable external access: ArgoCD (control plane) and Kafka (kafka-0)

---

## Why This Matters

### 1. **Cost Optimization**

| Approach | Monthly Cost | Notes |
|----------|--------------|-------|
| **Current (auto-assigned)** | €2.00 | 4 VMs × €0.50/mo (wasteful, not reusable) |
| **Floating IP approach** | €5.20 | 2× Primary (€1.00) + 1× Floating (€4.20) |
| **Persistent Primary IPs** ✅ | **€1.00** | 2× Primary IPs, reusable across deployments |

**Savings**: €1.00/month (50% reduction), €12/year vs current, €50/year vs Floating IP

### 2. **Operational Benefits**

✅ **Stable DNS**: Same IPs across all cluster recreations
```
argocd.yourdomain.tld → 95.217.X.Y (never changes)
kafka.yourdomain.tld  → 95.217.A.B (never changes)
```

✅ **Ephemeral-Friendly**: 
- VMs destroyed via hcloud CLI (fast, no Terraform state needed)
- IPs persist across all deployments
- Next deployment reuses same IPs automatically via GitHub Actions

✅ **No Terraform State Management**: 
- No remote backend required (Terraform Cloud, S3, etc.)
- State discarded after each deployment
- Primary IPs managed directly via Hetzner API

✅ **No Floating IP Costs**: Save €4.20/month (€50.40/year)

✅ **ArgoCD External Access**: Required for GitOps workflow changes and monitoring

✅ **Fully Automated**: GitHub Actions handles Primary IP assignment (no manual steps)

### 3. **Technical Requirements**

**Must-Have**:
- ArgoCD accessible from internet (for applying Kubernetes config changes)
- Kafka-0 accessible externally (for external data producers/consumers)
- SSH access to control plane during bootstrap (for kubeconfig fetch)
- Minimal public IP exposure (security)

**Nice-to-Have**:
- Stable IPs for DNS (achieved with persistent Primary IPs)
- Low operational overhead (fully automated via GitHub Actions)

---

## Final Topology

### Infrastructure Layout (4 VMs)

```
┌─────────────────────────────────────────────────────────────────┐
│ Hetzner Private Network: 10.0.0.0/16                            │
│ Subnet: 10.0.1.0/24                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ VM1: k3s-control (CPX21)                                  │  │
│  │ ─────────────────────────────────────────────────────────│  │
│  │ Private IP:  10.0.1.10                                   │  │
│  │ Public IPv4: 95.217.X.Y (Primary IP #1) ✅ PERSISTENT    │  │
│  │ Public IPv6: 2a01:xxxx (free)                            │  │
│  │                                                           │  │
│  │ Services:                                                 │  │
│  │  • K3s control plane (API: 6443)                         │  │
│  │  • ArgoCD (exposed via NodePort/LoadBalancer)            │  │
│  │  • Python ingestion app (800MB)                          │  │
│  │  • Python strategy apps (1600MB)                         │  │
│  │                                                           │  │
│  │ External Access:                                          │  │
│  │  • SSH: root@95.217.X.Y (bootstrap only)                 │  │
│  │  • ArgoCD UI: https://argocd.yourdomain.tld              │  │
│  │  • Kubectl API: kubectl --server=https://95.217.X.Y:6443 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          ▲                                      │
│                          │ K3s API (internal)                  │
│          ┌───────────────┴───────────────┐                     │
│          │                               │                     │
│  ┌───────▼──────┐  ┌──────────────┐  ┌──▼──────────┐          │
│  │ VM2: kafka-0 │  │ VM3: kafka-1 │  │ VM4: kafka-2│          │
│  │ (CPX31)      │  │ (CPX31)      │  │ (CPX31)     │          │
│  │──────────────│  │──────────────│  │─────────────│          │
│  │ 10.0.1.20    │  │ 10.0.1.21    │  │ 10.0.1.22   │          │
│  │ 95.217.A.B ✅│  │ (no IPv4)    │  │ (no IPv4)   │          │
│  │ Primary IP #2│  │ IPv6 only    │  │ IPv6 only   │          │
│  │ PERSISTENT   │  │ (free)       │  │ (free)      │          │
│  │              │  │              │  │             │          │
│  │ Kafka Broker │  │ Kafka Broker │  │ Kafka Broker│          │
│  │ + Controller │  │ + Controller │  │ + Controller│          │
│  │ (KRaft)      │  │ (KRaft)      │  │ (KRaft)     │          │
│  │              │  │              │  │             │          │
│  │ External:    │  │ Internal only│  │ Internal    │          │
│  │ Port 9093    │  │ Port 9092    │  │ Port 9092   │          │
│  │ (TLS)        │  │ (plaintext)  │  │ (plaintext) │          │
│  └──────────────┘  └──────────────┘  └─────────────┘          │
│         ▲                                                       │
│         │ External Kafka clients                               │
│         │ kafka.yourdomain.tld:9093                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

External Internet
      │
      │ ArgoCD UI, kubectl, SSH
      ├──────────────────────► 95.217.X.Y (Primary IP #1)
      │                        VM1: Control Plane
      │
      │ Kafka producers/consumers
      └──────────────────────► 95.217.A.B (Primary IP #2)
                               VM2: Kafka-0
```

### IP Assignment Summary

| VM | Role | Private IP | Public IPv4 | Cost | Purpose |
|----|------|------------|-------------|------|---------|
| VM1 | Control Plane | 10.0.1.10 | **Primary IP #1** (95.217.X.Y) | €0.50/mo | ArgoCD, kubectl, SSH (bootstrap) |
| VM2 | kafka-0 | 10.0.1.20 | **Primary IP #2** (95.217.A.B) | €0.50/mo | External Kafka access |
| VM3 | kafka-1 | 10.0.1.21 | None (IPv6 free) | €0.00 | Internal Kafka only |
| VM4 | kafka-2 | 10.0.1.22 | None (IPv6 free) | €0.00 | Internal Kafka only |
| **Total** | | | **2× Primary IPv4** | **€1.00/mo** | |

### DNS Configuration

```
# A Records (stable across all deployments)
argocd.yourdomain.tld.    300  IN  A  95.217.X.Y
kafka.yourdomain.tld.     300  IN  A  95.217.A.B

# Optional: Wildcard for services
*.k3s.yourdomain.tld.     300  IN  A  95.217.X.Y
```

---

## How Primary IP Reuse Works (Without Terraform State)

### Key Concepts

**Hetzner Primary IPs**:
- Independent resources (survive server deletion)
- Billed monthly at €0.50/IP
- Can be reassigned between servers in same datacenter
- Requires server power-off during reassignment (~1 minute)
- Set `auto_delete = false` in Terraform to persist after VM deletion
- Exist in Hetzner account even without Terraform state

**vs Floating IPs**:
- Can be moved live (no power-off required)
- €4.20/month (420% more expensive!)
- Can move between datacenters in same network zone
- Designed for high-availability scenarios (not needed for ephemeral clusters)

**Why We Don't Need Terraform State Backend**:
- VMs destroyed via **hcloud maintenance script** (not `terraform destroy`)
- Primary IPs queried from Hetzner API on each deployment
- Terraform creates Primary IPs if they don't exist, or references existing ones
- GitHub Actions assigns Primary IP #2 to kafka-0 automatically after Terraform completes
- No state persistence required between deployments

### Lifecycle Example

#### **Day 1: First Deployment**
```bash
# GitHub Actions workflow: deploy-cluster → dev → create

# 1. Terraform creates:
terraform apply
# - Primary IP #1 (95.217.X.Y, name: k3s-trading-dev-control-ip) → attached to control plane
# - Primary IP #2 (95.217.A.B, name: k3s-trading-dev-kafka-ip) → created, not attached
# - VM1 (control plane) with Primary IP #1
# - VM2-VM4 (kafka-0, kafka-1, kafka-2)

# 2. GitHub Actions post-deployment step (automatic):
hcloud server poweroff <kafka-0-id>
hcloud primary-ip assign <primary-ip-2-id> <kafka-0-id>
hcloud server poweron <kafka-0-id>
# Takes ~1 minute, fully automated

# Result:
# ✅ VM1 (control plane) has Primary IP #1 (95.217.X.Y)
# ✅ VM2 (kafka-0) has Primary IP #2 (95.217.A.B)
# ✅ VM3-VM4 (kafka-1, kafka-2) have no IPv4 (IPv6 only)
# ✅ DNS configured to point to these IPs
# ✅ Terraform state discarded (not needed anymore)
```

#### **Day 2: Cluster Destroyed**
```bash
# GitHub Actions workflow: hcloud-maintenance → dev → destroy-vms

# Deletes via hcloud CLI (NOT terraform destroy):
hcloud server delete <vm1> <vm2> <vm3> <vm4>

# What happens:
# ✅ All 4 VMs deleted instantly
# ✅ Primary IP #1 persists (auto_delete=false) → still billed €0.50/mo
# ✅ Primary IP #2 persists (auto_delete=false) → still billed €0.50/mo
# ✅ IPs remain in Hetzner account, unattached but ready
# ✅ No Terraform state to manage!
```

#### **Day 3: Second Deployment**
```bash
# GitHub Actions workflow: deploy-cluster → dev → create

# 1. Terraform sees Primary IPs exist (queries Hetzner API by name):
terraform apply
# - Finds Primary IP #1 (k3s-trading-dev-control-ip) → reuses it
# - Finds Primary IP #2 (k3s-trading-dev-kafka-ip) → reuses it
# - Creates NEW VM1 with Primary IP #1 attached
# - Creates NEW VM2-VM4

# 2. GitHub Actions post-deployment step:
hcloud primary-ip assign <primary-ip-2-id> <new-kafka-0-id>
# Assigns same Primary IP #2 to new kafka-0

# DNS still works (no changes needed):
# ✅ argocd.yourdomain.tld → 95.217.X.Y (same IP!)
# ✅ kafka.yourdomain.tld  → 95.217.A.B (same IP!)
```

#### **Day 100: After Many Deployments**
- Same IPs (95.217.X.Y, 95.217.A.B) used across all deployments
- No DNS changes ever needed
- No Terraform state management overhead
- Total cost: €1.00/month (same as Day 1)

### Cost Over Time Comparison

**Scenario**: 10 cluster deployments over 3 months

| Approach | Setup Cost | Monthly Cost | 3-Month Total |
|----------|------------|--------------|---------------|
| Auto-assigned IPs (current) | €0 | €2.00 | €6.00 |
| Floating IP | €0 | €5.20 | €15.60 |
| **Persistent Primary IPs** | €0 | **€1.00** | **€3.00** |

**Winner**: Persistent Primary IPs save €3-€12.60 over 3 months

---

## Terraform Changes Required

### Overview

**Goal**: Create persistent Primary IPs and attach them to control plane and kafka-0.

**Modules to Modify**:
1. `terraform/modules/network/` - Create Primary IP resources
2. `terraform/modules/k3s/` - Attach Primary IPs to servers
3. `terraform/main.tf` - Wire modules together
4. `terraform/outputs.tf` - Expose public IPs
5. `terraform/variables.tf` - Add datacenter variable
6. `terraform/environments/*.tfvars` - Add datacenter config

### Change Summary

#### 1. **Network Module** (`terraform/modules/network/`)

**Add**: 
- `hcloud_primary_ip.control_plane` resource (Primary IP #1)
- `hcloud_primary_ip.kafka_external` resource (Primary IP #2)
- Both with `auto_delete = false` to persist after VM deletion
- Predictable names: `k3s-trading-{env}-control-ip`, `k3s-trading-{env}-kafka-ip`

**Why**: 
- Primary IPs must be created before servers (or queried if they exist)
- Separate resources allow reuse across deployments without Terraform state
- Predictable names enable Terraform to find existing IPs via Hetzner API
- Network module is the logical place (alongside firewall, network)

**Files**:
- `main.tf`: Add 2 `hcloud_primary_ip` resources with lifecycle to prevent recreation
- `variables.tf`: Add `datacenter` variable (required for Primary IPs)
- `outputs.tf`: Export Primary IP IDs and addresses for GitHub Actions

#### 2. **K3s Module** (`terraform/modules/k3s/`)

**Modify**:
- Control plane server: Attach Primary IP #1 via `public_net.ipv4` parameter
- Kafka-0 server: Enable IPv4 (Primary IP #2 assigned by GitHub Actions post-deployment)
- Kafka-1, Kafka-2: Disable IPv4 completely (`ipv4_enabled = false`)

**Change**: 
```hcl
# Before (auto-assigned IP):
public_net {
  ipv4_enabled = true
  ipv6_enabled = true
}

# After (use persistent Primary IP):
public_net {
  ipv4_enabled = true
  ipv4         = var.control_plane_primary_ip_id  # Attach Primary IP #1
  ipv6_enabled = true
}
```

**Why**:
- Explicitly attach Primary IP #1 to control plane (Terraform)
- Kafka-0 gets Primary IP #2 via GitHub Actions (post-deployment, automated)
- Other Kafka nodes don't need public IPs (save €1.00/month)

**Files**:
- `main.tf`: Modify `public_net` blocks for all servers
- `variables.tf`: Add `control_plane_primary_ip_id` variable
- `outputs.tf`: Change `control_plane_ip` to return `ipv4_address` instead of private IP, add `kafka_node_0_id`

#### 3. **Root Module** (`terraform/main.tf`)

**Add**:
- Pass `datacenter` to network module
- Pass `control_plane_primary_ip_id` to k3s module
- Add Kafka ports (9092-9094) to firewall rules

**Why**:
- Wire network module outputs to k3s module inputs
- Ensure firewall allows Kafka external access

#### 4. **Outputs** (`terraform/outputs.tf`)

**Change**:
```hcl
# Before (wrong - returns private IP):
output "control_plane_ip" {
  value = module.k3s.control_plane_ip  # Returns 10.0.1.10 ❌
}

# After (correct - returns public IP):
output "control_plane_ip" {
  value = module.network.control_plane_primary_ip_address  # Returns 95.217.X.Y ✅
}
```

**Add**:
- `kafka_external_ip` - Primary IP #2 address
- `kafka_external_primary_ip_id` - For GitHub Actions IP assignment
- `kafka_node_0_id` - Server ID for Primary IP #2 assignment

**Why**:
- GitHub Actions needs public IP for SSH
- GitHub Actions needs IP IDs for automated assignment
- Clear distinction between private and public IPs

#### 5. **Variables** (`terraform/variables.tf`, `environments/*.tfvars`)

**Add**:
- `datacenter` variable (e.g., "nbg1-dc3")
- Must match server `location` to avoid errors

**Why**:
- Primary IPs are bound to a specific datacenter
- Server and Primary IP must be in same datacenter for assignment

### Detailed File Changes

#### File 1: `terraform/modules/network/main.tf`

**Add 2 Primary IP resources**:
```hcl
resource "hcloud_primary_ip" "control_plane" {
  name          = "${var.network_name}-control-ip"
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false  # ✅ Key setting - IP survives server deletion
  datacenter    = var.datacenter
  labels        = merge(var.common_labels, { purpose = "control-plane-argocd" })
}

resource "hcloud_primary_ip" "kafka_external" {
  name          = "${var.network_name}-kafka-ip"
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false  # ✅ Key setting - IP survives server deletion
  datacenter    = var.datacenter
  labels        = merge(var.common_labels, { purpose = "kafka-external" })
}
```

#### File 2: `terraform/modules/network/outputs.tf`

**Add 4 new outputs**:
```hcl
output "control_plane_primary_ip_id" {
  description = "ID of the control plane primary IP"
  value       = hcloud_primary_ip.control_plane.id
}

output "control_plane_primary_ip_address" {
  description = "Address of the control plane primary IP"
  value       = hcloud_primary_ip.control_plane.ip_address
}

output "kafka_external_primary_ip_id" {
  description = "ID of the Kafka external primary IP"
  value       = hcloud_primary_ip.kafka_external.id
}

output "kafka_external_primary_ip_address" {
  description = "Address of the Kafka external primary IP"
  value       = hcloud_primary_ip.kafka_external.ip_address
}
```

#### File 3: `terraform/modules/k3s/main.tf`

**Modify control plane server**:
```hcl
resource "hcloud_server" "control_plane" {
  # ... existing config ...
  
  public_net {
    ipv4_enabled = true
    ipv4         = var.control_plane_primary_ip_id  # ✅ Attach Primary IP #1
    ipv6_enabled = true
  }
  
  # ... rest unchanged ...
}
```

**Modify Kafka nodes (conditional IPv4)**:
```hcl
resource "hcloud_server" "kafka_nodes" {
  count = var.kafka_node_count
  
  # ... existing config ...
  
  public_net {
    # Only kafka-0 (count.index == 0) gets IPv4 enabled
    # Primary IP #2 will be assigned by GitHub Actions post-deployment
    ipv4_enabled = count.index == 0 ? true : false
    ipv6_enabled = true
  }
  
  # ... rest unchanged ...
}
```

#### File 4: `terraform/modules/k3s/outputs.tf`

**Fix control_plane_ip output**:
```hcl
# Before:
output "control_plane_ip" {
  value = [for n in hcloud_server.control_plane.network : n.ip][0]  # ❌ Private IP (10.0.1.10)
}

# After:
output "control_plane_ip" {
  value = hcloud_server.control_plane.ipv4_address  # ✅ Public IP (95.217.X.Y)
}
```

**Add new outputs for GitHub Actions**:
```hcl
output "kafka_node_0_id" {
  description = "Server ID of kafka-0 (for Primary IP assignment by GitHub Actions)"
  value       = hcloud_server.kafka_nodes[0].id
}

output "kafka_node_0_private_ip" {
  description = "Private IP of kafka-0 (for verification)"
  value       = [for n in hcloud_server.kafka_nodes[0].network : n.ip][0]
}
```

#### File 5: `terraform/main.tf`

**Update module calls**:
```hcl
module "network" {
  source     = "./modules/network"
  datacenter = var.datacenter  # ✅ Add this
  # ... rest unchanged ...
}

module "k3s" {
  source                       = "./modules/k3s"
  control_plane_primary_ip_id  = module.network.control_plane_primary_ip_id  # ✅ Add this
  # ... rest unchanged ...
}
```

**Add Kafka firewall rules**:
```hcl
firewall_rules = [
  # ... existing rules ...
  {
    direction   = "in"
    protocol    = "tcp"
    port        = "9092-9094"  # ✅ Add Kafka ports
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow Kafka"
  }
]
```

#### File 6: `terraform/outputs.tf`

**Replace and add outputs**:
```hcl
output "control_plane_ip" {
  description = "Public IPv4 of control plane (Primary IP #1 - persistent)"
  value       = module.network.control_plane_primary_ip_address  # ✅ Changed
}

output "kafka_external_ip" {
  description = "Public IPv4 for Kafka (Primary IP #2 - persistent)"
  value       = module.network.kafka_external_primary_ip_address  # ✅ New
}

output "kafka_external_primary_ip_id" {
  description = "ID of Kafka external Primary IP (for GitHub Actions assignment)"
  value       = module.network.kafka_external_primary_ip_id  # ✅ New
}

output "kafka_node_0_id" {
  description = "Server ID of kafka-0 (for Primary IP assignment by GitHub Actions)"
  value       = module.k3s.kafka_node_0_id  # ✅ New
}
```

#### File 7: `terraform/variables.tf`

**Add datacenter variable**:
```hcl
variable "datacenter" {
  description = "Datacenter for Primary IPs (must match server location)"
  type        = string
  default     = "nbg1-dc3"  # Nuremberg datacenter 3
}
```

#### File 8: `terraform/environments/dev.tfvars`

**Add datacenter**:
```hcl
environment  = "dev"
cluster_name = "k3s-trading"
location     = "nbg1"
datacenter   = "nbg1-dc3"  # ✅ Add this line
# ... rest unchanged ...
```

#### File 9: `terraform/environments/prod.tfvars`

**Add datacenter**:
```hcl
environment  = "prod"
cluster_name = "k3s-trading"
location     = "nbg1"
datacenter   = "nbg1-dc3"  # ✅ Add this line
# ... rest unchanged ...
```

---

## Implementation Steps

### Phase 1: Terraform Changes (30 minutes)

1. **Backup current state**:
   ```bash
   git checkout -b feature/ipv4-optimization
   ```

2. **Modify files** (in order):
   - `terraform/modules/network/variables.tf` (add datacenter)
   - `terraform/modules/network/main.tf` (add Primary IPs)
   - `terraform/modules/network/outputs.tf` (export IPs)
   - `terraform/modules/k3s/variables.tf` (add Primary IP variable)
   - `terraform/modules/k3s/main.tf` (attach Primary IPs)
   - `terraform/modules/k3s/outputs.tf` (fix outputs)
   - `terraform/variables.tf` (add datacenter)
   - `terraform/main.tf` (wire modules)
   - `terraform/outputs.tf` (expose IPs)
   - `terraform/environments/dev.tfvars` (add datacenter)
   - `terraform/environments/prod.tfvars` (add datacenter)

3. **Validate**:
   ```powershell
   cd terraform
   terraform init
   terraform validate
   ```

### Phase 2: GitHub Actions Workflow Changes (20 minutes)

1. **Update `deploy-cluster.yml`**:
   - Add post-deployment step: Assign Primary IP #2 to kafka-0
   - Install hcloud CLI
   - Power off kafka-0, assign Primary IP, power on
   - Update summary to mention Primary IP persistence

2. **Update `hcloud-maintenance.yml`**:
   - Rename action options: `list`, `destroy-vms`, `destroy-all`
   - Add Primary IP listing (always shown)
   - `destroy-vms`: Delete VMs only, keep Primary IPs
   - `destroy-all`: Delete VMs + Primary IPs (with warning)

### Phase 3: Deploy via GitHub Actions

1. **Commit and push**:
   ```bash
   git add .
   git commit -m "feat: optimize IPv4 costs with persistent Primary IPs"
   git push origin feature/ipv4-optimization
   ```

2. **Create Pull Request**:
   - Review Terraform plan in PR comments
   - Merge to `main` branch

3. **Trigger deployment**:
   - GitHub Actions → Deploy K3s Cluster
   - Select environment: `dev`
   - Select action: `create`

4. **Monitor deployment**:
   - SSH should succeed on first attempt (not 60 retries!) ✅
   - Terraform completes successfully
   - **New step**: GitHub Actions assigns Primary IP #2 to kafka-0 (automatic, ~1 minute)
   - ArgoCD installs successfully

### Phase 4: Configure DNS (One-Time, 5 minutes)

```bash
# Get Primary IPs from GitHub Actions output or Terraform:
terraform output control_plane_ip  # 95.217.X.Y
terraform output kafka_external_ip # 95.217.A.B

# Add A records in your DNS provider:
argocd.yourdomain.tld.  A  95.217.X.Y
kafka.yourdomain.tld.   A  95.217.A.B

# These IPs will never change across deployments!
```

### Phase 5: Verify Everything Works

```bash
# Download kubeconfig from GitHub Actions artifacts

# Test ArgoCD access
kubectl --kubeconfig=kubeconfig.yaml get svc -n argocd
# Should show ArgoCD service with external IP or NodePort

# Test Kafka access (after configuring external listener)
kafka-console-producer --bootstrap-server kafka.yourdomain.tld:9093 --topic test

# SSH to control plane (should work immediately)
ssh root@95.217.X.Y
```

---

## Post-Implementation: Daily Workflow

### **Day 1: Deploy Cluster**
```bash
# GitHub Actions → Deploy K3s Cluster → dev → create
# ✅ Terraform creates 2 Primary IPs (if they don't exist)
# ✅ Terraform attaches Primary IP #1 to control plane
# ✅ SSH succeeds immediately to public IP (no 60 retries!)
# ✅ GitHub Actions assigns Primary IP #2 to kafka-0 (automatic, ~1 min)
# ✅ Strimzi + Kafka cluster deployed
# ✅ ArgoCD installs
# ✅ Access ArgoCD at: https://argocd.yourdomain.tld
```

### **Day 2: Destroy Cluster**
```bash
# GitHub Actions → hcloud-maintenance → dev → destroy-vms
# ✅ All 4 VMs deleted via hcloud CLI (fast!)
# ✅ Primary IPs persist (still billed €1.00/mo)
# ✅ DNS still points to same IPs (no changes needed)
# ✅ No Terraform state to clean up
```

### **Day 3: Redeploy Cluster**
```bash
# GitHub Actions → Deploy K3s Cluster → dev → create
# ✅ Terraform finds existing Primary IPs by name (k3s-trading-dev-control-ip, k3s-trading-dev-kafka-ip)
# ✅ Reuses same Primary IPs (95.217.X.Y, 95.217.A.B)
# ✅ GitHub Actions assigns Primary IP #2 to new kafka-0
# ✅ ArgoCD accessible at same URL
# ✅ Kafka accessible at same URL
# ✅ No manual steps needed!
```

---

## Rollback Plan

If something goes wrong:

1. **Revert Terraform changes**:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

2. **Delete Primary IPs via maintenance script** (to stop billing):
   ```bash
   # GitHub Actions → hcloud-maintenance → dev → destroy-all
   # This deletes both VMs and Primary IPs
   ```

3. **Or delete manually via hcloud CLI**:
   ```bash
   hcloud primary-ip list -l environment=dev
   hcloud primary-ip delete <primary-ip-1-id>
   hcloud primary-ip delete <primary-ip-2-id>
   ```

**Note**: Primary IPs are billed monthly, so you'll pay €1.00 for the month even if deleted mid-month.

**If Terraform fails to find existing Primary IPs:**
- Check name matches: `k3s-trading-{env}-control-ip`, `k3s-trading-{env}-kafka-ip`
- Verify datacenter matches: `nbg1-dc3`
- Delete and recreate Primary IPs if names/datacenters don't match

**Note**: Primary IPs are billed monthly, so you'll pay €1.00 for the month even if deleted mid-month.

---

## Success Criteria

### Must Pass

- [ ] GitHub Actions SSH connects on first attempt (not 60 retries)
- [ ] GitHub Actions automatically assigns Primary IP #2 to kafka-0 (no manual steps)
- [ ] ArgoCD accessible from internet via Primary IP #1
- [ ] Kafka-0 accessible externally via Primary IP #2
- [ ] Kafka-1, Kafka-2 remain private (no public IPv4, only IPv6)
- [ ] Terraform outputs show public IPs correctly
- [ ] Total IPv4 cost = €1.00/month
- [ ] Primary IPs persist after VM destruction via `hcloud-maintenance → destroy-vms`
- [ ] Next deployment reuses same IPs automatically

### Nice to Have

- [ ] DNS configured for stable access (argocd.yourdomain.tld, kafka.yourdomain.tld)
- [ ] Maintenance script shows Primary IPs in listing
- [ ] `destroy-all` action deletes Primary IPs with confirmation
- [ ] Documentation updated with new architecture

---

## Cost Analysis: 3 Months of Ephemeral Clusters

**Assumptions**:
- Dev cluster: 2h/day × 22 days = 44h/month
- Prod cluster: 10h/day × 21 days = 210h/month
- 3 months of operation

### Current Approach (Auto-Assigned IPs)

| Month | VM Costs | IPv4 Costs | Total |
|-------|----------|------------|-------|
| 1 | €21.20 | €2.00 | €23.20 |
| 2 | €21.20 | €2.00 | €23.20 |
| 3 | €21.20 | €2.00 | €23.20 |
| **Total** | **€63.60** | **€6.00** | **€69.60** |

### Proposed Approach (Persistent Primary IPs)

| Month | VM Costs | IPv4 Costs | Total |
|-------|----------|------------|-------|
| 1 | €21.20 | €1.00 | €22.20 |
| 2 | €21.20 | €1.00 | €22.20 |
| 3 | €21.20 | €1.00 | €22.20 |
| **Total** | **€63.60** | **€3.00** | **€66.60** |

**3-Month Savings**: €3.00 (13% reduction in IPv4 costs)
**Annual Savings**: €12.00

### Alternative: Floating IP Approach

| Month | VM Costs | IPv4 Costs | Total |
|-------|----------|------------|-------|
| 1 | €21.20 | €5.20 | €26.40 |
| 2 | €21.20 | €5.20 | €26.40 |
| 3 | €21.20 | €5.20 | €26.40 |
| **Total** | **€63.60** | **€15.60** | **€79.20** |

**3-Month Extra Cost vs Proposed**: €12.60
**Annual Extra Cost**: €50.40

---

## Questions & Answers

### Q: Why not use Floating IP if it allows live reassignment?

**A**: For ephemeral clusters (destroyed daily/weekly), live reassignment isn't needed:
- Deployment happens infrequently (1-2 times per week)
- Power cycle for Primary IP assignment takes ~1 minute (acceptable)
- Floating IP costs €4.20/mo extra (€50.40/year) for a feature we don't need
- Persistent Primary IPs are "good enough" and 420% cheaper

### Q: Why not store Terraform state in S3/Terraform Cloud?

**A**: For our ephemeral workflow, it's unnecessary complexity:
- VMs destroyed via hcloud CLI (not `terraform destroy`)
- Primary IPs persist in Hetzner (queryable by name)
- Terraform finds existing resources automatically on each deployment
- No state management overhead
- Simpler CI/CD workflow

### Q: Will GitHub Actions still work after this change?

**A**: Yes, even better:
- **Before**: Returns private IP (10.0.1.10) → 60 SSH retries → timeout ❌
- **After**: Returns public IP (95.217.X.Y) → SSH succeeds on first attempt ✅
- **Bonus**: Primary IP assignment is automatic (no manual steps)

### Q: What happens if we destroy Primary IPs by mistake?

**A**: 
- IPs are released back to Hetzner pool (lost forever)
- New random IPs assigned on next deployment
- DNS must be updated
- Billing stops (pro-rated)
- **Prevention**: 
  - Set `prevent_destroy = true` in Terraform lifecycle
  - Maintenance script requires explicit `destroy-all` action (not default)

### Q: Can we reduce to 1 Primary IP to save €0.50/mo?

**A**: Only if you:
- Give up ArgoCD external access (use kubectl port-forward only), OR
- Give up Kafka external access (internal consumers only)

**Not recommended**: Losing ArgoCD external access complicates GitOps workflow.

### Q: What about IPv6?

**A**: IPv6 is free on Hetzner and enabled by default:
- All VMs get IPv6 automatically (no cost)
- Can be used for internal communication
- Not used for external access (GitHub Actions typically lacks IPv6)
- Keep enabled for future-proofing

### Q: How does Terraform find existing Primary IPs without state?

**A**: Terraform queries Hetzner API by resource name:
- Primary IP names: `k3s-trading-dev-control-ip`, `k3s-trading-dev-kafka-ip`
- On `terraform apply`, Terraform checks if resources exist
- If found: reuses them (import-like behavior)
- If not found: creates new ones
- **Lifecycle `ignore_changes`** prevents Terraform from trying to modify assignments

---

## References

- [Hetzner Primary IPs Documentation](https://docs.hetzner.com/cloud/servers/primary-ips/overview/)
- [Hetzner Floating IPs Documentation](https://docs.hetzner.com/cloud/floating-ips/overview/)
- [Terraform Hetzner Provider - Primary IP Resource](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/primary_ip)
- Current Architecture: `ARCHITECTURE_FINAL_CLEAN.md`

---

## Conclusion

**Recommended Action**: Proceed with Persistent Primary IP implementation

**Reasons**:
1. ✅ Fixes critical SSH timeout bug
2. ✅ Saves €12/year vs current approach
3. ✅ Saves €50/year vs Floating IP approach
4. ✅ Enables ArgoCD external access (required for GitOps)
5. ✅ Stable DNS for professional setup
6. ✅ Low operational overhead (one-time manual step)
7. ✅ Perfect for ephemeral clusters

**Next Steps**:
1. Review this plan thoroughly
2. Confirm approval to proceed
3. Implement Terraform changes
4. Test in dev environment first
5. Deploy to production after validation

---

**Document Version**: 1.0  
**Date**: 2025-11-06  
**Author**: GitHub Copilot  
**Status**: Pending Review
