# kube-lab

A project for automating Kubernetes deployment in a homelab environment using network booting and remote orchestration.

## Project Objective

The main goal of this project is to automate the end-to-end process of installing and configuring a Kubernetes cluster in a homelab environment. The automation includes network booting of nodes and complete cluster setup initiated from a control machine (laptop).

## Hardware Configuration

The homelab consists of:
- 3 Mini PCs with Intel N95 processors
- Each node equipped with 16GB RAM
- Each node has 512MB of storage
- Control machine (laptop) for orchestrating the deployment

## Key Features

- Network boot (PXE) capability for initial OS loading
- Automated Kubernetes installation and configuration
- Remote deployment initiated from control machine
- End-to-end automation from bare metal to working Kubernetes cluster

## Architecture Diagram

The following diagram illustrates the architecture of the Kubernetes homelab setup:

```mermaid
flowchart TD
    subgraph "Home Network"
        Z[TP-Link ER605 V2 Router] -- DHCP --> F
        Z -- DHCP --> L
        Z -- DHCP --> P
        Z -- DHCP --> Laptop
    end
    
    subgraph "Control Plane (Laptop)"
        A[Deploy Script] --> B[TFTP Server]
        A --> C[Ansible Controller]
        B --> D[Boot Files]
        A --> E[HTTP Server]
    end
    
    subgraph "Kubernetes Cluster"
        F[Master Node] --> H[kube-apiserver]
        F --> I[etcd]
        F --> J[kube-scheduler]
        F --> K[kube-controller-manager]
        L[Worker Node 1] --> M[kubelet]
        L --> N[kube-proxy]
        L --> O[Container Runtime]
        P[Worker Node 2] --> Q[kubelet]
        P --> R[kube-proxy]
        P --> S[Container Runtime]
    end
    
    Z -- PXE Option 66,67 --> B
    F -- PXE Boot --> B
    L -- PXE Boot --> B
    P -- PXE Boot --> B
    C -- Ansible Playbooks --> F
    C -- Ansible Playbooks --> L
    C -- Ansible Playbooks --> P
    D -- Boot Files --> F
    D -- Boot Files --> L
    D -- Boot Files --> P
    E -- Kickstart Files --> F
    E -- Kickstart Files --> L
    E -- Kickstart Files --> P
```

## Deployment Flow

The following diagram shows the automated deployment flow:

```mermaid
sequenceDiagram
    participant User
    participant Laptop as Control Laptop
    participant Router as TP-Link Router
    participant TFTP as TFTP Server (Laptop)
    participant Master as Master Node
    participant Workers as Worker Nodes
    
    User->>Laptop: Run deploy_k8s.sh
    Laptop->>Laptop: Setup TFTP server
    Laptop->>Router: Configure PXE options 66,67
    
    User->>Master: Power on
    Master->>Router: DHCP request
    Router->>Master: IP assignment + PXE boot info
    Master->>TFTP: Request boot files
    TFTP->>Master: Send boot files & kickstart
    Master->>Master: Install OS via kickstart
    
    User->>Workers: Power on
    Workers->>Router: DHCP request
    Router->>Workers: IP assignment + PXE boot info
    Workers->>TFTP: Request boot files
    TFTP->>Workers: Send boot files & kickstart
    Workers->>Workers: Install OS via kickstart
    
    Laptop->>Laptop: Verify nodes are online
    
    Laptop->>Master: Run Ansible playbooks
    Master->>Master: Install Kubernetes master components
    
    Laptop->>Workers: Run Ansible playbooks
    Workers->>Workers: Install Kubernetes worker components
    
    Master->>Workers: Join workers to cluster
    
    Laptop->>Master: Get kubeconfig
    Master->>Laptop: Return kubeconfig
    
    User->>Laptop: Access cluster with kubectl
```

## Prerequisites

Before starting, ensure you have:

1. A control machine (laptop) running Linux with administrator/sudo access
2. 3 Mini PCs with network boot capability enabled in BIOS
3. All machines connected to the same network
4. The following tools installed on your control machine:
   - Git
   - Ansible
   - SSH client
   - Basic networking tools

## Step-by-Step Setup Guide

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/kube-lab.git
cd kube-lab
```

### 2. Configure the Ansible Inventory

Edit `kube-lab/ansible/inventory/hosts.ini` to match your network configuration:

```ini
# Example configuration - update IP addresses to match your network
[k8s_masters]
master ansible_host=192.168.1.101 ansible_user=ubuntu

