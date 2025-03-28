#!/bin/bash
# Script to prepare Ubuntu boot images for PXE installation inside a container

set -e

# Configuration
UBUNTU_VERSION="20.04"
UBUNTU_CODENAME="focal"
ARCHITECTURE="amd64"
TFTP_ROOT="/var/lib/tftpboot"
WORK_DIR="/tmp/netboot-setup"

echo "=== Preparing Ubuntu ${UBUNTU_VERSION} PXE Boot Images ==="

# Create working directory
echo "Creating working directory..."
mkdir -p $WORK_DIR
cd $WORK_DIR

# Download Ubuntu netboot files
echo "Downloading Ubuntu ${UBUNTU_VERSION} netboot files..."
wget -q http://archive.ubuntu.com/ubuntu/dists/${UBUNTU_CODENAME}/main/installer-${ARCHITECTURE}/current/legacy-images/netboot/netboot.tar.gz
if [ $? -ne 0 ]; then
  echo "Failed to download netboot files. Check your internet connection and Ubuntu version."
  exit 1
fi

# Extract netboot files
echo "Extracting netboot files..."
tar -xzf netboot.tar.gz
if [ $? -ne 0 ]; then
  echo "Failed to extract netboot files."
  exit 1
fi

# Copy netboot files to TFTP root
echo "Copying netboot files to TFTP root..."
cp -r ubuntu-installer $TFTP_ROOT/
cp -r pxelinux.0 $TFTP_ROOT/ 2>/dev/null || echo "pxelinux.0 already exists"
cp -r pxelinux.cfg $TFTP_ROOT/ 2>/dev/null || echo "pxelinux.cfg already exists"
cp -r ldlinux.c32 $TFTP_ROOT/ 2>/dev/null || echo "ldlinux.c32 already exists"

# Copy kernel and initrd to TFTP root for simplicity
echo "Copying kernel and initramfs..."
cp $TFTP_ROOT/ubuntu-installer/${ARCHITECTURE}/linux $TFTP_ROOT/vmlinuz
cp $TFTP_ROOT/ubuntu-installer/${ARCHITECTURE}/initrd.gz $TFTP_ROOT/initrd.img

# Set proper permissions
echo "Setting permissions..."
chmod -R 755 $TFTP_ROOT

# Clean up
echo "Cleaning up..."
rm -rf $WORK_DIR

echo "PXE boot environment setup complete!"
echo "Ubuntu ${UBUNTU_VERSION} netboot files have been installed and configured."

exit 0