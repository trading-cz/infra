# Copilot Instructions: K3s Trading Infrastructure

## Project Identity

**Repository**: `trading-cz/infra` (Branch: `main` for dev, `production` for prod)  
**Purpose**: Ephemeral K3s clusters on Hetzner Cloud for algorithmic trading  
**Architecture**: Cost-optimized (58% savings), persistent IPs, ephemeral VMs  
**Stack**: K3s v1.34.1+k3s1, Kafka 4.0.0 (Strimzi), Terraform v1.13.4

### Core Concept
- Deploy K3s clusters during trading hours (2-10h/day)
- Destroy VMs after hours → massive cost savings
- Persistent Primary IPs (€1/month) maintain stable DNS
- Kafka streaming pipeline: market data → trading strategies

---

## Technology Stack

- **IaC**: Terraform v1.13.4 (modular: network, compute, k3s)
- **Kubernetes**: K3s v1.34.1+k3s1
- **Message Broker**: Kafka 4.0.0 (Strimzi, KRaft mode)
- **Cloud**: Hetzner (Nuremberg), cx23 VMs (2 vCPU, 4GB RAM)

---

## Architecture (2 nodes for start)

```
k3s-control (cx23): Primary IP #1 + 10.0.1.10
├─ K3s control plane, ArgoCD, Python apps
└─ Firewall: disabled (testing)

kafka-0 (cx23): Primary IP #2 + 10.0.1.20
├─ Kafka broker
└─ External Kafka access via NodePort 33333

```

**Kafka Listeners**:
- Internal (9092): `trading-cluster-kafka-bootstrap.kafka:9092` (pod access)
- External (33333): `<kafka-0-ip>:33333` (internet access via NodePort)

**Why 1 Kafka brokers?** only for testing

---

## Repository Structure

```
root/
├── versions.tf                        # Terraform & provider versions
├── main.tf                            # Root module orchestration
├── variables.tf                       # Variable declarations
├── outputs.tf                         # Output definitions
├── environments/{dev,prod}.tfvars     # Environment-specific configs
├── modules/
│   ├── network/       # VPC, subnet, firewall
│   ├── k3s-server/    # K3s control plane + ArgoCD
│   └── kafka-server/  # Kafka nodes (Strimzi ready)
└── templates/*.sh     # Cloud-init bootstrap scripts

.github/workflows/
├── hcloud-maintenance.yml    # list|destroy-cluster|destroy-all
└── megalinter-terraform.yml  # linter for PR review
```

---

## Key Workflows

### Deploy Cluster (GitHub Actions)
**Trigger**: Actions → Deploy K3s Cluster  
**Inputs**: environment (dev|prod)  
**Secrets**: `HCLOUD_TOKEN`, `SSH_PRIVATE_KEY`, `SSH_PUBLIC_KEY`

**Steps** (~10 min):
1. Terraform creates/reuses network, Primary IPs, 4 VMs
2. Attaches Primary IP #1 to control plane (Terraform)
3. Assigns Primary IP #2 to kafka-0 (hcloud CLI)
4. Cloud-init installs K3s on all nodes
5. Deploys Strimzi + Kafka cluster
6. Outputs kubeconfig artifact

### Destroy Cluster (Daily)
**Trigger**: Actions → hcloud-maintenance  
**Actions**:
- `destroy-cluster`: Delete VMs, keep Primary IPs (recommended)
- `destroy-all`: Delete everything including IPs (permanent shutdown)
- `list`: Show all resources

---

## Configuration

### GitHub Actions Environment Variables
Credentials passed via `TF_VAR_*` environment variables:
- `TF_VAR_hcloud_token`: Set from `${{ secrets.HCLOUD_TOKEN }}`
- `TF_VAR_ssh_public_key`: Set from `${{ secrets.SSH_PUBLIC_KEY }}`