[k8s_workers]
worker1 ansible_host=192.168.1.102 ansible_user=ubuntu
worker2 ansible_host=192.168.1.103 ansible_user=ubuntu
```

### 3. Network Boot Options

You have two options for setting up the network boot environment:

#### Option A: Containerized PXE Boot Server (Recommended)

This option uses Docker to run the PXE boot server, making it portable across different laptops:

1. Ensure Docker is installed on your machine
2. Run the containerized PXE boot server:
   ```bash
   sudo bash kube-lab/scripts/run_pxe_container.sh
   ```
3. Follow the interactive prompts to configure the PXE server based on your network
4. The script will build and run a Docker container with all necessary services

This containerized approach offers several advantages:
- Portable: Run from any machine with Docker
- Isolated: Doesn't affect your host system
- Consistent: Same environment regardless of the host

#### Option B: Native PXE Boot Setup

Since you're using a TP-Link ER605 V2 router as your DHCP server, you'll need to configure it to support PXE booting:

1. Log in to your TP-Link ER605 V2 router's admin interface
2. Navigate to Network → DHCP → DHCP Settings
3. Ensure DHCP Service is enabled
4. Under DHCP Options Configuration, add the following options:
   - Option 66 (TFTP Server): [Your laptop's IP address]
   - Option 67 (Bootfile Name): pxelinux.0
5. Save the configuration

Alternatively, the deployment script offers a "proxy DHCP" mode that doesn't require router configuration but provides only PXE boot information alongside your router's DHCP service.

### 4. Run the Deployment Script

The main deployment script will guide you through the entire process:

```bash
sudo bash kube-lab/scripts/deploy_k8s.sh
```

The deployment process has three stages:

#### Stage 1: Network Boot Setup

- Configures your control machine as a PXE boot server
- Sets up DHCP, TFTP, and HTTP services for network booting
- Prepares Ubuntu installer and kickstart files

#### Stage 2: Node Verification

- Boots mini PCs from the network and installs Ubuntu automatically
- Verifies all nodes are online and accessible via SSH
- Ensures proper configuration for Kubernetes installation

#### Stage 3: Kubernetes Deployment

- Deploys Kubernetes using Ansible
- Configures the master node and worker nodes
- Sets up networking, storage, and basic cluster configuration
- Provides a kubeconfig file for cluster access

### 5. Access Your Kubernetes Cluster

Once the deployment is complete, you can access your Kubernetes cluster from your control machine:

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Detailed Documentation

For more detailed instructions and configuration options:

- Network boot setup: `docs/network-boot-setup.md`
- Kubernetes configuration: Review files in the `configs/kubernetes/` directory
- Ansible roles and playbooks: Explore the `ansible/` directory

## Troubleshooting

If you encounter issues during deployment:

1. Check network connectivity between your control machine and mini PCs
2. Ensure BIOS settings on mini PCs have network boot enabled
3. Verify there are no DHCP conflicts on your network
4. Review logs in the deployment terminal output
5. Check individual service logs:
   - DHCP/TFTP: `sudo journalctl -u dnsmasq -f`
   - Ansible: Check output during deployment

## Known Issues and TODO
### PXE Boot Container Improvements
1. Apache2 Service Stability
   - Fix Apache2 service startup issues in the container
   - Add proper error logging for Apache2 service
   - Implement proper Apache2 configuration for serving kickstart files

2. DNSmasq Configuration
   - Improve interface binding logic for DNSmasq
   - Add validation for network interface selection
   - Implement fallback mechanism for interface detection

3. Container Enhancements
   - Add proper user permissions for services
   - Implement health checks for all services
   - Add proper signal handling for container shutdown
   - Add volume persistence for TFTP and HTTP content

4. Error Handling
   - Implement better error reporting for service failures
   - Add diagnostic tools in the container
   - Create troubleshooting documentation

5. Testing
   - Add automated tests for the PXE boot process
   - Create network simulation tests
   - Add integration tests for all DHCP modes

### Future Improvements
1. Service Monitoring
   - Add Prometheus metrics for PXE boot services
   - Implement service status dashboard
   - Create alert system for service failures

2. Network Boot Security
   - Implement HTTPS for kickstart file delivery
   - Add authentication for PXE boot services
   - Implement secure boot chain

3. Documentation
   - Add detailed troubleshooting guide for each service
   - Create network requirements documentation
   - Add performance tuning guide

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Add your license information here]