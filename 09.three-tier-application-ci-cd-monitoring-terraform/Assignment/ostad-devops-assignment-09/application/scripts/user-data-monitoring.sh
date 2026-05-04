#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data-monitoring.log) 2>&1

echo "=== PLG Stack Installation ==="

# Update system
dnf update -y

# Install Docker
dnf install -y docker aws-cli
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create monitoring directory
mkdir -p /opt/monitoring/{prometheus,grafana/provisioning/datasources,grafana/provisioning/dashboards,loki,promtail}
cd /opt/monitoring

# ==========================================
# DISCOVER INSTANCE IPs VIA AWS CLI
# ==========================================
echo "=== Discovering instance IPs ==="

# Configure AWS CLI with instance metadata credentials (if available) or use local
export AWS_REGION=us-east-1

# Get frontend IP
FRONTEND_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ostad-assignment-09-frontend" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text 2>/dev/null || echo "10.0.1.10")

# Get backend IP (first running instance in ASG)
BACKEND_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ostad-assignment-09-backend" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text 2>/dev/null || echo "10.0.4.10")

# Get database IP
DATABASE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ostad-assignment-09-database" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text 2>/dev/null || echo "10.0.3.10")

echo "Frontend: $FRONTEND_IP"
echo "Backend: $BACKEND_IP"
echo "Database: $DATABASE_IP"

# ==========================================
# PROMETHEUS CONFIGURATION
# ==========================================
cat > /opt/monitoring/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter-frontend'
    static_configs:
      - targets: ['${FRONTEND_IP}:9100']

  - job_name: 'node-exporter-backend'
    static_configs:
      - targets: ['${BACKEND_IP}:9100']

  - job_name: 'node-exporter-database'
    static_configs:
      - targets: ['${DATABASE_IP}:9100']

  - job_name: 'backend-app'
    static_configs:
      - targets: ['${BACKEND_IP}:8080']
    metrics_path: /metrics
EOF

# ==========================================
# LOKI CONFIGURATION
# ==========================================
cat > /opt/monitoring/loki/loki-config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /tmp/loki
  storage:
    filesystem:
      chunks_directory: /tmp/loki/chunks
      rules_directory: /tmp/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

analytics:
  reporting_enabled: false
EOF

# ==========================================
# PROMTAIL CONFIGURATION
# ==========================================
cat > /opt/monitoring/promtail/promtail-config.yml << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log

  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
EOF

# ==========================================
# GRAFANA DATASOURCES — Auto-configured
# ==========================================
cat > /opt/monitoring/grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
EOF

# ==========================================
# GRAFANA DASHBOARD PROVISIONING
# ==========================================
cat > /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create a simple system metrics dashboard JSON
mkdir -p /opt/monitoring/grafana/dashboards
cat > /opt/monitoring/grafana/dashboards/system-metrics.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "System Metrics",
    "tags": ["system"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{instance}}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "100 * (1 - ((node_memory_MemAvailable_bytes or node_memory_MemFree_bytes) / node_memory_MemTotal_bytes))",
            "legendFormat": "{{instance}}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Disk Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\"} * 100) / node_filesystem_size_bytes{mountpoint=\"/\"})",
            "legendFormat": "{{instance}}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "10s"
  }
}
EOF

# ==========================================
# DOCKER COMPOSE
# ==========================================
cat > /opt/monitoring/docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:v2.48.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'

  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    volumes:
      - ./loki:/etc/loki
      - loki-data:/tmp/loki
    command: -config.file=/etc/loki/loki-config.yml

  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./promtail:/etc/promtail
      - /var/log:/var/log:ro
      - /var/run/docker.sock:/var/run/docker.sock
    command: -config.file=/etc/promtail/promtail-config.yml
    depends_on:
      - loki

  grafana:
    image: grafana/grafana:10.2.3
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=ostad123
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000

volumes:
  prometheus-data:
  loki-data:
  grafana-data:
EOF

# ==========================================
# START PLG STACK
# ==========================================
cd /opt/monitoring
docker-compose up -d

echo "=== PLG Stack Installation Complete ==="
echo "Grafana: http://$(curl -s ifconfig.me):3000 (admin/ostad123)"
echo "Prometheus: http://$(curl -s ifconfig.me):9090"
echo ""
echo "Waiting 30 seconds for services to start..."
sleep 30

# Verify Prometheus targets
echo "=== Prometheus Targets ==="
curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"[^"]*"' || echo "Check Prometheus UI manually"

echo "=== Done ==="