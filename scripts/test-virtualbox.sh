#!/bin/bash

# test-virtualbox.sh - Configure and test PXE boot server with VirtualBox
# Created on: March 28, 2025

set -e

echo "=============================================="
echo "PXE Boot Server - VirtualBox Testing Setup"
echo "=============================================="

# Check if running in WSL
WSL_ENV=false
if grep -q Microsoft /proc/version; then
  echo "WSL environment detected."
  WSL_ENV=true
fi

# Stop any running containers
echo "Stopping any running PXE server containers..."
docker stop pxe-boot-server 2>/dev/null || true
docker rm pxe-boot-server 2>/dev/null || true

# Create temporary test configuration for VirtualBox
echo "Creating test configuration for VirtualBox..."
mkdir -p temp/dhcp

# Choose appropriate configuration based on environment
if [ "$WSL_ENV" = true ]; then
  echo "Using WSL-specific configuration for VirtualBox..."
  cp temp/dhcp/wsl-virtualbox.conf temp/dhcp/dnsmasq.conf
else
  # Generate regular test dnsmasq.conf for VirtualBox testing
  cat > temp/dhcp/dnsmasq.conf << 'EOF'
# Disable DNS server functionality
port=0

# Enable DHCP server - using VirtualBox host-only network range
dhcp-range=172.28.205.230,172.28.205.250,255.255.240.0,12h

# Network options
dhcp-option=3,172.28.205.1  # Router (option 3)
dhcp-option=6,8.8.8.8,8.8.4.4  # DNS Server (option 6)

# PXE boot options
# Enable PXE boot - using this machine's IP as the PXE server
dhcp-boot=pxelinux.0,pxeserver,172.28.205.1

# TFTP server configuration - using dnsmasq for TFTP too
enable-tftp
tftp-root=/tftpboot

# Logging
log-dhcp
log-queries

# Bind to all interfaces for test purposes
interface=*

# Don't use /etc/hosts or /etc/resolv.conf
no-hosts
no-resolv
EOF
fi

# If in WSL, try to set up port forwarding using socat for DHCP/TFTP
if [ "$WSL_ENV" = true ]; then
  echo "Setting up port forwarding for WSL-to-VirtualBox communication..."
  
  # Check if socat is installed
  if ! command -v socat &> /dev/null; then
    echo "socat not found. Installing..."
    sudo apt-get update && sudo apt-get install -y socat
  fi
  
  # Kill any existing socat processes
  echo "Stopping any existing port forwarding..."
  pkill -f "socat" 2>/dev/null || true
  
  # Get WSL IP
  WSL_IP=$(hostname -I | awk '{print $1}')
  
  # Start port forwarding for DHCP (UDP 67)
  echo "Starting DHCP port forwarding..."
  socat UDP4-LISTEN:67,fork,bind=0.0.0.0,range=0.0.0.0/0,reuseaddr UDP4:$WSL_IP:67 &
  SOCAT_PID_1=$!
  
  # Start port forwarding for TFTP (UDP 69)
  echo "Starting TFTP port forwarding..."
  socat UDP4-LISTEN:69,fork,bind=0.0.0.0,range=0.0.0.0/0,reuseaddr UDP4:$WSL_IP:69 &
  SOCAT_PID_2=$!
  
  # Save PIDs to file for later cleanup
  echo "$SOCAT_PID_1 $SOCAT_PID_2" > temp/socat_pids.txt
  
  echo "Port forwarding set up. DHCP/TFTP traffic from VirtualBox will be forwarded to WSL."
  echo "For WSL+VirtualBox setup: Remember to check your Windows firewall settings to allow UDP ports 67 and 69."
fi

# Create a docker-compose override file
cat > temp/docker-compose.override.yml << 'EOF'
version: '3'
services:
  pxe-server:
    volumes:
      - ./temp/dhcp/dnsmasq.conf:/etc/dnsmasq.conf:ro
EOF

# Start the container with test configuration
echo "Starting PXE server with VirtualBox test configuration..."
docker run -d --name pxe-boot-server --network host --privileged -v $(pwd)/temp/dhcp/dnsmasq.conf:/etc/dnsmasq.conf:ro pxe-boot-server

echo "=============================================="
echo "PXE Boot Server started in VirtualBox test mode"
echo ""
echo "Now follow these steps:"
echo "1. Start your VirtualBox VM configured for PXE boot"
echo "2. The VM should get an IP from the PXE server"
echo "3. Monitor the web UI at http://172.28.205.1"
echo "4. When done testing, stop this container with:"
echo "   docker stop pxe-boot-server"
echo "=============================================="

# If in WSL, show additional instructions
if [ "$WSL_ENV" = true ]; then
  echo ""
  echo "WSL + VirtualBox Special Instructions:"
  echo "-------------------------------------"
  echo "- If your VirtualBox VM still can't connect, check Windows Defender firewall"
  echo "  and allow UDP ports 67 and 69 through it."
  echo "- You might need to temporarily disable Windows Firewall for testing."
  echo "- When done, stop the port forwarding with: pkill -f socat"
  echo "=============================================="
fi