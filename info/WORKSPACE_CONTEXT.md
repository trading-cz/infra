# Workspace Context

## 1. Project Identity
**Project:** K3s Trading Infrastructure (`trading-cz`)
**Goal:** Ephemeral, cost-optimized Kubernetes cluster for algorithmic trading.
**Philosophy:**
*   **Ephemeral Compute:** VMs are destroyed daily to save costs (running ~2-10h/day).
*   **Persistent State:** Primary IPs and Volumes persist.
*   **Platform vs. Application:** Strict separation between Infrastructure (`infra`) and GitOps Configuration (`config`).

## 2. Architecture
*   **Cloud Provider:** Hetzner Cloud (HCloud) - Nuremberg DC.
*   **Orchestrator:** K3s (Lightweight Kubernetes).
*   **Infrastructure as Code:** Terraform (manages VMs, Network, Firewalls).
*   **GitOps:** ArgoCD (manages Applications, Kafka Clusters).
*   **Streaming:** Kafka (Strimzi Operator).
*   **Ingress:** Traefik (Manually installed via Helm).

### Networking Strategy (Bare Metal Mode)
Since Hetzner Cloud VMs are "bare metal" in Kubernetes terms (no Cloud Controller Manager for LoadBalancers), we use **NodePorts** for external access.
*   **Traefik:** Installed manually via Helm to force `ServiceType=NodePort`.
    *   **HTTP:** NodePort `30080` (Firewall Open).
    *   **HTTPS:** NodePort `30443` (Firewall Open).
    *   **ArgoCD Access:** Uses `Host: argocd.local` header.
        *   *Reason:* Kubernetes Ingress validation forbids IP addresses in the `host` field. We configure the Ingress with `argocd.local` and simulate the DNS resolution by sending the `Host` header in `curl` requests.
*   **Kafka:** Uses NodePorts for external access.
    *   **Bootstrap:** NodePort `30001`.
    *   **Broker-0:** NodePort `30002`.
    *   *Constraint:* Kubernetes NodePorts must be in the range `30000-32767`. Previous attempts to use `33333` failed with "Invalid value" errors from the Strimzi Operator.

### Cluster Topology
*   **Control Plane (`k3s-control`):**
    *   Runs K3s Server, ArgoCD, System Apps.
    *   Has Persistent Primary IP #1.
*   **Worker Nodes (`kafka-0`, etc.):**
    *   Runs Kafka Brokers, Trading Strategies.
    *   `kafka-0` has Persistent Primary IP #2 (for external access).
    *   Internal Network: `10.0.0.0/16`.

## 3. Repository Structure

### `infra/` (The Platform)
*   **Role:** Bootstrapper. Handles the "Chicken" (Cluster + Operators).
*   **Key Files:**
    *   `main.tf`: Terraform entry point.
    *   `.github/workflows/deploy-cluster.yml`: Main orchestration workflow.
    *   `.github/workflows/hcloud-maintenance.yml`: Cleanup workflow (destroy cluster, keep IPs).
    *   `.github/workflows/03-reusable-deploy-argocd.yml`: Installs ArgoCD Operator & Bootstraps instance.
    *   `.github/workflows/05-reusable-verify-access.yml`: Verifies external connectivity (ArgoCD UI + Kafka Broker).

### `config/` (The Application)
*   **Role:** GitOps source of truth. Defines "What runs on the cluster".
*   **Structure:**
    *   `base/`: Base Kustomize configurations (ArgoCD, Dummy App).
    *   `overlays/minimal`: The entry point applied by the `infra` bootstrap workflow.

## 4. Deployment Pipeline (`deploy-cluster.yml`)
The deployment is fully automated and idempotent.

1.  **Verify Clean:** Checks if environment is clean (calls `hcloud-maintenance.yml`).
2.  **Provision (`01-reusable-provision-infra.yml`):**
    *   Terraform creates resources.
    *   Cloud-init installs K3s.
3.  **Verify Cluster (`02-reusable-verify-cluster.yml`):**
    *   Checks Node readiness and connectivity.
4.  **Deploy ArgoCD (`03-reusable-deploy-argocd.yml`):**
    *   Installs ArgoCD Operator (v0.15.0) using **Server-Side Apply**.
    *   Bootstraps ArgoCD instance by applying `config/overlays/minimal` (local checkout).
    *   Waits for ArgoCD Server deployment to be created and available.
5.  **Deploy Strimzi (`04-reusable-deploy-strimzi.yml`):**
    *   Installs Strimzi Cluster Operator.
6.  **Verify Access (`05-reusable-verify-access.yml`):**
    *   Checks ArgoCD UI (HTTPS + Host Header).
    *   Checks Kafka Broker (kcat + NodePort 30002).
    *   Includes "Debug on Failure" logic (SSH port check, CR dumps, logs).
7.  **Auto-Cleanup:**
    *   If any step fails, `hcloud-maintenance.yml` is triggered to destroy the broken cluster immediately.

## 5. Current Status & Known Behaviors
*   **ArgoCD Bootstrap:** Now uses a local checkout of `config` repo with a PAT (`TOKEN_GIT_REPO_CONFIG`) to avoid `git fetch` authentication errors.
*   **CRD Issues:** ArgoCD CRDs are large, requiring `kubectl apply --server-side`.
*   **Race Conditions:** ArgoCD Operator takes time to create deployments; workflows include explicit wait loops.
*   **Verification:** The verification workflow is critical. It performs deep diagnostics (SSH into nodes, checking `ss -tulpn`) if it fails, helping to distinguish between Firewall, K3s, and Application issues.