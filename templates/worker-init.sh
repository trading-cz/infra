#!/bin/bash
set -e

echo "=== K3s Worker Node Initialization ==="
echo "Node IP (private): ${node_ip}"
echo "Cluster endpoint (private): ${k3s_url}"
echo "Node label: ${node_label}"

# Update system and install dependencies
# NOTE: Kafka nodes have ephemeral public IPs during cloud-init
# kafka-0's ephemeral IP will be replaced with Primary IP #2 by GitHub Actions after deployment
apt-get update
apt-get install -y curl

# Wait for control plane to be ready with timeout
echo ""
echo "Waiting for control plane to be ready..."
TIMEOUT=300  # 5 minutes timeout
ELAPSED=0
INTERVAL=10

until curl -k ${k3s_url}/readyz &>/dev/null; do
  if [ $$ELAPSED -ge $$TIMEOUT ]; then
    echo ""
    echo "❌ FATAL ERROR: Control plane not ready after $${TIMEOUT}s"
    echo ""
    echo "Diagnostics:"
    echo "  - K3s URL: ${k3s_url}"
    echo "  - Node IP: ${node_ip}"
    echo "  - Current time: $$(date)"
    echo ""
    echo "Network diagnostics:"
    echo "  - IP address: $$(ip addr show dev eth0 | grep 'inet ' || echo 'N/A')"
    echo "  - Private network: $$(ip addr show dev ens10 | grep 'inet ' || echo 'N/A')"
    echo "  - Default route: $$(ip route | grep default || echo 'N/A')"
    echo "  - DNS servers: $$(cat /etc/resolv.conf | grep nameserver || echo 'N/A')"
    echo ""
    echo "Control plane reachability:"
    echo "  - Ping test: $$(ping -c 3 10.0.1.10 2>&1 | tail -3 || echo 'FAILED')"
    echo "  - Port 6443 test: $$(timeout 3 bash -c '</dev/tcp/10.0.1.10/6443' 2>&1 && echo 'OPEN' || echo 'CLOSED/TIMEOUT')"
    echo ""
    echo "Possible causes:"
    echo "  1. Control plane is still booting (check: hcloud server list)"
    echo "  2. Network connectivity issue between nodes"
    echo "  3. Firewall blocking port 6443 from private network"
    echo "  4. K3s control plane failed to start"
    echo ""
    echo "Next steps:"
    echo "  1. SSH into control plane (10.0.1.10)"
    echo "  2. Check: journalctl -xe -u k3s"
    echo "  3. Check logs: tail -50 /var/log/cloud-init-output.log"
    echo ""
    exit 1
  fi
  
  echo "[$${ELAPSED}/$${TIMEOUT} s] Control plane not ready yet, retrying in $${INTERVAL}s..."
  sleep $$INTERVAL
  ELAPSED=$$((ELAPSED + INTERVAL))
done

echo "✅ Control plane is ready!"
echo ""

# Install K3s agent
echo "Installing K3s agent..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${k3s_version}" K3S_URL="${k3s_url}" K3S_TOKEN="${k3s_token}" sh -s - agent \
  --node-ip="${node_ip}" \
  --node-label="${node_label}"

echo ""
echo "=== K3s Worker Node Ready ==="
echo "Node joined cluster: ${node_ip}"
echo "Next: Control plane will detect this node automatically"
