#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data-frontend.log) 2>&1

echo "=== Frontend Setup Starting ==="

# Install dependencies
dnf update -y
dnf install -y git nodejs20 npm nginx aws-cli

# Create app directory for initial clone (fallback)
mkdir -p /opt/app
cd /opt/app

# Clone your public GitHub repo
git clone ${github_url} .

# Enter frontend folder
cd frontend

# Install dependencies and build for production
npm install
npm run build

# Ensure Nginx web root exists and is writable
sudo mkdir -p /usr/share/nginx/html
sudo chown -R ec2-user:ec2-user /usr/share/nginx/html

# Copy built files to Nginx web root
cp -r dist/* /usr/share/nginx/html/

# Configure Nginx to proxy /api to Backend ALB
cat > /etc/nginx/nginx.conf << 'NGINXEOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /api/ {
            proxy_pass http://${backend_alb_dns};
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /nginx-health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
NGINXEOF

# Fix permissions for future SSH deployments
sudo chown -R ec2-user:ec2-user /usr/share/nginx/html
sudo chmod -R 755 /usr/share/nginx/html

# Start Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

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

sudo systemctl enable node_exporter 2>/dev/null || true
sudo systemctl start node_exporter 2>/dev/null || true

echo "=== Frontend Setup Complete ==="