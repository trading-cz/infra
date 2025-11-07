# ArgoCD Bootstrap Configuration

This directory contains the ArgoCD parent application template used during cluster bootstrap.

## Purpose

The `parent-app-bootstrap.yaml.tpl` template is used by Terraform's cloud-init script to configure ArgoCD to automatically sync applications from the **config repository** (`trading-cz/config`).

## How It Works

1. **Terraform** provisions infrastructure and VMs
2. **cloud-init** script on control plane:
   - Installs K3s
   - Installs Strimzi Operator
   - Installs ArgoCD
   - Renders this template with environment-specific values
   - Applies the rendered parent app to ArgoCD
3. **ArgoCD** starts syncing from config repository automatically

## Template Variables

- `${environment}`: Environment name (dev|prod)
- `${config_repo_url}`: URL to config repository (https://github.com/trading-cz/config.git)
- `${target_revision}`: Git branch to track (main for dev, production for prod)

## What This Parent App Does

The parent application follows the **App-of-Apps** pattern:
- Points to `overlays/${environment}/app-of-apps/` in the config repo
- That directory contains child Application definitions for:
  - Kafka cluster
  - Alpaca ingestion service  
  - Dummy strategy service
- ArgoCD automatically creates and syncs all child applications

## Repository Split

- **This repo (infra)**: Infrastructure bootstrap only
- **Config repo**: All Kubernetes manifests and Kustomize configs
- **Parent app template**: Lives here because it's part of infrastructure provisioning
- **Child app definitions**: Live in config repo (synced by ArgoCD)
