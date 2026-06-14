#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting Jenkins installation at $(date)"

# Update system
apt-get update -y
apt-get upgrade -y

# Install Java 21 (required for Jenkins 2.555+)
apt-get install -y \
    openjdk-21-jdk \
    fontconfig \
    git \
    docker.io \
    wget \
    curl \
    awscli \
    jq

# Verify Java version
java -version

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Create jenkins user and directories
useradd -m -s /bin/bash jenkins
mkdir -p /var/lib/jenkins /var/log/jenkins
chown -R jenkins:jenkins /var/lib/jenkins /var/log/jenkins

# Download Jenkins WAR (LTS 2.555.3)
JENKINS_VERSION="2.555.3"
wget -q "https://get.jenkins.io/war-stable/${JENKINS_VERSION}/jenkins.war" -O /usr/share/jenkins.war

# Create systemd service
cat > /etc/systemd/system/jenkins.service << 'EOF'
[Unit]
Description=Jenkins Automation Server
After=network.target

[Service]
Type=simple
User=jenkins
Group=jenkins
ExecStart=/usr/bin/java -Djava.awt.headless=true -jar /usr/share/jenkins.war --httpPort=8080 --webroot=/var/lib/jenkins/war
Restart=always
RestartSec=10
Environment="JENKINS_HOME=/var/lib/jenkins"

[Install]
WantedBy=multi-user.target
EOF

# Create init script to skip setup wizard and create admin user
mkdir -p /var/lib/jenkins/init.groovy.d
cat > /var/lib/jenkins/init.groovy.d/basic-security.groovy << 'EOF'
#!groovy
import jenkins.model.*
import hudson.security.*
import jenkins.install.*

def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
instance.setSecurityRealm(hudsonRealm)
def user = hudsonRealm.createAccount("admin", "admin123")
user.save()
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
instance.save()
EOF

chown -R jenkins:jenkins /var/lib/jenkins

# Start Jenkins
systemctl daemon-reload
systemctl start jenkins
systemctl enable jenkins
usermod -aG docker jenkins
systemctl restart jenkins

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Terraform
TERRAFORM_VERSION="1.9.0"
wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Cleanup
apt-get autoremove -y
apt-get clean

echo "Jenkins installation completed at $(date)"
echo "Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Admin user: admin / admin123"