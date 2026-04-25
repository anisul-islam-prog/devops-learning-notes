data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  user_data_public = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Ostad Assignment-08: Public Instance Healthy</h1>" > /var/www/html/index.html
  EOF
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.public.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true
  # iam_instance_profile        = aws_iam_instance_profile.ssm.name # Not Enough permission

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-bastion" })
}

resource "aws_instance" "public" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.public.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true
  # iam_instance_profile        = aws_iam_instance_profile.ssm.name # Not Enough permission
  user_data = local.user_data_public

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-web" })
}

resource "aws_instance" "private" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.private.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = false
  # iam_instance_profile        = aws_iam_instance_profile.ssm.name # Not Enough permission

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-private-app" })
}