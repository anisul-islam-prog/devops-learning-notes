# Assignment-17

```markdown

## AWS Scalable Deployment Using Provided Application
> Use the following application for deployment: https://github.com/roy35-909/Module-3-deployment

### Objective
Deploy the given application on AWS with a scalable, secure, and monitored architecture.

### Tasks

1. Launch EC2 instances and deploy the application from the provided repository
2. Configure IAM Role for EC2 with appropriate permissions
3. Set up an Application Load Balancer and connect it with your application
4. Configure Auto Scaling Group using a Launch Template
   - Minimum: 1
   - Maximum: 2
5. Create and configure an S3 bucket (enable versioning)
6. Set up monitoring using CloudWatch (metrics and alarms)
7. Enable CloudTrail and verify activity logs
8. Implement a basic backup strategy (EBS snapshot or similar)
9. Apply a cost optimization approach (brief explanation required)
```

---

## 1. The Infrastructure Architecture

We are deploying a **3-tier scalable web architecture** on AWS with the following design:

```plain
                  ┌─────────────────────────────────────────────────────────────────┐
                  │                         AWS CLOUD                               │
                  │  ┌─────────────────────────────────────────────────────────┐    │
                  │  │              APPLICATION LOAD BALANCER                  │    │
                  │  │         (Internet-Facing, Cross-AZ, HTTP:80)            │    │
                  │  │                   [ALB Security Group]                  │    │
                  │  └────────────────────┬────────────────────────────────────┘    │
                  │                       │                                         │
                  │           ┌───────────┴───────────┐                             │
                  │           │    Target Group:3000  │                             │
                  │           └───────────┬───────────┘                             │
                  │                       │                                         │
                  │        ┌──────────────┼──────────────┐                          │
                  │        ▼              ▼              ▼                          │
                  │   ┌─────────┐   ┌─────────┐   ┌───────────┐                     │
                  │   │  EC2-1  │   │  EC2-2  │   │EC2 (spare)│  ← Auto Scaling     │
                  │   │ (AZ-a)  │   │ (AZ-b)  │   │  (scale)  │    Group (1-2)      │
                  │   │Node+PM2 │   │Node+PM2 │   │Node+PM2   │                     │
                  │   └────┬────┘   └────┬────┘   └────┬──────┘                     │
                  │        │             │             │                            │
                  │        └─────────────┴─────────────┘                            │
                  │              [EC2 Security Group]                               │
                  │                       │                                         │
                  │                       ▼                                         │
                  │              ┌─────────────┐                                    │
                  │              │  S3 Bucket  │  ← Artifacts + Versioning          │
                  │              │ (Backups)   │                                    │
                  │              └─────────────┘                                    │
                  │                                                                 │
                  │  VPC: 10.0.0.0/16  |  Public Subnets: 10.0.1.0/24, 10.0.2.0/24  │
                  │  IGW + Route Tables + NAT (optional)                            │
                  └─────────────────────────────────────────────────────────────────┘
```

### Traffic Flow

1. User hits the **ALB DNS endpoint** on HTTP port 80
2. ALB routes to the **Target Group** (health check on `/` or `/api`)
3. Target Group distributes across healthy EC2 instances in different AZs
4. Each EC2 runs the Node.js app via **PM2** on port 3000
5. **Auto Scaling Group** maintains 1-2 instances based on demand
6. **S3** stores deployment artifacts, logs, and backup data with versioning enabled
7. **EBS Snapshots** provide point-in-time backup for instance volumes

---

## 2. Services Required

| # | Service | Purpose | Assignment Task |
|---|---------|---------|-----------------|
| 1 | **EC2** | Compute instances running Node.js + PM2 | Task 1 |
| 2 | **VPC + Subnets + IGW + RT** | Network isolation, routing, internet access | Foundation |
| 3 | **Application Load Balancer (ELB)** | Traffic distribution, high availability | Task 3 |
| 4 | **Auto Scaling Group (ASG)** | Dynamic scaling (Min:1, Max:2) | Task 4 |
| 5 | **Launch Template** | Immutable instance configuration | Task 4 |
| 6 | **S3** | Artifact storage with versioning | Task 5 |
| 7 | **IAM Role / Instance Profile** | EC2 permissions (S3, CloudWatch) | Task 2 |
| 8 | **CloudWatch** | Metrics, logs, alarms | Task 6 |
| 9 | **CloudTrail** | API activity audit logs | Task 7 |
| 10 | **EBS + Snapshots** | Persistent storage, backup strategy | Task 8 |

