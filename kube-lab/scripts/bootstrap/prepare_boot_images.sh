#!/bin/bash
# Script to prepare Ubuntu boot images for PXE installation
# This script downloads Ubuntu netboot files and sets them up for PXE booting

set -e

# Configuration
UBUNTU_VERSION="20.04"
UBUNTU_CODENAME="focal"
ARCHITECTURE="amd64"
TFTP_ROOT="/var/lib/tftpboot"
WORK_DIR="/tmp/netboot-setup"
HTTP_SERVER_ROOT="/var/www/html"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Preparing Ubuntu ${UBUNTU_VERSION} PXE Boot Images ===${NC}"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# Create working directory
echo -e "${YELLOW}Creating working directory...${NC}"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Download Ubuntu netboot files
echo -e "${YELLOW}Downloading Ubuntu ${UBUNTU_VERSION} netboot files...${NC}"
wget -q http://archive.ubuntu.com/ubuntu/dists/${UBUNTU_CODENAME}/main/installer-${ARCHITECTURE}/current/legacy-images/netboot/netboot.tar.gz
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to download netboot files. Check your internet connection and Ubuntu version.${NC}"
  exit 1
fi

# Extract netboot files
echo -e "${YELLOW}Extracting netboot files...${NC}"
tar -xzf netboot.tar.gz
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to extract netboot files.${NC}"
  exit 1
fi

# Ensure TFTP directory exists
echo -e "${YELLOW}Setting up TFTP directory...${NC}"
mkdir -p ${TFTP_ROOT}

# Copy netboot files to TFTP root
echo -e "${YELLOW}Copying netboot files to TFTP root...${NC}"
cp -r ubuntu-installer $TFTP_ROOT/
cp -r pxelinux.0 $TFTP_ROOT/
cp -r pxelinux.cfg $TFTP_ROOT/
cp -r ldlinux.c32 $TFTP_ROOT/

# Copy kernel and initrd to TFTP root for simplicity
echo -e "${YELLOW}Copying kernel and initramfs...${NC}"
cp $TFTP_ROOT/ubuntu-installer/${ARCHITECTURE}/linux $TFTP_ROOT/vmlinuz
cp $TFTP_ROOT/ubuntu-installer/${ARCHITECTURE}/initrd.gz $TFTP_ROOT/initrd.img

# Setup HTTP server for kickstart files
echo -e "${YELLOW}Setting up HTTP server for kickstart files...${NC}"
mkdir -p ${HTTP_SERVER_ROOT}/ks
cp /home/ubuntu/repos/kube-lab/kube-lab/network-boot/tftp/ks/master.ks ${HTTP_SERVER_ROOT}/ks/
cp /home/ubuntu/repos/kube-lab/kube-lab/network-boot/tftp/ks/worker.ks ${HTTP_SERVER_ROOT}/ks/

# Update PXE configuration for kickstart files
echo -e "${YELLOW}Updating PXE configuration...${NC}"
mkdir -p ${TFTP_ROOT}/pxelinux.cfg
cp /home/ubuntu/repos/kube-lab/kube-lab/network-boot/pxe/default ${TFTP_ROOT}/pxelinux.cfg/

# Set proper permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chmod -R 755 $TFTP_ROOT
chmod -R 755 ${HTTP_SERVER_ROOT}/ks

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
rm -rf $WORK_DIR

echo -e "${GREEN}PXE boot environment setup complete!${NC}"
echo -e "Ubuntu ${UBUNTU_VERSION} netboot files have been installed and configured."
echo -e "Boot files are located at: ${TFTP_ROOT}"
echo -e "Kickstart files are available at: http://your-server-ip/ks/"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Make sure your DHCP server is configured to point to this PXE server"
echo "2. Ensure your network boot environment is properly set up"
echo "3. Boot your nodes and select the appropriate installation option"

exit 0