#!/bin/bash
set -e

echo "=== K3s Control Plane Initialization ==="
echo "Environment: ${environment}"
echo "Node IP (private): ${node_ip}"
echo "Public IP: ${public_ip}"

# Update system
apt-get update
apt-get install -y curl

# Install K3s server with both private and public IPs in TLS certificate
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${k3s_version}" sh -s - server \
  --token="${k3s_token}" \
  --node-ip="${node_ip}" \
  --advertise-address="${node_ip}" \
  --tls-san="${node_ip}" \
  --tls-san="${public_ip}" \
  --disable=traefik \
  --disable=servicelb \
  --write-kubeconfig-mode=644 \
  --cluster-init

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
until kubectl get nodes &>/dev/null; do
  echo "Waiting for kubectl..."
  sleep 5
done

echo "=== K3s Control Plane Ready ==="
kubectl get nodes

# Wait for worker nodes to join before installing workloads
echo ""
echo "=== Waiting for worker nodes to join cluster ==="
echo "Expected: 3 kafka workers + 1 control plane = 4 nodes total"
TIMEOUT=300
ELAPSED=0
until [ $(kubectl get nodes --no-headers | wc -l) -ge 4 ] || [ $ELAPSED -ge $${TIMEOUT} ]; do
  CURRENT=$(kubectl get nodes --no-headers | wc -l)
  echo "[$ELAPSED/$${TIMEOUT} s] Nodes joined: $CURRENT/4"
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

FINAL_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ $FINAL_COUNT -ge 4 ]; then
  echo "✅ All worker nodes joined! ($FINAL_COUNT nodes total)"
  kubectl get nodes
else
  echo "⚠️  Warning: Only $FINAL_COUNT nodes joined after $${TIMEOUT}s"
  kubectl get nodes
fi

# Taint control plane to prevent regular workloads from scheduling here
echo ""
echo "Adding taint to control plane..."
kubectl taint nodes ${cluster_name}-${environment}-control node-role.kubernetes.io/control-plane=true:NoSchedule --overwrite || true
echo "✅ Control plane tainted - regular workloads will only run on worker nodes"

# =============================================================================
# INSTALL STRIMZI OPERATOR
# =============================================================================
echo ""
echo "=== Installing Strimzi Operator ==="
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

echo "Waiting for Strimzi Operator to be ready..."
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=300s || true

echo "✅ Strimzi Operator installed"
kubectl get pods -n kafka

# =============================================================================
# INSTALL ARGOCD
# =============================================================================
echo ""
echo "=== Installing ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s || true

echo "✅ ArgoCD installed"
kubectl get pods -n argocd

# =============================================================================
# CONFIGURE ARGOCD PARENT APP (App-of-Apps Bootstrap)
# =============================================================================
echo ""
echo "=== Configuring ArgoCD Parent Application ==="

# Determine target revision based on environment
if [ "${environment}" = "prod" ]; then
  TARGET_REVISION="production"
else
  TARGET_REVISION="main"
fi

# Apply parent app that points to config repository
cat <<EOF | kubectl apply -f -
${argocd_parent_app}
EOF

echo "✅ ArgoCD parent application created"
kubectl get applications -n argocd

# =============================================================================
# CREATE APPLICATION NAMESPACES
# =============================================================================
echo ""
echo "=== Creating application namespaces ==="
kubectl create namespace ingestion --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace strategies --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Application namespaces created"

# =============================================================================
# BOOTSTRAP COMPLETE
# =============================================================================
echo ""
echo "========================================="
echo "✅ K3s Cluster Bootstrap Complete!"
echo "========================================="
echo "Installed:"
echo "  - K3s ${k3s_version}"
echo "  - Strimzi Operator (Kafka)"
echo "  - ArgoCD (GitOps)"
echo "  - Parent Application (App-of-Apps)"
echo ""
echo "ArgoCD will now sync applications from:"
echo "  Repository: https://github.com/trading-cz/config.git"
echo "  Branch: $TARGET_REVISION"
echo "  Path: overlays/${environment}/app-of-apps"
echo ""
echo "Monitor deployment:"
echo "  kubectl get applications -n argocd"
echo "  kubectl get kafka -n kafka"
echo "  kubectl get pods -A"
echo "========================================="
