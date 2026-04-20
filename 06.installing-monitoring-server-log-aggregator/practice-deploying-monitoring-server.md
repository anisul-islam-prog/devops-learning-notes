# 🚀 AWS EC2 Monitoring Lab: Complete Setup Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS VPC                                 │
│                                                                 │
│  ┌──────────────────────────┐    ┌──────────────────────────┐   │
│  │   MONITORING SERVER      │    │   APPLICATION SERVER     │   │
│  │   (t2.large - 2GB RAM)   │    │   (t2.micro - 1GB RAM)   │   │
│  │   20 GB Storage          │    │   8 GB Storage           │   │
│  │                          │    │                          │   │
│  │  • PLG Stack:            │◄───│  • Node.js App           │   │
│  │    - Prometheus (9090)   │    │  • Log Generator         │   │
│  │    - Loki (3100)         │    │  • Node Exporter         │   │
│  │    - Grafana (3000)      │    │  • Promtail Agent        │   │
│  │                          │    │                          │   │
│  │  • ELK Stack:            │◄───│  • Filebeat Agent        │   │
│  │    - Elasticsearch       │    │                          │   │
│  │    - Logstash            │    │                          │   │
│  │    - Kibana (5601)       │    │                          │   │
│  │                          │    │                          │   │
│  │  Security Group:         │    │  Security Group:         │   │
│  │  22, 3000, 5601, 9090    │    │  22, 3000, 9100          │   │
│  └──────────────────────────┘    └──────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Infrastructure Setup

### Step 1: Launch EC2 Instances

**Instance 1: Monitoring Server**
- **Name**: `monitoring-server`
- **AMI**: Ubuntu Server 22.04 LTS
- **Instance Type**: `t2.large` (2 vCPU, 8GB RAM) - *ELK needs 4GB+ RAM*
- **Storage**: 20 GB gp2
- **Security Group Rules**:

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | Your IP/32 | Admin access |
| Custom TCP | TCP | 3000 | 0.0.0.0/0 | Grafana UI |
| Custom TCP | TCP | 5601 | 0.0.0.0/0 | Kibana UI |
| Custom TCP | TCP | 9090 | Your IP/32 | Prometheus |
| Custom TCP | TCP | 3100 | App Server IP | Loki (internal) |
| Custom TCP | TCP | 9200 | Your IP/32 | Elasticsearch |

**Instance 2: Application Server**
- **Name**: `app-server`
- **AMI**: Ubuntu Server 22.04 LTS
- **Instance Type**: `t2.micro` (1 vCPU, 1GB RAM)
- **Storage**: 8 GB gp2
- **Security Group Rules**:

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | Your IP/32 | Admin access |
| Custom TCP | TCP | 3000 | 0.0.0.0/0 | Node.js App |
| Custom TCP | TCP | 9100 | Monitoring IP | Node Exporter |
| Custom TCP | TCP | 3100 | Monitoring IP | Promtail |

---

### Step 2: Initial Setup (Run on Both Instances)

```bash
# SSH into each instance
ssh -i your-key.pem ubuntu@INSTANCE_PUBLIC_IP

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker & Docker Compose
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce docker-compose

# Add user to docker group
sudo usermod -aG docker ubuntu
newgrp docker

# Verify Docker
docker --version
docker-compose --version

# Install additional tools
sudo apt install -y git curl wget vim htop net-tools
```

---

## Phase 2: PLG Stack Setup (Monitoring Server)

### Step 3: Create PLG Directory Structure

```bash
mkdir -p ~/monitoring/plg-stack && cd ~/monitoring/plg-stack

# Create directories for persistent data
mkdir -p prometheus-data grafana-data loki-data
```

### Step 4: Prometheus Configuration

Create `prometheus.yml`:
```bash
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files: []

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['APP_SERVER_PRIVATE_IP:9100']  # Replace with app server IP
    metrics_path: '/metrics'

  - job_name: 'node-app'
    static_configs:
      - targets: ['APP_SERVER_PRIVATE_IP:3000']  # Replace with app server IP
    metrics_path: '/metrics'
EOF
```

### Step 5: Loki Configuration

Create `loki-config.yml`:
```bash
cat > loki-config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index

  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF
```

### Step 6: Promtail Configuration (for receiving logs)

Create `promtail-config.yml`:
```bash
cat > promtail-config.yml << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: system-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: system-logs
          __path__: /var/log/syslog
    
  - job_name: app-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: app-logs
          env: production
EOF
```

### Step 7: Docker Compose for PLG

Create `docker-compose-plg.yml`:
```bash
cat > docker-compose-plg.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    networks:
      - monitoring

  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml
      - ./loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    volumes:
      - ./promtail-config.yml:/etc/promtail/config.yml
      - /var/log:/var/log:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitoring
    depends_on:
      - loki

  grafana:
    image: grafana/grafana:10.0.0
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - ./grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
    networks:
      - monitoring
    depends_on:
      - prometheus
      - loki

networks:
  monitoring:
    driver: bridge
EOF
```

### Step 8: Start PLG Stack

```bash
cd ~/monitoring/plg-stack

# Start services
docker-compose -f docker-compose-plg.yml up -d

# Verify all running
docker-compose -f docker-compose-plg.yml ps

# Check logs
docker-compose -f docker-compose-plg.yml logs -f
```

**Access URLs:**
- Grafana: `http://MONITORING_SERVER_IP:3000` (admin/admin123)
- Prometheus: `http://MONITORING_SERVER_IP:9090`
- Loki: `http://MONITORING_SERVER_IP:3100/metrics`

---

## Phase 3: ELK Stack Setup (Monitoring Server)

### Step 9: Create ELK Directory

```bash
mkdir -p ~/monitoring/elk-stack && cd ~/monitoring/elk-stack

# Create data directories
mkdir -p elasticsearch-data
chmod 777 elasticsearch-data  # Elasticsearch needs write permissions
```

