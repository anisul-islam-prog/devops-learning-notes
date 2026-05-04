# ==========================================
# MONITORING SERVER — PLG Stack
# ==========================================

resource "aws_instance" "monitoring" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.monitoring_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.monitoring.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false
  }

  # Use file() instead of templatefile() — no variables needed
  user_data = base64encode(file("${path.module}/../application/scripts/user-data-monitoring.sh"))

  tags = {
    Name = "${var.project_name}-monitoring"
    Tier = "Monitoring"
  }
}