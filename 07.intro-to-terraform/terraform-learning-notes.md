# Terraform Field Manual

## 1. The Core Definition

**Terraform** is HashiCorp's declarative infrastructure provisioning engine. In the 2026 SDLC, it sits at the **"Platform Layer"**—the boundary between application code and the substrate it runs on.

Unlike configuration management tools (Ansible, Puppet) that mutate existing servers, Terraform is an **orchestrator**. It builds, modifies, and destroys entire cloud topologies via API calls to providers (AWS, Azure, GCP, Kubernetes, and 3,000+ others). It translates HCL (HashiCorp Configuration Language) into real infrastructure state.

**Its place in the SDLC:**
- **Dev:** Local `terraform plan` validates architecture before a single resource is billed
- **CI/CD:** Automated `apply` gates in GitOps pipelines (Terraform Cloud, Atlantis, Spacelift)
- **Ops:** Immutable infrastructure—no snowflake servers, no configuration drift
- **Security:** Policy-as-Code integration (Sentinel, OPA) enforces guardrails pre-deployment

---

## 2. The "Why": The Solo IT Head's Force Multiplier

As a "One-Man Army" managing complex infrastructure, Terraform isn't optional—it's **survival infrastructure**.

| Pain Point | Terraform Solution |
|------------|------------------|
| **Context Switching** | One HCL file defines AWS VPCs, Azure AD apps, and GCP Cloud Run services. One mental model, one toolchain. |
| **Audit Nightmares** | `terraform plan` output is a self-documenting change log. Every modification is version-controlled, reviewable, and reversible. |
| **Cost Sprawl** | `terraform destroy` or targeted `taint` eliminates zombie resources. Tagging enforcement via `default_tags` enables FinOps attribution. |
| **On-Call Trauma** | Disaster recovery becomes `git clone` + `terraform apply`. RTO measured in minutes, not hours. |
| **Vendor Lock-in** | HCL abstracts provider APIs. Migrating from AWS to GCP? Rewrite provider blocks, keep logic intact. |

**Scalability:** A single engineer can manage 50+ environments (dev, staging, prod, DR, client-isolated) using workspaces and modules. What once required a platform team now requires disciplined code reuse.

---

## 3. The Workflow: The Terraform Lifecycle

### The Golden Path
```
Write → Init → Plan → Review → Apply → State Lock → Destroy (if needed)
```

**Phase Breakdown:**

1. **`terraform init`** — Downloads providers, modules, and configures backend (S3, GCS, Azure Blob, Terraform Cloud)
2. **`terraform plan`** — Dry-run execution plan. Shows exact delta: what will be created, modified, destroyed
3. **`terraform apply`** — Executes plan with explicit approval. State file (`terraform.tfstate`) is updated atomically
4. **`terraform destroy`** — Idempotent teardown. Critical for ephemeral environments (PR previews, load testing)

### Gold Standard: Multi-Environment AWS VPC Module

```hcl
# environments/prod/main.tf
terraform {
  required_version = ">= 1.9.0"
  
  backend "s3" {
    bucket         = "myorg-terraform-state-prod"
    key            = "vpc/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "prod-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false  # High availability: one per AZ
  enable_dns_hostnames = true

  # Cost allocation and compliance tagging
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    CostCenter  = "platform-engineering"
  }

  # Flow logs for security audit
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
}

# outputs.tf
output "private_subnets" {
  description = "Private subnet IDs for EKS/node placement"
  value       = module.vpc.private_subnets
}
```

**Key Patterns:**
- **Remote State:** S3 + DynamoDB locking prevents state corruption in team/solo contexts
- **Module Registry:** Pin versions (`~> 5.0`) to prevent breaking changes
- **Tagging Strategy:** Enforce at provider level for cost attribution and IAM policy scoping

---

## 4. Production Scenario: Neo-Bank Transaction Service Auto-Scaling

**Context:** You're the sole SRE for *NexusPay*, a digital bank processing 50,000+ transactions/minute during payroll cycles (1st & 15th of month).

**The Architecture:**
- **Compute:** AWS EKS cluster with transaction API microservices
- **Data:** RDS PostgreSQL (primary) + ElastiCache Redis (session state)
- **Networking:** Private subnets, NAT Gateways, AWS WAF
- **Observability:** CloudWatch metrics → SNS → Lambda → Slack/PagerDuty

