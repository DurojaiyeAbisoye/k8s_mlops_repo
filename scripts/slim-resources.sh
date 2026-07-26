#!/bin/bash
set -euo pipefail

echo "=== Slimming requests for 16 GB node ==="

patch_deploy() {
  local ns=$1 name=$2 c=$3 m=$4 lc=$5 lm=$6
  kubectl set resources deployment "$name" -n "$ns" --containers='*' \
    --requests=cpu="$c",memory="$m" \
    --limits=cpu="$lc",memory="$lm" 2>/dev/null && echo "  ✓ $ns/$name" || echo "  ✗ $ns/$name (not found or no containers)"
}

patch_sts() {
  local ns=$1 name=$2 c=$3 m=$4 lc=$5 lm=$6
  kubectl set resources statefulset "$name" -n "$ns" --containers='*' \
    --requests=cpu="$c",memory="$m" \
    --limits=cpu="$lc",memory="$lm" 2>/dev/null && echo "  ✓ $ns/$name" || echo "  ✗ $ns/$name"
}

# --- ArgoCD (keep 1 replica each) ---
kubectl scale deploy argocd-server argocd-repo-server argocd-dex-server \
  argocd-redis argocd-applicationset-controller argocd-notifications-controller \
  -n argocd --replicas=1 2>/dev/null || true
kubectl scale sts argocd-application-controller -n argocd --replicas=1 2>/dev/null || true

patch_deploy argocd argocd-server            50m 128Mi 500m 256Mi
patch_deploy argocd argocd-repo-server       50m 128Mi 500m 256Mi
patch_deploy argocd argocd-dex-server        25m  64Mi 200m 128Mi
patch_deploy argocd argocd-redis             25m  64Mi 200m 128Mi
patch_deploy argocd argocd-applicationset-controller 25m 64Mi 200m 128Mi
patch_deploy argocd argocd-notifications-controller 25m 64Mi 200m 128Mi
patch_sts    argocd argocd-application-controller 100m 256Mi 1000m 512Mi

# --- Istio ---
kubectl scale deploy istio-ingressgateway cluster-local-gateway istiod \
  cluster-jwks-proxy -n istio-system --replicas=1 2>/dev/null || true

patch_deploy istio-system istiod                    100m 256Mi 1000m 512Mi
patch_deploy istio-system istio-ingressgateway       50m 128Mi  500m 256Mi
patch_deploy istio-system cluster-local-gateway      50m 128Mi  500m 256Mi
patch_deploy istio-system cluster-jwks-proxy         25m  64Mi  200m 128Mi

# --- Knative (scaled to 0 earlier; set limits for when you scale back up) ---
for d in activator autoscaler controller webhook net-istio-controller net-istio-webhook; do
  patch_deploy knative-serving "$d" 50m 128Mi 500m 256Mi
done

# --- Auth ---
kubectl scale deploy dex -n auth --replicas=1 2>/dev/null || true
patch_deploy auth dex 25m 64Mi 200m 128Mi

# --- Cert-manager ---
for d in cert-manager cert-manager-cainjector cert-manager-webhook; do
  patch_deploy cert-manager "$d" 25m 64Mi 200m 128Mi
done

# --- Katib ---
patch_deploy kubeflow katib-controller   25m  64Mi 200m 128Mi
patch_deploy kubeflow katib-db-manager 25m  64Mi 200m 128Mi
patch_deploy kubeflow katib-mysql      50m 256Mi 500m 512Mi
patch_deploy kubeflow katib-ui         25m  64Mi 200m 128Mi

# --- KServe ---
patch_deploy kubeflow kserve-controller-manager        50m 128Mi 500m 256Mi
patch_deploy kubeflow kserve-localmodel-controller-manager 25m 64Mi 200m 128Mi
patch_deploy kubeflow kserve-models-web-application    25m  64Mi 200m 128Mi

