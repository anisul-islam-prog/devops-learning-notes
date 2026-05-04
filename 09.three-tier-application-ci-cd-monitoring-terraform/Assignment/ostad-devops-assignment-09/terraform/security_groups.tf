# ==========================================
# SECURITY GROUPS — Least Privilege, Tier-Isolated
# ==========================================

# ------------------------------------------
# ALB Security Groups
# ------------------------------------------

resource "aws_security_group" "frontend_alb" {
  name        = "${var.project_name}-frontend-alb-sg"
  description = "Security group for Frontend ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from Internet (redirect to HTTPS)"
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
    Name = "${var.project_name}-frontend-alb-sg"
  }
}

resource "aws_security_group" "backend_alb" {
  name        = "${var.project_name}-backend-alb-sg"
  description = "Security group for Backend Internal ALB"
  vpc_id      = aws_vpc.main.id

  # ALB receives HTTP requests from Frontend tier only
  ingress {
    description     = "HTTP from Frontend tier only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_ec2.id]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["161.248.241.230/32"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-alb-sg"
  }
}

# ------------------------------------------
# Frontend EC2 Security Group
# ------------------------------------------

resource "aws_security_group" "frontend_ec2" {
  name        = "${var.project_name}-frontend-ec2-sg"
  description = "Security group for Frontend EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from Frontend ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_alb.id]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-frontend-ec2-sg"
  }
}

# ------------------------------------------
# Backend EC2 / ASG Security Group
# ------------------------------------------

resource "aws_security_group" "backend_ec2" {
  name        = "${var.project_name}-backend-ec2-sg"
  description = "Security group for Backend ASG instances"
  vpc_id      = aws_vpc.main.id

  # Backend instances accept traffic FROM the Backend ALB
  ingress {
    description     = "App traffic from Backend ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb.id]
  }

  ingress {
    description = "SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Prometheus scraping from monitoring server
  ingress {
    description = "Prometheus metrics scraping"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Promtail/Loki log shipping
  ingress {
    description = "Loki log shipping"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-ec2-sg"
  }
}

# ------------------------------------------
# Database EC2 Security Group
# ------------------------------------------

resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "Security group for PostgreSQL EC2 database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Backend tier only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_ec2.id]
  }

  ingress {
    description = "SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-database-sg"
  }
}

# ------------------------------------------
# Monitoring Server Security Group
# ------------------------------------------

resource "aws_security_group" "monitoring" {
  name        = "${var.project_name}-monitoring-sg"
  description = "Security group for PLG Monitoring Stack"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Grafana Web UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["161.248.241.230/32"]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["161.248.241.230/32"]
  }

  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["161.248.241.230/32"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-monitoring-sg"
  }
}