# 📚 Server & Application Log Monitoring: Complete Learning Notes

## Table of Contents
1. [Why Monitoring is Essential](#why-monitoring-is-essential)
2. [The Three Pillars of Observability](#the-three-pillars-of-observability)
3. [Cloud-Native Solutions](#cloud-native-solutions)
4. [Open-Source Stack (Self-Hosted)](#open-source-stack-self-hosted)
5. [Hybrid & On-Premises Solutions](#hybrid--on-premises-solutions)
6. [Log Collection & Shipping Architecture](#log-collection--shipping-architecture)
7. [Alerting & Incident Response](#alerting--incident-response)
8. [Best Practices & Security](#best-practices--security)
9. [Cost Comparison & Selection Guide](#cost-comparison--selection-guide)

---

## Why Monitoring is Essential

### The Core Problem: Why We Monitor

Without monitoring, you're **flying blind**. Here's what happens when you don't monitor logs:

| Scenario | Without Monitoring | With Monitoring |
|----------|-----------------|-----------------|
| **Application crashes at 3 AM** | Customer reports it at 9 AM | Alert fires immediately, auto-restart triggers |
| **Security breach** | Discovered weeks later via forensic analysis | Real-time anomaly detection blocks attack |
| **Performance degradation** | Users complain about slowness | Dashboard shows CPU spike, scale-up triggers |
| **Compliance audit** | Scramble to find logs across servers | Centralized logs with 1-click retention reports |
| **Debugging production bug** | SSH into 50 servers to grep logs | Search entire infrastructure in 10 seconds |

### Business Impact

- **Downtime costs**: $5,600/minute average (Gartner)
- **MTTR (Mean Time to Repair)**: Reduced by 60% with proper logging
- **Security incidents**: Detected 200x faster with real-time monitoring

---

## The Three Pillars of Observability

Modern monitoring requires three data types working together :

```
┌─────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY TRIANGLE                   │
│                                                             │
│           ┌─────────────┐                                   │
│           │   METRICS   │  ← "What" is happening?           │
│           │  (Numbers)  │    CPU, memory, request rates     │
│           └──────┬──────┘                                   │
│                  /│\                                        │
│                 / │ \                                       │
│                /  │  \                                      │
│           ┌───┴───┴───┐                                     │
│           │   LOGS    │  ← "Why" is it happening?           │
│           │  (Text)   │    Error messages, stack traces     │
│           │           │    Application events               │
│           └─────┬─────┘                                     │
│                /  \                                         │
│               /    \                                        │
│          ┌───┴────┴───┐                                     │
│          │   TRACES   │  ← "Where" is it happening?         │
│          │ (Journey)  │    Request flow across services     │
│          │            │    Distributed tracking             │
│          └────────────┘                                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Example**: User reports slow checkout
- **Metrics**: API latency spiked to 5s (normally 200ms)
- **Logs**: Payment service timeout errors
- **Traces**: Request stuck in database connection pool

---

## Cloud-Native Solutions

### AWS CloudWatch (Native AWS Monitoring) 

**What it is**: Fully managed monitoring service integrated with all AWS services.

**Architecture**:
```
┌─────────────────────────────────────────────────────────────┐
│                      AWS CLOUDWATCH                         │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   Logs      │    │  Metrics    │    │   Alarms    │      │
│  │  (CloudWatch│    │  (Custom &  │    │  (SNS/Lambda│      │
│  │   Logs)     │    │   Built-in) │    │   Actions)  │      │
│  └──────┬──────┘    └──────┬──────┘    └─────────────┘      │
│         │                  │                                │
│         └──────────────────┘                                │
│                 │                                           │
│         ┌───────┴───────┐                                   │
│         │   Dashboards  │  ← Visualize everything           │
│         │  (Widgets/    │                                   │
│         │   Insights)   │                                   │
│         └───────────────┘                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Key Components**:

| Feature | Purpose | Example |
|---------|---------|---------|
| **Log Groups** | Container for logs from specific source | `/aws/lambda/payment-processor` |
| **Log Streams** | Sequence of logs from same source | `2024/04/07/[$LATEST]abc123` |
| **Metric Filters** | Extract metrics from logs | Count 5xx errors in real-time |
| **Insights** | Query logs with SQL-like syntax | `fields @timestamp, @message \| filter statusCode=500` |
| **Alarms** | Trigger actions on thresholds | CPU > 80% for 5 minutes → Scale up |

**Practical Example: Monitoring Lambda Function**

```python
# Lambda function with structured logging
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # CloudWatch Logs automatically captures this
    logger.info({
        "message": "Processing payment",
        "order_id": event['order_id'],
        "amount": event['amount'],
        "timestamp": context.aws_request_id
    })
    
    try:
        process_payment(event)
        logger.info({"status": "success", "order_id": event['order_id']})
        return {"statusCode": 200, "body": "Payment processed"}
    except Exception as e:
        # This creates an ERROR log in CloudWatch
        logger.error({
            "status": "failed",
            "order_id": event['order_id'],
            "error": str(e),
            "type": "payment_processing_error"
        })
        raise
```

**CloudWatch Insights Query Example**:
```sql
-- Find all failed payments in last hour
fields @timestamp, order_id, amount, error
| filter status = "failed"
| sort @timestamp desc
| limit 20

-- Calculate error rate by service
fields @message
| filter @message like /ERROR/
| parse @message /type: (?<error_type>\w+)/
| stats count() as error_count by error_type, bin(5m)
```

**Best Practices for AWS** :
- Use structured logging (JSON) for easier parsing
- Set log retention (14 days default, adjust for compliance)
- Create metric filters for business KPIs (orders/minute)
- Use CloudWatch Agent for on-prem servers
- Enable X-Ray tracing for distributed systems

---

### Azure Monitor (Microsoft Azure)

**Key Components**:
- **Log Analytics Workspace**: Central log storage with Kusto Query Language (KQL)
- **Application Insights**: APM for web apps
- **Metrics Explorer**: Built-in Azure metrics

**KQL Example**:
```kusto
// Find exceptions in Application Insights
exceptions
| where timestamp > ago(1h)
| summarize count() by type, bin(timestamp, 5m)
| render timechart
```

---

### Google Cloud Operations Suite (GCP)

**Components**:
- **Cloud Logging**: Log aggregation and analysis
- **Cloud Monitoring**: Metrics and dashboards
- **Cloud Trace**: Distributed tracing
- **Error Reporting**: Automatic error grouping

---

## Open-Source Stack (Self-Hosted)

### The Modern Open-Source Stack: PLG (Prometheus, Loki, Grafana) 

```
┌─────────────────────────────────────────────────────────────┐
│                    PLG STACK ARCHITECTURE                   │
│                                                             │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐  │
│  │  PROMETHEUS │      │    LOKI     │      │   GRAFANA   │  │
│  │  (Metrics)  │      │   (Logs)    │      │(Visualization)││
│  │             │      │             │      │             │  │
│  │ Time-series │      │  Log        │      │  Unified    │  │
│  │ database    │      │  aggregation│      │  dashboards │  │
│  │ PromQL      │      │  LogQL      │      │  Alerting   │  │
│  └──────┬──────┘      └──────┬──────┘      └──────┬──────┘  │
│         │                    │                    │         │
│         └────────────────────┴────────────────────┘         │
│                           │                                 │
│                    ┌──────┴──────┐                          │
│                    │ ALERTMANAGER│  ← Unified alerting      │
│                    │ (Prometheus)│                          │
│                    └─────────────┘                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Component Deep Dive

#### 1. Prometheus (Metrics)

**What it collects**: Numerical data over time (CPU, memory, request duration).

**Configuration** (`prometheus.yml`):
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  # Monitor itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Monitor Node.js application
  - job_name: 'node-app'
    static_configs:
      - targets: ['localhost:3000']
    metrics_path: '/metrics'  # Your app exposes metrics here
```

**Application Instrumentation** (Node.js with `prom-client`):
```javascript
const client = require('prom-client');
const express = require('express');

// Create metrics
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status']
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.3, 0.5, 1, 2, 5]
});

// Middleware to track metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestsTotal.inc({
      method: req.method,
      route: req.route?.path || 'unknown',
      status: res.statusCode
    });
    httpRequestDuration.observe(
      { method: req.method, route: req.route?.path },
      duration
    );
  });
  
  next();
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
```

#### 2. Loki (Logs) 

**Why Loki?**: Cost-efficient logging designed for Kubernetes. Indexes only labels, not full log content.

**Architecture**:
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Application │────→│  Promtail   │────→│    Loki     │
│   (logs)    │     │  (agent)    │     │  (storage)  │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                       ┌───────┴────────┐
                                       │  Object Store  │
                                       │ (S3/GCS/Azure) │
                                       └────────────────┘
```

**Promtail Configuration** (`promtail-config.yml`):
```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Docker container logs
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'logstream'

  # Application specific logs
  - job_name: node-app
    static_configs:
      - targets:
          - localhost
        labels:
          job: node-app
          env: production
          __path__: /var/log/node-app/*.log
```

**LogQL Query Examples**:
```logql
-- Find all error logs
{job="node-app"} |= "ERROR"

-- Filter by level and parse JSON
{job="node-app"} 
  | json 
  | level="error" 
  | line_format "{{.message}} ({{.error_type}})"

-- Count errors over time
sum(rate({job="node-app"} |= "ERROR" [5m])) by (level)

-- Join with metrics (correlate high latency with errors)
{job="node-app"} 
  | json 
  | status_code="500" 
  | __error__=""
```

#### 3. Grafana (Visualization) 

**Dashboard Configuration** (JSON Model):
```json
{
  "dashboard": {
    "title": "Application Monitoring",
    "panels": [
      {
        "title": "Request Rate",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{route}}"
          }
        ],
        "datasource": "prometheus"
      },
      {
        "title": "Error Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"node-app\"} |= \"ERROR\"",
            "datasource": "loki"
          }
        ]
      },
      {
        "title": "95th Percentile Latency",
        "type": "stat",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ]
      }
    ]
  }
}
```

---

### The Classic ELK Stack (Elasticsearch, Logstash, Kibana) 

**When to use**: Full-text search capabilities, complex log analysis, compliance requirements.

```
┌─────────────────────────────────────────────────────────────┐
│                      ELK STACK FLOW                         │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   BEATS     │───→│   LOGSTASH  │───→│ELASTICSEARCH│      │
│  │  (Shippers) │    │  (Parse/    │    │  (Index/    │      │
│  │  Filebeat   │    │   Enrich)   │    │   Search)   │      │
│  │  Metricbeat │    │             │    │             │      │
│  └─────────────┘    └─────────────┘    └──────┬──────┘      │
│                                               │             │
│                                       ┌───────┴───────┐     │
│                                       │    KIBANA     │     │
│                                       │ (Visualize/   │     │
│                                       │  Discover)    │     │
│                                       └───────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Filebeat Configuration**:
```yaml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/nginx/*.log
    - /var/log/node-app/*.log
  fields:
    service: node-app
    environment: production

output.logstash:
  hosts: ["logstash:5044"]
```

**Logstash Pipeline**:
```ruby
input {
  beats { port => 5044 }
}

filter {
  # Parse JSON logs
  json {
    source => "message"
    target => "parsed"
  }
  
  # Add geoIP for nginx logs
  geoip {
    source => "client_ip"
  }
  
  # Parse timestamps
  date {
    match => ["parsed.timestamp", "ISO8601"]
    target => "@timestamp"
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
  }
}
```

---

## Hybrid & On-Premises Solutions

### Graylog (Enterprise-Ready Open Source) 

**Best for**: Security teams, compliance, stream processing.

```
┌─────────────────────────────────────────────────────────────┐
│                      GRAYLOG ARCHITECTURE                   │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   INPUTS    │    │   GRAYLOG   │    │ ELASTICSEARCH│     │
│  │  (Syslog/   │───→│   SERVER    │───→│  (Storage)  │      │
│  │   GELF/     │    │ (Processing)│    │             │      │
│  │   Beats)    │    │             │    │             │      │
│  └─────────────┘    └──────┬──────┘    └─────────────┘      │
│                            │                                │
│                    ┌───────┴───────┐                        │
│                    │    MONGODB    │  ← Configuration       │
│                    │   (Metadata)  │                        │
│                    └───────────────┘                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Graylog Setup Example** (Docker Compose):
```yaml
version: '3'
services:
  graylog:
    image: graylog/graylog:5.0
    environment:
      - GRAYLOG_PASSWORD_SECRET=somepasswordpepper
      - GRAYLOG_ROOT_PASSWORD_SHA2=8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918
      - GRAYLOG_HTTP_EXTERNAL_URI=http://localhost:9000/
    ports:
      - "9000:9000"      # Web UI
      - "514:514/udp"    # Syslog
      - "12201:12201/udp" # GELF
    depends_on:
      - mongodb
      - elasticsearch

  mongodb:
    image: mongo:6.0

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.10.2
    environment:
      - discovery.type=single-node
```

**Sending Logs to Graylog** (Node.js with GELF):
```javascript
const graylog2 = require('graylog2');

const logger = new graylog2.graylog({
  servers: [{ host: 'graylog-server', port: 12201 }],
  facility: 'Node.js App'
});

logger.log('Application started', {
  environment: 'production',
  version: '1.2.3',
  server: os.hostname()
});
```

---

### Fluentd/Fluent Bit (Universal Log Collector) 

**The "Swiss Army Knife" of log shipping**.

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUENTD ARCHITECTURE                     │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   SOURCES   │───→│   FLUENTD   │───→│   OUTPUTS   │      │
│  │             │    │  (Filter/   │    │             │      │
│  │  Tail files │    │   Parse/    │    │ Elasticsearch│     │
│  │  Syslog     │    │   Buffer)   │    │  CloudWatch │      │
│  │  HTTP       │    │             │    │  S3         │      │
│  │  Docker     │    │             │    │  Kafka      │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Fluentd Configuration** (`fluent.conf`):
```xml
# Source: Tail application logs
<source>
  @type tail
  path /var/log/node-app/app.log
  pos_file /var/log/fluent/node-app.pos
  tag node.app
  <parse>
    @type json
    time_key timestamp
    time_format %iso8601
  </parse>
</source>

# Filter: Add hostname and environment
<filter node.app>
  @type record_transformer
  <record>
    hostname ${hostname}
    environment production
  </record>
</filter>

# Filter: Mask sensitive data (PII)
<filter node.app>
  @type grep
  <exclude>
    key message
    pattern /password|credit_card|ssn/
  </exclude>
</filter>

# Output: Send to multiple destinations
<match node.app>
  @type copy
  
  # To Elasticsearch
  <store>
    @type elasticsearch
    host elasticsearch
    index_name node-app-logs
  </store>
  
  # To AWS S3 for archival
  <store>
    @type s3
    aws_key_id YOUR_KEY
    aws_sec_key YOUR_SECRET
    s3_bucket logs-archive
    s3_region us-east-1
    path logs/%Y/%m/%d/
  </store>
  
  # To CloudWatch for real-time monitoring
  <store>
    @type cloudwatch_logs
    region us-east-1
    log_group_name /aws/node-app
    log_stream_name ${hostname}
  </store>
</match>
```

---

## Log Collection & Shipping Architecture

### Sidecar Pattern (Kubernetes)

```
┌─────────────────────────────────────────────────────────────┐
│                    POD: APPLICATION + LOG SHIPPER           │
│                                                             │
│  ┌─────────────────────────┐  ┌─────────────────────────┐   │
│  │    APPLICATION          │  │    FLUENT BIT SIDECAR   │   │
│  │    (Node.js)            │  │                         │   │
│  │                         │  │  ┌─────────────────┐    │   │
│  │  Logs to:               │  │  │  Tail /logs     │    │   │
│  │  /var/log/app/*.log     │──┼──┼─→ Parse JSON    │    │   │
│  │                         │  │  │  → Add K8s meta │    │   │
│  └─────────────────────────┘  │  │  → Push to Loki │    |   │
│           │                   │  └─────────────────┘    │   │
│           │ Shared volume     └─────────────────────────┘   │
│           └──────────────────────────────────────────────   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Kubernetes DaemonSet for Node-Level Collection**:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    spec:
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:2.0
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: dockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: dockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

---

## Alerting & Incident Response

### Multi-Channel Alerting Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ALERT FLOW ARCHITECTURE                  │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   TRIGGER   │    │  ROUTING    │    │  NOTIFICATION│     │
│  │             │    │             │    │             │      │
│  │ High error  │───→│  PagerDuty  │───→│  SMS/Phone  │      │
│  │ rate        │    │  (On-call)  │    │  (Critical) │      │
│  │             │    │             │    │             │      │
│  │ Disk space  │───→│  Slack      │───→│  #alerts    │      │
│  │ warning     │    │  (Team)     │    │  (Warning)  │      │
│  │             │    │             │    │             │      │
│  │ Daily       │───→│  Email      │───→│  Digest     │      │
│  │ summary     │    │  (Managers) │    │  (Info)     │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Prometheus AlertManager Configuration**:
```yaml
global:
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

route:
  receiver: 'default'
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
  - match:
      severity: critical
    receiver: 'pagerduty-critical'
    continue: true
    
  - match:
      severity: warning
    receiver: 'slack-warnings'

receivers:
- name: 'default'
  slack_configs:
  - channel: '#monitoring'

- name: 'pagerduty-critical'
  pagerduty_configs:
  - service_key: YOUR_PD_KEY
    severity: critical
    description: '{{ .GroupLabels.alertname }}: {{ .CommonAnnotations.summary }}'

- name: 'slack-warnings'
  slack_configs:
  - channel: '#alerts'
    title: 'Warning: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

**Sample Alert Rules**:
```yaml
groups:
- name: application-alerts
  rules:
  # High error rate
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value }} errors/second"
      
  # Slow response time
  - alert: SlowResponseTime
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Slow API responses"
      description: "95th percentile latency is {{ $value }}s"
      
  # Disk space running low
  - alert: DiskSpaceLow
    expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Disk space low on {{ $labels.instance }}"
      description: "Only {{ $value | humanizePercentage }} space remaining"
```

---

## Best Practices & Security

### 1. Structured Logging 

**Bad (Hard to parse)**:
```
2024-04-07 10:30:45 - User john_doe logged in from 192.168.1.1 successfully
```

**Good (JSON, machine-readable)**:
```json
{
  "timestamp": "2024-04-07T10:30:45Z",
  "level": "info",
  "event": "user_login",
  "user_id": "john_doe",
  "ip_address": "192.168.1.1",
  "status": "success",
  "auth_method": "password",
  "user_agent": "Mozilla/5.0...",
  "request_id": "req_abc123"
}
```

### 2. Log Levels & Retention 

| Level | Usage | Retention | Example |
|-------|-------|-----------|---------|
| **DEBUG** | Development troubleshooting | 7 days | `User object: {id: 123, ...}` |
| **INFO** | Normal operations | 30 days | `Order #456 created` |
| **WARN** | Unexpected but handled | 90 days | `Database connection slow (2s)` |
| **ERROR** | Failed operations | 1 year | `Payment processing failed` |
| **FATAL** | System crashes | 2+ years | `Out of memory, shutting down` |

### 3. Security Best Practices 

```yaml
# Encrypt logs in transit and at rest
security:
  # TLS for all log shipping
  tls:
    enabled: true
    cert_file: /certs/client.crt
    key_file: /certs/client.key
    ca_file: /certs/ca.crt
  
  # Mask sensitive fields
  masking:
    fields:
      - password
      - credit_card
      - ssn
      - api_key
    replacement: "[REDACTED]"
  
  # Access control
  rbac:
    roles:
      - name: developer
        permissions: [read, query]
        indices: ["logs-dev-*"]
      - name: security
        permissions: [read, write, admin]
        indices: ["logs-*"]
```

---

## Cost Comparison & Selection Guide

### Tool Comparison Matrix 

| Tool | Type | Best For | Cost | Setup Complexity | Cloud/On-Prem |
|------|------|----------|------|-----------------|---------------|
| **CloudWatch** | AWS Native | AWS environments, quick start | $0.50/GB ingested + storage | Low | Cloud |
| **Datadog** | SaaS | Unified observability, enterprise | $15/host + $0.10/GB logs | Low | Cloud |
| **Splunk** | Enterprise | Security, compliance, heavy analytics | ~$150/GB | Medium | Both |
| **ELK Stack** | Open Source | Full-text search, custom hosting | Free (infrastructure only) | High | On-Prem |
| **PLG Stack** | Open Source | Kubernetes, cost-efficient | Free (infrastructure only) | Medium | Both |
| **Graylog** | Open Source | Security teams, stream processing | Free/Paid support | Medium | On-Prem |
| **Fluentd/Bit** | Collector | Universal log shipping | Free | Low | Both |

### Decision Tree

```
START
  │
  ├─► Running primarily on AWS?
  │     ├─► YES → CloudWatch (native integration)
  │     └─► NO → Continue
  │
  ├─► Need full-text search on massive logs?
  │     ├─► YES → ELK Stack or Splunk
  │     └─► NO → Continue
  │
  ├─► Running Kubernetes?
  │     ├─► YES → PLG Stack (Prometheus + Loki + Grafana)
  │     └─► NO → Continue
  │
  ├─► Budget constraints + technical expertise?
  │     ├─► YES → PLG Stack or Graylog
  │     └─► NO → Datadog or Splunk Cloud
  │
  └─► Need compliance/audit features?
        ├─► YES → Splunk or Graylog Enterprise
        └─► NO → Any of the above based on other needs
```

---

## Quick Start: Minimal Viable Monitoring

### For AWS (5 minutes setup):
```bash
# 1. Install CloudWatch agent
sudo yum install amazon-cloudwatch-agent

# 2. Configure
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard

# 3. Start
sudo systemctl start amazon-cloudwatch-agent
```

### For Self-Hosted (Docker Compose):
```yaml
version: '3'
services:
  loki:
    image: grafana/loki:2.9.0
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml

  promtail:
    image: grafana/promtail:2.9.0
    volumes:
      - /var/log:/var/log:ro
      - ./promtail-config.yml:/etc/promtail/config.yml

  grafana:
    image: grafana/grafana:10.0.0
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

---

## Summary: Key Takeaways

1. **Start with metrics, add logs, then traces** - Don't try to implement everything at once
2. **Structured logging is non-negotiable** - JSON format enables powerful querying
3. **Centralize everything** - One place to search across all systems
4. **Alert on symptoms, not causes** - "High error rate" not "Disk full"
5. **Test your monitoring** - Regular fire drills to ensure alerts work
6. **Cost grows with retention** - 30 days hot, 1 year cold (S3), archive rest
7. **Security from day one** - Encrypt, mask PII, implement RBAC

**Next Steps**: Start with CloudWatch if on AWS, or PLG stack for Kubernetes. Graduate to enterprise tools (Datadog/Splunk) as complexity and budget grow.