---

## 3. Critical Permission Constraint Analysis

As we have **no access to IAM, CloudWatch, CloudTrail, CodeCommit, CodeDeploy, or RDS**. This directly impacts **Tasks 2, 6, and 7**. Here is the reality check and workaround strategy:

### Task 2: IAM Role for EC2

- **Problem:** We cannot create IAM Roles or Instance Profiles.
- **Workaround Options:**
  - **Option A (Recommended):** Request your AWS admin to create an IAM Role named `ec2-app-role` with the policy below, and attach it as an Instance Profile. Provide them the exact JSON.
  - **Option B:** If your account already has a generic EC2 instance profile (common in sandbox/lab environments), use that and document its ARN.
  - **Option C:** Skip IAM entirely and embed AWS credentials in user data (⚠️ **NEVER do this in production** — document it as a known lab limitation).

**Required IAM Policy for the EC2 Role:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-app-bucket-name",
        "arn:aws:s3:::your-app-bucket-name/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    }
  ]
}
```

### Task 6: CloudWatch Metrics & Alarms

- **Problem:** No CloudWatch access means you cannot create Alarms, Log Groups, or Dashboards.
- **Workaround Options:**
  - **Option A:** Request admin to enable CloudWatch permissions or pre-create a Log Group (`/aws/ec2/app-logs`) and allow `cloudwatch:PutMetricData`.
  - **Option B (Fallback):** Implement a **custom shell-based monitoring script** on each EC2 instance that logs to a local file and uploads to S3 periodically. Document this as a "self-hosted monitoring layer" due to permission constraints.
  - **Option C:** Use the AWS CLI to pull instance metrics (`aws cloudwatch get-metric-statistics`) if read-only CloudWatch access exists.

### Task 7: CloudTrail

- **Problem:** CloudTrail requires IAM permissions to create trails and S3 bucket policies.
- **Workaround Options:**
  - **Option A:** Ask the admin to enable an **Organization Trail** or create a trail for you.
  - **Option B:** Use `aws cloudtrail lookup-events` via CLI (if read access exists) to show recent API activity as proof of concept.
  - **Option C:** Document the exact CloudTrail configuration needed and state that implementation is blocked pending IAM elevation.

---

## 4. High-Level Deployment Flow

| Phase | Action |
|-------|--------|
| **Phase 0** | Clone repo locally, verify app structure, prepare deployment bundle |
| **Phase 1** | Write Terraform code for VPC, ALB, ASG, Launch Template, S3 |
| **Phase 2** | Build user data script for automated Node.js + PM2 bootstrap |
| **Phase 3** | `terraform init` → `terraform plan` → `terraform apply` |
| **Phase 4** | Verify ALB health checks, test `/` and `/api` endpoints |
| **Phase 5** | Configure ASG scaling policies (optional but good) |
| **Phase 6** | Enable S3 versioning, upload deployment artifacts |
| **Phase 7** | Create EBS snapshot schedule (via AWS CLI or Data Lifecycle Manager if available) |
| **Phase 8** | Document cost optimization measures |
| **Phase 9** | Implement the "One-Man Army" bonus best practice |

---

## 5. Pre-Deployment Checklist

Before running Terraform, ensure you have:

- [x] AWS CLI installed and configured (`aws configure`)
- [x] Terraform v1.9+ installed
- [x] Key Pair created in the target region (for emergency SSH access)
- [x] Confirmed AWS region (e.g., `us-east-1`, `ap-south-1`)
- [x] Identified your public IP for SSH security group CIDR
- [x] Confirmed whether an IAM Instance Profile exists in the account (run: `aws iam list-instance-profiles`)

---

## Project Structure

```plain
assignment-17/terraform/
├── main.tf
├── variables.tf
├── vpc.tf
├── security_groups.tf
├── s3.tf
├── alb.tf
├── launch_template.tf
├── asg.tf
├── cloudwatch.tf          # Documented but likely blocked by IAM
├── cloudtrail.tf          # Documented but likely blocked by IAM
├── outputs.tf
└── terraform.tfvars       # local values (gitignored)
```

---

## File 1: `main.tf` — Provider & Backend

```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # S3 backend for state storage (no DynamoDB = no locking, fine for solo work)
  backend "s3" {
    bucket  = "ostad-tfstate-738928894806"  # Use YOUR account ID for global uniqueness
    key     = "assignment-17/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Ostad-Assignment-17"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner_email
    }
  }
}
```

---

## File 2: `variables.tf`

```hcl
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner_email" {
  description = "Your email for tagging"
  type        = string
}

