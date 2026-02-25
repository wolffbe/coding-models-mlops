#!/usr/bin/env bash
# Deploys MLflow to Kubernetes inside minikube.
#
# Builds the image directly inside minikube's Docker daemon (no registry push),
# then applies PVC, Deployment, and Service manifests. imagePullPolicy is
# patched to Never so Kubernetes uses the locally built image.
#
# Overridable env vars:
#   MINIKUBE_PROFILE    default: coding-agents-mlops
#   REGISTRY            default: mlops   (image name prefix inside minikube)
#   K8S_NS              default: mlops
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-coding-agents-mlops}"
REGISTRY="${REGISTRY:-mlops}"
K8S_NS="${K8S_NS:-mlops}"

kubectl apply -f "$REPO_ROOT/k8s/namespace.yaml"
kubectl apply -f "$REPO_ROOT/k8s/configmap.yaml"

# ── 1. Build image inside minikube's Docker daemon ────────────────────────────
echo "mlflow : building image inside minikube …"
eval "$(minikube docker-env -p "$MINIKUBE_PROFILE")"
docker build -t "${REGISTRY}/mlflow:latest" \
  -f "$REPO_ROOT/docker/mlflow/Dockerfile" "$REPO_ROOT"
eval "$(minikube docker-env -p "$MINIKUBE_PROFILE" --unset)"
echo "mlflow : image built"

# ── 2. Apply PVC, Deployment, Service ─────────────────────────────────────────
kubectl apply -f "$REPO_ROOT/k8s/mlflow/pvc.yaml"
REGISTRY="$REGISTRY" envsubst < "$REPO_ROOT/k8s/mlflow/deployment.yaml" | kubectl apply -f -
kubectl apply -f "$REPO_ROOT/k8s/mlflow/service.yaml"

# ── 3. Patch imagePullPolicy to Never ─────────────────────────────────────────
kubectl patch deployment mlflow -n "$K8S_NS" --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"Never"}]' \
  2>/dev/null || true

echo "mlflow : deployed to namespace $K8S_NS"
echo "         Access: make k8s-forward"
