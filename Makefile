# ── Defaults (override on the command line) ───────────────────────────────────
PROVIDER     ?= claude
MODEL        ?= claude-opus-4-6
URL          ?=
JUPYTER_PORT ?= 8888

# Prepend .venv/bin when it exists (created on macOS by make install).
# All targets that invoke Python tools pick up venv binaries automatically.
VENV_BIN := $(shell [ -d .venv ] && echo "$(PWD)/.venv/bin:" || echo "")
export PATH := $(VENV_BIN)$(PATH)

.PHONY: help install start stop cli

.DEFAULT_GOAL := help

# ── help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "Usage:"
	@echo "  make install                       Set up Python, install deps, configure API keys"
	@echo "  make start                         Start Jupyter and open it in the browser"
	@echo "  make stop                          Stop the Jupyter server"
	@echo "  make cli URL=https://...           Generate a Python CLI from a docs URL"
	@echo ""
	@echo "Parameters for make cli (with defaults):"
	@echo "  PROVIDER=$(PROVIDER)   claude | hf"
	@echo "  MODEL=$(MODEL)"
	@echo "  URL=$(URL)"
	@echo "  JUPYTER_PORT=$(JUPYTER_PORT)"
	@echo ""
	@echo "Examples:"
	@echo "  make cli URL=https://docs.anthropic.com/en/api/messages"
	@echo "  make cli URL=https://huggingface.co/docs/hub/api PROVIDER=hf MODEL=mistralai/Mistral-7B-Instruct-v0.3"
	@echo ""

# ── install ───────────────────────────────────────────────────────────────────
## Check Python, create venv, install dependencies + Jupyter, create notebooks/,
## and prompt for HuggingFace / Anthropic API keys (skipped when .env exists).
install:
	@chmod +x scripts/setup.sh
	@bash scripts/setup.sh
	@echo ""
	@echo "All done. Run 'make start' to launch Jupyter."

# ── start ─────────────────────────────────────────────────────────────────────
## Launch Jupyter in the background and open it in your default browser.
start:
	@[ -f .env ] || { echo "Run 'make install' first to install dependencies and configure API keys."; exit 1; }
	@mkdir -p notebooks
	@set -a && . ./.env && set +a && \
	  nohup jupyter notebook --port $(JUPYTER_PORT) --notebook-dir notebooks > .jupyter.log 2>&1 & echo $$! > .jupyter.pid
	@echo "Jupyter starting on port $(JUPYTER_PORT) … (log: .jupyter.log)"
	@sleep 2
	@open http://localhost:$(JUPYTER_PORT) 2>/dev/null || \
	  xdg-open http://localhost:$(JUPYTER_PORT) 2>/dev/null || \
	  echo "Open http://localhost:$(JUPYTER_PORT) in your browser."

# ── stop ──────────────────────────────────────────────────────────────────────
## Stop the Jupyter server.
stop:
	@PID=""; \
	[ -f .jupyter.pid ] && PID=$$(cat .jupyter.pid); \
	if [ -n "$$PID" ] && kill "$$PID" 2>/dev/null; then \
	  echo "Jupyter stopped (PID $$PID)."; rm -f .jupyter.pid; \
	elif pkill -f "jupyter.*notebook" 2>/dev/null; then \
	  echo "Jupyter process killed."; rm -f .jupyter.pid; \
	else \
	  echo "No Jupyter server found."; \
	fi

# ── cli ───────────────────────────────────────────────────────────────────────
## Generate a Python CLI tool from a documentation URL.
## Usage: make cli URL=https://... [PROVIDER=claude|hf] [MODEL=model-name]
cli:
	@[ -f .env ] || { echo "Run 'make install' first to install dependencies and configure API keys."; exit 1; }
ifndef URL
	$(error URL is required. Usage: make cli URL=https://... [PROVIDER=claude|hf] [MODEL=model-name])
endif
	@echo ""
	@echo "Provider : $(PROVIDER)"
	@echo "Model    : $(MODEL)"
	@echo "URL      : $(URL)"
	@echo ""
	@set -a && . ./.env && set +a && \
	  PROVIDER=$(PROVIDER) MODEL=$(MODEL) URL=$(URL) \
	  papermill notebooks/generate_cli.ipynb \
	    /tmp/cli_out_$$(date +%s).ipynb \
	    -p PROVIDER "$(PROVIDER)" \
	    -p MODEL    "$(MODEL)" \
	    -p URL      "$(URL)"
