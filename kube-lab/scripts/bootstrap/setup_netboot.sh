#!/bin/bash
# Script to set up network boot services on the control laptop
# Modified to work with an existing TP-Link ER605 V2 DHCP server

set -e

# Ensure script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN} Setting up network boot environment ${NC}"
echo -e "${GREEN} Compatible with TP-Link ER605 V2 ${NC}"
echo -e "${GREEN}====================================${NC}"

# Get the project root directory
SCRIPT_DIR=$(dirname $(realpath $0))
PROJECT_ROOT=$(dirname $(dirname $SCRIPT_DIR))

# Display DHCP configuration options
echo -e "${YELLOW}DHCP Server Configuration Options:${NC}"
echo "1. Configure TP-Link ER605 V2 router for PXE booting (recommended)"
echo "2. Use dnsmasq in proxy DHCP mode (advanced)"
echo ""
read -p "Select option [1-2]: " dhcp_option

if [ "$dhcp_option" = "1" ]; then
  echo -e "${YELLOW}You've chosen to configure your TP-Link router for PXE booting.${NC}"
  echo -e "${YELLOW}Please follow these steps on your router:${NC}"
  echo "1. Log into your TP-Link ER605 V2 router admin interface"
  echo "2. Go to Network → DHCP → DHCP Settings"
  echo "3. Enable DHCP Service if not already enabled"
  echo "4. Under DHCP Options Configuration, add the following options:"
  echo "   - Option 66 (TFTP Server): [Enter your laptop's IP address]"
  echo "   - Option 67 (Bootfile Name): pxelinux.0"
  echo "5. Save the configuration and apply changes"
  echo ""
  read -p "Have you configured your router for PXE booting? (y/n): " router_configured
  
  if [ "$router_configured" != "y" ]; then
    echo -e "${RED}Please configure your router before continuing.${NC}"
    exit 1
  fi
  
  # Not using dnsmasq for DHCP, only for TFTP
  USE_DNSMASQ_DHCP=false
else
  echo -e "${YELLOW}You've chosen to use dnsmasq in proxy DHCP mode.${NC}"
  echo "This mode will only provide PXE boot information without interfering with your router's IP assignments."
  echo ""
  USE_DNSMASQ_DHCP=true
fi

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
apt-get update
apt-get install -y dnsmasq syslinux pxelinux nfs-kernel-server apache2

# Setup TFTP directory
echo -e "${YELLOW}Setting up TFTP server...${NC}"
mkdir -p /var/lib/tftpboot
cp -r /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot/ 2>/dev/null || cp -r /usr/lib/syslinux/pxelinux.0 /var/lib/tftpboot/
cp -r /usr/lib/syslinux/modules/bios/menu.c32 /var/lib/tftpboot/ 2>/dev/null || cp -r /usr/lib/syslinux/menu.c32 /var/lib/tftpboot/
cp -r /usr/lib/syslinux/modules/bios/ldlinux.c32 /var/lib/tftpboot/ 2>/dev/null || cp -r /usr/lib/syslinux/ldlinux.c32 /var/lib/tftpboot/
cp -r /usr/lib/syslinux/modules/bios/libutil.c32 /var/lib/tftpboot/ 2>/dev/null || cp -r /usr/lib/syslinux/libutil.c32 /var/lib/tftpboot/

# Create PXE boot directory structure
mkdir -p /var/lib/tftpboot/pxelinux.cfg
cp $PROJECT_ROOT/network-boot/pxe/default /var/lib/tftpboot/pxelinux.cfg/

# Setup NFS shares for network boot
echo -e "${YELLOW}Setting up NFS shares...${NC}"
mkdir -p /nfs/kubernetes-master /nfs/kubernetes-worker

# Add NFS exports
cat > /etc/exports <<EOF
/nfs/kubernetes-master *(ro,sync,no_subtree_check)
/nfs/kubernetes-worker *(ro,sync,no_subtree_check)
EOF

