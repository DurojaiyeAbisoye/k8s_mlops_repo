#!/usr/bin/env bash
set -euo pipefail

# Tear down the repo-managed Argo CD applications and namespaces,
# then recreate them from the repository by applying the root bootstrap.
#
# This intentionally leaves MLflow and Helm-managed namespaces alone.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/kustomization.yaml" ]]; then
  echo "Could not find kustomization.yaml in $ROOT_DIR" >&2
  exit 1
fi

echo "Tearing down repo-managed applications and namespaces..."
"$ROOT_DIR/scripts/teardown-repo-managed.sh"

echo "Waiting a few seconds for the teardown to settle..."
sleep 10

echo "Applying the repo bootstrap again..."
if command -v kubectl >/dev/null 2>&1; then
  kubectl apply -f "$ROOT_DIR/kubeflow.yaml" >/dev/null 2>&1 || true
  kubectl apply -f "$ROOT_DIR/argocd-apps" >/dev/null 2>&1 || true
else
  echo "kubectl is not available" >&2
  exit 1
fi

echo "Rebuild requested."
echo "If Argo CD is managing these resources, wait for the app sync to converge."