### Step 10: Docker Compose for ELK

Create `docker-compose-elk.yml`:
```bash
cat > docker-compose-elk.yml << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - ./elasticsearch-data:/usr/share/elasticsearch/data
    networks:
      - elk

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: logstash
    volumes:
      - ./logstash-config:/usr/share/logstash/pipeline:ro
    ports:
      - "5044:5044"
      - "9600:9600"
    environment:
      - "LS_JAVA_OPTS=-Xmx512m -Xms512m"
    networks:
      - elk
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    networks:
      - elk
    depends_on:
      - elasticsearch

networks:
  elk:
    driver: bridge
EOF
```

### Step 11: Logstash Pipeline Configuration

```bash
mkdir -p logstash-config

cat > logstash-config/logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
  
  tcp {
    port => 5000
    codec => json
  }
}

filter {
  if [type] == "syslog" {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" }
    }
    date {
      match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    }
  }
  
  if [service] == "node-app" {
    json {
      source => "message"
      target => "parsed"
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
  }
  
  stdout { codec => rubydebug }
}
EOF
```

### Step 12: Start ELK Stack

```bash
cd ~/monitoring/elk-stack

# Start services (this may take 2-3 minutes)
docker-compose -f docker-compose-elk.yml up -d

# Check status
docker-compose -f docker-compose-elk.yml ps

# Wait for Elasticsearch to be ready
curl http://localhost:9200/_cluster/health

# View logs
docker-compose -f docker-compose-elk.yml logs -f elasticsearch
```

**Access URLs:**
- Kibana: `http://MONITORING_SERVER_IP:5601`
- Elasticsearch: `http://MONITORING_SERVER_IP:9200`

---

## Phase 4: Application Server Setup

### Step 13: Install Node.js and App

```bash
# SSH into App Server
ssh -i your-key.pem ubuntu@APP_SERVER_PUBLIC_IP

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Create app directory
mkdir -p ~/app && cd ~/app

# Create package.json
cat > package.json << 'EOF'
{
  "name": "monitoring-demo-app",
  "version": "1.0.0",
  "description": "Demo app for monitoring practice",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "prom-client": "^15.1.0",
    "winston": "^3.11.0"
  }
}
EOF

npm install
```

### Step 14: Create Application with Metrics & Logging

Create `server.js`:
```bash
cat > server.js << 'EOF'
const express = require('express');
const promClient = require('prom-client');
const winston = require('winston');
const fs = require('fs');
const path = require('path');

const app = express();
const port = 3000;

// Create logs directory
const logDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir);
}

// Configure Winston logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: path.join(logDir, 'app.log') }),
    new winston.transports.Console()
  ]
});

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register]
});

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.3, 0.5, 1, 2, 5],
  registers: [register]
});

// Middleware
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    
    httpRequestsTotal.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode
    });
    
    httpRequestDuration.observe(
      { method: req.method, route: req.route?.path || req.path },
      duration
    );
    
    // Log every request
    logger.info({
      event: 'http_request',
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: duration,
      userAgent: req.get('user-agent'),
      ip: req.ip
    });
  });
  
  next();
});

// Routes
app.get('/', (req, res) => {
  logger.info({ event: 'page_view', page: 'home' });
  res.json({ message: 'Welcome to Monitoring Demo', timestamp: new Date().toISOString() });
});

app.get('/api/data', (req, res) => {
  // Simulate processing time
  const delay = Math.random() * 1000;
  
  setTimeout(() => {
    if (Math.random() > 0.9) {
      logger.error({ event: 'api_error', path: '/api/data', reason: 'simulated_error' });
      return res.status(500).json({ error: 'Simulated error' });
    }
    
    logger.info({ event: 'api_success', path: '/api/data', items: 100 });
    res.json({ data: Array.from({length: 100}, (_, i) => ({ id: i, value: Math.random() })) });
  }, delay);
});

app.get('/api/slow', (req, res) => {
  logger.warn({ event: 'slow_endpoint_called', path: '/api/slow' });
  setTimeout(() => {
    res.json({ message: 'This was intentionally slow' });
  }, 3000);
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', uptime: process.uptime() });
});

// Error endpoint for testing
app.get('/error', (req, res) => {
  logger.error({ event: 'forced_error', message: 'This is a test error' });
  res.status(500).json({ error: 'Test error' });
});

app.listen(port, () => {
  logger.info({ event: 'server_start', port: port, pid: process.pid });
  console.log(`Server running on port ${port}`);
});
EOF
```

### Step 15: Install Node Exporter (for system metrics)

```bash
# Download and install Node Exporter
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.7.0.linux-amd64*

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Verify
curl http://localhost:9100/metrics
```

### Step 16: Setup Promtail (for PLG/Loki)

```bash
# Install Promtail
cd ~
wget https://github.com/grafana/loki/releases/download/v2.9.0/promtail-linux-amd64.zip
sudo apt install -y unzip
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail

# Create config
sudo mkdir -p /etc/promtail

sudo tee /etc/promtail/promtail-config.yml > /dev/null << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://MONITORING_SERVER_PRIVATE_IP:3100/loki/api/v1/push

scrape_configs:
  - job_name: app-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: node-app
          env: production
          host: app-server
          __path__: /home/ubuntu/app/logs/*.log
  
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log
EOF

# Create systemd service
sudo tee /etc/systemd/system/promtail.service > /dev/null << 'EOF'
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start promtail
sudo systemctl enable promtail
```

### Step 17: Setup Filebeat (for ELK)

