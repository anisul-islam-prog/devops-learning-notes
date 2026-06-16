#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting App Server setup at $(date)"

# Update system
apt-get update -y
apt-get upgrade -y

# Remove any pre-installed nodejs packages FIRST to avoid conflicts
apt-get remove -y libnode-dev nodejs npm || true
apt-get autoremove -y

# Install Node.js 20.x from NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install other dependencies
apt-get install -y \
    curl \
    git \
    docker.io \
    awscli \
    jq

# Start Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Install PM2 globally
npm install -g pm2

# Install Zabbix Agent 2
wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu22.04_all.deb
dpkg -i zabbix-release_7.0-2+ubuntu22.04_all.deb
apt-get update -y
apt-get install -y zabbix-agent2

# Configure Zabbix Agent 2
cat > /etc/zabbix/zabbix_agent2.conf << 'EOF'
PidFile=/var/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0
Server=ZABBIX_SERVER_IP_PLACEHOLDER
ServerActive=ZABBIX_SERVER_IP_PLACEHOLDER
Hostname=app-server
Include=/etc/zabbix/zabbix_agent2.d/*.conf
EOF

systemctl enable zabbix-agent2
systemctl start zabbix-agent2

# Create app directory
mkdir -p /opt/app
chown ubuntu:ubuntu /opt/app

# Create writable log directory for app
mkdir -p /var/log/app
chown ubuntu:ubuntu /var/log/app

echo "App Server setup completed at $(date)"
echo "Node version: $(node -v)"
echo "PM2 version: $(pm2 -v || echo 'pm2 not found')"