**The Terraform Implementation:**

```hcl
# modules/eks_app/main.tf
resource "aws_eks_node_group" "transaction_api" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "transaction-api-ng"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.private_subnets

  scaling_config {
    desired_size = var.base_node_count      # 3
    min_size     = var.min_node_count       # 2
    max_size     = var.max_node_count       # 20 (payroll peak)
  }

  capacity_type = "ON_DEMAND"  # Avoid spot interruption for financial TX

  labels = {
    workload = "transaction-api"
  }

  # Taint to prevent other workloads from scheduling here
  taint {
    key    = "dedicated"
    value  = "transaction-api"
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable_percentage = 25  # Rolling update safety
  }
}

# Horizontal Pod Autoscaler via Terraform kubernetes provider
resource "kubernetes_horizontal_pod_autoscaler_v2" "transaction_api" {
  metadata {
    name      = "transaction-api-hpa"
    namespace = "production"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "transaction-api"
    }
    min_replicas = 10
    max_replicas = 200
    
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 60
        policy {
          type           = "Percent"
          value          = 100
          period_seconds = 60
        }
      }
      scale_down {
        stabilization_window_seconds = 300  # 5min cooldown post-peak
        policy {
          type           = "Percent"
          value          = 10
          period_seconds = 60
        }
      }
    }
  }
}

# RDS read replica for query offloading during peak
resource "aws_db_instance" "transaction_replica" {
  identifier          = "transaction-db-replica"
  replicate_source_db = aws_db_instance.transaction_primary.arn
  instance_class      = "db.r6g.2xlarge"
  
  # Critical for fintech: encryption in transit + at rest
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds_encryption.arn

  # Prevent accidental deletion
  deletion_protection = true
  skip_final_snapshot = false
}
```

**The Peak Load Drill:**
1. **Day Before Payroll:** `terraform plan` shows zero changes (infrastructure is already defined)
2. **T-0:** CloudWatch alarm triggers HPA → EKS node group scales out → Terraform-managed security groups auto-allow new nodes
3. **T+6 Hours:** Load drops. HPA scales down. Terraform state remains consistent; no manual console clicks made
4. **Audit:** `terraform show` provides exact resource graph for compliance team

---

## 5. Architect's Warning: The Silent Killers

### 🔴 State File Management (The #1 Career-Ending Mistake)
- **The Risk:** `terraform.tfstate` contains **plaintext secrets** (RDS passwords, IAM keys, private IPs). Committing to Git = instant breach.
- **The Fix:** Remote backend (S3 with SSE-KMS, Azure Blob with CMK). Enable versioning. **Never** local state in production.
- **The Nightmare:** Two engineers run `apply` simultaneously. State corruption = manual resource reconciliation hell.
- **The Fix:** State locking (DynamoDB for S3, native locking for Terraform Cloud). Non-negotiable.

### 🔴 The `count` vs. `for_each` Trap
```hcl
# DANGEROUS: Adding an item to the middle of the list shifts all indices
resource "aws_iam_user" "bad" {
  count = length(var.user_names)
  name  = var.user_names[count.index]  # "alice", "bob", "charlie" -> add "aaron" at index 0? Bob becomes index 1, gets recreated.
}

# SAFE: Map-based addressing prevents index shifting
resource "aws_iam_user" "good" {
  for_each = toset(var.user_names)
  name     = each.value
}
```

### 🔴 Provider Version Pinning Neglect
- **The Risk:** `hashicorp/aws` releases v6.0 with breaking API changes. Your CI pipeline auto-updates. Production VPC gets recreated during routine run.
- **The Fix:** Strict version constraints:
  ```hcl
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.46.0"  # Pessimistic: 5.46.x only
    }
  }
  ```

### 🔴 The "Works on My Machine" Module Path
```hcl
# Fragile: Breaks in CI/CD where relative paths differ
source = "../modules/vpc"

# Robust: Version-pinned, registry-backed, immutable
source  = "terraform-aws-modules/vpc/aws"
version = "5.5.1"
```

### 🔴 Ignoring `lifecycle` Rules
```hcl
resource "aws_db_instance" "prod" {
  # Prevent destroy on critical resources
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [password]  # Managed by Secrets Manager rotation
  }
}
```

