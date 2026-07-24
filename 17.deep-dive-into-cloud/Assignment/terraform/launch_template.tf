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
  instance_type = "t3.micro" # Free tier eligible + cost optimized
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
      volume_size           = 30 # <-- Changed from 8 to 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(local.user_data)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 enforced (security best practice)
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