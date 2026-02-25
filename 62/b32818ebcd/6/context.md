# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Plan: Kubernetes Deployment for Jupyter and MLflow

## Context

The project currently runs Jupyter and MLflow as local background processes managed by `make start/stop`.
The goal is to containerise both services and deploy them on Kubernetes, supporting:
- **Local testing**: minikube on the dev laptop
- **Remote production**: a Proxmox-managed cluster with 4 GPUs

Images will be pushed to a container registry; data will persist via PersistentVolumeClaims.

---...

### Prompt 2

The system will produce new software packages that I would like to push to my GitHub repository. I would like to use a monorepo for that.

### Prompt 3

[Request interrupted by user for tool use]