### 🔴 Cost Blindness
- `terraform apply` can spin up $10k/month GPU instances. Use `infracost` integration in CI pipelines for cost estimation before approval.

---

## 6. The Balanced View

| **Advantages** | **Disadvantages** |
|----------------|-------------------|
| **Multi-Cloud Abstraction:** Single HCL syntax for AWS, Azure, GCP, K8s, VMware, and 3,000+ providers. True cloud-agnostic workflows. | **State Complexity:** State files are a single point of failure. Remote backends, locking, and backup strategies add operational overhead. |
| **Immutable Infrastructure:** Eliminates configuration drift. Resources are replaced, not patched. Predictable, repeatable environments. | **Not Real-Time:** Terraform is not an event-driven orchestrator. It won't auto-heal a failed instance (use Kubernetes or Auto Scaling Groups for that). |
| **Execution Plans:** `terraform plan` provides bulletproof pre-flight checks. No surprises, no "oops" moments in production. | **HCL Learning Curve:** Declarative logic differs from imperative scripting. Dynamic blocks, `for_each`, and complex conditionals have steep mastery curves. |
| **Module Ecosystem:** The Terraform Registry provides battle-tested, community-vetted modules (VPCs, EKS, secure baselines). Accelerates delivery 10x. | **Provider Lag:** Cloud providers release new services; Terraform providers lag by weeks/months. Workarounds require `awscli` local-exec hacks or null_resources. |
| **Rich IDE Support:** VS Code with Terraform extension provides IntelliSense, validation, and `terraform fmt` formatting. | **Secret Sprawl:** State files snapshot all resource attributes at apply-time. Sensitive data requires careful backend encryption and potentially external secret stores (Vault). |
| **Cost Visibility:** Integration with Infracost and native cloud tagging enables FinOps governance directly in the pipeline. | **Apply-Time Failures:** A 45-minute `apply` can fail at 95% completion due to a single API timeout, leaving state partially updated and requiring manual intervention. |

---

## 7. The Landscape

### Open Source Alternatives

