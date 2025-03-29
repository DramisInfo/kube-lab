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

    // Check TFTP server - Now provided by dnsmasq
    // Instead of checking for in.tftpd, we check if dnsmasq is configured with TFTP enabled
    exec('grep "enable-tftp" /etc/dnsmasq.conf', (error, stdout) => {
      // If dnsmasq is running and enable-tftp is in the config, then TFTP is active
      status.tftp = !error && status.dhcp;

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

// New endpoint to get service logs
app.get('/logs/:service', (req, res) => {
  const service = req.params.service;
  const validServices = ['dnsmasq', 'nginx', 'setup', 'web-ui'];
  
  if (!validServices.includes(service)) {
    return res.status(400).json({ error: 'Invalid service name' });
  }
  
  let logFile;
  switch(service) {
    case 'dnsmasq':
      logFile = '/var/log/dnsmasq.log';
      break;
    case 'nginx':
      logFile = '/var/log/nginx/access.log';
      break;
    case 'setup':
      logFile = '/var/log/supervisor/setup_stdout.log';
      break;
    case 'web-ui':
      logFile = '/var/log/supervisor/web_ui_stdout.log';
      break;
  }
  
  // Get the last 100 lines of the log file
  exec(`tail -n 100 ${logFile}`, (error, stdout) => {
    if (error) {
      return res.status(500).json({ error: `Could not read ${service} logs` });
    }
    res.send(stdout);
  });
});

// New endpoint to get system resource usage
app.get('/system-stats', (req, res) => {
  exec('top -bn1 | grep -E "Cpu|Mem"', (error, cpuMemOutput) => {
    if (error) {
      return res.status(500).json({ error: 'Could not retrieve system stats' });
    }
    
    exec('df -h | grep -E "Filesystem|/$"', (error, diskOutput) => {
      if (error) {
        return res.status(500).json({ 
          cpu_mem: cpuMemOutput.trim().split('\n'),
          disk: 'Could not retrieve disk stats' 
        });
      }
      
      res.json({
        cpu_mem: cpuMemOutput.trim().split('\n'),
        disk: diskOutput.trim().split('\n')
      });
    });
  });
});

// New endpoint to get active TFTP connections
app.get('/tftp-active', (req, res) => {
  exec('netstat -an | grep -E ":69\\s" | wc -l', (error, stdout) => {
    if (error) {
      return res.status(500).json({ error: 'Could not retrieve TFTP connection stats' });
    }
    
    const connections = parseInt(stdout.trim());
    res.json({ active_connections: connections });
  });
});

// Start the server
app.listen(port, () => {
  console.log(`PXE Boot UI API server running on port ${port}`);
});