```bash
# Install Filebeat
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.0-linux-x86_64.tar.gz
tar xzvf filebeat-8.11.0-linux-x86_64.tar.gz
sudo mv filebeat-8.11.0-linux-x86_64 /usr/local/filebeat

# Create config
sudo tee /usr/local/filebeat/filebeat.yml > /dev/null << EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /home/ubuntu/app/logs/*.log
  fields:
    service: node-app
    environment: production
  fields_under_root: true

output.logstash:
  hosts: ["MONITORING_SERVER_PRIVATE_IP:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
EOF

sudo mkdir -p /var/log/filebeat

# Create systemd service
sudo tee /etc/systemd/system/filebeat.service > /dev/null << 'EOF'
[Unit]
Description=Filebeat sends log files to Logstash
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/local/filebeat/filebeat -e -c /usr/local/filebeat/filebeat.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start filebeat
sudo systemctl enable filebeat
```

### Step 18: Start Application

```bash
cd ~/app

# Start with PM2 for persistence
sudo npm install -g pm2
pm2 start server.js --name node-app
pm2 save
pm2 startup

# Verify
pm2 status
curl http://localhost:3000/health
```

---

## Phase 5: Generate Traffic & Configure Dashboards

### Step 19: Traffic Generator Script

On App Server, create `generate-traffic.sh`:
```bash
cat > ~/generate-traffic.sh << 'EOF'
#!/bin/bash

BASE_URL="http://localhost:3000"

while true; do
  # Normal traffic
  curl -s $BASE_URL/ > /dev/null
  curl -s $BASE_URL/api/data > /dev/null
  
  # Slow endpoint (10% of time)
  if [ $((RANDOM % 10)) -eq 0 ]; then
    curl -s $BASE_URL/api/slow > /dev/null
  fi
  
  # Error (5% of time)
  if [ $((RANDOM % 20)) -eq 0 ]; then
    curl -s $BASE_URL/error > /dev/null
  fi
  
  sleep 1
done
EOF

chmod +x ~/generate-traffic.sh

# Run in background
nohup ./generate-traffic.sh > /dev/null 2>&1 &
```

### Step 20: Configure Grafana Dashboards

1. **Access Grafana**: `http://MONITORING_SERVER_IP:3000` (admin/admin123)

2. **Add Prometheus Data Source**:
   - Configuration → Data Sources → Add data source
   - Select Prometheus
   - URL: `http://prometheus:9090`
   - Save & Test

3. **Add Loki Data Source**:
   - Add data source → Loki
   - URL: `http://loki:3100`
   - Save & Test

4. **Import Node Exporter Dashboard**:
   - Create → Import
   - Dashboard ID: `1860` (Node Exporter Full)
   - Select Prometheus datasource
   - Import

5. **Create Custom Application Dashboard**:
   - Create → Dashboard → Add Panel
   - **Panel 1**: Request Rate
     - Query: `rate(http_requests_total[5m])`
   - **Panel 2**: Error Rate
     - Query: `rate(http_requests_total{status=~"5.."}[5m])`
   - **Panel 3**: 95th Percentile Latency
     - Query: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
   - **Panel 4**: Logs (Loki)
     - Query: `{job="node-app"} |= "error"`

### Step 21: Configure Kibana (ELK)

1. **Access Kibana**: `http://MONITORING_SERVER_IP:5601`

2. **Create Index Pattern**:
   - Stack Management → Index Patterns → Create index pattern
   - Pattern: `logs-*`
   - Time field: `@timestamp`

3. **Create Visualizations**:
   - **Discover**: View raw logs
   - **Visualize Library** → Create visualization
   - **Dashboard**: Add visualizations

4. **Sample Kibana Queries**:
   ```json
   // Find all errors
   {
     "query": {
       "match": {
         "level": "error"
       }
     }
   }
   
   // Find slow requests
   {
     "query": {
       "range": {
         "duration": {
           "gte": 1.0
         }
       }
     }
   }
   ```

---

## Phase 6: Verification Checklist

### Verify PLG Stack
```bash
# On Monitoring Server
curl http://localhost:9090/api/v1/targets  # Should show app-server:9100
curl http://localhost:3100/ready          # Loki ready check

# Check Promtail is shipping logs
sudo journalctl -u promtail -f
```

### Verify ELK Stack
```bash
# Check Elasticsearch
curl http://localhost:9200/_cat/indices?v  # Should show logs-* indices

# Check Logstash
curl http://localhost:9600/_node/stats

# Check Filebeat on App Server
sudo systemctl status filebeat
sudo tail -f /var/log/filebeat/filebeat
```

### Verify Application
```bash
# On App Server
curl http://localhost:3000/metrics  # Should show Prometheus metrics
ls -la ~/app/logs/                  # Should show app.log with entries
pm2 logs                            # View application logs
```

---

## Access URLs Summary

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | `http://MONITORING_IP:3000` | admin/admin123 |
| **Prometheus** | `http://MONITORING_IP:9090` | None |
| **Kibana** | `http://MONITORING_IP:5601` | None |
| **Node App** | `http://APP_IP:3000` | None |
| **Elasticsearch** | `http://MONITORING_IP:9200` | None |

---

## Cleanup Commands

When done practicing:

```bash
# Stop all Docker containers on Monitoring Server
cd ~/monitoring/plg-stack && docker-compose down
cd ~/monitoring/elk-stack && docker-compose down

# Stop services on App Server
pm2 delete all
sudo systemctl stop node_exporter promtail filebeat

# Terminate EC2 instances via AWS Console to avoid charges
```

---

## What You've Learned

✅ **Infrastructure**: Multi-server AWS setup with proper security groups  
✅ **Metrics**: Prometheus scraping + Grafana visualization  
✅ **Logging**: Loki (cloud-native) vs ELK (full-text search)  
✅ **Agents**: Promtail, Filebeat, Node Exporter configuration  
✅ **Dashboards**: Creating meaningful visualizations  
✅ **Correlation**: Connecting metrics with logs for root cause analysis

