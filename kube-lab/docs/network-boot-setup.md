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
- Dnsmasq or similar for DHCP + TFTP services

## Setup Instructions

### 1. DHCP Configuration

The DHCP server needs to be configured to direct PXE clients to the TFTP server for boot files.

### 2. TFTP Server Setup

The TFTP server will host the network boot files including the kernel and initramfs.

### 3. Boot Image Preparation

We'll need to prepare a bootable Linux image suitable for Kubernetes installation.

### 4. PXE Configuration

Configure the PXE boot menu to offer the Kubernetes node installation option.

## Network Requirements

- Ensure mini PCs and control machine are on the same subnet
- Make sure no other DHCP servers are active on the network
- Configure firewall rules to allow DHCP, TFTP, and HTTP/HTTPS traffic

## Troubleshooting

Common issues and solutions will be documented here as we encounter them.