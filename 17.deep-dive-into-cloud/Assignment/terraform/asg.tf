resource "aws_autoscaling_group" "app" {
  name                      = "ostad-asg-${var.environment}"
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
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