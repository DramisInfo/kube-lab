const express = require('express');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const app = express();
const port = 3000;

// Middleware to parse JSON requests
app.use(express.json());

// Serve static files from the public directory
app.use(express.static('public'));

// API endpoint to get system status
app.get('/status', (req, res) => {
  const status = {
    dhcp: false,
    tftp: false,
    nginx: false,
    pxe_files: false,
    ubuntu_files: false
  };

  // Check DHCP server
  exec('pgrep dnsmasq', (error, stdout) => {
    status.dhcp = !error;

    // Check TFTP server
    exec('pgrep in.tftpd', (error, stdout) => {
      status.tftp = !error;

      // Check Nginx server
      exec('pgrep nginx', (error, stdout) => {
        status.nginx = !error;

        // Check PXE boot files
        fs.access('/tftpboot/pxelinux.0', fs.constants.F_OK, (error) => {
          status.pxe_files = !error;

          // Check Ubuntu files
          fs.access('/tftpboot/ubuntu/vmlinuz', fs.constants.F_OK, (error) => {
            status.ubuntu_files = !error;
            res.json(status);
          });
        });
      });
    });
  });
});

// Get DHCP leases
app.get('/dhcp-leases', (req, res) => {
  fs.readFile('/var/lib/misc/dnsmasq.leases', 'utf8', (err, data) => {
    if (err) {
      return res.status(500).json({ error: 'Could not read DHCP leases' });
    }
    
    const leases = data.split('\n')
      .filter(line => line.trim() !== '')
      .map(line => {
        const parts = line.split(' ');
        return {
          expires: parts[0],
          mac: parts[1],
          ip: parts[2],
          hostname: parts[3],
          client_id: parts[4] || ''
        };
      });
    
    res.json(leases);
  });
});

// Update preseed configuration
app.post('/update-preseed', (req, res) => {
  const { hostname, username, password, packages } = req.body;
  
  if (!hostname || !username || !password) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  
  fs.readFile('/var/www/html/ubuntu/preseed.cfg', 'utf8', (err, data) => {
    if (err) {
      return res.status(500).json({ error: 'Could not read preseed file' });
    }
    
    // Update hostname
    let updatedData = data.replace(
      /d-i netcfg\/get_hostname string .+/,
      `d-i netcfg/get_hostname string ${hostname}`
    );
    
    // Update username
    updatedData = updatedData.replace(
      /d-i passwd\/username string .+/,
      `d-i passwd/username string ${username}`
    );
    
    // Update password
    updatedData = updatedData.replace(
      /d-i passwd\/user-password password .+/,
      `d-i passwd/user-password password ${password}`
    );
    updatedData = updatedData.replace(
      /d-i passwd\/user-password-again password .+/,
      `d-i passwd/user-password-again password ${password}`
    );
    
    // Update packages if provided
    if (packages) {
      updatedData = updatedData.replace(
        /d-i pkgsel\/include string .+/,
        `d-i pkgsel/include string ${packages}`
      );
    }
    
    fs.writeFile('/var/www/html/ubuntu/preseed.cfg', updatedData, 'utf8', (err) => {
      if (err) {
        return res.status(500).json({ error: 'Could not write preseed file' });
      }
      
      res.json({ success: true, message: 'Preseed configuration updated successfully' });
    });
  });
});

// Get network configuration
app.get('/network-config', (req, res) => {
  exec('ip addr show | grep -w inet', (error, stdout) => {
    if (error) {
      return res.status(500).json({ error: 'Could not retrieve network configuration' });
    }
    
    const networkInterfaces = stdout.split('\n')
      .filter(line => line.trim() !== '')
      .map(line => {
        const parts = line.trim().split(/\s+/);
        const ipCidr = parts[1];
        const interface = parts[parts.length - 1];
        return { interface, ipCidr };
      });
    
    res.json(networkInterfaces);
  });
});

// Start the server
app.listen(port, () => {
  console.log(`PXE Boot UI API server running on port ${port}`);
});