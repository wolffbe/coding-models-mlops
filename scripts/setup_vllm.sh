#!/usr/bin/env bash
# Deploys vLLM via a KServe InferenceService.
#
# Requires KServe to be installed (run setup_kserve_knative.sh first).
# The vLLM ClusterServingRuntime is included in KServe's cluster resources
# and is available automatically after KServe installation.
#
# The HuggingFace token is read from the mlops-secrets k8s Secret, so the
# secret must exist before this script runs (created by make k8s-secret).
#
# Overridable env vars:
#   VLLM_MODEL          default: facebook/opt-125m  (small CPU-friendly model)
#   K8S_NS              default: mlops
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VLLM_MODEL="${VLLM_MODEL:-facebook/opt-125m}"
K8S_NS="${K8S_NS:-mlops}"

kubectl apply -f "$REPO_ROOT/k8s/namespace.yaml"

echo "vllm   : deploying InferenceService (model: $VLLM_MODEL) …"
VLLM_MODEL="$VLLM_MODEL" envsubst < "$REPO_ROOT/k8s/vllm/inferenceservice.yaml" | kubectl apply -f -

echo "vllm   : InferenceService applied in namespace $K8S_NS"
echo "         Check: kubectl get inferenceservice vllm -n $K8S_NS"
