#!/usr/bin/env bash
set -euo pipefail

# Tear down the Argo CD Applications that come from this repository,
# while leaving Helm-managed namespaces and MLflow intact.
#
# This script:
# 1. Deletes the repo-managed Argo CD Application resources.
# 2. Removes the repo-managed namespaces that are safe to delete.
# 3. Deletes workloads in the repo-managed namespaces if they are still present.
#
# IMPORTANT: review the list carefully before running in a shared cluster.

REPO_MANAGED_APPS=(
  admission-webhook
  central-dashboard
  cert-manager
  cert-manager-base
  cluster-local-gateway
  dex
  istio
  istio-crds
  istio-namespace
  jupyter-web-app
  katib
  knative
  kserve
  kubeflow
  kubeflow-istio-resources
  kubeflow-ns
  kubeflow-roles
  models-web-app
  notebook-controller
  oauth2-proxy
  pipeline
  profiles
  pvcviewer-controller
  tensorboard-controller
  tensorboards-web-app
  trainer
  training-operator
  user-profiles
  volumes-web-app
)

REPO_MANAGED_NAMESPACES=(
  auth
  cert-manager
  istio-system
  knative-serving
  kubeflow
  kubeflow-system
  oauth2-proxy
)

for app in "${REPO_MANAGED_APPS[@]}"; do
  if kubectl get application "$app" -n argocd >/dev/null 2>&1; then
    echo "Deleting Argo CD Application $app"
    kubectl delete application "$app" -n argocd --ignore-not-found=true
  fi
done

for ns in "${REPO_MANAGED_NAMESPACES[@]}"; do
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    echo "Deleting namespace $ns"
    kubectl delete namespace "$ns" --ignore-not-found=true --wait=false
  fi
done

# Leave MLflow and Helm-managed namespaces alone.
echo "Teardown requested for repo-managed applications and namespaces."
echo "MLflow was intentionally not included."
echo "Helm-managed namespaces were intentionally not included."