**Next Steps**: Add alerting (AlertManager for PLG, Watcher for ELK), implement distributed tracing (Tempo/Jaeger), or scale to Kubernetes!

# 🚀 Advanced Monitoring Lab: Alerting, Tracing & Multi-App Setup

## Architecture Expansion

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       EXPANDED MONITORING ARCHITECTURE                  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    MONITORING SERVER (t2.large)                  │   │
│  │                                                                  │   │
│  │  PLG Stack:                  ELK Stack:        New Additions:    │   │
│  │  • Prometheus (9090)        • Elasticsearch    • AlertManager    │   │
│  │  • Loki (3100)              • Logstash         • Tempo (3200)    │   │
│  │  • Grafana (3000)           • Kibana (5601)    • Jaeger (16686)  │   │
│  │                                                • OTel Collector  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                    │                                    │
│           ┌────────────────────────┼────────────────────────┐           │
│           │                        │                        │           │
│  ┌────────▼─────────┐    ┌──────────▼──────────┐   ┌────────▼────────┐  │
│  │   APP SERVER 1   │    │    APP SERVER 2     │   │  APP SERVER 3   │  │
│  │  (Node.js API)   │    │  (Python Flask)     │   │ (Java Spring)   │  │
│  │                  │    │                     │   │                 │  │
│  │  • Node Exporter │    │  • Node Exporter    │   │ • Node Exporter │  │
│  │  • Promtail      │    │  • Promtail         │   │ • Promtail      │  │
│  │  • Filebeat      │    │  • Filebeat         │   │ • Filebeat      │  │
│  │  • OTel SDK      │    │  • OTel SDK         │   │• OTel Java Agent│  │
│  │    (tracing)     │    │    (tracing)        │   │(auto-instrument)│  │
│  │  Port: 3000      │    │  Port: 5000         │   │  Port: 8080     │  │
│  └──────────────────┘    └─────────────────────┘   └─────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 1: Alerting Setup (AlertManager for PLG Stack)

### Step 1: Create AlertManager Configuration

On **Monitoring Server**:

```bash
cd ~/monitoring/plg-stack

# Create alertmanager directory
mkdir -p alertmanager-data

# Create AlertManager configuration
cat > alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@yourdomain.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'  # Use app password, not regular password

# Route alerts to different receivers based on severity
route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default'
  
  routes:
    # Critical alerts → PagerDuty/Slack + Email
    - match:
        severity: critical
      receiver: 'critical-alerts'
      continue: true
    
    # Warning alerts → Slack only
    - match:
        severity: warning
      receiver: 'slack-warnings'
    
    # Info alerts → Email digest
    - match:
        severity: info
      receiver: 'email-digest'

# Receivers define where alerts go
receivers:
  - name: 'default'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#monitoring'
        title: 'Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#critical-alerts'
        title: '🔥 CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
    
    email_configs:
      - to: 'oncall@yourdomain.com'
        subject: 'CRITICAL Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Time: {{ .StartsAt }}
          {{ end }}

  - name: 'slack-warnings'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#warnings'
        title: '⚠️ Warning: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

  - name: 'email-digest'
    email_configs:
      - to: 'team@yourdomain.com'
        subject: 'Daily Monitoring Digest'
        send_resolved: false

# Inhibit alerts (don't warn about disk if node is down)
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF
```

### Step 2: Create Prometheus Alert Rules

```bash
cat > alert-rules.yml << 'EOF'
groups:
  - name: node-alerts
    interval: 30s
    rules:
      # High CPU Usage
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% (current value: {{ $value }}%)"

      # Critical CPU
      - alert: CriticalCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 95
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "CRITICAL: CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 95% (current value: {{ $value }}%)"

      # High Memory Usage
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% (current value: {{ $value }}%)"

      # Disk Space Running Low
      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Less than 10% disk space remaining (current: {{ $value }}%)"

      # Node Down
      - alert: NodeDown
        expr: up{job="node-exporter"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "Node exporter has been down for more than 1 minute"

  - name: application-alerts
    interval: 30s
    rules:
      # High Error Rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on {{ $labels.instance }}"
          description: "Error rate is {{ $value }} errors per second"

      # Slow Response Time
      - alert: SlowResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Slow response time on {{ $labels.instance }}"
          description: "95th percentile latency is {{ $value }}s"

      # Application Down
      - alert: ApplicationDown
        expr: up{job="node-app"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Application {{ $labels.instance }} is down"
          description: "Application has been down for more than 1 minute"

      # Log Error Spike
      - alert: LogErrorSpike
        expr: rate({job="node-app"} |= "error" | line_format "{{.level}}" [5m]) > 10
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Error spike in application logs"
          description: "More than 10 errors per minute in logs"

  - name: log-alerts
    interval: 1m
    rules:
      # Database Connection Error
      - alert: DatabaseConnectionError
        expr: |
          sum(rate({job="node-app"} |= "database" |= "connection" |= "failed" [5m])) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection failures detected"
          description: "Application is failing to connect to database"

      # Security Alert - Multiple Failed Logins
      - alert: MultipleFailedLogins
        expr: |
          sum(rate({job="node-app"} |= "login" |= "failed" [15m])) > 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Multiple failed login attempts"
          description: "Possible brute force attack detected"
EOF
```

### Step 3: Update Prometheus Configuration

Update `prometheus.yml`:
```bash
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'monitoring-server'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

# Load alert rules
rule_files:
  - 'alert-rules.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']

  - job_name: 'node-exporter-app1'
    static_configs:
      - targets: ['APP_SERVER_1_IP:9100']
    metrics_path: '/metrics'

  - job_name: 'node-exporter-app2'
    static_configs:
      - targets: ['APP_SERVER_2_IP:9100']

  - job_name: 'node-exporter-app3'
    static_configs:
      - targets: ['APP_SERVER_3_IP:9100']

  - job_name: 'node-app-1'
    static_configs:
      - targets: ['APP_SERVER_1_IP:3000']
    metrics_path: '/metrics'

  - job_name: 'node-app-2'
    static_configs:
      - targets: ['APP_SERVER_2_IP:5000']
    metrics_path: '/metrics'

  - job_name: 'java-app-3'
    static_configs:
      - targets: ['APP_SERVER_3_IP:8080']
    metrics_path: '/actuator/prometheus'
EOF
```

