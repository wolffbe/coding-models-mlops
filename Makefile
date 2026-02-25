# ── Defaults (override on the command line) ───────────────────────────────────
PROVIDER          ?= anthropic
MODEL             ?= claude-opus-4-6
URL               ?=
REGISTRY          ?= docker.io/youruser
MINIKUBE_REGISTRY ?= mlops                # image prefix inside minikube's Docker daemon
MINIKUBE_PROFILE  ?= coding-agents-mlops  # minikube profile name
K8S_NS            ?= mlops

.PHONY: help install uninstall \
        k8s-kserve k8s-vllm k8s-mlflow \
        k8s-build k8s-push k8s-secret k8s-delete k8s-forward \
        k8s-minikube-build \
        pkg-test

.DEFAULT_GOAL := help

# ── help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "Usage:"
	@echo "  make install                       Prompt for API keys, start minikube, deploy full k8s stack"
	@echo "  make uninstall                     Tear down all k8s resources and delete the minikube profile"
	@echo ""
	@echo "Kubernetes:"
	@echo "  make k8s-kserve                    Install KServe + Knative (Istio, Cert Manager)"
	@echo "  make k8s-vllm                      Deploy vLLM InferenceService via KServe"
	@echo "  make k8s-mlflow                    Build image + deploy MLflow pod"
	@echo "  make k8s-secret                    Create mlops-secrets from .env (idempotent)"
	@echo "  make k8s-delete                    Delete all k8s resources in namespace $(K8S_NS)"
	@echo "  make k8s-forward                   Port-forward mlflow:5000 to localhost"
	@echo ""
	@echo "Kubernetes — registry workflow (non-minikube):"
	@echo "  make k8s-build                     Build Docker images (host daemon)"
	@echo "  make k8s-push                      Push images to \$$REGISTRY (default: $(REGISTRY))"
	@echo "  make k8s-minikube-build            (Re)build images inside minikube's Docker daemon"
	@echo "                                     (MINIKUBE_REGISTRY=$(MINIKUBE_REGISTRY), MINIKUBE_PROFILE=$(MINIKUBE_PROFILE))"
	@echo ""
	@echo "Parameters:"
	@echo "  PROVIDER=$(PROVIDER)"
	@echo "  MODEL=$(MODEL)"
	@echo "  VLLM_MODEL=<hf-model-id>           Model for vLLM InferenceService (default: facebook/opt-125m)"
	@echo ""
	@echo "Monorepo package targets:"
	@echo "  make pkg-test NAME=mypackage           Run tests for one package"
	@echo "  make pkg-test                          Run tests for all packages"
	@echo ""
	@echo "Examples:"
	@echo "  make install"
	@echo "  make k8s-vllm VLLM_MODEL=Qwen/Qwen2.5-0.5B-Instruct"
	@echo ""

# ── install ───────────────────────────────────────────────────────────────────
## Prompt for API keys, ensure minikube is running, deploy the full k8s stack.
install:
	@chmod +x scripts/setup_env.sh scripts/setup_minikube.sh \
	           scripts/setup_kserve_knative.sh \
	           scripts/setup_vllm.sh scripts/setup_mlflow.sh
	@bash scripts/setup_env.sh
	@bash scripts/setup_minikube.sh
	@$(MAKE) --no-print-directory k8s-kserve
	@$(MAKE) --no-print-directory k8s-secret
	@$(MAKE) --no-print-directory k8s-vllm
	@$(MAKE) --no-print-directory k8s-mlflow
	@echo ""
	@echo "All done. Run 'make k8s-forward' to reach the in-cluster pods."

