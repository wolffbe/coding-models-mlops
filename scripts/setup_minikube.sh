#!/usr/bin/env bash
# Minikube setup for macOS — installs prerequisites and ensures a minikube
# cluster is running with enough resources for KServe + Knative + Istio.
#
# Overridable env vars (all optional):
#   MINIKUBE_CPUS       default: 4
#   MINIKUBE_MEMORY     default: 8192  (MiB)
#   MINIKUBE_DISK       default: 40g
#   MINIKUBE_DRIVER     default: docker
#   MINIKUBE_K8S_VERSION default: v1.32.0
#   MINIKUBE_PROFILE    default: coding-agents-mlops
set -e

MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-8192}"
MINIKUBE_DISK="${MINIKUBE_DISK:-40g}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
MINIKUBE_K8S_VERSION="${MINIKUBE_K8S_VERSION:-v1.32.0}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-coding-agents-mlops}"

# ── 1. Homebrew prerequisite check ────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "minikube: error — Homebrew is required. Install from https://brew.sh" >&2
  exit 1
fi

install_brew_if_missing() {
  local cmd="$1" pkg="${2:-$1}"
  if ! command -v "$cmd" &>/dev/null; then
    echo "minikube: $cmd not found — installing via Homebrew …"
    brew install "$pkg"
    echo "minikube: $cmd installed"
  else
    echo "minikube: $cmd already installed ($(command -v "$cmd"))"
  fi
}

install_brew_if_missing minikube minikube
install_brew_if_missing kubectl kubernetes-cli
install_brew_if_missing helm helm

# ── 2. Docker daemon check (required for docker driver) ───────────────────────
if [ "$MINIKUBE_DRIVER" = "docker" ]; then
  if ! docker info &>/dev/null 2>&1; then
    echo "minikube: Docker daemon is not running." >&2
    echo "          Start Docker Desktop and re-run 'make install'." >&2
    exit 1
  fi
  echo "minikube: Docker daemon is running"
fi

# ── 3. Create or start the minikube cluster ───────────────────────────────────
STATUS="$(minikube status -p "$MINIKUBE_PROFILE" --format='{{.Host}}' 2>/dev/null || echo 'Nonexistent')"

case "$STATUS" in
  Running)
    echo "minikube: profile '$MINIKUBE_PROFILE' is already running"
    ;;
  Stopped|Paused)
    echo "minikube: starting existing profile '$MINIKUBE_PROFILE' …"
    minikube start -p "$MINIKUBE_PROFILE"
    echo "minikube: started"
    ;;
  *)
    echo "minikube: creating profile '$MINIKUBE_PROFILE' …"
    echo "          CPUs: $MINIKUBE_CPUS  Memory: ${MINIKUBE_MEMORY}MiB  Disk: $MINIKUBE_DISK"
    minikube start \
      -p "$MINIKUBE_PROFILE" \
      --driver="$MINIKUBE_DRIVER" \
      --kubernetes-version="$MINIKUBE_K8S_VERSION" \
      --cpus="$MINIKUBE_CPUS" \
      --memory="$MINIKUBE_MEMORY" \
      --disk-size="$MINIKUBE_DISK"
    echo "minikube: created and started"
    ;;
esac

# ── 4. Enable required addons ─────────────────────────────────────────────────
for addon in ingress metrics-server; do
  if minikube addons list -p "$MINIKUBE_PROFILE" | grep -q "^| $addon.*enabled"; then
    echo "minikube: addon '$addon' already enabled"
  else
    echo "minikube: enabling addon '$addon' …"
    minikube addons enable "$addon" -p "$MINIKUBE_PROFILE"
  fi
done

# ── 5. Point kubectl at this cluster ──────────────────────────────────────────
minikube update-context -p "$MINIKUBE_PROFILE" &>/dev/null
echo "minikube: kubectl context set to '$MINIKUBE_PROFILE'"
echo "minikube: cluster IP = $(minikube ip -p "$MINIKUBE_PROFILE")"
echo "minikube: setup complete"
