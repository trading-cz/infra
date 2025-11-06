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