# Create directories for kickstart files
echo -e "${YELLOW}Setting up HTTP server for kickstart files...${NC}"
mkdir -p /var/www/html/ks
cp $PROJECT_ROOT/network-boot/tftp/ks/master.ks /var/www/html/ks/
cp $PROJECT_ROOT/network-boot/tftp/ks/worker.ks /var/www/html/ks/
chmod 644 /var/www/html/ks/*

# Configure dnsmasq based on selected option
echo -e "${YELLOW}Configuring TFTP server...${NC}"

# Ask for network interface to use
echo -e "${YELLOW}Available network interfaces:${NC}"
ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}'

read -p "Enter the network interface to use for the TFTP server (e.g. eth0): " NETWORK_INTERFACE

# Get laptop's IP address on selected interface
LAPTOP_IP=$(ip -o -4 addr show $NETWORK_INTERFACE | awk '{print $4}' | cut -d/ -f1)

if [ -z "$LAPTOP_IP" ]; then
  echo -e "${RED}Could not determine IP address for interface ${NETWORK_INTERFACE}${NC}"
  read -p "Please enter your laptop's IP address manually: " LAPTOP_IP
fi

echo -e "${GREEN}Using IP address: ${LAPTOP_IP}${NC}"

# Configure dnsmasq.conf differently based on the selected option
if [ "$USE_DNSMASQ_DHCP" = true ]; then
  # Create dnsmasq.conf for proxy DHCP mode
  cat > /etc/dnsmasq.conf <<EOF
# dnsmasq configuration for PXE Boot in proxy DHCP mode
# This mode works alongside your existing DHCP server

# Listen on specific interface
interface=${NETWORK_INTERFACE}

# Run as proxy DHCP server, not replacing existing DHCP server
dhcp-range=${LAPTOP_IP},proxy

# PXE boot options
dhcp-boot=pxelinux.0,pxeserver,${LAPTOP_IP}

# TFTP server
enable-tftp
tftp-root=/var/lib/tftpboot

# Log settings
log-dhcp
log-queries
EOF

  echo -e "${YELLOW}Configured dnsmasq in proxy DHCP mode.${NC}"
  echo "This will provide only PXE boot information while your TP-Link router handles IP assignments."
else
  # Create dnsmasq.conf for TFTP only
  cat > /etc/dnsmasq.conf <<EOF
# dnsmasq configuration for TFTP only
# DHCP handled by TP-Link ER605 V2 router

# Don't function as a DHCP server
no-dhcp-interface=${NETWORK_INTERFACE}

# Listen on specific interface
interface=${NETWORK_INTERFACE}

# TFTP server
enable-tftp
tftp-root=/var/lib/tftpboot

# Log settings
log-queries
EOF

  echo -e "${YELLOW}Configured dnsmasq for TFTP service only.${NC}"
  echo "Make sure your TP-Link router is configured with options 66 and 67 as instructed."
fi

# Prepare the boot images
echo -e "${YELLOW}Preparing boot images...${NC}"
bash $PROJECT_ROOT/scripts/bootstrap/prepare_boot_images.sh

# Update the PXE configuration with correct server IP
echo -e "${YELLOW}Updating PXE configuration with server IP...${NC}"
sed -i "s/192.168.1.10/${LAPTOP_IP}/g" /var/lib/tftpboot/pxelinux.cfg/default

# Restart services
echo -e "${YELLOW}Restarting services...${NC}"
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server
systemctl enable apache2
systemctl restart apache2
systemctl stop dnsmasq
systemctl enable dnsmasq
systemctl start dnsmasq

echo -e "${GREEN}Network boot environment setup complete!${NC}"
echo ""
echo -e "${YELLOW}Important Notes for TP-Link ER605 V2 Router Users:${NC}"
echo "1. Your TFTP server is running at: ${LAPTOP_IP}"
echo "2. If using router configuration (option 1):"
echo "   - Ensure option 66 is set to: ${LAPTOP_IP}"
echo "   - Ensure option 67 is set to: pxelinux.0"
echo "3. Kickstart files are available at: http://${LAPTOP_IP}/ks/"
echo ""
echo "To monitor DHCP/TFTP logs, run: sudo journalctl -u dnsmasq -f"
echo "To test PXE boot, configure your mini PCs to boot from network and power them on."

exit 0