variable "key_name" {
  description = "Existing EC2 Key Pair name for emergency SSH access"
  type        = string
}

variable "my_ip" {
  description = "Your public IP for SSH access (e.g., 203.0.113.10/32)"
  type        = string
}

variable "instance_profile_name" {
  description = "Name of EXISTING IAM Instance Profile for EC2. You cannot create IAM resources, so use an existing one or request from admin."
  type        = string
  default     = "" # Leave empty if none exists; app will work without S3/CloudWatch integration
}

variable "app_repo_url" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/roy35-909/Module-3-deployment.git"
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000
}
```

---

## File 3: `vpc.tf`

```hcl
# Fetch available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ostad-vpc-${var.environment}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ostad-igw-${var.environment}"
  }
}

# Public Subnet 1
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block                = "10.0.1.0/24"
  availability_zone         = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch   = true

  tags = {
    Name = "ostad-public-1-${var.environment}"
    Type = "Public"
  }
}

# Public Subnet 2
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block                = "10.0.2.0/24"
  availability_zone         = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch   = true

  tags = {
    Name = "ostad-public-2-${var.environment}"
    Type = "Public"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "ostad-public-rt-${var.environment}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
```

---

## File 4: `security_groups.tf`

```hcl
# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "ostad-alb-sg-"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ostad-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Security Group
resource "aws_security_group" "ec2" {
  name_prefix = "ostad-ec2-sg-"
  description = "Security group for EC2 instances running Node.js app"
  vpc_id      = aws_vpc.main.id

  # SSH access - RESTRICTED to your IP only
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # App port - ONLY from ALB SG
  ingress {
    description     = "Node.js app from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound (for GitHub, npm, updates)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ostad-ec2-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

---

## File 5: `s3.tf`

```hcl
# Random suffix for global uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "app" {
  bucket = "ostad-app-artifacts-${var.environment}-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "ostad-app-artifacts"
  }
}

# Enable Versioning (Task 5)
resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption (security best practice)
resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule: transition old versions to cheaper storage (cost optimization)
resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"
    
    # Required in newer provider versions
    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Bucket policy: allow only HTTPS
resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.app.arn,
          "${aws_s3_bucket.app.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```

---

## File 6: `alb.tf`

```hcl
# Application Load Balancer
resource "aws_lb" "main" {
  name               = "ostad-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false
  enable_http2               = true

  tags = {
    Name = "ostad-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "app" {
  name     = "ostad-tg-${var.environment}"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name = "ostad-app-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

---

## File 7: `launch_template.tf`

```hcl
# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  user_data = templatefile("${path.module}/user_data.sh", {
    app_repo_url = var.app_repo_url
    app_port     = var.app_port
    bucket_name  = aws_s3_bucket.app.id
  })
}

