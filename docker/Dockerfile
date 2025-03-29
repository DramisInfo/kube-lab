FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    dnsmasq \
    tftpd-hpa \
    nginx \
    iproute2 \
    wget \
    unzip \
    cpio \
    iputils-ping \
    net-tools \
    curl \
    vim \
    supervisor \
    gnupg \
    ca-certificates \
    --no-install-recommends

# Install Node.js for the web UI
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /tftpboot/pxelinux.cfg \
    && mkdir -p /var/www/html/ubuntu \
    && mkdir -p /app/web-ui \
    && mkdir -p /etc/dnsmasq.d

# Copy configuration files
COPY config/dhcp/dnsmasq.conf /etc/dnsmasq.conf
COPY config/dhcp/* /etc/dnsmasq.d/
COPY config/tftp/tftpd-hpa /etc/default/tftpd-hpa
COPY config/http/nginx.conf /etc/nginx/sites-available/default
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy TFTP boot files
COPY config/tftp/*.c32 /tftpboot/
COPY config/tftp/pxelinux.0 /tftpboot/
COPY config/tftp/pxelinux.cfg/default /tftpboot/pxelinux.cfg/

# Copy web UI files
COPY web-ui /app/web-ui/
WORKDIR /app/web-ui
RUN npm install

# Set up working directory
WORKDIR /app

# Copy setup scripts
COPY scripts /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Create symbolic links from web UI files to Nginx web root
RUN ln -sf /app/web-ui/public/* /var/www/html/

# Fix permissions for NGINX and TFTP
RUN chmod -R 755 /var/www/html/ && \
    chmod -R 755 /tftpboot/ && \
    chown -R www-data:www-data /var/www/html/ && \
    chown -R nobody:nogroup /tftpboot/

# Expose required ports
EXPOSE 67/udp 69/udp 80 3000

# Command to run services using supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]