#!/bin/bash
# Main script to deploy Kubernetes homelab
# This script will orchestrate the entire deployment process

set -e

SCRIPT_DIR=$(dirname $(realpath $0))
PROJECT_ROOT=$(dirname $SCRIPT_DIR)

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN} Kubernetes Homelab Deployment Tool ${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required tools
echo -e "${YELLOW}Checking prerequisites...${NC}"
for cmd in ansible-playbook ssh; do
  if ! command_exists $cmd; then
    echo -e "${RED}Error: $cmd is not installed. Please install it and try again.${NC}"
    exit 1
  fi
done
echo -e "${GREEN}All prerequisites are installed.${NC}"
echo ""

# Stage 1: Setup network boot environment
echo -e "${YELLOW}=== STAGE 1: NETWORK BOOT SETUP ===${NC}"
echo "This stage will set up the network boot environment on your laptop."
echo "You will be able to boot your mini PCs from the network and install Ubuntu."
read -p "Do you want to set up the network boot environment? (y/n): " setup_netboot

if [ "$setup_netboot" = "y" ]; then
  echo -e "${YELLOW}Setting up network boot environment...${NC}"
  echo "This will require sudo privileges to install and configure services."
  sudo bash "$PROJECT_ROOT/scripts/bootstrap/setup_netboot.sh"
  
  # Confirm network boot setup completed
  read -p "Did the network boot setup complete successfully? (y/n): " netboot_success
  if [ "$netboot_success" != "y" ]; then
    echo -e "${RED}Network boot setup did not complete successfully.${NC}"
    echo "Please check the errors and try again."
    exit 1
  fi
  
  # Ask to start DHCP/TFTP service
  read -p "Do you want to start the DHCP/TFTP service now? (y/n): " start_dhcp
  if [ "$start_dhcp" = "y" ]; then
    echo -e "${YELLOW}Starting DHCP/TFTP service...${NC}"
    sudo systemctl start dnsmasq
    echo -e "${GREEN}DHCP/TFTP service started.${NC}"
    echo "You can check the logs with: sudo journalctl -u dnsmasq -f"
  else
    echo "You can start the DHCP/TFTP service later with: sudo systemctl start dnsmasq"
  fi
  
  # Instructions for network booting
  echo -e "${YELLOW}Instructions for network booting:${NC}"
  echo "1. Make sure your mini PCs are configured to boot from network (PXE)"
  echo "2. Connect your laptop and mini PCs to the same network"
  echo "3. Power on your mini PCs and they should boot from the network"
  echo "4. Select the appropriate installation option (master or worker)"
  echo ""
  
  # Ask to proceed with booting
  read -p "Have you configured your mini PCs for network boot? (y/n): " configured_netboot
  if [ "$configured_netboot" != "y" ]; then
    echo -e "${YELLOW}Please configure your mini PCs for network boot before proceeding.${NC}"
    echo "You can run this script again later to continue with the deployment."
    exit 0
  fi
  
  # Start OS installation
  echo -e "${YELLOW}Starting OS installation via network boot...${NC}"
  echo "Please power on your mini PCs now."
  echo "They will boot from the network and automatically install Ubuntu."
  echo "This process may take 10-15 minutes per node."
  echo ""
  read -p "Press Enter once all mini PCs have completed the OS installation and rebooted..."
else
  echo -e "${YELLOW}Skipping network boot setup.${NC}"
  echo "Assuming you have already installed the operating system on your mini PCs."
  echo ""
fi

# Stage 2: Wait for nodes to become available
echo -e "${YELLOW}=== STAGE 2: VERIFYING NODE AVAILABILITY ===${NC}"
echo "This stage will check if all your nodes are reachable via SSH."

# Check if hosts are reachable
echo "Checking if hosts are reachable..."
while true; do
  unreachable=0
  
  # Parse the Ansible inventory to get the hosts
  while IFS= read -r line; do
    if [[ $line =~ ansible_host=([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
      host="${BASH_REMATCH[1]}"
      echo -n "Checking $host: "
      if ping -c 1 -W 1 "$host" > /dev/null 2>&1; then
        echo -e "${GREEN}Ping OK${NC}"
        
        # Try SSH connection
        if ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$host exit 2>/dev/null; then
          echo -e "SSH: ${GREEN}OK${NC}"
        else
          echo -e "SSH: ${RED}Failed${NC}"
          ((unreachable++))
        fi
      else
        echo -e "${RED}Ping Failed${NC}"
        ((unreachable++))
      fi
    fi
  done < "$PROJECT_ROOT/ansible/inventory/hosts.ini"
  
  if [ "$unreachable" -eq 0 ]; then
    echo -e "${GREEN}All hosts are reachable via ping and SSH.${NC}"
    break
  else
    echo -e "${YELLOW}$unreachable hosts are not fully reachable.${NC}"
    read -p "Do you want to try again? (y/n): " retry
    if [ "$retry" != "y" ]; then
      echo -e "${RED}Cannot continue without all hosts being reachable.${NC}"
      echo "Please check your network and host configurations."
      exit 1
    fi
  fi
done

# Stage 3: Execute Ansible playbook to set up kubernetes
echo -e "${YELLOW}=== STAGE 3: KUBERNETES DEPLOYMENT ===${NC}"
echo "This stage will use Ansible to configure Kubernetes on your nodes."
read -p "Do you want to proceed with Kubernetes deployment? (y/n): " deploy_k8s

if [ "$deploy_k8s" = "y" ]; then
  echo -e "${YELLOW}Running Ansible playbooks to configure Kubernetes...${NC}"
  cd "$PROJECT_ROOT/ansible"
  ansible-playbook -i inventory/hosts.ini playbooks/k8s-cluster.yml -v

  # Check if deployment was successful
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Kubernetes deployment completed successfully!${NC}"
    
    # Fetch kubeconfig
    echo "Fetching kubeconfig from master node..."
    master_ip=$(grep -oP 'ansible_host=\K[0-9.]+' "$PROJECT_ROOT/ansible/inventory/hosts.ini" | head -n 1)
    
    mkdir -p "$HOME/.kube"
    scp -o StrictHostKeyChecking=no ubuntu@$master_ip:/home/ubuntu/.kube/config "$HOME/.kube/config"
    
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN} Kubernetes homelab deployment successful! ${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo "You can now access your Kubernetes cluster using:"
    echo "kubectl get nodes"
  else
    echo -e "${RED}Kubernetes deployment failed.${NC}"
    echo "Please check the error messages above."
    exit 1
  fi
else
  echo -e "${YELLOW}Skipping Kubernetes deployment.${NC}"
  echo "You can deploy Kubernetes later by running this script again."
fi

exit 0