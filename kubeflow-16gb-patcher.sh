#!/bin/bash
# =============================================================================
# kubeflow-16gb-patcher.sh
# =============================================================================
# Patches the Kubeflow Community Distribution manifests to add conservative
# resource requests/limits suitable for a 16 GB single-node cluster.
# Run this from the repo root: ~/Documents/mlops_platform/community-distribution-26.03.1
# =============================================================================

set -euo pipefail

REPO_ROOT="$(pwd)"
PATCH_DIR="${REPO_ROOT}/patches/16gb-laptop"

mkdir -p "${PATCH_DIR}"

echo "=== Creating reusable resource patch files ==="

# --- Tiny tier: 25m / 64Mi request, 200m / 128Mi limit ---
cat > "${PATCH_DIR}/tiny-resources.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-used
spec:
  template:
    spec:
      containers:
      - name: '*'
        resources:
          requests:
            cpu: 25m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
EOF

# --- Small tier: 50m / 128Mi request, 500m / 256Mi limit ---
cat > "${PATCH_DIR}/small-resources.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-used
spec:
  template:
    spec:
      containers:
      - name: '*'
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
EOF

# --- Medium tier: 100m / 256Mi request, 1000m / 512Mi limit ---
cat > "${PATCH_DIR}/medium-resources.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-used
spec:
  template:
    spec:
      containers:
      - name: '*'
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 512Mi
EOF

# --- StatefulSet medium tier ---
cat > "${PATCH_DIR}/medium-sts-resources.yaml" <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: not-used
spec:
  template:
    spec:
      containers:
      - name: '*'
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 512Mi
EOF

echo "=== Patching component kustomization.yaml files ==="

# Helper: add patch to kustomization.yaml if not already present
add_patch() {
  local file="$1"
  local patch_file="$2"
  local target_name="$3"
  local target_kind="${4:-Deployment}"

  if [ ! -f "$file" ]; then
    echo "  SKIP: $file not found"
    return
  fi

  if grep -q "$(basename "$patch_file")" "$file" 2>/dev/null; then
    echo "  SKIP: already patched: $file"
    return
  fi

  # Check if file has patches section
  if grep -q "^patches:" "$file" 2>/dev/null || grep -q "patches:" "$file" 2>/dev/null; then
    # Append to existing patches
    cat >> "$file" <<EOF
  - path: ${PATCH_DIR/$REPO_ROOT/.}/$(basename "$patch_file")
    target:
      kind: ${target_kind}
      name: ${target_name}
EOF
  else
    # Add patches section
    cat >> "$file" <<EOF

patches:
  - path: ${PATCH_DIR/$REPO_ROOT/.}/$(basename "$patch_file")
    target:
      kind: ${target_kind}
      name: ${target_name}
EOF
  fi
  echo "  PATCHED: $file"
}

# --- ArgoCD ---
add_patch "applications/argocd/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "argocd-server"
add_patch "applications/argocd/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "argocd-repo-server"
add_patch "applications/argocd/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "argocd-dex-server"
add_patch "applications/argocd/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "argocd-redis"
add_patch "applications/argocd/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "argocd-applicationset-controller"
add_patch "applications/argocd/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "argocd-notifications-controller"
add_patch "applications/argocd/kustomization.yaml" "${PATCH_DIR}/medium-sts-resources.yaml" "argocd-application-controller" "StatefulSet"

# --- Istio ---
add_patch "common/istio/istio-install/base/kustomization.yaml" "${PATCH_DIR}/medium-resources.yaml" "istiod"
add_patch "common/istio/istio-install/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "istio-ingressgateway"
add_patch "common/istio/cluster-local-gateway/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "cluster-local-gateway"

# --- Knative ---
add_patch "common/knative/knative-serving/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "activator"
add_patch "common/knative/knative-serving/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "autoscaler"
add_patch "common/knative/knative-serving/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "controller"
add_patch "common/knative/knative-serving/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "webhook"
add_patch "common/knative/knative-serving/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "net-istio-controller"
add_patch "common/knative/knative-serving/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "net-istio-webhook"

# --- Dex ---
add_patch "common/dex/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "dex"

# --- Cert-manager ---
add_patch "common/cert-manager/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "cert-manager"
add_patch "common/cert-manager/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "cert-manager-cainjector"
add_patch "common/cert-manager/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "cert-manager-webhook"

# --- Katib ---
add_patch "applications/katib/upstream/installs/katib-with-kubeflow/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "katib-controller"
add_patch "applications/katib/upstream/installs/katib-with-kubeflow/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "katib-db-manager"
add_patch "applications/katib/upstream/installs/katib-with-kubeflow/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "katib-mysql"
add_patch "applications/katib/upstream/installs/katib-with-kubeflow/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "katib-ui"