| Tool | Core Philosophy | Best For |
|------|----------------|----------|
| **OpenTofu** | Community-driven fork of Terraform (post-BSL license change). Drop-in replacement, Linux Foundation backed. | Organizations avoiding HashiCorp's BSL licensing; requires exact Terraform parity without enterprise features. |
| **Pulumi** | Infrastructure as *Real* Code (Python, TypeScript, Go, C#). Imperative logic, loops, and classes. | Teams with strong software engineering culture needing complex conditional logic that HCL struggles with. |
| **Crossplane** | Kubernetes-native control planes. Uses YAML and CRDs to provision cloud resources via provider controllers. | K8s-first shops wanting GitOps-native infrastructure management with existing ArgoCD/Flux pipelines. |
| **Ansible + AWX** | Configuration management with cloud provisioning modules. Agentless, SSH-based. | Environments requiring heavy OS-level configuration *and* cloud provisioning in one tool; less declarative state management. |
| **CloudFormation (AWS-only)** | Native AWS IaC. Deep service integration, fastest feature support for new AWS services. | AWS-only shops prioritizing day-one access to new services over multi-cloud portability. |
| **CDK for Terraform (CDKTF)** | Generate Terraform configurations using TypeScript, Python, Java, C#, or Go. | Teams rejecting HCL but wanting Terraform's provider ecosystem and state management. |

### Closed Source / Managed Alternatives

| Tool | Core Value Proposition | Best For |
|------|----------------------|----------|
| **HashiCorp Terraform Cloud / Enterprise** | Remote state, team collaboration, Sentinel policy-as-code, private module registry, SSO, and audit logging. | Teams scaling beyond solo practitioners; requires governance, approval workflows, and compliance reporting. |
| **Spacelift** | Terraform automation platform with sophisticated policy engine (OPA), drift detection, and multi-infrastructure support (Pulumi, CloudFormation, Ansible). | High-velocity teams needing granular access controls, custom workflows, and competitive pricing vs. Terraform Cloud. |
| **Env0** | Self-service IaC with cost estimation, TTL-based environments (auto-destroy), and RBAC. | Dev/Test environments, ephemeral infrastructure, and FinOps-conscious organizations. |
| **Scalr** | Terraform-focused alternative to Terraform Cloud with hierarchical workspaces, RBAC, and agent-based execution. | Enterprises needing on-premise or hybrid execution with strict network isolation requirements. |
| **AWS CloudFormation + Service Catalog** | Native AWS managed service with StackSets for multi-account deployment and Service Catalog for self-service governance. | Heavily regulated industries (finance, gov) requiring AWS-native compliance tooling and minimal third-party risk. |
| **Azure Resource Manager (ARM) + Deployment Stacks** | Native Azure declarative templates with Bicep abstraction and Deployment Stacks for lifecycle management. | Azure-centric organizations leveraging Microsoft ecosystem and native Policy/Blueprint governance. |
| **Google Cloud Deployment Manager / Config Connector** | Native GCP templating or K8s-native resource management via Config Connector. | GCP-focused shops integrating infrastructure with Anthos/GKE-centric workflows. |

---

## Final Word

Terraform is the **lingua franca** of modern infrastructure. For the solo architect, it transforms overwhelming cloud complexity into version-controlled, reviewable, and repeatable code. But respect the state file—it is both your greatest asset and your greatest liability. Master remote backends, enforce locking, pin your providers, and treat your HCL with the same rigor as your application code. The alternative is 3 AM emergency console sessions that no amount of coffee can fix.


# Terraform AWS Deployment Blueprint

## 1. The Infrastructure Code (Gold Standard)

This modular Terraform configuration deploys a secure, production-ready web application stack. It follows AWS Well-Architected principles: least privilege IAM, defense-in-depth security groups, and immutable infrastructure patterns.

**File: `main.tf`**
```hcl
# ============================================================
# PROVIDER & BACKEND
# ============================================================
# Pin provider version for reproducibility; use S3 backend for 
# team collaboration and state locking (critical for production)
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Lock to major version to prevent breaking changes
    }
  }
  
  # Uncomment for production: S3 backend with DynamoDB state locking
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "webapp/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = "webapp-deployment"
    }
  }
}

# ============================================================
# DATA SOURCES
# ============================================================
# Fetch latest Amazon Linux 2023 AMI with ARM64 (Graviton) for 
# cost/performance efficiency. Filter ensures we get the official image.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# NETWORKING
# ============================================================
# Dedicated VPC with DNS hostnames enabled for internal service discovery
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Public subnet for the bastion/app server (simplified single-AZ for learning)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block                = "10.0.1.0/24"
  availability_zone         = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch   = true  # Required for direct internet access without EIP

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================
# SECURITY GROUPS (Defense in Depth)
# ============================================================
# SG-1: Bastion/Jump Host access - ONLY port 22 from specific CIDR
# WHY: Restricting SSH to office IP prevents brute force attacks
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-bastion-"
  vpc_id      = aws_vpc.main.id
  description = "Bastion host security group"

  ingress {
    description = "SSH from trusted IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ip]  # NEVER use 0.0.0.0/0 for SSH
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# SG-2: Application Tier - HTTP/HTTPS from internet, SSH only from bastion
# WHY: Layered security; app server not directly exposed to SSH from internet
resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-app-"
  vpc_id      = aws_vpc.main.id
  description = "Application server security group"

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH from bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# ============================================================
# IAM (Least Privilege)
# ============================================================
# WHY: Instance role prevents hardcoded credentials; SSM policy enables 
# Session Manager (browser-based SSH) as secure alternative to port 22
resource "aws_iam_role" "app_role" {
  name = "${var.project_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app_role.name
}

# ============================================================
# COMPUTE (Immutable Infrastructure)
# ============================================================
# WHY: user_data script bootstraps on launch; no manual SSH config needed
# T3/T4g instances provide burstable performance for dev/test workloads
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  # Root volume encrypted by default (compliance requirement)
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"  # Better IOPS than gp2, lower cost
    encrypted             = true
    delete_on_termination = true   # Cleanup with instance
  }

  # Bootstrap script: installs Docker and deploys nginx container
  user_data = base64encode(templatefile("${path.module}/bootstrap.sh", {
    app_version = var.app_version
  }))

  user_data_replace_on_change = true  # Trigger replacement if script changes

  tags = {
    Name = "${var.project_name}-app-server"
  }
}

# Elastic IP for stable DNS (optional, costs $0.005/hr when unattached)
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

# ============================================================
# OUTPUTS
# ============================================================
output "app_public_ip" {
  description = "Public IP of the application server"
  value       = aws_eip.app.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_eip.app.public_ip}"
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_eip.app.public_ip}"
}
```

**File: `variables.tf`**
```hcl
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project identifier for resource naming"
  type        = string
  default     = "tf-webapp"
}

variable "instance_type" {
  description = "EC2 instance type (t4g.micro for free tier ARM)"
  type        = string
  default     = "t4g.micro"  # ARM64: 2 vCPU, 1GB RAM, free tier eligible
}

variable "key_name" {
  description = "Name of existing EC2 Key Pair for SSH"
  type        = string
}

variable "trusted_ip" {
  description = "CIDR block for SSH access (your public IP/32)"
  type        = string
}

variable "app_version" {
  description = "Application version tag for Docker image"
  type        = string
  default     = "latest"
}
```

**File: `bootstrap.sh`**
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Update system and install Docker
dnf update -y
dnf install -y docker amazon-cloudwatch-agent

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Run nginx container with health check
docker run -d \
  --name webapp \
  --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -e APP_VERSION="${app_version}" \
  nginx:alpine

# Configure CloudWatch log agent for centralized logging
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/docker",
            "log_group_name": "/aws/ec2/webapp",
            "log_stream_name": "{instance_id}/docker"
          }
        ]
      }
    }
  }
}
EOF

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Signal success to CloudFormation/Systems Manager (optional)
echo "Bootstrap completed at $(date)" >> /var/log/bootstrap.log
```

---

## 2. Environment Prep

### Prerequisites Installation

```bash
# 1. Terraform (Infrastructure as Code)
brew install terraform                    # macOS
# OR
sudo apt-get update && sudo apt-get install -y terraform  # Ubuntu/Debian

