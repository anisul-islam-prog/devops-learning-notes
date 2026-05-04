# ==========================================
# DATABASE TIER — PostgreSQL on EC2
# ==========================================

# Fetch latest Amazon Linux 2023 AMI
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

resource "aws_instance" "database" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private[0].id # Private subnet AZ-1
  vpc_security_group_ids = [aws_security_group.database.id]
  key_name               = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false # Keep data on termination
  }

  # Additional EBS for PostgreSQL data (persistent)
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false

    tags = {
      Name = "${var.project_name}-postgres-data"
    }
  }

  user_data = base64encode(templatefile("${path.module}/../application/scripts/user-data-db.sh", {
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
  }))

  tags = {
    Name = "${var.project_name}-database"
    Tier = "Database"
  }
}

# ==========================================
# Database Backup to S3 (Manual snapshots)
# ==========================================

resource "aws_s3_bucket" "db_backups" {
  bucket = "${var.project_name}-db-backups-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-db-backups"
  }
}

resource "aws_s3_bucket_versioning" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ==========================================
# Additional Database Variables
# ==========================================