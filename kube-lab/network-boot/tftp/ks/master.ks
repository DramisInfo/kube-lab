#version=DEVEL
# System language
lang en_US.UTF-8

# Keyboard layouts
keyboard us

# Enable network
network --bootproto=dhcp --device=link --activate

# Root password (encrypted) - default is 'kubernetes'
rootpw --iscrypted $6$HrfdC.zqzTpod5y3$7cKqRvL7yFWdDi6BdYB.8gRFfSsQY0/CvxxwgA4trXy2UwBGGaUNnBuLyNww77wHLc3ry5IpY5jAmUMQgDfm81

# Use network installation
url --url="http://archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64"

# Use text mode install
text

# Do not configure the X Window System
skipx

# System timezone
timezone America/New_York --utc

# System bootloader configuration
bootloader --location=mbr --append="console=tty0 console=ttyS0,115200n8"

# Clear the Master Boot Record
zerombr

# Partition clearing information
clearpart --all --initlabel

# Disk partitioning information
part /boot --fstype="ext4" --size=1024
part pv.01 --grow --size=1

# Volume group
volgroup vg_root pv.01

# Logical volumes
logvol / --fstype="ext4" --size=15360 --name=lv_root --vgname=vg_root
logvol swap --size=2048 --name=lv_swap --vgname=vg_root
logvol /var --fstype="ext4" --size=10240 --name=lv_var --vgname=vg_root
logvol /var/log --fstype="ext4" --size=4096 --name=lv_varlog --vgname=vg_root
logvol /home --fstype="ext4" --size=4096 --name=lv_home --vgname=vg_root

# System services
services --disabled="kdump" --enabled="NetworkManager,sshd,chronyd"

# Reboot after installation
reboot

# Package Selection
%packages --ignoremissing
@^minimal-environment
@standard
open-vm-tools
openssh-server
curl
wget
vim
net-tools
%end

# Post-installation Script
%post --log=/root/ks-post.log
# Setup SSH keys for remote access
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat > /root/.ssh/authorized_keys << 'EOT'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0WGP1EZykEtv5YGC9nMiRYu3+0z0jHVCOcA1vROVNgPzQC4PEMH0qv3cHLnR9LxQqWQTuqPL7+4jCErW3Xaf8hwBLBJyqolT1AoOQh5pR3ykGVDOb8+6GCWdebXdBJF7wMYHWmkFmSK43UVi9S7qGKv8+5rEIHvZ1J7tpS/EfF/Q0TTpByOJE17aNcA2ozBEW9SiutMRACPs9xBsJMH5Siyd0pEfxImuav41jyLRYJQlcWov1n/7qz8rOJ4Sisk2Qyp4yFuJ5xJKKzGGnN+RJx66dH+4NyOCR8ILsUZwlWYIGSGNQdxD8UVj2zxlCCwNRWp0Y7DOyIRKpEHWuXqZV kubernetes-key
EOT
chmod 600 /root/.ssh/authorized_keys

# Create Ubuntu user for Ansible
useradd -m -s /bin/bash ubuntu
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
cat > /home/ubuntu/.ssh/authorized_keys << 'EOT'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0WGP1EZykEtv5YGC9nMiRYu3+0z0jHVCOcA1vROVNgPzQC4PEMH0qv3cHLnR9LxQqWQTuqPL7+4jCErW3Xaf8hwBLBJyqolT1AoOQh5pR3ykGVDOb8+6GCWdebXdBJF7wMYHWmkFmSK43UVi9S7qGKv8+5rEIHvZ1J7tpS/EfF/Q0TTpByOJE17aNcA2ozBEW9SiutMRACPs9xBsJMH5Siyd0pEfxImuav41jyLRYJQlcWov1n/7qz8rOJ4Sisk2Qyp4yFuJ5xJKKzGGnN+RJx66dH+4NyOCR8ILsUZwlWYIGSGNQdxD8UVj2zxlCCwNRWp0Y7DOyIRKpEHWuXqZV kubernetes-key
EOT
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Add Ubuntu user to sudoers
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 440 /etc/sudoers.d/ubuntu

# Set hostname
hostnamectl set-hostname k8s-master

# Disable swap (required for Kubernetes)
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Mark the node as a master
touch /etc/kubernetes-master

# Prepare for Kubernetes installation
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Update system
apt-get update && apt-get upgrade -y

%end