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

(Instructions will be added as development progresses)

## Remaining Tasks

The following tasks still need to be completed to fully implement the PXE boot server:

1. **Fix Web UI**
   - The web UI currently returns a 403 Forbidden error
   - ✅ Added symbolic link in Dockerfile, but needs troubleshooting
   - Check that `/app/web-ui/public/*` files are actually being linked to `/var/www/html/`
   - Verify Nginx configuration is properly set up to serve static files
   - Ensure proper file permissions for web files

2. **Set Up Node.js API Server**
   - The web UI depends on API endpoints that need to be running
   - Check that the Node.js server is properly starting in the container
   - Verify API endpoints are accessible from the browser
   - Debug any connection issues between the web UI and API

3. **Complete PXE Boot Configuration**
   - Download and configure Ubuntu netboot files
   - Set up the TFTP boot environment with proper menu entries
   - Configure preseed files for automated Ubuntu installation
   - Test the complete PXE boot process with a client machine

4. **Network Configuration Fine-tuning**
   - Ensure DHCP server is properly configured for the network
   - Fix any IP address range or subnet mask issues
   - Verify that DHCP options for PXE boot are correctly set

5. **Logging and Monitoring**
   - Implement proper logging for all services
   - Add monitoring capabilities to track successful/failed boots
   - Create an admin dashboard to monitor system status

6. **Documentation**
   - Complete user documentation for operation
   - Add troubleshooting section for common issues
   - Document the architecture and configuration details

To continue development, run the container and use the following commands to investigate and fix issues:

```bash
# View logs to identify issues
docker logs pxe-boot-server

# Inspect container to verify file links
docker exec pxe-boot-server ls -la /var/www/html/

# Check Nginx configuration
docker exec pxe-boot-server cat /etc/nginx/sites-available/default

# Verify the Node.js server is running
docker exec pxe-boot-server ps aux | grep node

# Restart Nginx if needed
docker exec pxe-boot-server service nginx restart
```