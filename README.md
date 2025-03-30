# Kubernetes Management Cluster Lab

A project for setting up and managing a Kubernetes management cluster using k3d that orchestrates other clusters via Cluster API (CAPI) and Open Cluster Management (OCM).

## Overview

This project provides tooling and configuration to:
1. Set up a local management Kubernetes cluster using k3d
2. Install and configure Cluster API (CAPI) for provisioning child clusters (future)
3. Deploy Open Cluster Management (OCM) for centralized multi-cluster management (future)
4. Create and manage clusters across multiple providers (future):
   - Proxmox
   - Azure
   - AWS

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

After setting up the management cluster, future versions of this project will include:

1. Cluster API integration for different providers
2. Open Cluster Management (OCM) setup
3. Creating and managing workload clusters

## Project Structure

```
kube-lab/
├── README.md
└── Taskfile.yml          # Task definitions for common operations
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.