#!/bin/bash
# Script to set up network boot services on the control laptop

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
echo -e "${GREEN}====================================${NC}"

# Get the project root directory
SCRIPT_DIR=$(dirname $(realpath $0))
PROJECT_ROOT=$(dirname $(dirname $SCRIPT_DIR))

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
apt-get update
apt-get install -y dnsmasq syslinux pxelinux nfs-kernel-server apache2 isc-dhcp-server

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

# Configure dnsmasq for DHCP and TFTP
echo -e "${YELLOW}Configuring DHCP server (dnsmasq)...${NC}"
cp $PROJECT_ROOT/network-boot/dhcp/dnsmasq.conf /etc/dnsmasq.conf

# Update the tftp-root directory in dnsmasq.conf to match the system path
sed -i 's|tftp-root=.*|tftp-root=/var/lib/tftpboot|g' /etc/dnsmasq.conf

# Ask for network interface to use
echo -e "${YELLOW}Available network interfaces:${NC}"
ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}'

read -p "Enter the network interface to use for DHCP/PXE (e.g. eth0): " NETWORK_INTERFACE

# Update interface in dnsmasq.conf
sed -i "s/^interface=.*/interface=${NETWORK_INTERFACE}/g" /etc/dnsmasq.conf

# Ask for DHCP range
read -p "Enter the DHCP range start IP (e.g. 192.168.1.100): " DHCP_START
read -p "Enter the DHCP range end IP (e.g. 192.168.1.200): " DHCP_END
read -p "Enter the subnet mask (e.g. 255.255.255.0): " SUBNET_MASK
read -p "Enter the router/gateway IP (e.g. 192.168.1.1): " ROUTER_IP
read -p "Enter the DNS server IP (typically same as router): " DNS_IP
read -p "Enter the TFTP server IP (this machine's IP on the network): " TFTP_IP

# Update dnsmasq.conf with provided information
sed -i "s/^dhcp-range=.*/dhcp-range=${DHCP_START},${DHCP_END},${SUBNET_MASK},12h/g" /etc/dnsmasq.conf
sed -i "s/^dhcp-option=option:router,.*/dhcp-option=option:router,${ROUTER_IP}/g" /etc/dnsmasq.conf
sed -i "s/^dhcp-option=option:dns-server,.*/dhcp-option=option:dns-server,${DNS_IP}/g" /etc/dnsmasq.conf
sed -i "s/^dhcp-boot=pxelinux.0,pxeserver,.*/dhcp-boot=pxelinux.0,pxeserver,${TFTP_IP}/g" /etc/dnsmasq.conf
sed -i "s/^dhcp-option=66,.*/dhcp-option=66,${TFTP_IP}/g" /etc/dnsmasq.conf

# Disable the ISC DHCP server to avoid conflicts
systemctl stop isc-dhcp-server
systemctl disable isc-dhcp-server

# Prepare the boot images
echo -e "${YELLOW}Preparing boot images...${NC}"
bash $PROJECT_ROOT/scripts/bootstrap/prepare_boot_images.sh

# Restart services
echo -e "${YELLOW}Restarting services...${NC}"
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server
systemctl enable apache2
systemctl restart apache2
systemctl stop dnsmasq
systemctl disable dnsmasq.service # Don't start automatically on boot

echo -e "${GREEN}Network boot environment setup complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Make sure no other DHCP servers are running on your network"
echo "2. Start the DHCP/TFTP service when ready with: sudo systemctl start dnsmasq"
echo "3. Configure your mini PCs to boot from network (PXE)"
echo "4. Power on your mini PCs and they should boot from the network"
echo ""
echo "To start the DHCP/TFTP service now, run: sudo systemctl start dnsmasq"
echo "To see the DHCP/TFTP logs, run: sudo journalctl -u dnsmasq -f"

exit 0