### Step 4: Update Docker Compose

Update `docker-compose-plg.yml`:
```bash
cat > docker-compose-plg.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alert-rules.yml:/etc/prometheus/alert-rules.yml
      - ./prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
      - '--alertmanager.url=http://alertmanager:9093'
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - ./alertmanager-data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    networks:
      - monitoring

  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml
      - ./loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    volumes:
      - ./promtail-config.yml:/etc/promtail/config.yml
      - /var/log:/var/log:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitoring
    depends_on:
      - loki

  grafana:
    image: grafana/grafana:10.0.0
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - ./grafana-data:/var/lib/grafana
      - ./grafana-provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource,grafana-piechart-panel
    networks:
      - monitoring
    depends_on:
      - prometheus
      - loki

networks:
  monitoring:
    driver: bridge
EOF
```

### Step 5: Start Updated Stack

```bash
cd ~/monitoring/plg-stack

# Recreate containers with new config
docker-compose -f docker-compose-plg.yml down
docker-compose -f docker-compose-plg.yml up -d

# Verify AlertManager is working
curl http://localhost:9093/api/v1/status

# Check Prometheus alerts page
# http://MONITORING_IP:9090/alerts
```

### Step 6: Test Alerts

```bash
# Simulate high CPU (run on App Server)
yes > /dev/null &

# Check Prometheus alerts page - should show firing alert

# Stop the CPU stress
kill %1

# Verify resolved notification
```

---

## Part 2: Distributed Tracing Setup (Tempo + OpenTelemetry)

### Step 1: Create Tempo Configuration

```bash
cd ~/monitoring/plg-stack

cat > tempo-config.yml << 'EOF'
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: "0.0.0.0:4318"
        grpc:
          endpoint: "0.0.0.0:4317"

ingester:
  trace_idle_period: 10s
  max_block_bytes: 1_000_000
  max_block_duration: 5m

compactor:
  compaction:
    compaction_window: 1h
    max_block_bytes: 100_000_000
    block_retention: 1h
    compacted_block_retention: 10m

storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/traces
    wal:
      path: /tmp/tempo/wal
EOF
```

### Step 2: Update Docker Compose for Tempo

Add to `docker-compose-plg.yml`:
```yaml
  tempo:
    image: grafana/tempo:latest
    container_name: tempo
    ports:
      - "3200:3200"    # Tempo HTTP
      - "4317:4317"    # OTLP gRPC
      - "4318:4318"    # OTLP HTTP
    volumes:
      - ./tempo-config.yml:/etc/tempo/tempo.yml
      - ./tempo-data:/tmp/tempo
    command: -config.file=/etc/tempo/tempo.yml
    networks:
      - monitoring

  # OpenTelemetry Collector (optional, for advanced routing)
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    container_name: otel-collector
    ports:
      - "4319:4317"    # OTLP gRPC
      - "4320:4318"    # OTLP HTTP
    volumes:
      - ./otel-collector-config.yml:/etc/otelcol-contrib/config.yaml
    command: --config /etc/otelcol-contrib/config.yaml
    networks:
      - monitoring
    depends_on:
      - tempo
```

### Step 3: Configure Grafana for Tracing

Add to `docker-compose-plg.yml` environment:
```yaml
  grafana:
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource,grafana-piechart-panel,grafana-tempo-datasource
```

### Step 4: Restart Stack with Tempo

```bash
docker-compose -f docker-compose-plg.yml up -d

# Verify Tempo
curl http://localhost:3200/ready
```

---

## Part 3: Add Application Server 2 (Python Flask)

### Step 5: Launch EC2 Instance

Create **App Server 2**:
- **Name**: `app-server-2-python`
- **AMI**: Ubuntu 22.04 LTS
- **Instance Type**: `t2.micro`
- **Security Group**: Same as App Server 1 (ports 22, 5000, 9100)

### Step 6: Setup Python Application

