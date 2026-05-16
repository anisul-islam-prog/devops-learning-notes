# ==========================================
# BLUE/GREEN DEPLOYMENT — Backend Target Groups
# ==========================================

resource "aws_lb_target_group" "backend_blue" {
  name     = "${var.project_name}-bkend-b-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name  = "${var.project_name}-bkend-b-tg"
    Color = "blue"
  }
}

resource "aws_lb_target_group" "backend_green" {
  name     = "${var.project_name}-bkend-g-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name  = "${var.project_name}-bkend-g-tg"
    Color = "green"
  }
}

# ==========================================
# ASG ATTACHMENT — Current ASG to BLUE target group
# ==========================================

resource "aws_autoscaling_attachment" "backend_blue" {
  autoscaling_group_name = aws_autoscaling_group.backend.id
  lb_target_group_arn    = aws_lb_target_group.backend_blue.arn
}