# ── uninstall ─────────────────────────────────────────────────────────────────
## Tear down everything: mlops workloads → KServe → Cert Manager → Knative → Istio → minikube.
uninstall:
	@echo "uninstall: removing mlops namespace resources …"
	@$(MAKE) --no-print-directory k8s-delete || true
	@echo "uninstall: removing KServe …"
	@if command -v helm &>/dev/null && helm list -A 2>/dev/null | grep -q kserve; then \
	  helm uninstall kserve     2>/dev/null || true; \
	  helm uninstall kserve-crd 2>/dev/null || true; \
	else \
	  kubectl delete --ignore-not-found \
	    -f "https://github.com/kserve/kserve/releases/download/v0.16.0/kserve-cluster-resources.yaml" || true; \
	  kubectl delete --ignore-not-found \
	    -f "https://github.com/kserve/kserve/releases/download/v0.16.0/kserve.yaml" || true; \
	fi
	@echo "uninstall: removing Cert Manager …"
	@kubectl delete --ignore-not-found \
	  -f "https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml" || true
	@echo "uninstall: removing Knative net-istio …"
	@kubectl delete --ignore-not-found \
	  -f "https://github.com/knative/net-istio/releases/download/knative-v1.19.0/net-istio.yaml" || true
	@echo "uninstall: removing Knative Serving …"
	@kubectl delete --ignore-not-found \
	  -f "https://github.com/knative/serving/releases/download/knative-v1.19.0/serving-core.yaml" || true
	@kubectl delete --ignore-not-found \
	  -f "https://github.com/knative/serving/releases/download/knative-v1.19.0/serving-crds.yaml" || true
	@echo "uninstall: removing Istio …"
	@if [ -x "istio-1.28.0/bin/istioctl" ]; then \
	  istio-1.28.0/bin/istioctl uninstall --purge -y 2>/dev/null || true; \
	elif command -v istioctl &>/dev/null; then \
	  istioctl uninstall --purge -y 2>/dev/null || true; \
	else \
	  kubectl delete namespace istio-system --ignore-not-found || true; \
	fi
	@echo "uninstall: deleting minikube profile $(MINIKUBE_PROFILE) …"
	@minikube delete -p $(MINIKUBE_PROFILE) 2>/dev/null || true
	@echo "uninstall: done."

# ── k8s-kserve ────────────────────────────────────────────────────────────────
## Install KServe in Knative serverless mode (skips if already installed).
## Installs: Knative Serving v1.19, Istio 1.28, Cert Manager v1.15, KServe v0.16.
## Configures the Knative domain to the minikube IP via sslip.io.
k8s-kserve:
	@chmod +x scripts/setup_kserve_knative.sh
	@if kubectl get namespace knative-serving &>/dev/null 2>&1; then \
	  echo "k8s    : KServe/Knative already installed — skipping"; \
	else \
	  bash scripts/setup_kserve_knative.sh; \
	fi
	@MINIKUBE_IP="$$(minikube ip -p $(MINIKUBE_PROFILE) 2>/dev/null || echo '')"; \
	if [ -n "$$MINIKUBE_IP" ] && kubectl get namespace knative-serving &>/dev/null 2>&1; then \
	  kubectl patch configmap/config-domain \
	    --namespace knative-serving \
	    --type merge \
	    -p "{\"data\":{\"$${MINIKUBE_IP}.sslip.io\":\"\"}}" 2>/dev/null \
	    && echo "k8s    : Knative domain → $${MINIKUBE_IP}.sslip.io" \
	    || echo "k8s    : Knative domain patch skipped (config-domain not ready)"; \
	fi

# ── k8s-vllm ──────────────────────────────────────────────────────────────────
## Deploy the vLLM InferenceService via KServe.
## Override the model: make k8s-vllm VLLM_MODEL=Qwen/Qwen2.5-0.5B-Instruct
k8s-vllm:
	@chmod +x scripts/setup_vllm.sh
	@VLLM_MODEL="$(or $(VLLM_MODEL),facebook/opt-125m)" bash scripts/setup_vllm.sh

# ── k8s-mlflow ────────────────────────────────────────────────────────────────
## Build the MLflow image inside minikube and deploy to the mlops namespace.
k8s-mlflow:
	@chmod +x scripts/setup_mlflow.sh
	@bash scripts/setup_mlflow.sh

