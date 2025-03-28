# Network Boot Setup for Kubernetes Homelab

This document outlines the setup required for PXE (Preboot Execution Environment) booting the mini PCs in our Kubernetes homelab.

## Overview

The network boot process involves:
1. DHCP server to assign IP addresses and point to the boot server
2. TFTP server to serve boot files
3. PXE configuration to specify the OS and configuration to load

## Requirements

- Control machine (laptop) connected to the same network as mini PCs
- Mini PCs with PXE boot capability enabled in BIOS/UEFI
- Dnsmasq or similar for TFTP services

## Setup with TP-Link ER605 V2 Router

Since you're using a TP-Link ER605 V2 router as your DHCP server, there are two ways to set up network booting:

### Option 1: Configure TP-Link Router for PXE Boot (Recommended)

1. Log in to your TP-Link ER605 V2 router's admin interface
2. Navigate to Network → DHCP → DHCP Settings
3. Ensure DHCP Service is enabled
4. Under DHCP Options Configuration, add the following options:
   - Option 66 (TFTP Server): [Your laptop's IP address]
   - Option 67 (Bootfile Name): pxelinux.0
5. Save the configuration

In this setup, your router will continue to handle IP address assignments while directing PXE boot clients to your laptop's TFTP server.

### Option 2: Use Proxy DHCP Mode (Advanced)

If you can't modify your router settings or prefer a solution that doesn't require router configuration:

1. Run dnsmasq in "proxy DHCP" mode on your laptop
2. This mode doesn't interfere with IP address assignments but provides only PXE boot information

This approach is more complex but keeps all PXE boot configuration on your laptop.

## Setup Instructions

### 1. TFTP Server Configuration

In both options, your laptop will run a TFTP server to provide boot files:

```bash
sudo apt-get install dnsmasq syslinux pxelinux
```

### 2. Boot Image Preparation

Prepare a bootable Linux image suitable for Kubernetes:

```bash
sudo ./scripts/bootstrap/prepare_boot_images.sh
```

### 3. Network Configuration

Ensure your laptop has a static IP address on the network or a DHCP reservation in your TP-Link router to maintain a consistent IP address.

### 4. Service Configuration

The setup script will handle most of the configuration automatically:

```bash
sudo ./scripts/bootstrap/setup_netboot.sh
```

## Network Requirements

- Your laptop and mini PCs must be on the same network segment
- If using Option 1, the TP-Link router must support DHCP options 66 and 67
- Firewall rules should allow TFTP (UDP port 69) and HTTP traffic

## Troubleshooting

### Common Issues with TP-Link ER605 V2

1. **PXE Boot Not Working**:
   - Verify options 66 and 67 are correctly set in the router
   - Check that your laptop's TFTP server is running: `systemctl status dnsmasq`

2. **DHCP IP Assignment Issues**:
   - Ensure there are no IP conflicts between your router's DHCP range and any static IPs

3. **TFTP Access Problems**:
   - Check your laptop's firewall settings: `sudo ufw status` and allow TFTP traffic if needed

### General Troubleshooting

- Check dnsmasq logs for TFTP requests: `sudo journalctl -u dnsmasq -f`
- Verify the mini PC is set to boot from network in BIOS
- Ensure boot files are correctly placed in `/var/lib/tftpboot`