```bash
ssh -i your-key.pem ubuntu@APP_SERVER_2_IP

# Update and install Python
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-pip python3-venv git

# Create app directory
mkdir -p ~/app && cd ~/app
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install flask opentelemetry-api opentelemetry-sdk opentelemetry-instrumentation-flask opentelemetry-exporter-otlp prometheus-client

# Create Flask app with tracing
cat > app.py << 'EOF'
from flask import Flask, jsonify, request
import time
import random
import logging
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.sdk.resources import Resource

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configure OpenTelemetry tracing
resource = Resource.create({"service.name": "python-flask-app", "service.version": "1.0.0"})
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Configure OTLP exporter (sending to Tempo on Monitoring Server)
otlp_exporter = OTLPSpanExporter(
    endpoint="http://MONITORING_SERVER_IP:4317",
    insecure=True
)
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    duration = time.time() - request.start_time
    REQUEST_COUNT.labels(method=request.method, endpoint=request.endpoint or 'unknown', status=response.status_code).inc()
    REQUEST_DURATION.labels(method=request.method, endpoint=request.endpoint or 'unknown').observe(duration)
    
    logger.info(f"Request: {request.method} {request.path} - {response.status_code} - {duration:.3f}s")
    return response

@app.route('/')
def home():
    logger.info("Home page accessed")
    return jsonify({"message": "Python Flask App", "service": "app-2", "version": "1.0.0"})

@app.route('/api/users', methods=['GET'])
def get_users():
    with tracer.start_as_current_span("get_users"):
        # Simulate database call
        with tracer.start_as_current_span("database_query"):
            time.sleep(random.uniform(0.01, 0.1))
            users = [{"id": i, "name": f"User {i}"} for i in range(10)]
        
        logger.info(f"Retrieved {len(users)} users")
        return jsonify({"users": users, "count": len(users)})

@app.route('/api/process', methods=['POST'])
def process_data():
    with tracer.start_as_current_span("process_data"):
        data = request.get_json() or {}
        
        # Simulate processing
        with tracer.start_as_current_span("validation"):
            time.sleep(0.05)
        
        with tracer.start_as_current_span("transformation"):
            time.sleep(random.uniform(0.1, 0.5))
            result = {"processed": True, "input": data, "timestamp": time.time()}
        
        logger.info(f"Processed data: {result}")
        return jsonify(result)

@app.route('/api/slow')
def slow_endpoint():
    delay = random.uniform(1, 3)
    time.sleep(delay)
    logger.warning(f"Slow endpoint called, delay: {delay}s")
    return jsonify({"message": "Slow response", "delay": delay})

@app.route('/api/error')
def error_endpoint():
    logger.error("Simulated error endpoint called")
    return jsonify({"error": "Simulated error"}), 500

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "python-flask-app"})

if __name__ == '__main__':
    import os
    os.makedirs('logs', exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

mkdir -p logs

# Create systemd service
sudo tee /etc/systemd/system/python-app.service > /dev/null << 'EOF'
[Unit]
Description=Python Flask Application
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/app
Environment="PATH=/home/ubuntu/app/venv/bin"
Environment="OTEL_EXPORTER_OTLP_ENDPOINT=http://MONITORING_SERVER_IP:4317"
ExecStart=/home/ubuntu/app/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start python-app
sudo systemctl enable python-app
```

### Step 7: Install Node Exporter & Promtail on App Server 2

```bash
# Node Exporter (same as App Server 1)
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.7.0.linux-amd64*

sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Promtail
wget https://github.com/grafana/loki/releases/download/v2.9.0/promtail-linux-amd64.zip
sudo apt install -y unzip
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail

sudo tee /etc/promtail/promtail-config.yml > /dev/null << EOF
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://MONITORING_SERVER_IP:3100/loki/api/v1/push

scrape_configs:
  - job_name: python-app-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: python-flask-app
          service: app-2
          env: production
          __path__: /home/ubuntu/app/logs/*.log
EOF

sudo tee /etc/systemd/system/promtail.service > /dev/null << 'EOF'
[Unit]
Description=Promtail Log Shipper
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start promtail
sudo systemctl enable promtail

# Filebeat for ELK
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.0-linux-x86_64.tar.gz
tar xzvf filebeat-8.11.0-linux-x86_64.tar.gz
sudo mv filebeat-8.11.0-linux-x86_64 /usr/local/filebeat

sudo tee /usr/local/filebeat/filebeat.yml > /dev/null << EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /home/ubuntu/app/logs/*.log
  fields:
    service: python-flask-app
    environment: production
    app_id: app-2
  fields_under_root: true

output.logstash:
  hosts: ["MONITORING_SERVER_IP:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
EOF

sudo mkdir -p /var/log/filebeat

sudo tee /etc/systemd/system/filebeat.service > /dev/null << 'EOF'
[Unit]
Description=Filebeat
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/local/filebeat/filebeat -e -c /usr/local/filebeat/filebeat.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start filebeat
sudo systemctl enable filebeat
```

---

## Part 4: Add Application Server 3 (Java Spring Boot)

### Step 8: Launch EC2 Instance

Create **App Server 3**:
- **Name**: `app-server-3-java`
- **AMI**: Ubuntu 22.04 LTS
- **Instance Type**: `t2.micro` (or `t2.small` for Java)
- **Security Group**: Ports 22, 8080, 9100

### Step 9: Setup Java Application

