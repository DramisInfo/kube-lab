# Kubernetes Management Cluster Lab

A project for setting up and managing a Kubernetes management cluster using k3d that orchestrates other clusters via Cluster API (CAPI) and Open Cluster Management (OCM), following GitOps principles with ArgoCD.

## Overview

This project provides tooling and configuration to:
1. Set up a local management Kubernetes cluster using k3d
2. Implement GitOps practices using ArgoCD for all deployments
3. Install and configure Cluster API (CAPI) for provisioning child clusters (future)
4. Deploy Open Cluster Management (OCM) for centralized multi-cluster management (future)
5. Create and manage clusters across multiple providers (future):
   - Proxmox
   - Azure
   - AWS

## Architecture

This project follows GitOps principles:
- The management cluster is created using k3d
- ArgoCD will be used to deploy and manage all components within the cluster
- All configuration will be stored in Git, representing the desired state
- No direct kubectl commands will be used for deployments
- Changes to the cluster will be made by updating the Git repository

## Prerequisites

- Linux operating system
- Docker
- [Task](https://taskfile.dev/) - Task runner (optional but recommended)
- The following tools will be installed via Taskfile if not already present:
  - kubectl
  - k3d (Lightweight Kubernetes distribution)
  - helm

## Getting Started

### Using Taskfile (Recommended)

This project uses [Taskfile](https://taskfile.dev/) to simplify common operations. Install Task first:

```bash
# Install Task
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
```

Then use Task commands to set up your environment:

```bash
# Install all prerequisites
task prereq:install

# Create management cluster
task mgmt:create

# List all available tasks
task
```

### Manual Setup

```bash
# Clone this repository
git clone https://github.com/yourusername/kube-lab.git
cd kube-lab

# Create a k3d cluster to serve as the management cluster
k3d cluster create mgmt-cluster --servers 1 --agents 2 --port 6443:6443 --k3s-arg "--disable=traefik@server:0"

# Verify the cluster is running
kubectl get nodes
```

## Available Tasks

The project includes the following tasks:

| Task | Description |
|------|-------------|
| `task prereq:install` | Install all prerequisites |
| `task prereq:install-k3d` | Install k3d |
| `task prereq:install-kubectl` | Install kubectl |
| `task prereq:install-helm` | Install Helm |
| `task mgmt:create` | Create management cluster with k3d |
| `task mgmt:delete` | Delete management cluster |

## Next Steps

After setting up the management cluster, the following steps will be implemented using GitOps with ArgoCD:

1. Deploy ArgoCD to the management cluster
2. Configure ArgoCD to sync from this Git repository
3. Deploy Cluster API components through ArgoCD
4. Deploy Open Cluster Management (OCM) through ArgoCD
5. Configure templates and workflows for creating workload clusters

## Project Structure

```
kube-lab/
├── README.md
├── Taskfile.yml          # Task definitions for common operations
└── gitops/               # GitOps manifests (to be added)
    ├── argocd/           # ArgoCD installation and configuration
    ├── cluster-api/      # Cluster API components
    ├── ocm/              # Open Cluster Management components
    └── clusters/         # Workload cluster definitions
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.