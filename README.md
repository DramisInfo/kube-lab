# Containerized PXE Boot Server for Ubuntu Mini PC Deployment

## Objective

This project aims to create a containerized grooming PC solution that can automate the setup of new mini PCs with Ubuntu using PXE (Preboot Execution Environment) boot. The container will provide all necessary services for network booting, allowing for consistent and efficient deployment of Ubuntu on multiple mini PCs without manual installation.

## Benefits

- Automated installation of Ubuntu on mini PCs
- Consistent system configuration across multiple devices
- Reduced manual setup time and potential for human error
- Portable solution that can be deployed anywhere with Docker

## Plan of Tasks

1. **Container Infrastructure Setup**
   - Define Docker container configuration
   - Create Dockerfile and docker-compose.yml files
   - Configure networking to allow PXE boot services

2. **PXE Boot Services Configuration**
   - Set up DHCP server (dnsmasq) to handle IP assignment and PXE boot options
   - Configure TFTP server to serve boot files
   - Prepare the network boot environment

3. **Ubuntu Installation Media Preparation**
   - Download Ubuntu installation media
   - Extract and configure netboot images
   - Create preseed/autoinstall configuration for automated installations

4. **Boot Menu Configuration**
   - Set up PXELinux or GRUB boot menu
   - Configure boot options for Ubuntu installation
   - Add advanced options (e.g., memory tests, rescue mode)

5. **Post-Installation Configuration**
   - Create scripts for post-installation setup
   - Configure user accounts, software packages, and system settings
   - Set up network configuration for deployed systems

6. **Testing and Validation**
   - Test PXE boot process in a controlled environment
   - Validate the automated installation process
   - Verify post-installation configuration

7. **Documentation**
   - Document setup and usage instructions
   - Create troubleshooting guide
   - Provide examples for customization

## Requirements

- Docker and Docker Compose
- Network with DHCP control
- Mini PC with PXE boot support
- Storage space for Ubuntu installation files

## Getting Started

### Running the PXE Boot Server

1. Clone the repository:
```bash
git clone https://github.com/yourusername/kube-lab.git
cd kube-lab
```

2. Build and start the container:
```bash
docker-compose -f docker/docker-compose.yml up -d
```

3. The PXE boot server should now be running with:
   - Web UI accessible at: http://localhost:80
   - DHCP server listening on the specified interface
   - TFTP server providing boot files

### Testing with VirtualBox

You can test the PXE boot server using VirtualBox without needing physical hardware:

1. **Setup VirtualBox Host-Only Network**:
   - Open VirtualBox → File → Host Network Manager
   - Create new network with these settings:
     - IPv4 Address: 172.28.205.1
     - IPv4 Network Mask: 255.255.240.0
     - Disable DHCP Server

2. **Create Test VM**:
   - Create a new VM in VirtualBox
   - Configure Network:
     - Adapter 1: Host-only Network (select the one created above)
     - Adapter 2: NAT (optional, for internet access)
   - Configure Boot Order:
     - System → Boot Order: Move "Network" to the top

3. **Run the VirtualBox testing script**:
```bash
./scripts/test-virtualbox.sh
```

4. **Start your VM**:
   - Start your VM - it should attempt to PXE boot
   - Monitor the logs: `docker logs pxe-boot-server -f`

5. **Expected results**:
   - VM gets IP address from your DHCP server
   - Boot menu appears via PXE
   - Ubuntu installation begins

This testing setup allows you to validate your PXE boot configuration without affecting your main network or requiring physical hardware.

## Remaining Tasks

The following tasks still need to be completed to fully implement the PXE boot server:

1. **Fix Web UI**
   - ✅ Web UI is now accessible via HTTP (returns 200 OK)
   - ✅ Added symbolic link in Dockerfile from `/app/web-ui/public/*` to `/var/www/html/`
   - ✅ Verified Nginx configuration is properly serving static files
   - ✅ File permissions are correctly set (755 for directories, ownership to www-data)
   - ✅ Updated web UI to correctly detect TFTP provided by dnsmasq

2. **Set Up Node.js API Server**
   - ✅ Node.js server is properly starting in the container and running
   - ✅ The web-ui-api service shows as RUNNING in supervisord
   - ✅ Node.js API correctly configured to serve API endpoints at /api/ path
   - ✅ Fixed status detection for consolidated services

3. **Complete PXE Boot Configuration**
   - ✅ Created placeholder netboot files to ensure system can start
   - ✅ Set up the TFTP boot environment with proper menu entries
   - ✅ Configured preseed files for automated Ubuntu installation
   - ✅ Created test script for validating PXE boot using VirtualBox
   - Need to test the complete PXE boot process with a client machine

4. **Network Configuration Fine-tuning**
   - ✅ DHCP server (dnsmasq) is now successfully running
   - ✅ TFTP server functionality provided by dnsmasq is working
   - ✅ Fixed service conflicts by consolidating DHCP and TFTP into a single dnsmasq service
   - ✅ Correctly configured DHCP options for PXE boot

5. **Logging and Monitoring**
   - ✅ Implemented live log viewing in the web UI
   - ✅ Added system resource monitoring (CPU, memory, disk usage)
   - ✅ Added DHCP and TFTP connection monitoring
   - ✅ Implemented auto-refresh functionality for real-time updates

6. **Documentation**
   - Complete user documentation for operation
   - Add troubleshooting section for common issues
   - Document the architecture and configuration details

## Troubleshooting Progress

During our testing, we've identified and fixed several issues:

1. **Service Conflicts (Fixed)** 
   - Resolved conflicts between separate DHCP and TFTP services
   - Consolidated both services into a single dnsmasq instance
   - Updated supervisord configuration to remove redundant tftpd-hpa service

2. **Web UI Status Detection (Fixed)**
   - Updated the Node.js API server to correctly detect TFTP functionality
   - Changed detection to check for "enable-tftp" in dnsmasq configuration
   - Now correctly shows both DHCP and TFTP as running when using dnsmasq for both

3. **Network Configuration (Fixed)**
   - Hard-coded proper IP addresses in dnsmasq.conf
   - Fixed the DHCP option syntax to be compatible with dnsmasq
   - Configured proper interface binding for network services

4. **Setup Script (Fixed)**
   - Added better error handling for Ubuntu netboot files download
   - Created placeholder files to ensure the system can start even if download fails
   - Improved permissions handling for TFTP files

To continue development, run the container and use the following commands to investigate and fix issues:

```bash
# View logs to identify issues
docker logs pxe-boot-server

# Inspect container to verify file links
docker exec pxe-boot-server ls -la /var/www/html/

# Check dnsmasq configuration
docker exec pxe-boot-server cat /etc/dnsmasq.conf

# Verify the Node.js server is running
docker exec pxe-boot-server ps aux | grep node

# Check active network ports
docker exec pxe-boot-server netstat -tulpn | grep -E '(67|69|80|3000)'
```