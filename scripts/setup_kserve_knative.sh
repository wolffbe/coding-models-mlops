#!/usr/bin/env bash
# KServe Knative mode installation.
# Follows the KServe Knative serverless deployment guide:
#   https://kserve.github.io/website/latest/admin/serverless/serverless/
#
# Versions (Kubernetes 1.32 recommended matrix):
#   Knative      v1.19.0
#   Istio        1.28.0
#   Cert Manager v1.15.0
#   KServe       v0.16.0
#
# Prerequisite: a running Kubernetes 1.32+ cluster with kubectl configured.
# KServe is installed via Helm when available, falling back to YAML.
set -e

KNATIVE_VERSION="v1.19.0"
ISTIO_VERSION="1.28.0"
CERT_MANAGER_VERSION="v1.15.0"
KSERVE_VERSION="v0.16.0"

# ── 1. Install Knative Serving ────────────────────────────────────────────────
echo "knative: installing Serving CRDs …"
kubectl apply -f "https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-crds.yaml"

echo "knative: installing Serving core …"
kubectl apply -f "https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-core.yaml"

echo "knative: waiting for Serving to be ready …"
kubectl wait --for=condition=Available deployment --all -n knative-serving --timeout=300s

# ── 2. Install Networking Layer (Istio + net-istio) ───────────────────────────
echo "istio  : downloading istioctl ${ISTIO_VERSION} …"
curl -sSL https://istio.io/downloadIstio | ISTIO_VERSION="${ISTIO_VERSION}" TARGET_ARCH="$(uname -m)" sh -
export PATH="${PWD}/istio-${ISTIO_VERSION}/bin:${PATH}"

echo "istio  : installing …"
istioctl install -y

echo "istio  : waiting for ingress gateway …"
kubectl wait --for=condition=Available deployment --all -n istio-system --timeout=300s

echo "istio  : installing Knative net-istio …"
kubectl apply -f "https://github.com/knative/net-istio/releases/download/knative-${KNATIVE_VERSION}/net-istio.yaml"

# ── 3. Install Cert Manager ───────────────────────────────────────────────────
echo "certmgr: installing Cert Manager ${CERT_MANAGER_VERSION} …"
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"

echo "certmgr: waiting for Cert Manager to be ready …"
kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=300s

# ── 4. Install KServe ─────────────────────────────────────────────────────────
if command -v helm &>/dev/null; then
  echo "kserve : installing CRDs via Helm …"
  helm upgrade --install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd \
    --version "${KSERVE_VERSION}"

  echo "kserve : installing controller via Helm …"
  # The chart registers a ValidatingWebhookConfiguration and ClusterServingRuntimes
  # in a single pass; the webhook pod may not be ready when CSRs are submitted,
  # producing a "connection refused" error.  Allow that failure — the controller
  # deployment is still created — and apply cluster resources once it is ready.
  helm upgrade --install kserve oci://ghcr.io/kserve/charts/kserve \
    --version "${KSERVE_VERSION}" --timeout 10m || true
else
  echo "kserve : helm not found — installing via YAML …"
  kubectl apply --server-side \
    -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve.yaml"
fi

echo "kserve : waiting for controller manager to be ready …"
kubectl wait --for=condition=Available deployment/kserve-controller-manager \
  -n default --timeout=300s

echo "kserve : applying ClusterServingRuntimes …"
kubectl apply --server-side \
  -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve-cluster-resources.yaml"

echo "kserve : Knative mode installation complete"
