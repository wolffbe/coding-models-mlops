#!/usr/bin/env bash
# Full first-time setup: Jupyter and MLflow environments.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

bash "$SCRIPT_DIR/setup_jupyter.sh"
bash "$SCRIPT_DIR/setup_mlflow.sh"
