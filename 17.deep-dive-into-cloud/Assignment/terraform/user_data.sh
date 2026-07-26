#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [$(date)] Starting bootstrap ==="

# -------------------------------------------------
# 1. SYSTEM UPDATE & DEPENDENCIES
# -------------------------------------------------
dnf update -y
dnf install -y git wget jq   # <-- REMOVED 'curl' — already installed as curl-minimal

# -------------------------------------------------
# 2. INSTALL NODE.JS 22 (via NodeSource)
# -------------------------------------------------
curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
dnf install -y nodejs

node -v
npm -v

# -------------------------------------------------
# 3. INSTALL PM2 PROCESS MANAGER
# -------------------------------------------------
npm install -g pm2

# -------------------------------------------------
# 4. DEPLOY APPLICATION
# -------------------------------------------------
APP_DIR="/var/www/Module-3-deployment"
mkdir -p /var/www
cd /var/www

# Clone repository
git clone "${app_repo_url}" Module-3-deployment
cd Module-3-deployment

# Install dependencies
npm install

# -------------------------------------------------
# 5. START APPLICATION WITH PM2 (as root)
# -------------------------------------------------
export PM2_HOME="/root/.pm2"
pm2 start ./src/server.js --name node-app
pm2 startup systemd --service-name pm2-node-app
pm2 save

# Allow ec2-user to read PM2 logs
chmod 755 /root/.pm2/logs

# -------------------------------------------------
# 6. CUSTOM HEALTH CHECK ENDPOINT (for ALB)
# -------------------------------------------------
# The app already has / and /api routes. PM2 ensures auto-restart.

# Ensure cron directory exists
mkdir -p /etc/cron.d

# -------------------------------------------------
# 7. SELF-HEALING: CRON JOB TO ENSURE APP IS RUNNING
# -------------------------------------------------
cat << 'EOF' > /usr/local/bin/ensure-app-running.sh
#!/bin/bash
if ! pgrep -f "node-app" > /dev/null; then
  echo "[$(date)] App not running. Restarting..."
  cd /var/www/Module-3-deployment && pm2 start ./src/server.js --name node-app
fi
EOF
chmod +x /usr/local/bin/ensure-app-running.sh
echo "*/5 * * * * root /usr/local/bin/ensure-app-running.sh >> /var/log/ensure-app.log 2>&1" > /etc/cron.d/ensure-app-running

# -------------------------------------------------
# 8. FALLBACK MONITORING (since CloudWatch may be blocked)
# -------------------------------------------------
mkdir -p /var/log/app-metrics
cat << 'EOF' > /usr/local/bin/collect-metrics.sh
#!/bin/bash
TIMESTAMP=$(date +%Y-%m-%d-%H:%M:%S)
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
MEM=$(free | grep Mem | awk '{printf("%.2f"), $3/$2 * 100.0}')
DISK=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
echo "$TIMESTAMP,CPU:$CPU,MEM:$MEM,DISK:$DISK" >> /var/log/app-metrics/system-metrics.csv
EOF
chmod +x /usr/local/bin/collect-metrics.sh
echo "*/2 * * * * root /usr/local/bin/collect-metrics.sh" > /etc/cron.d/collect-metrics

# -------------------------------------------------
# 9. UPLOAD METRICS TO S3 (if IAM role allows)
# -------------------------------------------------
cat << EOF > /usr/local/bin/upload-metrics.sh
#!/bin/bash
BUCKET="${bucket_name}"
if aws s3 cp /var/log/app-metrics/system-metrics.csv s3://\$BUCKET/metrics/\$(hostname)-metrics.csv 2>/dev/null; then
  echo "[\$(date)] Metrics uploaded to S3"
else
  echo "[\$(date)] S3 upload failed (check IAM permissions)"
fi
EOF
chmod +x /usr/local/bin/upload-metrics.sh
echo "0 * * * * root /usr/local/bin/upload-metrics.sh >> /var/log/metrics-upload.log 2>&1" > /etc/cron.d/upload-metrics

# -------------------------------------------------
# 10. SIGNAL COMPLETION
# -------------------------------------------------
echo "=== [$(date)] Bootstrap complete ==="