```bash
ssh -i your-key.pem ubuntu@APP_SERVER_3_IP

# Install Java
sudo apt update && sudo apt upgrade -y
sudo apt install -y openjdk-17-jdk maven git

java -version

# Create Spring Boot app
mkdir -p ~/app && cd ~/app

# Create pom.xml
cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>
    
    <groupId>com.example</groupId>
    <artifactId>monitoring-demo</artifactId>
    <version>1.0.0</version>
    
    <properties>
        <java.version>17</java.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>
        <dependency>
            <groupId>io.opentelemetry.javaagent</groupId>
            <artifactId>opentelemetry-javaagent</artifactId>
            <version>1.32.0</version>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Create directory structure
mkdir -p src/main/java/com/example/demo src/main/resources

# Create main application
cat > src/main/java/com/example/demo/DemoApplication.java << 'EOF'
package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import org.springframework.beans.factory.annotation.Autowired;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Timer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.concurrent.TimeUnit;

@SpringBootApplication
@RestController
public class DemoApplication {
    
    private static final Logger logger = LoggerFactory.getLogger(DemoApplication.class);
    
    @Autowired
    private MeterRegistry meterRegistry;
    
    private final Counter requestCounter;
    private final Timer requestTimer;
    
    public DemoApplication(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        this.requestCounter = Counter.builder("http_requests_total")
            .description("Total HTTP requests")
            .register(meterRegistry);
        this.requestTimer = Timer.builder("http_request_duration_seconds")
            .description("HTTP request duration")
            .register(meterRegistry);
    }
    
    @GetMapping("/")
    public Map<String, String> home() {
        logger.info("Java Spring Boot app accessed");
        requestCounter.increment();
        return Map.of(
            "message", "Java Spring Boot Application",
            "service", "app-3",
            "technology", "java",
            "timestamp", new Date().toString()
        );
    }
    
    @GetMapping("/api/orders")
    public Map<String, Object> getOrders() {
        long start = System.currentTimeMillis();
        logger.info("Fetching orders from database");
        
        // Simulate database call
        List<Map<String, Object>> orders = new ArrayList<>();
        for (int i = 1; i <= 5; i++) {
            orders.add(Map.of(
                "id", i,
                "customer", "Customer " + i,
                "amount", Math.random() * 1000,
                "status", "completed"
            ));
        }
        
        long duration = System.currentTimeMillis() - start;
        requestTimer.record(duration, TimeUnit.MILLISECONDS);
        requestCounter.increment();
        
        logger.info("Retrieved {} orders in {}ms", orders.size(), duration);
        
        return Map.of("orders", orders, "count", orders.size(), "duration_ms", duration);
    }
    
    @PostMapping("/api/process")
    public Map<String, Object> processOrder(@RequestBody Map<String, Object> request) {
        long start = System.currentTimeMillis();
        logger.info("Processing order: {}", request);
        
        // Simulate processing
        try {
            Thread.sleep((long)(Math.random() * 200));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        Map<String, Object> result = Map.of(
            "processed", true,
            "input", request,
            "processed_at", new Date().toString()
        );
        
        long duration = System.currentTimeMillis() - start;
        requestTimer.record(duration, TimeUnit.MILLISECONDS);
        requestCounter.increment();
        
        logger.info("Order processed in {}ms", duration);
        return result;
    }
    
    @GetMapping("/api/slow")
    public Map<String, Object> slowEndpoint() {
        long delay = (long)(1000 + Math.random() * 2000);
        logger.warn("Slow endpoint called with delay: {}ms", delay);
        
        try {
            Thread.sleep(delay);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        return Map.of("message", "Slow response", "delay_ms", delay);
    }
    
    @GetMapping("/api/error")
    public Map<String, String> errorEndpoint() {
        logger.error("Simulated error in Java application");
        throw new RuntimeException("Simulated error");
    }
    
    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "healthy", "service", "java-spring-app");
    }
    
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
EOF

# Create application.properties
cat > src/main/resources/application.properties << 'EOF'
server.port=8080
management.endpoints.web.exposure.include=health,info,metrics,prometheus
management.endpoint.health.show-details=always
management.metrics.tags.application=java-spring-app
logging.file.name=logs/app.log
logging.pattern.file=%d{yyyy-MM-dd HH:mm:ss} - %msg%n
logging.level.root=INFO
EOF

# Build and run
mvn clean package -DskipTests

# Create systemd service
sudo tee /etc/systemd/system/java-app.service > /dev/null << 'EOF'
[Unit]
Description=Java Spring Boot Application
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/app
Environment="OTEL_EXPORTER_OTLP_ENDPOINT=http://MONITORING_SERVER_IP:4317"
Environment="OTEL_SERVICE_NAME=java-spring-app"
Environment="OTEL_RESOURCE_ATTRIBUTES=service.version=1.0.0,deployment.environment=production"
Environment="JAVA_TOOL_OPTIONS=-javaagent:/home/ubuntu/app/opentelemetry-javaagent.jar"
ExecStart=/usr/bin/java -jar target/monitoring-demo-1.0.0.jar
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Download OpenTelemetry Java Agent
wget https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.32.0/opentelemetry-javaagent.jar

sudo systemctl daemon-reload
sudo systemctl start java-app
sudo systemctl enable java-app
```

### Step 10: Install Node Exporter & Agents on App Server 3

```bash
# Node Exporter
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.7.0.linux-amd64*

sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Promtail
wget https://github.com/grafana/loki/releases/download/v2.9.0/promtail-linux-amd64.zip
sudo apt install -y unzip
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail

sudo mkdir -p /etc/promtail

sudo tee /etc/promtail/promtail-config.yml > /dev/null << EOF
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://MONITORING_SERVER_IP:3100/loki/api/v1/push

scrape_configs:
  - job_name: java-app-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: java-spring-app
          service: app-3
          env: production
          __path__: /home/ubuntu/app/logs/*.log
EOF

sudo tee /etc/systemd/system/promtail.service > /dev/null << 'EOF'
[Unit]
Description=Promtail
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start promtail
sudo systemctl enable promtail

# Filebeat
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.0-linux-x86_64.tar.gz
tar xzvf filebeat-8.11.0-linux-x86_64.tar.gz
sudo mv filebeat-8.11.0-linux-x86_64 /usr/local/filebeat

sudo tee /usr/local/filebeat/filebeat.yml > /dev/null << EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /home/ubuntu/app/logs/*.log
  fields:
    service: java-spring-app
    environment: production
    app_id: app-3
  fields_under_root: true

output.logstash:
  hosts: ["MONITORING_SERVER_IP:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
EOF

sudo mkdir -p /var/log/filebeat

sudo tee /etc/systemd/system/filebeat.service > /dev/null << 'EOF'
[Unit]
Description=Filebeat
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/local/filebeat/filebeat -e -c /usr/local/filebeat/filebeat.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start filebeat
sudo systemctl enable filebeat
```

---

## Part 5: Final Configuration & Dashboard Setup

### Step 11: Update All Configurations on Monitoring Server

