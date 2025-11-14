#!/bin/bash

# ====================================================================================
#
#  ArgoCD Health Verification Script
#
#  This script waits for ArgoCD applications to become healthy and, if they fail,
#  collects detailed diagnostic information to help debug deployment issues.
#
#  Usage:
#  export KUBECONFIG=<path-to-kubeconfig>
#  ./verify-argocd-health.sh
#
# ====================================================================================

# --- Configuration ---
# Timeout in seconds to wait for applications to become healthy
APP_HEALTH_TIMEOUT=600
# Time to sleep between checks
SLEEP_INTERVAL=20
# Namespaces
ARGOCD_NS="argocd"
KAFKA_NS="kafka"

# --- Helper Functions ---
print_header() {
  echo "======================================================================"
  echo " $1"
  echo "======================================================================"
}

print_subheader() {
  echo "--- $1 ---"
}

# --- Main Verification Logic ---

# 1. Wait for ArgoCD Server to be ready
print_header "1. Waiting for ArgoCD Server to be Healthy"
if ! kubectl wait --for=condition=healthy --timeout=300s -n $ARGOCD_NS application/argocd >/dev/null 2>&1; then
    echo "⚠️ ArgoCD server application did not become healthy within 5 minutes."
    print_subheader "ArgoCD Server Pods:"
    kubectl get pods -n $ARGOCD_NS
    print_subheader "ArgoCD Server Logs:"
    kubectl logs -n $ARGOCD_NS --selector=app.kubernetes.io/name=argocd-server --tail=100
    # exit 1 # We can still try to get app status
else
    echo "✅ ArgoCD server is healthy."
fi


# 2. Wait for all ArgoCD applications to be Healthy
print_header "2. Waiting for ArgoCD Applications to Sync and become Healthy"
echo "Timeout set to $APP_HEALTH_TIMEOUT seconds."

END_TIME=$((SECONDS + APP_HEALTH_TIMEOUT))

while [ $SECONDS -lt $END_TIME ]; do
  # Get application status, handling the case where no applications are found yet
  APP_STATUS_JSON=$(kubectl get applications.argoproj.io -A -o json 2>/dev/null)
  
  if [ -z "$APP_STATUS_JSON" ] || [ "$(echo "$APP_STATUS_JSON" | jq '.items | length')" -eq 0 ]; then
      echo "⏳ No ArgoCD applications found yet. Waiting..."
      sleep $SLEEP_INTERVAL
      continue
  fi

  # Check for non-healthy or non-synced applications
  UNHEALTHY_APPS=$(echo "$APP_STATUS_JSON" | jq -r '.items[] | select(.status.health.status != "Healthy" or .status.sync.status != "Synced") | .metadata.name')

  if [ -z "$UNHEALTHY_APPS" ]; then
    print_header "✅ All ArgoCD Applications are Healthy and Synced"
    kubectl get applications.argoproj.io -A -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status,PROJECT:.spec.project,DESTINATION:.spec.destination.server
    exit 0
  fi

  echo "----------------------------------------------------------------------"
  echo "⏳ Waiting for applications to become Healthy. The following are not ready:"
  echo "$UNHEALTHY_APPS"
  echo ""
  kubectl get applications.argoproj.io -A -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status
  
  REMAINING_TIME=$((END_TIME - SECONDS))
  echo "Retrying in $SLEEP_INTERVAL seconds... ($REMAINING_TIME seconds remaining)"
  sleep $SLEEP_INTERVAL
done

# --- Timeout Reached: Collect Debug Information ---

print_header "❌ TIMEOUT: Not all applications became healthy within $APP_HEALTH_TIMEOUT seconds."

# Get final status
print_subheader "Final Application Status"
kubectl get applications.argoproj.io -A -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status,REVISION:.status.sync.revision,PROJECT:.spec.project

# Detailed analysis for each unhealthy app
UNHEALTHY_APPS_FINAL=$(kubectl get applications.argoproj.io -A -o json | jq -r '.items[] | select(.status.health.status != "Healthy") | .metadata.name')

for APP in $UNHEALTHY_APPS_FINAL; do
  NS=$(kubectl get applications.argoproj.io $APP -o json | jq -r .spec.destination.namespace)
  print_header "🔍 Debugging Application: $APP (in namespace: $NS)"

  print_subheader "ArgoCD Application Tree"
  argocd app get $APP --show-tree

  print_subheader "ArgoCD Application Details"
  argocd app get $APP

  print_subheader "Kubernetes Events in Namespace '$NS'"
  kubectl get events -n $NS --sort-by='.lastTimestamp' | tail -n 25
  
  print_subheader "Pods in Namespace '$NS'"
  kubectl get pods -n $NS -o wide
  
  # Specific checks for Kafka
  if [[ "$APP" == *"kafka"* ]]; then
    print_subheader "Strimzi Operator Logs (in namespace: $ARGOCD_NS)"
    kubectl logs -n $ARGOCD_NS --selector=name=strimzi-cluster-operator --tail=100
    
    print_subheader "Kafka Custom Resource (CR) in '$KAFKA_NS'"
    kubectl get kafka -n $KAFKA_NS -o yaml
    
    print_subheader "Kafka Pod Logs in '$KAFKA_NS'"
    # Get logs from the first kafka pod found
    KAFKA_POD=$(kubectl get pods -n $KAFKA_NS -l strimzi.io/cluster=trading-cluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$KAFKA_POD" ]; then
      kubectl logs $KAFKA_POD -n $KAFKA_NS --tail=100
    else
      echo "No Kafka pods found to retrieve logs from."
    fi

    print_subheader "Persistent Volume Claims (PVCs) in '$KAFKA_NS'"
    kubectl get pvc -n $KAFKA_NS
  fi
done

exit 1
