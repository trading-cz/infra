# Terraform Modularization: K3s Trading Infrastructure

## 🏗️ Modular Structure

This Terraform setup is fully modular. All cloud resources are managed via modules for network, compute, K3s, and Kafka. Environment-specific variables are in `environments/`, and VM initialization scripts are in `templates/`.

```
terraform/
├── main.tf, variables.tf, outputs.tf, versions.tf
├── modules/
│   ├── network/   # Networking (VPC, subnets, firewall)
│   ├── compute/   # VMs, SSH keys
│   ├── k3s/       # K3s cluster resources
│   └── kafka/     # Kafka cluster (future)
├── environments/
│   ├── dev.tfvars
│   └── prod.tfvars
└── templates/     # VM initialization scripts
```

All changes are validated by CI/CD review gates for Terraform format, lint, and config validity before deployment.

## Overview
This directory contains the modular Terraform setup for ephemeral K3s clusters on Hetzner Cloud, supporting Kafka-based trading pipelines. All infrastructure is managed via modules for clarity and maintainability.

## Directory Structure
- `main.tf` / `variables.tf` / `outputs.tf` / `versions.tf`: Compose modules and manage shared config.
- `modules/`
  - `network/`: Networking resources (VPC, subnets, firewall)
  - `compute/`: VM resources (control plane, Kafka nodes, SSH keys)
  - `k3s/`: K3s cluster resources (user data, readiness, cluster config)
  - `kafka/`: (Optional) Kafka cluster resources
- `environments/`
  - `dev.tfvars`: Dev environment variables
  - `prod.tfvars`: Prod environment variables
- `templates/`: Initialization scripts for VMs

## Usage
1. **Set environment variables:**
   - `TF_VAR_hcloud_token` (Hetzner API token)
   - `TF_VAR_ssh_public_key` (SSH public key)
   - `TF_VAR_environment` (`dev` or `prod`)
2. **Initialize and validate:**
   ```powershell
   cd terraform
   $env:TF_VAR_hcloud_token = Get-Content -Raw '...path...'; $env:TF_VAR_ssh_public_key = Get-Content -Raw '...path...'; $env:TF_VAR_environment = 'dev';
   C:\projects\apps\terraform_1.13.4\terraform.exe init -backend=false
   C:\projects\apps\terraform_1.13.4\terraform.exe validate
   ```
3. **Apply configuration:**
   ```powershell
   C:\projects\apps\terraform_1.13.4\terraform.exe apply -var-file="environments/dev.tfvars"
   ```
   (Replace with `prod.tfvars` for production)

## Troubleshooting
- Always run `terraform validate` after any change.
- See `MODULARIZATION_PLAN.md` for migration steps and validation requirements.

## CI/CD
- Infrastructure changes are validated and deployed via GitHub Actions.
- Local validation is recommended before pushing.

## Documentation
- See `MODULARIZATION_PLAN.md` for migration status.
- See `../doc/` for technology-specific details.