# --- Kubeflow Pipelines & Metadata ---
patch_deploy kubeflow metadata-envoy-deployment        25m  64Mi 200m 128Mi
patch_deploy kubeflow metadata-grpc-deployment       50m 128Mi 500m 256Mi
patch_deploy kubeflow metadata-writer                25m  64Mi 200m 128Mi
patch_deploy kubeflow ml-pipeline                   100m 256Mi 1000m 512Mi
patch_deploy kubeflow ml-pipeline-ui                 25m  64Mi 200m 128Mi
patch_deploy kubeflow ml-pipeline-persistenceagent   25m  64Mi 200m 128Mi
patch_deploy kubeflow ml-pipeline-scheduledworkflow  25m  64Mi 200m 128Mi
patch_deploy kubeflow ml-pipeline-viewer-crd         25m  64Mi 200m 128Mi
patch_deploy kubeflow ml-pipeline-visualizationserver 50m 128Mi 500m 256Mi
patch_deploy kubeflow cache-server                    50m 128Mi 500m 256Mi
patch_deploy kubeflow cache-deployer-deployment      25m  64Mi 200m 128Mi
patch_sts    kubeflow mysql                          50m 256Mi 500m 512Mi

# --- Kubeflow UI & Controllers ---
patch_deploy kubeflow jupyter-web-app-deployment       25m  64Mi 200m 128Mi
patch_deploy kubeflow notebook-controller-deployment   25m  64Mi 200m 128Mi
patch_deploy kubeflow volumes-web-app-deployment       25m  64Mi 200m 128Mi
patch_deploy kubeflow tensorboards-web-app-deployment  25m  64Mi 200m 128Mi
patch_deploy kubeflow pvcviewer-controller-manager     25m  64Mi 200m 128Mi
patch_deploy kubeflow tensorboard-controller-deployment 25m  64Mi 200m 128Mi
patch_deploy kubeflow profiles-deployment             25m  64Mi 200m 128Mi
patch_deploy kubeflow poddefaults-webhook-deployment  25m  64Mi 200m 128Mi
patch_deploy kubeflow kubeflow-pipelines-profile-controller 25m 64Mi 200m 128Mi
patch_deploy kubeflow training-operator               50m 128Mi 500m 256Mi
patch_deploy kubeflow kubeflow-trainer-controller-manager 50m 128Mi 500m 256Mi
patch_deploy kubeflow llmisvc-controller-manager      25m  64Mi 200m 128Mi
patch_deploy kubeflow workflow-controller             50m 128Mi 500m 256Mi
patch_deploy kubeflow dashboard                       25m  64Mi 200m 128Mi
patch_deploy kubeflow jobset-controller-manager       25m  64Mi 200m 128Mi
patch_deploy kubeflow seaweedfs                      50m 256Mi 500m 512Mi
patch_deploy kubeflow metacontroller                  25m  64Mi 200m 128Mi

# --- MLflow ---
patch_deploy mlflow mlflow-deployment 50m 256Mi 500m 512Mi

# --- Redis (scale replicas to 1; you don't need 3 on a laptop) ---
kubectl patch statefulset redis-deployment-replicas-1 -n redis -p '{"spec":{"replicas":0}}' 2>/dev/null || true
kubectl patch statefulset redis-deployment-replicas-2 -n redis -p '{"spec":{"replicas":0}}' 2>/dev/null || true
patch_sts redis redis-deployment-master    25m 128Mi 500m 256Mi
patch_sts redis redis-deployment-replicas-0 25m 128Mi 500m 256Mi

# --- Postgres ---
patch_sts postgres postgres-release-postgresql 50m 256Mi 500m 512Mi

# --- OAuth2 Proxy ---
kubectl scale deploy oauth2-proxy -n oauth2-proxy --replicas=1 2>/dev/null || true
patch_deploy oauth2-proxy oauth2-proxy 25m 64Mi 200m 128Mi

echo ""
echo "=== Done. Run: watch kubectl get pods -A ==="