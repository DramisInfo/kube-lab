#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting PXE Boot Server setup...${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker Compose is installed (either v1 or v2)
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Get the default network interface
DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
DEFAULT_IP=$(ip addr show ${DEFAULT_INTERFACE} | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
DEFAULT_GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
DEFAULT_SUBNET=$(ip route | grep ${DEFAULT_INTERFACE} | grep -v default | awk '{print $1}' | head -n 1)

# Extract subnet information
if [[ "$DEFAULT_SUBNET" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.0/[0-9]+$ ]]; then
    SUBNET_PREFIX=${BASH_REMATCH[1]}
    
    # Create DHCP range
    RANGE_START="${SUBNET_PREFIX}.100"
    RANGE_END="${SUBNET_PREFIX}.200"
    NETMASK="255.255.255.0"
else
    echo -e "${YELLOW}Could not determine subnet automatically. Using defaults.${NC}"
    SUBNET_PREFIX="192.168.1"
    RANGE_START="${SUBNET_PREFIX}.100"
    RANGE_END="${SUBNET_PREFIX}.200"
    NETMASK="255.255.255.0"
fi

# Display network information
echo -e "${GREEN}Network Configuration:${NC}"
echo "Interface: ${DEFAULT_INTERFACE}"
echo "Server IP: ${DEFAULT_IP}"
echo "Gateway: ${DEFAULT_GATEWAY}"
echo "DHCP Range: ${RANGE_START} - ${RANGE_END}"

# Ask user for confirmation
read -p "Do you want to continue with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    # Ask for custom settings
    echo -e "${YELLOW}Please enter your custom network settings:${NC}"
    read -p "Network Interface (e.g., eth0): " CUSTOM_INTERFACE
    read -p "DHCP Range Start (e.g., 192.168.1.100): " CUSTOM_RANGE_START
    read -p "DHCP Range End (e.g., 192.168.1.200): " CUSTOM_RANGE_END
    read -p "Gateway IP (e.g., 192.168.1.1): " CUSTOM_GATEWAY
    read -p "Netmask (e.g., 255.255.255.0): " CUSTOM_NETMASK
    
    # Use custom settings if provided
    DEFAULT_INTERFACE=${CUSTOM_INTERFACE:-$DEFAULT_INTERFACE}
    RANGE_START=${CUSTOM_RANGE_START:-$RANGE_START}
    RANGE_END=${CUSTOM_RANGE_END:-$RANGE_END}
    DEFAULT_GATEWAY=${CUSTOM_GATEWAY:-$DEFAULT_GATEWAY}
    NETMASK=${CUSTOM_NETMASK:-$NETMASK}
fi

# Set environment variables for docker-compose
export INTERFACE=${DEFAULT_INTERFACE}
export SUBNET=${DEFAULT_SUBNET}
export NETMASK=${NETMASK}
export RANGE_START=${RANGE_START}
export RANGE_END=${RANGE_END}
export GATEWAY=${DEFAULT_GATEWAY}
export DNS="8.8.8.8,8.8.4.4"

# Navigate to the docker directory and build/start the container
cd "$(dirname "$0")/docker"

echo -e "${YELLOW}Building and starting the PXE Boot Server container...${NC}"
${DOCKER_COMPOSE} down -v
${DOCKER_COMPOSE} up --build -d

# Check if the container started successfully
if [ $? -eq 0 ]; then
    echo -e "${GREEN}PXE Boot Server started successfully!${NC}"
    echo -e "Access the web UI at: ${GREEN}http://${DEFAULT_IP}${NC}"
    echo -e "To stop the server, run: ${YELLOW}${DOCKER_COMPOSE} down${NC}"
else
    echo -e "${RED}Failed to start the PXE Boot Server container. Please check the logs.${NC}"
    exit 1
fi