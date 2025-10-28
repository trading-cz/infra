#!/bin/bash
# Test App of Apps configuration
# This script validates the app-of-apps kustomization without deploying

set -e

echo "=== Testing App of Apps Configuration ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to test environment
test_environment() {
    local env=$1
    echo -e "${YELLOW}Testing ${env} environment...${NC}"
    
    # Check if kustomization exists
    if [ ! -f "kubernetes/app-of-apps/overlays/${env}/kustomization.yaml" ]; then
        echo -e "${RED}❌ Missing kustomization.yaml for ${env}${NC}"
        return 1
    fi
    
    # Build kustomization
    echo "  Building kustomization..."
    if kubectl kustomize "kubernetes/app-of-apps/overlays/${env}" > "/tmp/app-of-apps-${env}.yaml"; then
        echo -e "${GREEN}  ✅ Kustomize build successful${NC}"
    else
        echo -e "${RED}  ❌ Kustomize build failed${NC}"
        return 1
    fi
    
    # Validate YAML
    echo "  Validating manifests..."
    if kubectl apply --dry-run=client -f "/tmp/app-of-apps-${env}.yaml" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✅ Manifests are valid${NC}"
    else
        echo -e "${RED}  ❌ Manifest validation failed${NC}"
        echo "  Run this to see errors:"
        echo "  kubectl apply --dry-run=client -f /tmp/app-of-apps-${env}.yaml"
        return 1
    fi
    
    # Count resources
    local resource_count=$(grep -c "^kind:" "/tmp/app-of-apps-${env}.yaml" || echo "0")
    echo -e "${GREEN}  ✅ Generated ${resource_count} resources${NC}"
    
    # Show resource types
    echo "  Resource types:"
    grep "^kind:" "/tmp/app-of-apps-${env}.yaml" | sort | uniq -c | sed 's/^/    /'
    
    echo ""
}

# Main tests
echo "Checking prerequisites..."

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ kubectl is installed${NC}"

# Check if we're in the right directory
if [ ! -d "kubernetes/app-of-apps" ]; then
    echo -e "${RED}❌ Not in project root or app-of-apps directory missing${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Found app-of-apps directory${NC}"
echo ""

# Test both environments
test_environment "dev"
test_environment "prod"

# Summary
echo "=== Test Summary ==="
echo -e "${GREEN}✅ All tests passed!${NC}"
echo ""
echo "Generated manifests are in:"
echo "  - /tmp/app-of-apps-dev.yaml"
echo "  - /tmp/app-of-apps-prod.yaml"
echo ""
echo "To deploy:"
echo "  kubectl apply -k kubernetes/app-of-apps/overlays/dev"
echo "  kubectl apply -k kubernetes/app-of-apps/overlays/prod"
echo ""
echo "To see what will be deployed:"
echo "  cat /tmp/app-of-apps-dev.yaml"
echo "  cat /tmp/app-of-apps-prod.yaml"
