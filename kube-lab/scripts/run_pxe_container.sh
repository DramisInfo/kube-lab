#!/bin/bash
# Script to build and run the PXE boot server container

set -e

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get project root directory
SCRIPT_DIR=$(dirname $(realpath $0))
PROJECT_ROOT=$(dirname $SCRIPT_DIR)
NETWORK_BOOT_DIR="${PROJECT_ROOT}/network-boot"

# Print header
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN} Containerized PXE Boot Server      ${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker and try again.${NC}"
    exit 1
fi

# Build the Docker image if it doesn't exist
if ! docker image inspect kube-lab-pxe:latest &> /dev/null; then
    echo -e "${YELLOW}Building PXE boot server Docker image...${NC}"
    cd ${NETWORK_BOOT_DIR}
    docker build -t kube-lab-pxe:latest .

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to build the Docker image.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Docker image built successfully.${NC}"
else
    echo -e "${GREEN}Using existing Docker image kube-lab-pxe:latest${NC}"
fi

# Get network interface
echo -e "${YELLOW}Available network interfaces:${NC}"
ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}'
echo ""

read -p "Enter the network interface to use (e.g., eth0): " INTERFACE
CONTAINER_IP=$(ip -o -4 addr show $INTERFACE | awk '{print $4}' | cut -d/ -f1)

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}Could not determine IP address for interface ${INTERFACE}${NC}"
    read -p "Please enter your machine's IP address manually: " CONTAINER_IP
fi

echo ""
echo -e "${YELLOW}DHCP Configuration Options:${NC}"
echo "1. TFTP-only mode (For use with TP-Link ER605 V2 router, options 66/67)"
echo "2. Proxy DHCP mode (Works alongside existing DHCP server)"
echo "3. Full DHCP server mode (Not recommended with existing DHCP server)"
echo ""
read -p "Select DHCP mode [1-3]: " DHCP_OPTION

case $DHCP_OPTION in
    1)
        DHCP_MODE="tftp-only"
        echo -e "${YELLOW}Selected TFTP-only mode${NC}"
        echo "Please configure your TP-Link router with:"
        echo "  - Option 66 (TFTP Server): ${CONTAINER_IP}"
        echo "  - Option 67 (Bootfile Name): pxelinux.0"
        ;;
    2)
        DHCP_MODE="proxy"
        echo -e "${YELLOW}Selected Proxy DHCP mode${NC}"
        ;;
    3)
        DHCP_MODE="full"
        echo -e "${YELLOW}Selected Full DHCP server mode${NC}"
        
        # Get DHCP configuration if full DHCP mode
        read -p "Enter DHCP range start IP (e.g., 192.168.1.100): " DHCP_RANGE_START
        read -p "Enter DHCP range end IP (e.g., 192.168.1.200): " DHCP_RANGE_END
        read -p "Enter subnet mask (e.g., 255.255.255.0): " DHCP_SUBNET
        read -p "Enter router IP (e.g., 192.168.1.1): " ROUTER_IP
        ;;
    *)
        echo -e "${RED}Invalid option selected${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Starting PXE boot container...${NC}"

# Prepare Docker run command
DOCKER_CMD="docker run -d --name kube-lab-pxe --restart=unless-stopped"
DOCKER_CMD+=" --net=host"  # Use host networking for proper network services
DOCKER_CMD+=" -v ${NETWORK_BOOT_DIR}/tftp/ks:/var/www/html/ks"
DOCKER_CMD+=" -e INTERFACE=${INTERFACE}"
DOCKER_CMD+=" -e DHCP_MODE=${DHCP_MODE}"
DOCKER_CMD+=" -e SERVER_IP=${CONTAINER_IP}"

# Add optional parameters for full DHCP mode
if [ "$DHCP_MODE" = "full" ]; then
    DOCKER_CMD+=" -e DHCP_RANGE_START=${DHCP_RANGE_START}"
    DOCKER_CMD+=" -e DHCP_RANGE_END=${DHCP_RANGE_END}"
    DOCKER_CMD+=" -e DHCP_SUBNET=${DHCP_SUBNET}"
    DOCKER_CMD+=" -e ROUTER_IP=${ROUTER_IP}"
fi

DOCKER_CMD+=" kube-lab-pxe:latest"

# Remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q '^kube-lab-pxe$'; then
    echo -e "${YELLOW}Removing existing PXE boot container...${NC}"
    docker rm -f kube-lab-pxe
fi

# Run the container
eval $DOCKER_CMD

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start the PXE boot container.${NC}"
    exit 1
fi

echo -e "${GREEN}PXE boot container started successfully!${NC}"
echo ""
echo -e "${YELLOW}Container Info:${NC}"
echo "  - PXE Server IP: ${CONTAINER_IP}"
echo "  - DHCP Mode: ${DHCP_MODE}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure your mini PCs to boot from network (PXE)"
echo "2. Power on your mini PCs and they should boot from the network"
echo "3. After OS installation, run the main deploy_k8s.sh script to install Kubernetes"
echo ""
echo "To view logs from the container:"
echo "  docker logs -f kube-lab-pxe"
echo ""
echo "To stop the container:"
echo "  docker stop kube-lab-pxe"

exit 0