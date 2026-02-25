#!/usr/bin/env bash
# MLflow environment setup:
#   1. Ensure MLFLOW_TRACKING_URI is present in .env
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$REPO_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo ".env   : not found — run setup_jupyter.sh first"
  exit 1
fi

if ! grep -q "MLFLOW_TRACKING_URI" "$ENV_FILE"; then
  printf "\n# MLflow tracking server\nMLFLOW_TRACKING_URI=http://127.0.0.1:5000\n" >> "$ENV_FILE"
  echo ".env   : MLFLOW_TRACKING_URI added"
else
  echo ".env   : MLFLOW_TRACKING_URI already set"
fi