# --- KServe ---
add_patch "applications/kserve/kserve/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "kserve-controller-manager"
add_patch "applications/kserve/models-web-app/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "kserve-models-web-app"

# --- Kubeflow Pipelines ---
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/medium-resources.yaml" "ml-pipeline"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "ml-pipeline-ui"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "ml-pipeline-persistenceagent"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "ml-pipeline-scheduledworkflow"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "ml-pipeline-viewer-crd"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "ml-pipeline-visualizationserver"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "cache-server"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "cache-deployer-deployment"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/medium-sts-resources.yaml" "mysql" "StatefulSet"

# --- Metadata ---
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "metadata-envoy-deployment"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "metadata-grpc-deployment"
add_patch "applications/pipeline/upstream/base/installs/multi-user/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "metadata-writer"

# --- Notebooks & UI ---
add_patch "applications/notebooks-v1/upstream/jupyter-web-app/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "jupyter-web-app-deployment"
add_patch "applications/notebooks-v1/upstream/notebook-controller/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "notebook-controller-deployment"
add_patch "applications/notebooks-v1/upstream/volumes-web-app/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "volumes-web-app-deployment"
add_patch "applications/notebooks-v1/upstream/tensorboards-web-app/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "tensorboards-web-app-deployment"
add_patch "applications/notebooks-v1/upstream/tensorboard-controller/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "tensorboard-controller-deployment"
add_patch "applications/notebooks-v1/upstream/pvcviewer-controller/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "pvcviewer-controller-manager"

# --- Profiles & Dashboard ---
add_patch "applications/dashboard/upstream/centraldashboard/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "centraldashboard"
add_patch "applications/dashboard/upstream/profile-controller/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "profiles-deployment"
add_patch "applications/dashboard/upstream/poddefaults-webhooks/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "poddefaults-webhook-deployment"

# --- Training ---
add_patch "applications/training-operator/upstream/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "training-operator"
add_patch "applications/trainer/upstream/base/kustomization.yaml" "${PATCH_DIR}/small-resources.yaml" "kubeflow-trainer-controller-manager"
add_patch "applications/trainer/upstream/base/kustomization.yaml" "${PATCH_DIR}/tiny-resources.yaml" "llmisvc-controller-manager"

# --- MLflow (plain YAML, patch directly) ---
if [ -f "applications/mlflow/deployment.yaml" ]; then
  if ! grep -q "resources:" "applications/mlflow/deployment.yaml"; then
    # Use yq if available, otherwise warn
    if command -v yq &> /dev/null; then
      yq -i '.spec.template.spec.containers[0].resources.requests.cpu = "50m"' applications/mlflow/deployment.yaml
      yq -i '.spec.template.spec.containers[0].resources.requests.memory = "256Mi"' applications/mlflow/deployment.yaml
      yq -i '.spec.template.spec.containers[0].resources.limits.cpu = "500m"' applications/mlflow/deployment.yaml
      yq -i '.spec.template.spec.containers[0].resources.limits.memory = "512Mi"' applications/mlflow/deployment.yaml
      echo "  PATCHED: applications/mlflow/deployment.yaml"
    else
      echo "  WARN: yq not installed. Skipping mlflow/deployment.yaml manual patch."
      echo "       Install yq and re-run, or patch manually."
    fi
  else
    echo "  SKIP: mlflow/deployment.yaml already has resources"
  fi
fi

echo ""
echo "=== Patching replica counts in key components ==="

# Helper to add replicas patch
add_replicas_patch() {
  local file="$1"
  local name="$2"
  local replicas="$3"
  local kind="${4:-Deployment}"

  if [ ! -f "$file" ]; then
    return
  fi

  if grep -q "replicas-${name}" "$file" 2>/dev/null; then
    return
  fi

  cat >> "$file" <<EOF
  - patch: |-
      apiVersion: apps/v1
      kind: ${kind}
      metadata:
        name: ${name}
      spec:
        replicas: ${replicas}
    target:
      kind: ${kind}
      name: ${name}
EOF
  echo "  REPLICAS PATCHED: $file -> $name=$replicas"
}

# Add replica patches to key kustomization files
add_replicas_patch "common/istio/istio-install/base/kustomization.yaml" "istio-ingressgateway" 1
add_replicas_patch "common/istio/cluster-local-gateway/base/kustomization.yaml" "cluster-local-gateway" 1
add_replicas_patch "common/dex/base/kustomization.yaml" "dex" 1

echo ""
echo "=== Done. Review changes with: git diff ==="
echo "=== Then commit and push so ArgoCD picks them up ==="
