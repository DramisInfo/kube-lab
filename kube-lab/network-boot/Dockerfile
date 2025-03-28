FROM ubuntu:22.04

# Set non-interactive installation and install dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y \
    dnsmasq \
    apache2 \
    syslinux \
    pxelinux \
    wget \
    curl \
    iputils-ping \
    iproute2 \
    net-tools \
    vim \
    tftpd-hpa \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/lib/tftpboot/pxelinux.cfg \
    && mkdir -p /var/www/html/ks \
    && mkdir -p /etc/dnsmasq.d

# Copy syslinux files to tftpboot directory
RUN cp -r /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot/ 2>/dev/null || cp -r /usr/lib/syslinux/pxelinux.0 /var/lib/tftpboot/ && \
    cp -r /usr/lib/syslinux/modules/bios/menu.c32 /var/lib/tftpboot/ 2>/dev/null || cp -r /usr/lib/syslinux/menu.c32 /var/lib/tftpboot/ && \
    cp -r /usr/lib/syslinux/modules/bios/ldlinux.c32 /var/lib/tftpboot/ 2>/dev/null || cp -r /usr/lib/syslinux/ldlinux.c32 /var/lib/tftpboot/ && \
    cp -r /usr/lib/syslinux/modules/bios/libutil.c32 /var/lib/tftpboot/ 2>/dev/null || cp -r /usr/lib/syslinux/libutil.c32 /var/lib/tftpboot/

# Copy configuration files
COPY pxe/default /var/lib/tftpboot/pxelinux.cfg/
COPY tftp/ks/* /var/www/html/ks/

# Create setup script to be run at container startup
COPY container-scripts/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

# Supervisor configuration for services
COPY container-scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create netboot preparation script
COPY container-scripts/prepare_boot_images.sh /usr/local/bin/prepare_boot_images.sh
RUN chmod +x /usr/local/bin/prepare_boot_images.sh

# Expose ports
# TFTP
EXPOSE 69/udp  
# DHCP
EXPOSE 67/udp  
# HTTP
EXPOSE 80      

# Run supervisord as the entrypoint
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]