Update Prometheus to scrape all apps:
```bash
cd ~/monitoring/plg-stack

cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'monitoring-server'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - 'alert-rules.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']

  - job_name: 'tempo'
    static_configs:
      - targets: ['tempo:3200']

  # App Server 1 - Node.js
  - job_name: 'node-exporter-app1'
    static_configs:
      - targets: ['APP_SERVER_1_IP:9100']
        labels:
          instance: 'app-server-1'
          env: 'production'

  - job_name: 'node-app-1'
    static_configs:
      - targets: ['APP_SERVER_1_IP:3000']
        labels:
          service: 'nodejs-api'
          instance: 'app-server-1'

  # App Server 2 - Python
  - job_name: 'node-exporter-app2'
    static_configs:
      - targets: ['APP_SERVER_2_IP:9100']
        labels:
          instance: 'app-server-2'
          env: 'production'

  - job_name: 'python-app-2'
    static_configs:
      - targets: ['APP_SERVER_2_IP:5000']
        labels:
          service: 'python-flask'
          instance: 'app-server-2'

  # App Server 3 - Java
  - job_name: 'node-exporter-app3'
    static_configs:
      - targets: ['APP_SERVER_3_IP:9100']
        labels:
          instance: 'app-server-3'
          env: 'production'

  - job_name: 'java-app-3'
    static_configs:
      - targets: ['APP_SERVER_3_IP:8080']
        labels:
          service: 'java-spring'
          instance: 'app-server-3'
    metrics_path: '/actuator/prometheus'
EOF
```

### Step 12: Create Grafana Dashboards

Create provisioning directory:
```bash
mkdir -p grafana-provisioning/dashboards grafana-provisioning/datasources

# Create datasource configuration
cat > grafana-provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
EOF

# Create dashboard provider
cat > grafana-provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF

mkdir -p grafana-data/dashboards
```

Create multi-app dashboard JSON (`grafana-data/dashboards/multi-app-dashboard.json`):
```json
{
  "dashboard": {
    "title": "Multi-Application Monitoring",
    "tags": ["prometheus", "grafana", "multi-app"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate by Service",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{service}} - {{instance}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Error Rate by Service",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])",
            "legendFormat": "{{service}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "95th Percentile Latency",
        "type": "stat",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "{{service}}"
          }
        ],
        "gridPos": {"h": 8, "w": 8, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "CPU Usage by Server",
        "type": "gauge",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{instance}}"
          }
        ],
        "gridPos": {"h": 8, "w": 8, "x": 8, "y": 8}
      },
      {
        "id": 5,
        "title": "Application Logs (Loki)",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=~\"node-app|python-flask-app|java-spring-app\"} |= \"error\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 8, "x": 16, "y": 8}
      },
      {
        "id": 6,
        "title": "Distributed Traces (Tempo)",
        "type": "traces",
        "targets": [
          {
            "queryType": "search",
            "serviceName": "python-flask-app"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "10s"
  }
}
```

### Step 13: Restart Everything

```bash
cd ~/monitoring/plg-stack

# Stop and restart with new config
docker-compose -f docker-compose-plg.yml down
docker-compose -f docker-compose-plg.yml up -d

# Verify all services
docker-compose ps

# Check logs
docker-compose logs -f
```

---

## Part 6: Testing & Verification

### Step 14: Generate Traffic to All Apps

Create traffic generator script on your local machine:
```bash
cat > generate-multi-app-traffic.sh << 'EOF'
#!/bin/bash

APP1_IP="APP_SERVER_1_IP"
APP2_IP="APP_SERVER_2_IP"
APP3_IP="APP_SERVER_3_IP"

while true; do
  # App 1 - Node.js
  curl -s http://$APP1_IP:3000/ > /dev/null
  curl -s http://$APP1_IP:3000/api/data > /dev/null
  [ $((RANDOM % 5)) -eq 0 ] && curl -s http://$APP1_IP:3000/api/slow > /dev/null
  [ $((RANDOM % 10)) -eq 0 ] && curl -s http://$APP1_IP:3000/error > /dev/null
  
  # App 2 - Python
  curl -s http://$APP2_IP:5000/ > /dev/null
  curl -s http://$APP2_IP:5000/api/users > /dev/null
  [ $((RANDOM % 5)) -eq 0 ] && curl -s http://$APP2_IP:5000/api/slow > /dev/null
  [ $((RANDOM % 10)) -eq 0 ] && curl -s http://$APP2_IP:5000/api/error > /dev/null
  
  # App 3 - Java
  curl -s http://$APP3_IP:8080/ > /dev/null
  curl -s http://$APP3_IP:8080/api/orders > /dev/null
  [ $((RANDOM % 5)) -eq 0 ] && curl -s http://$APP3_IP:8080/api/slow > /dev/null
  
  sleep 2
done
EOF

chmod +x generate-multi-app-traffic.sh
./generate-multi-app-traffic.sh
```

### Step 15: Access Dashboards

| Service | URL | What to Check |
|---------|-----|-------------|
| **Grafana** | `http://MONITORING_IP:3000` | Multi-app dashboard, traces, logs |
| **Prometheus** | `http://MONITORING_IP:9090` | All 3 apps in targets, firing alerts |
| **AlertManager** | `http://MONITORING_IP:9093` | Active alerts, silences |
| **Kibana** | `http://MONITORING_IP:5601` | Logs from all 3 apps |
| **Tempo** | `http://MONITORING_IP:3200` | Trace backend (query via Grafana) |

### Step 16: Verify Tracing

In Grafana:
1. Explore → Select "Tempo" datasource
2. Search by service name: `python-flask-app`
3. Click on a trace to see distributed span tree

---

## Summary: What You've Built

✅ **3 Application Servers**: Node.js, Python Flask, Java Spring Boot  
✅ **Complete PLG Stack**: Prometheus, Loki, Grafana + Tempo for tracing  
✅ **ELK Stack**: Elasticsearch, Logstash, Kibana for alternative log analysis  
✅ **Alerting**: AlertManager with Slack/Email notifications  
✅ **Distributed Tracing**: OpenTelemetry auto-instrumentation  
✅ **Multi-Service Dashboards**: Unified view of all applications  

**Architecture Skills**: Multi-cloud monitoring, observability patterns, agent deployment  
**Tools Mastered**: Prometheus, Grafana, Loki, ELK, OpenTelemetry, AlertManager  

**Next Steps**: Add Kubernetes monitoring, implement SLO-based alerting, or explore Grafana Mimir for long-term metrics storage.