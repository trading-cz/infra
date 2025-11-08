#!/bin/bash
# One-time cleanup script for unlabeled resources
# Run this via GitHub Actions or manually with hcloud CLI

set -euo pipefail

ENV="${1:-dev}"

echo "==========================================="
echo "  Manual Cleanup of Unlabeled Resources"
echo "==========================================="
echo ""
echo "⚠️  This will DELETE resources by NAME pattern:"
echo "   - SSH keys matching: ${ENV}-k3s-trading-*"
echo "   - Networks matching: ${ENV}-k3s-trading-*"
echo "   - Firewalls matching: ${ENV}-k3s-trading-*"
echo ""
echo "Sleeping 5 seconds... (Ctrl+C to cancel)"
sleep 5

# Delete SSH keys by name pattern
echo "Checking for SSH keys..."
mapfile -t SSHKEYS < <(
  hcloud ssh-key list -o noheader -o columns=id,name | grep "${ENV}-k3s-trading" | awk '{print $1}' || true
)
if [ ${#SSHKEYS[@]} -gt 0 ]; then
  echo "Deleting ${#SSHKEYS[@]} SSH keys..."
  for key_id in "${SSHKEYS[@]}"; do
    hcloud ssh-key delete "$key_id"
    echo "  ✅ Deleted SSH key $key_id"
  done
else
  echo "  No SSH keys found"
fi

# Delete networks by name pattern
echo "Checking for networks..."
mapfile -t NETS < <(
  hcloud network list -o noheader -o columns=id,name | grep "${ENV}-k3s-trading" | awk '{print $1}' || true
)
if [ ${#NETS[@]} -gt 0 ]; then
  echo "Deleting ${#NETS[@]} networks..."
  for net_id in "${NETS[@]}"; do
    hcloud network delete "$net_id"
    echo "  ✅ Deleted network $net_id"
  done
else
  echo "  No networks found"
fi

# Delete firewalls by name pattern
echo "Checking for firewalls..."
mapfile -t FWS < <(
  hcloud firewall list -o noheader -o columns=id,name | grep "${ENV}-k3s-trading" | awk '{print $1}' || true
)
if [ ${#FWS[@]} -gt 0 ]; then
  echo "Deleting ${#FWS[@]} firewalls..."
  for fw_id in "${FWS[@]}"; do
    hcloud firewall delete "$fw_id"
    echo "  ✅ Deleted firewall $fw_id"
  done
else
  echo "  No firewalls found"
fi

echo ""
echo "==========================================="
echo "✅ Manual Cleanup Complete!"
echo "==========================================="
echo "You can now run terraform apply without conflicts"
