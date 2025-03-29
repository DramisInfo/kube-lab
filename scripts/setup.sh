#!/bin/bash
set -e

echo "Starting PXE boot server setup..."

# Process dnsmasq configuration to replace environment variables
echo "Generating dnsmasq configuration..."
cat /etc/dnsmasq.conf | envsubst > /tmp/dnsmasq.conf
mv /tmp/dnsmasq.conf /etc/dnsmasq.conf

# Process dnsmasq.d configuration files too if they exist
if [ -d /etc/dnsmasq.d ]; then
    for f in /etc/dnsmasq.d/*; do
        if [ -f "$f" ]; then
            echo "Processing $f..."
            cat "$f" | envsubst > /tmp/$(basename "$f")
            mv /tmp/$(basename "$f") "$f"
        fi
    done
fi

# Create necessary directories
mkdir -p /tftpboot/pxelinux.cfg
mkdir -p /var/www/html/ubuntu
mkdir -p /tftpboot/ubuntu

# Download and set up SYSLINUX for PXE booting
if [ ! -f /tftpboot/pxelinux.0 ]; then
    echo "Setting up SYSLINUX for PXE booting..."
    apt-get update
    apt-get install -y syslinux pxelinux syslinux-common
    
    # Copy required SYSLINUX files
    cp /usr/lib/PXELINUX/pxelinux.0 /tftpboot/
    cp /usr/lib/syslinux/modules/bios/*.c32 /tftpboot/
    
    # Create default PXE configuration
    cat > /tftpboot/pxelinux.cfg/default << EOF
DEFAULT menu.c32
PROMPT 0
TIMEOUT 300
ONTIMEOUT ubuntu

MENU TITLE PXE Boot Menu

LABEL ubuntu
    MENU LABEL Install Ubuntu 22.04 LTS
    KERNEL ubuntu/vmlinuz
    APPEND initrd=ubuntu/initrd.gz url=http://172.28.192.1/ubuntu/preseed.cfg auto=true priority=critical vga=normal --- quiet
    
LABEL local
    MENU LABEL Boot from local disk
    LOCALBOOT 0
EOF
fi

# Create placeholder Ubuntu netboot files to ensure system can start
echo "Creating placeholder netboot files..."
touch /tftpboot/ubuntu/vmlinuz
touch /tftpboot/ubuntu/initrd.gz

# Try to download real Ubuntu netboot files in background
echo "Attempting to download Ubuntu netboot files in background (continuing setup regardless)..."
(
    mkdir -p /tmp/ubuntu-netboot
    cd /tmp/ubuntu-netboot
    
    # Try different Ubuntu 22.04 (Jammy) netboot file locations
    echo "Trying legacy-images location..."
    if wget -q http://archive.ubuntu.com/ubuntu/dists/jammy/main/installer-amd64/current/legacy-images/netboot/netboot.tar.gz; then
        echo "Successfully downloaded from legacy-images location"
    else
        echo "Trying alternate URL..."
        wget -q http://archive.ubuntu.com/ubuntu/dists/jammy-updates/main/installer-amd64/current/legacy-images/netboot/netboot.tar.gz
    fi
    
    if [ -f netboot.tar.gz ]; then
        echo "Extracting netboot files..."
        tar -xzf netboot.tar.gz
        mkdir -p /tftpboot/ubuntu
        if [ -f ubuntu-installer/amd64/linux ]; then
            cp ubuntu-installer/amd64/linux /tftpboot/ubuntu/vmlinuz
            cp ubuntu-installer/amd64/initrd.gz /tftpboot/ubuntu/initrd.gz
            echo "Successfully installed Ubuntu netboot files"
            chmod 644 /tftpboot/ubuntu/vmlinuz /tftpboot/ubuntu/initrd.gz
        else
            echo "Warning: Expected files not found in netboot.tar.gz"
        fi
    else
        echo "Failed to download Ubuntu netboot files. Using placeholders."
    fi
    
    # Clean up
    cd /
    rm -rf /tmp/ubuntu-netboot
) &

# Create preseed configuration if not present
if [ ! -f /var/www/html/ubuntu/preseed.cfg ]; then
    echo "Creating preseed configuration..."
    mkdir -p /var/www/html/ubuntu
    
    cat > /var/www/html/ubuntu/preseed.cfg << EOF
# Localization
d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us

# Network configuration
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string ubuntu-mini-pc
d-i netcfg/get_domain string local

# Mirror settings
d-i mirror/country string manual
d-i mirror/http/hostname string archive.ubuntu.com
d-i mirror/http/directory string /ubuntu
d-i mirror/http/proxy string

# Account setup
d-i passwd/user-fullname string Ubuntu User
d-i passwd/username string ubuntu
d-i passwd/user-password password ubuntu
d-i passwd/user-password-again password ubuntu
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

# Clock and time zone setup
d-i clock-setup/utc boolean true
d-i time/zone string UTC
d-i clock-setup/ntp boolean true

# Partitioning
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# Package selection
tasksel tasksel/first multiselect standard, ubuntu-desktop
d-i pkgsel/include string openssh-server build-essential net-tools
d-i pkgsel/upgrade select full-upgrade

# Boot loader installation
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default

# Finishing up the installation
d-i finish-install/reboot_in_progress note

# Post-installation script
d-i preseed/late_command string \
    in-target bash -c "echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu && chmod 440 /etc/sudoers.d/ubuntu"
EOF
fi

# Set the correct permissions for TFTP
chmod -R 755 /tftpboot
chown -R root:root /tftpboot

echo "PXE boot server setup completed successfully."
exit 0