# 2. AWS CLI v2 (API interaction)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 3. SSH Key Pair generation (if none exists)
ssh-keygen -t ed25519 -C "tf-deploy-$(date +%Y%m%d)" -f ~/.ssh/tf-deploy
chmod 400 ~/.ssh/tf-deploy
```

### Authentication Setup

```bash
# Method A: AWS SSO (Enterprise standard)
aws configure sso
aws sso login --profile dev-admin

# Method B: Access Keys (Development only)
aws configure
# Enter: AWS Access Key ID, Secret Key, region (us-east-1), output (json)

# Verify credentials
aws sts get-caller-identity

# Upload public key to AWS (required for SSH access)
aws ec2 import-key-pair \
  --key-name tf-deploy \
  --public-key-material fileb://~/.ssh/tf-deploy.pub
```

---

## 3. The Deployment Workflow

### Pre-Flight Check (Validate Before You Fly)

```bash
# Step 0: Format and validate syntax
terraform fmt -recursive                    # Canonical formatting
terraform init                              # Initialize providers/modules
terraform validate                          # Syntax validation

# Step 1: Security scan (optional but recommended)
terraform plan -out=tfplan
terraform show -json tfplan | jq '.planned_values' > plan.json

# Step 2: Cost estimation (install infracost: https://www.infracost.io)
infracost breakdown --path . --terraform-plan-flags "-var-file=dev.tfvars"

# Step 3: Apply with auto-approval (only after validation passes)
terraform apply -auto-approve tfplan
```

### Complete Command Sequence

```bash
# 1. Initialize (one-time per environment)
terraform init -backend-config="bucket=my-tf-state" -backend-config="key=webapp/dev"

# 2. Plan with variables
terraform plan \
  -var="key_name=tf-deploy" \
  -var="trusted_ip=$(curl -s ifconfig.me)/32" \
  -var="app_version=v1.2.0" \
  -out=tfplan

# 3. Apply
terraform apply tfplan

# 4. Verify outputs
terraform output
```

---

## 4. Live Verification

### SSH Access

```bash
# Method 1: Direct SSH (if port 22 open in SG)
ssh -i ~/.ssh/tf-deploy.pem ec2-user@$(terraform output -raw app_public_ip)

# Method 2: AWS Session Manager (no open ports, audit trail)
aws ssm start-session \
  --target $(terraform output -raw app_instance_id) \
  --document-name AWS-StartInteractiveCommand \
  --parameters command="bash -l"
```

### The 3-Command Verification Checklist

```bash
# CHECK 1: Service Health (nginx container running?)
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep webapp
# Expected: webapp   Up 2 minutes   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp

