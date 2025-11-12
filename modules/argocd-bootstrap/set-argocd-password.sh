#!/bin/bash
# Set custom ArgoCD admin password
# Usage: ./set-argocd-password.sh <password>

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <password>"
    echo "Example: $0 MySecurePassword123"
    exit 1
fi

PASSWORD="$1"

echo "=================================================="
echo "ArgoCD - Set Custom Admin Password"
echo "=================================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found"
    exit 1
fi

# Check if we can connect
if ! kubectl get namespace argocd &> /dev/null; then
    echo "❌ Cannot access ArgoCD namespace"
    exit 1
fi

echo "⚙️  Generating bcrypt hash for password..."

# Generate bcrypt hash using htpasswd (from apache2-utils package)
if command -v htpasswd &> /dev/null; then
    BCRYPT_HASH=$(htpasswd -nbBC 10 admin "$PASSWORD" | cut -d: -f2)
elif command -v python3 &> /dev/null; then
    # Fallback to Python bcrypt
    BCRYPT_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw('$PASSWORD'.encode('utf-8'), bcrypt.gensalt(rounds=10)).decode('utf-8'))")
else
    echo "❌ Neither htpasswd nor python3 with bcrypt available"
    echo "Install: apt-get install apache2-utils   OR   pip3 install bcrypt"
    exit 1
fi

echo "✅ Password hash generated"
echo ""

# Delete old initial secret
echo "🗑️  Removing initial admin secret..."
kubectl delete secret argocd-initial-admin-secret -n argocd 2>/dev/null || echo "Initial secret already removed"

# Update admin password in argocd-secret
echo "📝 Updating admin password..."
kubectl patch secret argocd-secret -n argocd \
    --type merge \
    -p "{\"stringData\": {\"admin.password\": \"$BCRYPT_HASH\", \"admin.passwordMtime\": \"$(date +%FT%T%Z)\"}}"

echo ""
echo "=================================================="
echo "✅ Admin Password Updated Successfully"
echo "=================================================="
echo ""
echo "Login with:"
echo "  Username: admin"
echo "  Password: $PASSWORD"
echo ""
echo "Note: ArgoCD server may take a few seconds to reload the new credentials"
