# ==========================================
# BACKEND LAUNCH TEMPLATE
# ==========================================

resource "aws_launch_template" "backend" {
  name          = "${var.project_name}-backend-lt"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.backend_ec2.id]

  update_default_version = true 

  user_data = base64encode(templatefile("${path.module}/../application/scripts/user-data-backend.sh", {
    db_host     = aws_instance.database.private_ip
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
    github_url  = var.github_repo_url
  }))

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-backend"
      Tier = "Backend"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.project_name}-backend-volume"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

# ==========================================
# BACKEND AUTO SCALING GROUP
# ==========================================

resource "aws_autoscaling_group" "backend" {
  name                      = "${var.project_name}-backend-asg"
  vpc_zone_identifier       = aws_subnet.private[*].id
  health_check_type         = "ELB"
  health_check_grace_period = 600

  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
    triggers = ["tag"]
  }

  termination_policies = ["OldestLaunchTemplate", "Default"]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  depends_on = [aws_nat_gateway.main]
}

# ==========================================
# SCALING POLICIES
# ==========================================

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 60
  alarm_description   = "Scale out when CPU > 60%"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend.name
  }
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project_name}-scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in when CPU < 30%"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend.name
  }
}

# Explicitly attach ASG to target group (more reliable than target_group_arns)
# resource "aws_autoscaling_attachment" "backend" {
# autoscaling_group_name = aws_autoscaling_group.backend.id
# lb_target_group_arn    = aws_lb_target_group.backend.arn
# }

# Optional: Email subscription for notifications
# resource "aws_sns_topic_subscription" "email" {
#   topic_arn = aws_sns_topic.asg_lifecycle.arn
#   protocol  = "email"
#   endpoint  = "your-email@example.com"
# }