#!/bin/bash
set -euo pipefail

echo "=================================================="
echo "ArgoCD Bootstrap - Trading System"
echo "=================================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl get nodes &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster."
    echo "Please set KUBECONFIG or run this script on the control plane node."
    exit 1
fi

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    echo "❌ ArgoCD namespace not found. Please install ArgoCD first."
    echo "ArgoCD should be installed automatically by cloud-init."
    exit 1
fi

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo ""
echo "=================================================="
echo "Step 1: Apply Repository Secret"
echo "=================================================="

if [ ! -f "repository-secret.yaml" ]; then
    echo "❌ repository-secret.yaml not found!"
    echo ""
    echo "Please create it first:"
    echo "  export GITHUB_TOKEN='ghp_your_token_here'"
    echo "  envsubst < repository-secret.yaml.template > repository-secret.yaml"
    echo ""
    echo "Or manually create from template and replace \${GITHUB_TOKEN}"
    exit 1
fi

kubectl apply -f repository-secret.yaml
echo "✅ Repository secret applied"

echo ""
echo "=================================================="
echo "Step 2: Apply Parent Application"
echo "=================================================="

kubectl apply -f parent-app.yaml
echo "✅ Parent application created"

echo ""
echo "=================================================="
echo "Step 3: Verify Deployment"
echo "=================================================="

echo "⏳ Waiting for parent app to sync..."
sleep 5

echo ""
echo "📋 ArgoCD Applications:"
kubectl get applications -n argocd

echo ""
echo "=================================================="
echo "✅ Bootstrap Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Access ArgoCD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Open: https://localhost:8080"
echo ""
echo "2. Get admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "3. Watch applications sync:"
echo "   kubectl get applications -n argocd -w"
echo ""
echo "4. Check pods across namespaces:"
echo "   kubectl get pods -A"
echo ""
