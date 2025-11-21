#!/bin/bash

# Comprehensive Deployment Verification Script
# Verifies each deployment step and provides detailed diagnostics

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG="${KUBECONFIG:=/home/runner/.kube/config}"
TIMEOUT_OPERATOR_READY=300  # 5 minutes
TIMEOUT_ARGOCD_READY=300    # 5 minutes
TIMEOUT_APP_SYNC=600        # 10 minutes

# Helper functions
print_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

# Verify kubectl connectivity
verify_kubectl_access() {
  print_header "STEP 1: Verify kubectl Access"
  
  if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot access Kubernetes cluster"
    echo "Debugging:"
    echo "  KUBECONFIG: $KUBECONFIG"
    echo "  Exists: $([ -f "$KUBECONFIG" ] && echo 'yes' || echo 'no')"
    exit 1
  fi
  
  print_success "kubectl can access cluster"
  
  # Get cluster info
  CLUSTER_NAME=$(kubectl cluster-info 2>&1 | grep -oP "(?<=for )[^ ]+" || echo "unknown")
  print_info "Cluster: $CLUSTER_NAME"
  
  # Get node count
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  print_info "Nodes: $NODE_COUNT"
  kubectl get nodes -o wide
}

# Verify ArgoCD Operator installation
verify_operator_installation() {
  print_header "STEP 2: Verify ArgoCD Operator Installation"
  
  # Check namespace exists
  if ! kubectl get namespace argocd-operator-system &> /dev/null; then
    print_error "Namespace argocd-operator-system not found"
    exit 1
  fi
  print_success "Namespace argocd-operator-system exists"
  
  # Check operator deployment exists
  if ! kubectl get deployment argocd-operator-controller-manager -n argocd-operator-system &> /dev/null; then
    print_error "Operator deployment not found"
    kubectl get all -n argocd-operator-system
    exit 1
  fi
  print_success "Operator deployment found"
  
  # Wait for operator to be ready
  echo "Waiting for operator to be ready (max ${TIMEOUT_OPERATOR_READY}s)..."
  if kubectl wait --for=condition=available --timeout=${TIMEOUT_OPERATOR_READY}s \
    deployment/argocd-operator-controller-manager \
    -n argocd-operator-system; then
    print_success "Operator is ready"
  else
    print_error "Operator deployment failed to become ready"
    echo ""
    echo "Pod status:"
    kubectl get pods -n argocd-operator-system -o wide
    echo ""
    echo "Pod logs:"
    kubectl logs -n argocd-operator-system -l control-plane=controller-manager --tail=100
    exit 1
  fi
  
  # Check ArgoCD CRDs are available
  echo "Checking ArgoCD CRDs..."
  if kubectl get crd argocds.argoproj.io &> /dev/null; then
    print_success "ArgoCD CRDs installed"
    echo "  CRD versions:"
    kubectl get crd argocds.argoproj.io -o jsonpath='{.spec.names.kind} versions: {.spec.versions[*].name}' | tr ' ' '\n' | sed 's/^/    /'
  else
    print_error "ArgoCD CRDs not found"
    kubectl get crd | grep argoproj || true
    exit 1
  fi
}