### Required GitHub Secrets
- `HCLOUD_TOKEN`: Hetzner API token (Read & Write permissions)
- `SSH_PUBLIC_KEY`: ED25519 public key (generate: `ssh-keygen -t ed25519 -f ./id_ed25519 -N ""`)
- `SSH_PRIVATE_KEY`: ED25519 private key (optional, for SSH access from workflows)

### Kafka Config (kafka-cluster.yaml)
```yaml
version: 4.0.0
replicas: 3  # KRaft quorum minimum
listeners:
  - name: plain, port: 9092, type: internal
  - name: external, port: 9094, type: nodeport, nodePort: 33333
```

**Primary IP Not Assigned**: Check GitHub Actions logs → "Assign Primary IP to kafka-0"
```bash
hcloud server poweroff <kafka-0-id>
hcloud primary-ip assign <ip-id> <server-id>
hcloud server poweron <kafka-0-id>
```
---

## Development Guidelines

**Terraform**:
- Always run local validation before committing (see checklist above)
- Never run `terraform destroy` manually (use hcloud-maintenance workflow)
- Update both dev.tfvars and prod.tfvars when changing infrastructure
- Test in dev environment first
- Commit `.terraform.lock.hcl` to version control
- Keep credentials in environment variables (TF_VAR_*), never in .tfvars files

Example: Remove-Item -Recurse -Force .terraform, .terraform.lock.hcl -ErrorAction SilentlyContinue; C:\projects\apps\terraform_1.13.4\terraform.exe init

**Kafka**:
- Internal: trading-cluster-kafka-bootstrap.kafka:9092
- External: <kafka-0-ip>:33333

---

## Local Validation Checklist

Before committing Terraform changes, always run terraform from: C:\projects\apps\terraform_1.13.4

### Step 1: Initialize Terraform
```powershell
# Clean initialization (if provider versions changed)
Remove-Item -Recurse -Force .terraform, .terraform.lock.hcl -ErrorAction SilentlyContinue
terraform.exe init
```

**What `terraform init` does:**
- ✅ Downloads providers (hetznercloud/hcloud ~> 1.54)
- ✅ Initializes backend (local state file)
- ✅ Loads modules (network, k3s-server, kafka-server)
- ✅ Creates `.terraform.lock.hcl` (commit this file!)

### Step 2: Format Code
```powershell
# Check if formatting is needed (CI/CD will fail if not formatted)
terraform.exe fmt -check -recursive

# Auto-format all files
terraform.exe fmt -recursive
```

### Step 3: Validate Configuration
```powershell
# Validate syntax, schemas, module dependencies
terraform.exe validate
```

**What `terraform validate` checks:**
- ✅ Terraform syntax (.tf files)
- ✅ Resource schemas (required args, valid types)
- ✅ Template variables in `templatefile()` calls
- ✅ Module dependencies
- ❌ Does NOT need environment variables (TF_VAR_*)
- ❌ Does NOT need backend/state
- ❌ Does NOT render templates with actual values

### Step 4: Plan (Optional - requires credentials)
```powershell
# Set credentials
$env:TF_VAR_hcloud_token = "your-token-here"
$env:TF_VAR_ssh_public_key = "ssh-ed25519 AAAAC3..."

# Plan with dev environment
terraform.exe plan -var-file="environments/dev.tfvars"
command line example:
$env:TF_VAR_hcloud_token = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; $env:TF_VAR_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI dummy-key"; $env:TF_VAR_control_plane_primary_ip_id = "12345"; $env:TF_VAR_kafka_primary_ip_id = "67890"; C:\projects\apps\terraform_1.13.4\terraform.exe plan -var-file="environments/dev.tfvars"
```

**Complete Local Validation Script:**
```powershell
# Run all checks
C:\projects\apps\terraform_1.13.4\terraform.exe fmt -recursive
C:\projects\apps\terraform_1.13.4\terraform.exe validate

# If validation passes, commit changes
git add .
git commit -m "terraform: update configuration"
```

**Template Variable Escaping** (for shell scripts):
- Terraform variables: `${variable_name}` (single $)
- Bash variables: `$$VARIABLE_NAME` (double $$ = literal $ in output)