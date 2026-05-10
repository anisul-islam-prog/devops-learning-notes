terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Security Group for K3s
resource "aws_security_group" "k3s_sg" {
  name_prefix = "k3s-assignment-sg-"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "K3s API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort Range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k3s-assignment-sg"
  }
}

# EC2 Instance for K3s
resource "aws_instance" "k3s_server" {
  ami                    = "ami-05cf1e9f73fbad2e2" # Ubuntu 22.04 LTS (us-east-1)
  instance_type          = "t3.medium"             # 2 vCPU, 4GB RAM — enough for K3s
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  key_name               = "anisul-islam-fahd"

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log) 2>&1
              set -x

              echo "=== START at $(date) ==="

              # IMDSv2: Get token first, then fetch metadata
              TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -sf http://169.254.169.254/latest/meta-data/public-ipv4)
              echo "PUBLIC_IP=$PUBLIC_IP"

              # Wait for apt lock
              for i in $(seq 1 60); do
                if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
                  break
                fi
                echo "apt locked, waiting... ($i)"
                sleep 5
              done

              apt-get update -y

              # Download installer, then execute with proper variable expansion
              curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
              chmod +x /tmp/k3s-install.sh
              INSTALL_K3S_EXEC="server --tls-san $PUBLIC_IP" /tmp/k3s-install.sh

              # Setup kubeconfig
              mkdir -p /home/ubuntu/.kube
              cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
              chown -R ubuntu:ubuntu /home/ubuntu/.kube
              chmod 600 /home/ubuntu/.kube/config
              echo "export KUBECONFIG=/home/ubuntu/.kube/config" >> /home/ubuntu/.bashrc
              echo "export KUBECONFIG=/home/ubuntu/.kube/config" >> /etc/profile.d/k3s.sh

              mkdir -p /home/ubuntu/k8s-assignment
              chown ubuntu:ubuntu /home/ubuntu/k8s-assignment

              echo "=== END at $(date) ==="
              EOF

  tags = {
    Name = "k3s-master-node"
  }
}

output "k3s_public_ip" {
  description = "Public IP of the K3s server"
  value       = aws_instance.k3s_server.public_ip
}