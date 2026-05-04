# ==========================================
# FRONTEND TIER — React/Vue + Nginx
# ==========================================

resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.frontend_ec2.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 15
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/../application/scripts/user-data-frontend.sh", {
    backend_alb_dns = aws_lb.backend.dns_name
    github_url      = var.github_repo_url
  }))

  tags = {
    Name = "${var.project_name}-frontend"
    Tier = "Frontend"
  }

  depends_on = [aws_nat_gateway.main]
}

# Attach the frontend EC2 instance to the ALB target group
resource "aws_lb_target_group_attachment" "frontend" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend.id
  port             = 80
}