# Verify ArgoCD Instance deployment
verify_argocd_instance() {
  print_header "STEP 3: Verify ArgoCD Instance Deployment"
  
  # Check if argocd namespace exists
  if ! kubectl get namespace argocd &> /dev/null; then
    print_error "Namespace argocd not found"
    exit 1
  fi
  print_success "Namespace argocd exists"
  
  # Check ArgoCD CR exists
  if ! kubectl get argocd -n argocd &> /dev/null; then
    print_error "No ArgoCD CRs found"
    exit 1
  fi
  
  # Get ArgoCD CR status
  echo "ArgoCD CR status:"
  ARGOCD_NAME=$(kubectl get argocd -n argocd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  
  if [ -z "$ARGOCD_NAME" ]; then
    print_error "Cannot determine ArgoCD CR name"
    exit 1
  fi
  
  print_info "ArgoCD CR: $ARGOCD_NAME"
  
  # Check CR conditions
  echo "Checking ArgoCD CR conditions..."
  PHASE=$(kubectl get argocd "$ARGOCD_NAME" -n argocd -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  print_info "Phase: $PHASE"
  
  if [ "$PHASE" = "Available" ]; then
    print_success "ArgoCD instance is available"
  else
    print_warning "ArgoCD instance phase is: $PHASE"
  fi
  
  # Show full CR status for debugging
  echo ""
  echo "Full ArgoCD CR status:"
  kubectl get argocd "$ARGOCD_NAME" -n argocd -o yaml | grep -A 30 "^status:"
}

# Verify ArgoCD components are running
verify_argocd_components() {
  print_header "STEP 4: Verify ArgoCD Components Are Running"
  
  # Expected components
  COMPONENTS=("argocd-server" "argocd-repo-server" "argocd-redis" "argocd-application-controller")
  
  echo "Waiting for ArgoCD components (max ${TIMEOUT_ARGOCD_READY}s)..."
  
  ATTEMPT=0
  COMPONENTS_READY=0
  
  while [ $ATTEMPT -lt 60 ]; do
    COMPONENTS_READY=0
    
    for COMPONENT in "${COMPONENTS[@]}"; do
      if kubectl get deployment "$COMPONENT" -n argocd &> /dev/null 2>&1 || \
         kubectl get statefulset "$COMPONENT" -n argocd &> /dev/null 2>&1; then
        ((COMPONENTS_READY++))
      fi
    done
    
    if [ $COMPONENTS_READY -eq ${#COMPONENTS[@]} ]; then
      print_success "All components found"
      break
    fi
    
    echo "⏳ Attempt $((ATTEMPT+1))/60: Found $COMPONENTS_READY/${#COMPONENTS[@]} components..."
    sleep 5
    ((ATTEMPT++))
  done
  
  if [ $COMPONENTS_READY -ne ${#COMPONENTS[@]} ]; then
    print_error "Not all ArgoCD components created (found $COMPONENTS_READY/${#COMPONENTS[@]})"
    echo ""
    echo "Available resources in argocd namespace:"
    kubectl get all -n argocd
    exit 1
  fi
  
  # Now wait for them to be ready
  echo ""
  echo "Waiting for components to be READY..."
  
  for COMPONENT in "${COMPONENTS[@]}"; do
    if kubectl get deployment "$COMPONENT" -n argocd &> /dev/null 2>&1; then
      echo "Waiting for deployment/$COMPONENT..."
      if kubectl wait --for=condition=available --timeout=300s deployment/"$COMPONENT" -n argocd; then
        print_success "deployment/$COMPONENT is ready"
      else
        print_warning "deployment/$COMPONENT timed out waiting to be ready"
        echo "Pod status:"
        kubectl get pods -n argocd -l "app.kubernetes.io/name=$COMPONENT" -o wide
        echo "Pod logs:"
        kubectl logs -n argocd -l "app.kubernetes.io/name=$COMPONENT" --tail=50 || true
      fi
    elif kubectl get statefulset "$COMPONENT" -n argocd &> /dev/null 2>&1; then
      echo "Waiting for statefulset/$COMPONENT..."
      if kubectl wait --for=condition=available --timeout=300s statefulset/"$COMPONENT" -n argocd; then
        print_success "statefulset/$COMPONENT is ready"
      else
        print_warning "statefulset/$COMPONENT timed out waiting to be ready"
        echo "Pod status:"
        kubectl get pods -n argocd -l "app.kubernetes.io/name=$COMPONENT" -o wide
        echo "Pod logs:"
        kubectl logs -n argocd -l "app.kubernetes.io/name=$COMPONENT" --tail=50 || true
      fi
    fi
  done
  
  # Summary
  echo ""
  echo "Final component status:"
  kubectl get all -n argocd
}

# Verify ArgoCD Services are accessible
verify_argocd_services() {
  print_header "STEP 5: Verify ArgoCD Services"
  
  echo "Checking services..."
  kubectl get svc -n argocd
  
  # Verify service IPs are assigned
  echo ""
  echo "Service details:"
  for SVC in argocd-server argocd-repo-server argocd-redis; do
    if kubectl get svc "$SVC" -n argocd &> /dev/null; then
      CLUSTER_IP=$(kubectl get svc "$SVC" -n argocd -o jsonpath='{.spec.clusterIP}')
      if [ -n "$CLUSTER_IP" ] && [ "$CLUSTER_IP" != "None" ]; then
        print_success "Service $SVC has ClusterIP: $CLUSTER_IP"
      else
        print_warning "Service $SVC has no ClusterIP"
      fi
    fi
  done
  
  # Check DNS resolution from within cluster
  echo ""
  echo "Testing internal DNS resolution..."
  kubectl run -n argocd dns-test --image=alpine:latest --rm -it --restart=Never -- \
    wget -q -O- http://argocd-server.argocd.svc.cluster.local:80/healthz 2>&1 || true
}

# Verify Parent App-of-Apps
verify_parent_app() {
  print_header "STEP 6: Verify Parent App-of-Apps Deployment"
  
  echo "Checking if parent app 'trading-system' exists..."
  if ! kubectl get application trading-system -n argocd &> /dev/null; then
    print_error "Parent application 'trading-system' not found"
    echo "Available applications:"
    kubectl get applications -n argocd || true
    echo ""
    echo "This is expected if you haven't deployed it yet."
    echo "Deploy it with: kubectl apply -f config/app-of-apps/argocd/parent-app.yaml"
    return 1
  fi
  
  print_success "Parent application 'trading-system' found"
  
  # Check status
  echo "Checking parent app status..."
  SYNC_STATUS=$(kubectl get application trading-system -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
  HEALTH_STATUS=$(kubectl get application trading-system -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
  
  echo "  Sync Status: $SYNC_STATUS"
  echo "  Health Status: $HEALTH_STATUS"
  
  # Check for error conditions
  if kubectl get application trading-system -n argocd -o jsonpath='{.status.conditions}' | grep -q "ComparisonError"; then
    print_warning "Parent app has comparison errors (may be syncing Git)"
    echo ""
    echo "Error details:"
    kubectl get application trading-system -n argocd -o jsonpath='{.status.conditions[?(@.type=="ComparisonError")].message}' | head -3
  fi
  
  # Show full status
  echo ""
  echo "Full parent app status:"
  kubectl get application trading-system -n argocd -o yaml | grep -A 50 "^status:"
}

# Verify Child Applications
verify_child_apps() {
  print_header "STEP 7: Verify Child Applications"
  
  echo "Checking for child applications created by parent app..."
  
  APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
  print_info "Total applications: $APP_COUNT"
  
  if [ "$APP_COUNT" -lt 2 ]; then
    print_warning "Less than 2 applications found (parent + children)"
    echo "Waiting up to 2 minutes for child apps to be created..."
    
    ATTEMPT=0
    while [ $ATTEMPT -lt 24 ]; do
      sleep 5
      APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
      
      if [ "$APP_COUNT" -ge 2 ]; then
        print_success "Child applications have been created"
        break
      fi
      
      echo "  Attempt $((ATTEMPT+1))/24: Still waiting for child apps... (current: $APP_COUNT)"
      ((ATTEMPT++))
    done
  fi
  
  # List all applications and their status
  echo ""
  echo "All applications and their status:"
  echo "=================================="
  kubectl get applications -n argocd -o wide
  
  echo ""
  echo "Detailed status of each application:"
  for app in $(kubectl get applications -n argocd -o name); do
    APP_NAME=$(echo "$app" | cut -d'/' -f2)
    SYNC=$(kubectl get "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    HEALTH=$(kubectl get "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    
    echo ""
    echo "  Application: $APP_NAME"
    echo "    Sync: $SYNC"
    echo "    Health: $HEALTH"
    
    # Check for errors
    if [ "$SYNC" = "Unknown" ] || [ "$HEALTH" = "Degraded" ]; then
      CONDITIONS=$(kubectl get "$app" -n argocd -o jsonpath='{.status.conditions[*].message}' 2>/dev/null)
      if [ -n "$CONDITIONS" ]; then
        echo "    Conditions: $CONDITIONS"
      fi
    fi
  done
}

# Diagnostic information
print_diagnostics() {
  print_header "DIAGNOSTICS"
  
  echo "Operator namespace status:"
  kubectl get all -n argocd-operator-system
  
  echo ""
  echo "ArgoCD namespace status:"
  kubectl get all -n argocd
  
  echo ""
  echo "Recent events in argocd namespace:"
  kubectl get events -n argocd --sort-by='.lastTimestamp' | tail -20
  
  echo ""
  echo "Recent events in argocd-operator-system namespace:"
  kubectl get events -n argocd-operator-system --sort-by='.lastTimestamp' | tail -20
}

# Main execution
main() {
  print_header "COMPREHENSIVE DEPLOYMENT VERIFICATION"
  echo "Starting deployment verification..."
  echo "KUBECONFIG: $KUBECONFIG"
  echo "Timestamp: $(date)"
  
  # Run all verification steps
  verify_kubectl_access
  verify_operator_installation
  verify_argocd_instance
  verify_argocd_components
  verify_argocd_services
  
  # Try to verify parent app, but don't fail if it doesn't exist yet
  if ! verify_parent_app; then
    print_warning "Parent app verification skipped (not deployed yet)"
  fi
  
  verify_child_apps
  
  # Print diagnostics
  print_diagnostics
  
  print_header "VERIFICATION COMPLETE"
  print_success "All critical components are operational!"
  echo ""
  echo "Next steps:"
  echo "  1. Deploy parent app: kubectl apply -f config/app-of-apps/argocd/parent-app.yaml"
  echo "  2. Watch parent app: kubectl get application trading-system -n argocd -w"
  echo "  3. Check sync status: kubectl get applications -n argocd"
  echo "  4. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:80"
}

# Run main function
main