# CHECK 2: Port Binding (locally and externally)
sudo ss -tlnp | grep -E '(:80|:443)'      # Local port binding
curl -s -o /dev/null -w "%{http_code}" http://localhost:80  # HTTP 200 expected

# CHECK 3: Log Health (no errors in bootstrap or application)
sudo journalctl -u docker --since "10 minutes ago" --no-pager | tail -20
sudo cat /var/log/bootstrap.log | grep -E "(error|failed|completed)" | tail -5
```

---

## 5. Force-Multiplier Efficiency Hack

**The `Makefile` Autopilot**: One command to rule them all. Creates a 5-minute deployment loop.

**File: `Makefile`**
```makefile
.PHONY: init plan apply destroy verify ssh clean

# Auto-detect public IP for security group
PUBLIC_IP := $(shell curl -s ifconfig.me)/32

init:
	terraform init
	terraform workspace new dev 2>/dev/null || terraform workspace select dev

plan:
	terraform plan -var="trusted_ip=$(PUBLIC_IP)" -out=tfplan

apply:
	terraform apply tfplan
	@echo "Deployment complete. URL: http://$(shell terraform output -raw app_public_ip)"

verify:
	@echo "=== SERVICE STATUS ==="
	@ssh -i ~/.ssh/tf-deploy.pem -o StrictHostKeyChecking=no ec2-user@$(shell terraform output -raw app_public_ip) 'sudo docker ps | grep webapp'
	@echo "=== PORT CHECK ==="
	@ssh -i ~/.ssh/tf-deploy.pem -o StrictHostKeyChecking=no ec2-user@$(shell terraform output -raw app_public_ip) 'curl -s -o /dev/null -w "%{http_code}" http://localhost:80'
	@echo "=== LOGS ==="
	@ssh -i ~/.ssh/tf-deploy.pem -o StrictHostKeyChecking=no ec2-user@$(shell terraform output -raw app_public_ip) 'sudo tail -5 /var/log/bootstrap.log'

destroy:
	terraform destroy -var="trusted_ip=$(PUBLIC_IP)" -auto-approve

ssh:
	ssh -i ~/.ssh/tf-deploy.pem ec2-user@$(shell terraform output -raw app_public_ip)
```

**Usage:**
```bash
make init && make plan && make apply  # Deploy in 3 commands
make verify                           # Health check
make destroy                          # Cleanup
```

---

## 6. Cost-Ops Cleanup

### Zero-Waste Teardown

```bash
# Standard destroy (removes all managed resources)
terraform destroy -auto-approve

# Nuclear option (if state is corrupted or resources drifted)
terraform state list | xargs -I {} terraform state rm {}  # Clear state
# Then manually purge via AWS CLI:
aws ec2 describe-instances --filters "Name=tag:Project,Values=webapp-deployment" --query 'Reservations[].Instances[].InstanceId' --output text | xargs aws ec2 terminate-instances --instance-ids

# Verify zero resources remain
aws ec2 describe-instances --filters "Name=tag:Project,Values=webapp-deployment" --query 'length(Reservations[])'
# Expected output: 0
```

### Cost Prevention Guardrails

```bash
# Set AWS Budget Alert (run once per account)
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json

# budget.json: Alert at $5 actual, $1 forecasted
```

---

## Architecture Summary

```
┌─────────────────┐
│   Internet      │
└────────┬────────┘
         │
┌────────▼────────┐     ┌─────────────────┐
│  ALB (optional) │────▶│  EC2 (t4g.micro)│
│   :80 / :443    │     │  Docker/Nginx   │
└─────────────────┘     │  EBS encrypted  │
                        │  CloudWatch logs│
                        └─────────────────┘
                               │
                        ┌──────▼──────┐
                        │  IAM Role   │
                        │  (SSM, CW)  │
                        └─────────────┘
```

**Key Security Decisions:**
- **No 0.0.0.0/0 on SSH**: Restricted to single IP prevents brute force
- **IAM over access keys**: Rotating credentials eliminated
- **EBS encryption**: Data at rest compliance by default
- **Session Manager**: Audit trail without bastion host costs

**Estimated Cost**: ~$8.50/month (t4g.micro on-demand) or $0 under AWS Free Tier (750 hours/month for 12 months).

Execute `terraform init` and begin.