# ── k8s-build ─────────────────────────────────────────────────────────────────
## Build Docker images against the host Docker daemon (for registry-push workflow).
k8s-build:
	docker build -t $(REGISTRY)/mlflow:latest  -f docker/mlflow/Dockerfile  .

# ── k8s-push ──────────────────────────────────────────────────────────────────
## Push images to the container registry.
## Usage: make k8s-push REGISTRY=docker.io/myuser
k8s-push:
	docker push $(REGISTRY)/mlflow:latest

# ── k8s-secret ────────────────────────────────────────────────────────────────
## Create mlops-secrets in the cluster from the local .env file (idempotent).
k8s-secret:
	@[ -f .env ] || { echo "No .env found. Run 'make install' first."; exit 1; }
	@kubectl apply -f k8s/namespace.yaml
	@HF_TOKEN=$$(grep -E '^HF_TOKEN=' .env | cut -d= -f2-) && \
	 ANTHROPIC_API_KEY=$$(grep -E '^ANTHROPIC_API_KEY=' .env | cut -d= -f2-) && \
	 kubectl create secret generic mlops-secrets \
	   --namespace=$(K8S_NS) \
	   --from-literal=HF_TOKEN="$$HF_TOKEN" \
	   --from-literal=ANTHROPIC_API_KEY="$$ANTHROPIC_API_KEY" \
	   --dry-run=client -o yaml | kubectl apply -f -
	@echo "Secret mlops-secrets applied in namespace $(K8S_NS)."

# ── k8s-delete ────────────────────────────────────────────────────────────────
## Delete all Kubernetes resources in the mlops namespace.
k8s-delete:
	kubectl delete -f k8s/mlflow/service.yaml       --ignore-not-found
	kubectl delete inferenceservice vllm -n $(K8S_NS) --ignore-not-found
	REGISTRY=$(MINIKUBE_REGISTRY) envsubst < k8s/mlflow/deployment.yaml  | kubectl delete -f - --ignore-not-found
	kubectl delete -f k8s/mlflow/pvc.yaml           --ignore-not-found
	kubectl delete -f k8s/configmap.yaml            --ignore-not-found
	kubectl delete -f k8s/namespace.yaml            --ignore-not-found

# ── k8s-forward ───────────────────────────────────────────────────────────────
## Port-forward Jupyter and MLflow from the cluster to localhost.
## Press Ctrl-C to stop.
k8s-forward:
	@echo "Forwarding mlflow  → http://localhost:5000"
	@echo "Press Ctrl-C to stop."
	@kubectl port-forward -n $(K8S_NS) svc/mlflow  5000:5000 &
	@wait

# ── k8s-minikube-build ────────────────────────────────────────────────────────
## (Re)build Docker images directly inside minikube's Docker daemon.
## Useful after source changes without re-running the full install.
k8s-minikube-build:
	@eval "$$(minikube docker-env -p $(MINIKUBE_PROFILE))" && \
	docker build -t $(MINIKUBE_REGISTRY)/mlflow:latest  -f docker/mlflow/Dockerfile  .

# ── pkg-test ──────────────────────────────────────────────────────────────────
## Run tests for one package or all packages.
## Usage: make pkg-test NAME=mypackage   (single)
##        make pkg-test                  (all)
pkg-test:
ifdef NAME
	@cd "packages/$(NAME)" && poetry install --quiet && poetry run pytest --tb=short -q
else
	@FAILED=""; \
	for dir in packages/*/ cli/*/; do \
	  [ -f "$$dir/pyproject.toml" ] || continue; \
	  echo "── Testing: $$dir"; \
	  (cd "$$dir" && poetry install --quiet && poetry run pytest --tb=short -q) \
	    || FAILED="$$FAILED $$dir"; \
	done; \
	[ -z "$$FAILED" ] && echo "All packages passed." || { echo "FAILED:$$FAILED"; exit 1; }
endif
