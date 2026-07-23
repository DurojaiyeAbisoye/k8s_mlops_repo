#!/usr/bin/env bash
set -euo pipefail

# Remove optional components that are commented out from the root bootstrap.
# This only removes the optional Argo CD Applications and namespaces that are not part of the core deploy.

OPTIONAL_NAMESPACES=(
  kubeflow-workspaces
)

# Delete optional Argo CD Applications if they exist.
for app in \
  hub-csi \
  hub-registry \
  workspaces-backend \
  workspaces-controller \
  workspaces-frontend \
  prometheus \
  grafana; do
  if kubectl get application "$app" -n argocd >/dev/null 2>&1; then
    echo "Deleting Argo CD Application $app"
    kubectl delete application "$app" -n argocd --ignore-not-found=true
  fi
done

# Best-effort namespace deletion for optional namespaces.
for ns in "${OPTIONAL_NAMESPACES[@]}"; do
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    echo "Deleting namespace $ns"
    kubectl delete namespace "$ns" --ignore-not-found=true --wait=false
  fi
done

echo "Optional component cleanup requested."
echo "If Argo CD is managing these resources, wait for the app sync to converge and confirm the resources are gone."
