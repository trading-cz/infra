#!/bin/bash
# Test Kustomize configurations locally before deploying

set -e

echo "=== Testing Kustomize Configurations ==="
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

echo "✅ kubectl found"
echo ""

# Test Dev Environment
echo "📦 Testing Dev Environment..."
echo ""

echo "--- Dev Kafka Configuration ---"
kubectl kustomize kubernetes/overlays/dev/kafka
echo ""

echo "--- Dev Apps Configuration ---"
kubectl kustomize kubernetes/overlays/dev/apps
echo ""

# Test Prod Environment
echo "📦 Testing Prod Environment..."
echo ""

echo "--- Prod Kafka Configuration ---"
kubectl kustomize kubernetes/overlays/prod/kafka
echo ""

echo "--- Prod Apps Configuration ---"
kubectl kustomize kubernetes/overlays/prod/apps
echo ""

echo "✅ All Kustomize configurations validated successfully!"
echo ""
echo "To deploy:"
echo "  Dev:  kubectl apply -k kubernetes/overlays/dev/kafka"
echo "  Prod: kubectl apply -k kubernetes/overlays/prod/kafka"