resource "aws_launch_template" "app" {
  name_prefix   = "ostad-app-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"          # Free tier eligible + cost optimized
  key_name      = var.key_name

  # IAM Instance Profile (Task 2 - use existing or leave empty)
  dynamic "iam_instance_profile" {
    for_each = var.instance_profile_name != "" ? [var.instance_profile_name] : []
    content {
      name = iam_instance_profile.value
    }
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Cost optimization: gp3 is cheaper and faster than gp2
   block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30    # <-- Changed from 8 to 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(local.user_data)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2 enforced (security best practice)
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ostad-app-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

---

## File 8: `user_data.sh` (Place in same directory)

```bash
#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [$(date)] Starting bootstrap ==="

# -------------------------------------------------
# 1. SYSTEM UPDATE & DEPENDENCIES
# -------------------------------------------------
dnf update -y
dnf install -y git curl wget jq

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
# 5. START APPLICATION WITH PM2
# -------------------------------------------------
pm2 start ./src/server.js --name node-app
pm2 startup systemd --service-name pm2-node-app
pm2 save

# -------------------------------------------------
# 6. CUSTOM HEALTH CHECK ENDPOINT (for ALB)
# -------------------------------------------------
# The app already has / and /api routes. PM2 ensures auto-restart.

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
```

---

## File 9: `asg.tf`

```hcl
resource "aws_autoscaling_group" "app" {
  name                = "ostad-asg-${var.environment}"
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Instance refresh for zero-downtime deployments
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "ostad-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "Ostad-Assignment-17"
    propagate_at_launch = true
  }
}

# Optional: Simple scaling policy (scale up at 70% CPU)
# Note: Requires CloudWatch permissions. Include for completeness.
# resource "aws_autoscaling_policy" "scale_up" {
#   name                   = "ostad-scale-up"
#   scaling_adjustment     = 1
#   adjustment_type        = "ChangeInCapacity"
#   cooldown               = 300
#   autoscaling_group_name = aws_autoscaling_group.app.name
#   policy_type            = "SimpleScaling"
# }
```

---

## File 10: `cloudwatch.tf` — Documented for Reference

```hcl
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  IMPORTANT: CloudWatch Alarms require IAM permissions to create.     ║
# ║  Since you do NOT have IAM/CloudWatch access, these resources are    ║
# ║  COMMENTED OUT. Include them in your submission as "Required but     ║
# ║  blocked by permission constraints."                                 ║
# ╚══════════════════════════════════════════════════════════════════════╝

# resource "aws_cloudwatch_log_group" "app" {
#   name              = "/aws/ec2/ostad-app"
#   retention_in_days = 7
# }
#
# resource "aws_cloudwatch_metric_alarm" "high_cpu" {
#   alarm_name          = "ostad-high-cpu"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = 120
#   statistic           = "Average"
#   threshold           = 70
#   alarm_description   = "Alarm when CPU exceeds 70%"
#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.app.name
#   }
# }
#
# resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
#   alarm_name          = "ostad-unhealthy-hosts"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "UnHealthyHostCount"
#   namespace           = "AWS/ApplicationELB"
#   period              = 60
#   statistic           = "Average"
#   threshold           = 0
#   dimensions = {
#     TargetGroup  = aws_lb_target_group.app.arn_suffix
#     LoadBalancer = aws_lb.main.arn_suffix
#   }
# }
```

---

## File 11: `cloudtrail.tf` — Documented for Reference

```hcl
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  IMPORTANT: CloudTrail requires IAM + CloudTrail permissions.        ║
# ║  Include this as documentation of what SHOULD be implemented.        ║
# ╚══════════════════════════════════════════════════════════════════════╝

# resource "aws_cloudtrail" "main" {
#   name           = "ostad-cloudtrail"
#   s3_bucket_name = aws_s3_bucket.app.id
#   is_multi_region_trail = true
#   enable_logging = true
#
#   event_selector {
#     read_write_type                 = "All"
#     include_management_events       = true
#   }
# }
```

---

## File 12: `outputs.tf`

```hcl
output "alb_dns_name" {
  description = "Application Load Balancer DNS endpoint"
  value       = aws_lb.main.dns_name
}

output "s3_bucket_name" {
  description = "S3 bucket for artifacts and backups"
  value       = aws_s3_bucket.app.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.app.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "ssh_command" {
  description = "SSH command template (replace with actual instance IP from console)"
  value       = "ssh -i ${var.key_name}.pem ec2-user@<INSTANCE_PUBLIC_IP>"
}
```

---

## File 13: `terraform.tfvars` (Create this locally)

```hcl
aws_region            = "us-east-1"
environment           = "dev"
owner_email           = "your.email@example.com"
key_name              = "your-key-pair-name"
my_ip                 = "YOUR.PUBLIC.IP.ADDRESS/32"
instance_profile_name = ""  # Leave empty if no IAM access; app still works
```

---

## Deployment Commands

```bash
# 1. Create the bucket (must be globally unique)
aws s3api create-bucket \
  --bucket ostad-tfstate-738928894806 \
  --region us-east-1

# 2. Enable versioning (protects your state history)
aws s3api put-bucket-versioning \
  --bucket ostad-tfstate-738928894806 \
  --versioning-configuration Status=Enabled

# 3. Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket ostad-tfstate-738928894806 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

# 4. Block all public access
aws s3api put-public-access-block \
  --bucket ostad-tfstate-738928894806 \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# 5. Format & Initialize
terraform fmt -recursive
terraform init

# 6. Validate
terraform validate

# 7. Plan
terraform plan -out=tfplan

# 8. Apply
terraform apply tfplan

# 9. Verify
terraform output alb_dns_name
# Open the ALB DNS in browser: http://<alb_dns_name>/
# Test API: http://<alb_dns_name>/api
```

---

## What This Code Handles

| Task | How It's Addressed |
|------|-------------------|
| **Task 1** (EC2 + App) | Launch Template + User Data bootstraps Node 22, PM2, clones repo |
| **Task 2** (IAM Role) | `instance_profile_name` variable uses existing profile; documents required policy |
| **Task 3** (ALB) | Full ALB + Target Group + Listener with health checks on `/` |
| **Task 4** (ASG) | ASG with min=1, max=2, Launch Template, cross-AZ distribution |
| **Task 5** (S3) | Private bucket with versioning, encryption, lifecycle rules |
| **Task 6** (CloudWatch) | Code documented + custom shell metrics fallback in user data |
| **Task 7** (CloudTrail) | Terraform code documented for admin implementation |
| **Task 8** (Backup) | EBS encryption + gp3; S3 versioning acts as artifact backup |

---

## Task 8: Implement a Basic Backup Strategy

Since we lack IAM permissions for automated services like **AWS Backup** or **Data Lifecycle Manager (DLM)**, here is a **hybrid manual + scripted approach** that works within the constraints.

### 8.1 EBS Snapshot Strategy (The Core Backup)

**What it is:** A point-in-time copy of your EBS volume stored in S3 (managed by AWS, invisible to you).

**Manual Method (Works with your permissions):**

```bash
# After Terraform deploys your instance, get the Instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ostad-asg-instance" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Get the root volume ID
VOLUME_ID=$(aws ec2 describe-volumes \
  --filters "Name=attachment.instance-id,Values=$INSTANCE_ID" \
  --query 'Volumes[0].VolumeId' \
  --output text)

# Create a snapshot
aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "Ostad Assignment-17 manual backup $(date +%Y%m%d-%H%M%S)" \
  --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=ostad-app-backup},{Key=Project,Value=Ostad-Assignment-17}]"
```

**Automated Fallback (Cron on a bastion or local machine):**
Since your EC2 instances may be terminated by ASG, schedule this on your **local machine** or a **dedicated "backup" t3.nano instance**:

```bash
# ~/.local/bin/ostad-backup.sh
#!/bin/bash
REGION="us-east-1"
RETENTION_DAYS=7

# Find running instance
INSTANCE_ID=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=instance-state-name,Values=running" "Name=tag:Project,Values=Ostad-Assignment-17" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
  VOLUME_ID=$(aws ec2 describe-volumes \
    --region $REGION \
    --filters "Name=attachment.instance-id,Values=$INSTANCE_ID" \
    --query 'Volumes[0].VolumeId' \
    --output text)
  
  SNAPSHOT_ID=$(aws ec2 create-snapshot \
    --region $REGION \
    --volume-id $VOLUME_ID \
    --description "Scheduled backup $(date +%Y-%m-%d)" \
    --query 'SnapshotId' --output text)
  
  echo "[$(date)] Created snapshot: $SNAPSHOT_ID for volume: $VOLUME_ID"
  
  # Delete snapshots older than retention period
  aws ec2 describe-snapshots \
    --region $REGION \
    --filters "Name=tag:Project,Values=Ostad-Assignment-17" \
    --query "Snapshots[?StartTime<='$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)'].SnapshotId" \
    --output text | tr '\t' '\n' | while read snap; do
      [ -n "$snap" ] && aws ec2 delete-snapshot --region $REGION --snapshot-id $snap
      echo "[$(date)] Deleted old snapshot: $snap"
    done
else
  echo "[$(date)] No running instance found. Skipping backup."
fi
```

Add to crontab (local machine):

```bash
0 2 * * * /home/youruser/.local/bin/ostad-backup.sh >> /var/log/ostad-backup.log 2>&1
```

### 8.2 Application-Level Backup (S3 as Source of Truth)

Since your app is stateless (no database mentioned), the "backup" is essentially:

1. **GitHub repository** → Source code is already versioned.
2. **S3 bucket** → Stores deployment artifacts, environment configs, and metrics.

**Create a deployment artifact backup in S3:**

```bash
# After each deployment, upload the exact deployed code
cd /var/www/Module-3-deployment
tar -czf /tmp/app-backup-$(date +%Y%m%d-%H%M%S).tar.gz .
aws s3 cp /tmp/app-backup-*.tar.gz s3://$(terraform output -raw s3_bucket_name)/backups/
```

### 8.3 Backup Strategy Summary Table

| Layer | Method | Frequency | Retention | RTO (Recovery Time) |
| ------- | -------- | ----------- | ----------- | --------------------- |
| EBS Volume | Snapshot | Daily (cron) | 7 days | ~5 min (new instance from AMI) |
| Application Code | GitHub + S3 tarball | On deploy | 30 days | ~2 min (git clone) |
| PM2 Config | S3 + User Data | Immutable | Forever | ~0 min (baked into LT) |
| System Metrics | S3 CSV upload | Every hour | 90 days | N/A |

> "Due to IAM permission constraints, automated AWS Backup and DLM could not be configured. Instead, a shell-based cron backup strategy was implemented on the operator's local machine, creating daily EBS snapshots with a 7-day retention policy. In production, this would be replaced with AWS Backup Plans and DLM lifecycle policies attached to the ASG Launch Template."

---

## Task 9: Cost Optimization Approach

### 9.1 Architecture Decisions That Save Money

| Decision | Cost Impact | Annual Savings* |
|----------|-------------|-----------------|
| **t3.micro** instead of t3.small | ~50% compute cost | ~$350/instance |
| **gp3** instead of gp2 EBS | ~20% storage cost + better IOPS | ~$15/volume |
| **No NAT Gateway** | $0.045/hr × 2 AZs = ~$790/yr saved | ~$790 |
| **Public subnets only** | No data transfer charges for NAT | Variable |
| **S3 Lifecycle Rules** | Old versions → IA → Glacier | ~60% on aged data |
| **ALB (not NLB)** | ALB is cheaper for HTTP workloads | ~$200/yr |
| **Min=1, Max=2 ASG** | Never runs idle instances | ~$350/yr vs fixed 2 |
| **No RDS** (not needed) | $0 database cost | ~$500/yr |

*\*Estimates for us-east-1, assuming 730 hrs/month*

### 9.2 Detailed Cost Breakdown (Monthly, us-east-1)

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| EC2 (t3.micro) | 1 instance, 730 hrs | ~$8.50 |
| EBS (gp3, 8GB) | 1 volume | ~$0.64 |
| ALB | 1 ALB + 1 LCU | ~$16.00 |
| Data Transfer | ~10GB out | ~$0.90 |
| S3 | 5GB standard + 2GB IA | ~$0.15 |
| S3 API Requests | ~10K requests | ~$0.05 |
| EBS Snapshots | 7 snapshots × 8GB | ~$2.80 |
| **TOTAL** | | **~$29/month** |

> This is **well under $30/month** — ideal for a student assignment and demonstrates fiscal responsibility.

### 9.3 Additional Cost Optimization Measures Implemented

**1. S3 Intelligent Tiering & Lifecycle**
Already in your `s3.tf`:

```hcl
# Non-current versions move to cheaper storage classes
noncurrent_version_transition {
  noncurrent_days = 30
  storage_class   = "STANDARD_IA"    # ~40% cheaper than Standard
}
noncurrent_version_transition {
  noncurrent_days = 90
  storage_class   = "GLACIER"        # ~80% cheaper than Standard
}
noncurrent_version_expiration {
  noncurrent_days = 365              # Auto-delete after 1 year
}
```

**2. EBS gp3 Over gp2**

```hcl
# In launch_template.tf
volume_type = "gp3"  # Same baseline IOPS as gp2, 20% cheaper, scalable IOPS
```

**3. ASG Right-Sizing**

```hcl
min_size = 1  # Never pay for idle capacity
max_size = 2  # Cap burst cost
```

**4. No Unnecessary Services**

- No NAT Gateway (saves ~$32/month)
- No RDS (not needed for stateless Node app)
- No CloudWatch custom metrics (blocked by IAM, but also saves ~$0.50/metric/month)

**5. Spot Instances (Advanced, Optional)**

```hcl
# In launch_template.tf, add:
instance_market_options {
  market_type = "spot"
  spot_options {
    max_price = "0.005"  # t3.micro spot ~70% cheaper than on-demand
    spot_instance_type = "one-time"
  }
}
```

> **Caution:** Spot instances can be interrupted. For a 1-2 instance ASG, this is risky but demonstrates advanced cost knowledge.

### 9.4 Cost Monitoring (Even Without CloudWatch)

Use AWS CLI to pull estimated costs:

```bash
# Requires billing permissions (may also be blocked)
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "30 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

**Fallback:** Use the **AWS Cost Explorer console** (usually accessible even with limited IAM) and take a screenshot for your submission.

---

## Bonus: The "One-Man Army" Edge

### 🏆 Best Practice to Add: **GitOps-Driven Immutable Infrastructure with Automated Instance Refresh**

Most students will submit a Terraform script that deploys once and forgets. **You will stand out** by implementing a **GitOps-style deployment pipeline** using only the tools you have (GitHub, S3, EC2, ASG) — no CodePipeline, no CodeDeploy.

### What It Is

A mechanism where **pushing to a specific GitHub branch triggers an automatic rolling update** of your ASG instances using **ASG Instance Refresh** — all without any AWS CI/CD services.

### How to Implement It

**Step 1: Create a GitHub Actions Workflow** (in YOUR fork of the repo)

```yaml
# .github/workflows/deploy.yml
name: Deploy to AWS ASG

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Build Deployment Bundle
        run: |
          tar -czf app-release-${{ github.sha }}.tar.gz .
          aws s3 cp app-release-${{ github.sha }}.tar.gz s3://${{ secrets.S3_BUCKET }}/releases/

      - name: Update Launch Template with New User Data
        run: |
          # Fetch current Launch Template
          LT_ID="${{ secrets.LAUNCH_TEMPLATE_ID }}"
          
          # Create new version with updated user_data that pulls the new release
          aws ec2 create-launch-template-version \
            --launch-template-id $LT_ID \
            --source-version '$Latest' \
            --launch-template-data "{
              \"UserData\": \"$(echo '#!/bin/bash
              set -e
              dnf install -y git nodejs
              npm install -g pm2
              mkdir -p /var/www && cd /var/www
              aws s3 cp s3://${{ secrets.S3_BUCKET }}/releases/app-release-${{ github.sha }}.tar.gz .
              tar -xzf app-release-${{ github.sha }}.tar.gz -C Module-3-deployment
              cd Module-3-deployment && npm install
              pm2 start ./src/server.js --name node-app || pm2 restart node-app
              pm2 save' | base64 -w 0)\"
            }"

      - name: Trigger ASG Instance Refresh
        run: |
          aws autoscaling start-instance-refresh \
            --auto-scaling-group-name ${{ secrets.ASG_NAME }} \
            --strategy Rolling \
            --preferences MinHealthyPercentage=50,InstanceWarmup=120

      - name: Wait for Refresh
        run: |
          echo "Waiting for instance refresh to complete..."
          while true; do
            STATUS=$(aws autoscaling describe-instance-refreshes \
              --auto-scaling-group-name ${{ secrets.ASG_NAME }} \
              --query 'InstanceRefreshes[0].Status' --output text)
            echo "Status: $STATUS"
            if [ "$STATUS" == "Successful" ]; then break; fi
            if [ "$STATUS" == "Failed" ] || [ "$STATUS" == "Cancelled" ]; then exit 1; fi
            sleep 30
          done
```

**Step 2: Store Secrets in GitHub**

Go to your fork → Settings → Secrets and variables → Actions:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `S3_BUCKET` (your bucket name)
- `LAUNCH_TEMPLATE_ID` (from `terraform output`)
- `ASG_NAME` (from `terraform output`)


## Final Submission Checklist

Before you submit, verify:

- [ ] `terraform apply` succeeds without errors
- [ ] `http://<ALB_DNS>/` returns the Hello World page
- [ ] `http://<ALB_DNS>/api` returns JSON
- [ ] ASG shows 1 healthy instance in 2 AZs
- [ ] S3 bucket has versioning enabled (check in console)
- [ ] EBS snapshot exists (check EC2 → Snapshots)
- [ ] Security Groups are restrictive (only your IP for SSH, only ALB for app)
- [ ] IMDSv2 is enforced (check Launch Template metadata options)
- [ ] Cost estimate is documented in README
- [ ] **Bonus:** GitHub Actions workflow file exists and triggers on push