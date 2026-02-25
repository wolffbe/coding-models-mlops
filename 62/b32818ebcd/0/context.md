# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Plan: Python Poetry Monorepo

## Context

The existing repo (`coding-agents-mlops`) is a base system that generates CLI tools from documentation URLs. The monorepo overlay should support two categories of Python packages:

- **`cli/<name>/`** — generated CLI packages (output of the CLI generator notebook)
- **`packages/<name>/`** — system-level packages written to control/extend the base system

Each package is a fully independent Poetry package (its own `pypr...

### Prompt 2

Remove the make commands to generate new system packages. Add .entire to .gitignore.

### Prompt 3

make install should install vllm, kserve, jupyter and mlflow

### Prompt 4

Follow the steps given in this tutorial: https://medium.com/@rohitkhatana/installing-vllm-on-macos-a-step-by-step-guide-bbbf673461af

### Prompt 5

[Request interrupted by user for tool use]

### Prompt 6

Installing vLLM on macOS: A Step-by-Step Guide
Rohit Khatana
Rohit Khatana
5 min read
·
Mar 14, 2025

vLLM is a powerful LLM inference and serving engine that enhances inference speed and throughput through PagedAttention, an optimized attention mechanism. While vLLM is primarily designed for CUDA-enabled hardware, it’s possible to get it running on macOS with some workarounds. This guide will walk you through the installation process and some basic usage examples.
The CUDA Challenge on macOS...

### Prompt 7

Remove the thin setup.sh. Make sure that make install uses one script per function: vllm, jupyter, mlflow, kserve.

### Prompt 8

Knative mode Installation Guide

KServe's Knative serverless deployment mode leverages Knative to provide autoscaling based on request volume and supports scale down to and from zero. It also supports revision management and canary rollout based on revisions.

This mode is particularly useful for:

    Cost optimization by automatically scaling resources based on demand
    Environments with varying or unpredictable traffic patterns
    Burst traffic scenarios where rapid scaling is required
...

### Prompt 9

I want to be able to run make cli after make install. Make cli should take three parameters and load a file. The parameters are model-provider (huggingface or anthropic), model name and docs-url, which points to a documentation online. The goal is that the system automatically downloads a given model or uses anthropics inference, and then creates a CLI from a Python SDK that I provide via the docs-url. The newly created cli should be saved as a package in the repository.

### Prompt 10

I would like to specify the prompt in 0_generate_cli in an extra folder named /prompts. The prompt needs to get injected while firing up the jupyter server in K8s.

### Prompt 11

Safely remove setup_kserve.sh

