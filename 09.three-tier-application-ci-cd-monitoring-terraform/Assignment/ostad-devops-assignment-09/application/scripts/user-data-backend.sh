#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data-backend.log) 2>&1

echo "=== Backend Setup Starting ==="

# Install Node.js 20 and Git
dnf update -y
dnf install -y git nodejs20 npm

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Clone your public GitHub repo (monorepo with frontend/ and backend/)
git clone ${github_url} .

# Enter backend folder
cd backend

# Install dependencies
npm install

# Create environment file
cat > .env << EOF
NODE_ENV=production
PORT=8080
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
APP_VERSION=1.0.0
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DEPLOYMENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

cat > /etc/systemd/system/backend.service << 'EOF'
[Unit]
Description=Ostad Backend API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app/backend
EnvironmentFile=/opt/app/backend/.env
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable backend
systemctl start backend

# Install Node Exporter for monitoring (optional)
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xzf node_exporter-1.7.0.linux-amd64.tar.gz 2>/dev/null || true
mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/ 2>/dev/null || true
useradd -rs /bin/false node_exporter 2>/dev/null || true

cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target
[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always
[Install]
WantedBy=default.target
EOF

systemctl enable node_exporter 2>/dev/null || true
systemctl start node_exporter 2>/dev/null || true

echo "=== Backend Setup Complete ==="
