#!/bin/bash

# test-virtualbox.sh - Configure and test PXE boot server with VirtualBox
# Created on: March 28, 2025

set -e

echo "=============================================="
echo "PXE Boot Server - VirtualBox Testing Setup"
echo "=============================================="

# Remove WSL check since we're running directly in Linux
# if ! grep -q Microsoft /proc/version; then
#   echo "This script is designed to run in WSL with VirtualBox on Windows host"
#   exit 1
# fi

# Stop any running containers
echo "Stopping any running PXE server containers..."
docker-compose -f docker/docker-compose.yml down || true

# Create temporary test configuration for VirtualBox
echo "Creating test configuration for VirtualBox..."
mkdir -p temp/dhcp

# Generate test dnsmasq.conf for VirtualBox testing
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

# Start the container with test configuration
echo "Starting PXE server with VirtualBox test configuration..."
docker-compose -f docker/docker-compose.yml -f - up -d << 'EOF'
version: '3'
services:
  pxe-server:
    volumes:
      - ./temp/dhcp/dnsmasq.conf:/etc/dnsmasq.conf:ro
EOF

echo "=============================================="
echo "PXE Boot Server started in VirtualBox test mode"
echo ""
echo "Now follow these steps:"
echo "1. Start your VirtualBox VM configured for PXE boot"
echo "2. The VM should get an IP from the PXE server"
echo "3. Monitor the logs with: docker logs pxe-boot-server -f"
echo "4. When done testing, stop this container with:"
echo "   docker-compose -f docker/docker-compose.yml down"
echo "=============================================="