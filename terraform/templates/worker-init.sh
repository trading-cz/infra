#!/bin/bash
set -e

echo "=== K3s Worker Node Initialization ==="
echo "Node IP: ${node_ip}"
echo "Joining cluster at: ${k3s_url}"

# Update system
apt-get update
apt-get install -y curl

# Wait for control plane to be ready
echo "Waiting for control plane to be ready..."
until curl -k ${k3s_url}/readyz &>/dev/null; do
  echo "Control plane not ready yet, waiting..."
  sleep 10
done

# Install K3s agent
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${k3s_version}" K3S_URL="${k3s_url}" K3S_TOKEN="${k3s_token}" sh -s - agent \
  --node-ip="${node_ip}" \
  --node-label="${node_label}"

echo "=== K3s Worker Node Ready ==="
