#!/bin/bash
# Validate Terraform configurations locally

set -e

cd "$(dirname "$0")/../terraform"

echo "=== Validating Terraform Configurations ==="
echo ""

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform first."
    exit 1
fi

echo "✅ Terraform found: $(terraform version | head -n1)"
echo ""

# Initialize
echo "📦 Initializing Terraform..."
terraform init -backend=false
echo ""

# Validate
echo "🔍 Validating Terraform syntax..."
terraform validate
echo ""

# Format check
echo "📝 Checking Terraform formatting..."
if terraform fmt -check -recursive; then
    echo "✅ All files are properly formatted"
else
    echo "⚠️  Some files need formatting. Run: terraform fmt -recursive"
fi
echo ""

echo "✅ Terraform validation completed successfully!"
echo ""
echo "To apply locally (not recommended, use GitHub Actions):"
echo "  terraform plan -var-file=environments/dev.tfvars"
