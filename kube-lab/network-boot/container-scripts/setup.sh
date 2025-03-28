#!/bin/bash
# Container startup script to configure PXE boot environment

set -e

# Default values
DHCP_MODE=${DHCP_MODE:-"proxy"}  # Options: full, proxy, tftp-only
INTERFACE=${INTERFACE:-"eth0"}
SERVER_IP=${SERVER_IP:-""}
DHCP_RANGE_START=${DHCP_RANGE_START:-"192.168.1.100"}
DHCP_RANGE_END=${DHCP_RANGE_END:-"192.168.1.200"}
DHCP_SUBNET=${DHCP_SUBNET:-"255.255.255.0"}
ROUTER_IP=${ROUTER_IP:-"192.168.1.1"}
LEASE_TIME=${LEASE_TIME:-"12h"}

# Get container IP if not provided
if [ -z "$SERVER_IP" ]; then
  SERVER_IP=$(ip -4 addr show ${INTERFACE} | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  if [ -z "$SERVER_IP" ]; then
    echo "ERROR: Could not determine container IP address. Please set SERVER_IP environment variable."
    exit 1
  fi
fi

echo "Starting PXE boot server with IP: ${SERVER_IP}"
echo "DHCP mode: ${DHCP_MODE}"

# Update server IP in kickstart files
sed -i "s/192.168.1.10/${SERVER_IP}/g" /var/lib/tftpboot/pxelinux.cfg/default

# Download Ubuntu netboot files if not already present
if [ ! -f /var/lib/tftpboot/vmlinuz ]; then
  echo "Downloading Ubuntu netboot files..."
  /usr/local/bin/prepare_boot_images.sh
fi

# Setup Apache2
mkdir -p /var/run/apache2 /var/lock/apache2
chown -R www-data:www-data /var/run/apache2 /var/lock/apache2 /var/www/html
chmod 755 /var/run/apache2 /var/lock/apache2

# Setup dnsmasq configuration based on DHCP mode
case "${DHCP_MODE}" in
    "tftp-only")
        cat > /etc/dnsmasq.conf <<EOF
interface=${INTERFACE}
bind-interfaces
port=0
enable-tftp
tftp-root=/var/lib/tftpboot
EOF
        ;;
    "full")
        # Full DHCP server mode
        cat > /etc/dnsmasq.conf <<EOF
# dnsmasq configuration for PXE Boot with full DHCP
interface=${INTERFACE}
bind-interfaces

# DHCP configuration
dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},${DHCP_SUBNET},${LEASE_TIME}
dhcp-option=option:router,${ROUTER_IP}
dhcp-option=option:dns-server,${ROUTER_IP}

# PXE boot
dhcp-boot=pxelinux.0,pxeserver,${SERVER_IP}
dhcp-option=66,${SERVER_IP}

# TFTP server
enable-tftp
tftp-root=/var/lib/tftpboot

# Logging
log-dhcp
log-queries
EOF
        echo "Configured as full DHCP server"
        ;;

    "proxy")
        # Proxy DHCP mode (for existing DHCP server)
        cat > /etc/dnsmasq.conf <<EOF
# dnsmasq configuration for PXE Boot in proxy DHCP mode
interface=${INTERFACE}
bind-interfaces

# Proxy DHCP mode
dhcp-range=${SERVER_IP},proxy
dhcp-boot=pxelinux.0,pxeserver,${SERVER_IP}

# TFTP server
enable-tftp
tftp-root=/var/lib/tftpboot

# Logging
log-dhcp
log-queries
EOF
        echo "Configured in proxy DHCP mode"
        ;;

    *)
        echo "Invalid DHCP_MODE: ${DHCP_MODE}"
        echo "Valid options are: full, proxy, tftp-only"
        exit 1
        ;;
esac

# Ensure permissions are correct
chmod -R 755 /var/lib/tftpboot
chmod 644 /var/www/html/ks/*

echo "PXE boot server setup complete"