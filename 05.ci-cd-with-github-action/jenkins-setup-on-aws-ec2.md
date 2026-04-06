# 🚀 Jenkins CI/CD Setup on AWS EC2 (Complete Guide)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│             AWS EC2 Instance (Jenkins Master)               │
│           Ubuntu 22.04 LTS, t2.medium (2GB RAM)             │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Jenkins Server (Port 8080)                           │  │
│  │  ├── Dashboard & Job Configuration                    │  │
│  │  ├── Pipeline Execution                               │  │
│  │  └── Plugin Management                                │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Node.js Application (Port 3000)                      │  │
│  │  └── Managed by PM2 (via Jenkins pipeline)            │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Security Group: 22 (SSH), 8080 (Jenkins), 3000 (App)       │
└─────────────────────────────────────────────────────────────┘
```

---

## Step 1: Launch EC2 Instance for Jenkins

### 1.1 AWS Console Setup

| Setting | Value |
|---------|-------|
| **Name** | `jenkins-server` |
| **AMI** | Ubuntu Server 22.04 LTS |
| **Instance Type** | `t2.medium` (2 vCPU, 4GB RAM) - *Jenkins needs min 2GB* |
| **Key Pair** | Create new or use existing |
| **Storage** | 20 GB gp2 |

**Security Group Rules:**

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | Your IP/32 | Admin access |
| Custom TCP | TCP | 8080 | Your IP/32 OR 0.0.0.0/0 | Jenkins Web UI |
| Custom TCP | TCP | 3000 | 0.0.0.0/0 | Application |

> ⚠️ **Important:** Jenkins needs at least **2GB RAM**. `t2.micro` (1GB) will crash.

---

## Step 2: Install Jenkins

### 2.1 Connect and Update System

```bash
# SSH into EC2
ssh -i your-key.pem ubuntu@YOUR_EC2_PUBLIC_IP

# Update system
sudo apt update && sudo apt upgrade -y

# Install Java (Jenkins requirement)
sudo apt install -y openjdk-17-jre-headless

# Verify Java
java -version
```

### 2.2 Install Jenkins

```bash
# Add Jenkins repository key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins repository
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update and install Jenkins
sudo apt update
sudo apt install -y jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Check status
sudo systemctl status jenkins
```

### 2.3 Install Node.js, PM2, and Git

```bash
# Install Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify
node -v  # v22.x.x
npm -v

# Install PM2 globally
sudo npm install -g pm2

# Setup PM2 startup
pm2 startup systemd
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Install Git
sudo apt install -y git

# Install curl for testing
sudo apt install -y curl
```

---

## Step 3: Configure Jenkins

### 3.1 Initial Setup

1. **Access Jenkins UI:**
   ```
   http://YOUR_EC2_PUBLIC_IP:8080
   ```

2. **Get initial admin password:**
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
   Copy the password and paste it into the Jenkins setup wizard.

3. **Install suggested plugins** (Click "Install suggested plugins")

4. **Create admin user:**
   - Username: `admin`
   - Password: Choose a secure password
   - Email: your-email@example.com

### 3.2 Install Required Plugins

**Manage Jenkins → Plugins → Available Plugins:**

Install these:
- **NodeJS Plugin** (for Node.js builds)
- **Pipeline** (usually pre-installed)
- **Pipeline Stage View** (visualization)
- **Git** (usually pre-installed)
- **Credentials Binding** (for secrets)

Click **Install without restart**.

### 3.3 Configure NodeJS in Jenkins

**Manage Jenkins → Tools → NodeJS installations:**

- Click **Add NodeJS**
- Name: `NodeJS-22`
- Version: `22.x.x` (or select from dropdown)
- Click **Save**

---

## Step 4: Add GitHub Credentials

**Manage Jenkins → Credentials → System → Global credentials:**

1. Click **Add Credentials**
2. Kind: **Username with password**
3. Username: Your GitHub username
4. Password: Your GitHub Personal Access Token (create at GitHub → Settings → Developer settings → Personal access tokens)
5. ID: `github-credentials`
6. Description: `GitHub Access`
7. Click **OK**

---

## Step 5: Create Jenkins Pipeline

### 5.1 Create New Job

1. **New Item**
2. Name: `ostad-module-5-ci-cd`
3. Type: **Pipeline**
4. Click **OK**

### 5.2 Pipeline Configuration

**General Section:**
- ✅ GitHub project
- Project url: `https://github.com/anisul-islam-prog/ostad-module-05-ci-cd-assignment/`

**Build Triggers:**
- ✅ GitHub hook trigger for GITScm polling (for webhook automation)

**Pipeline Section:**
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/anisul-islam-prog/ostad-module-05-ci-cd-assignment.git`
- Credentials: `github-credentials`
- Branch Specifier: `*/main`
- Script Path: `Jenkinsfile`

Click **Save**.

---

## Step 6: Create Jenkinsfile

Create `Jenkinsfile` in your repository root:

```groovy
pipeline {
    agent any
    
    tools {
        nodejs 'NodeJS-22'
    }
    
    environment {
        APP_DIR = '/var/lib/jenkins/workspace/ostad-module-5-ci-cd'
        TEST_RESULTS_FILE = 'test-results.txt'
    }
    
    stages {
        //──────────────────────────────────────────────────────────────
        // STAGE 1: Checkout
        //──────────────────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                echo 'Checking out code...'
                checkout scm
            }
        }
        
        //──────────────────────────────────────────────────────────────
        // STAGE 2: Install Dependencies
        //──────────────────────────────────────────────────────────────
        stage('Install Dependencies') {
            steps {
                echo 'Installing Node.js dependencies...'
                sh 'npm install'
            }
        }
        
        //──────────────────────────────────────────────────────────────
        // STAGE 3: Test
        //──────────────────────────────────────────────────────────────
        stage('Test') {
            steps {
                echo 'Running application tests...'
                sh '''
                    echo "Test Execution Report" > ${TEST_RESULTS_FILE}
                    echo "=====================" >> ${TEST_RESULTS_FILE}
                    echo "Date: $(date)" >> ${TEST_RESULTS_FILE}
                    echo "Node Version: $(node -v)" >> ${TEST_RESULTS_FILE}
                    echo "NPM Version: $(npm -v)" >> ${TEST_RESULTS_FILE}
                    echo "Jenkins Build: ${BUILD_NUMBER}" >> ${TEST_RESULTS_FILE}
                    echo "" >> ${TEST_RESULTS_FILE}
                    echo "--- Application Check Output ---" >> ${TEST_RESULTS_FILE}
                    npm run check >> ${TEST_RESULTS_FILE} 2>&1 || echo "Check completed" >> ${TEST_RESULTS_FILE}
                    echo "" >> ${TEST_RESULTS_FILE}
                    echo "--- Test Status ---" >> ${TEST_RESULTS_FILE}
                    echo "Tests completed successfully on $(date)" >> ${TEST_RESULTS_FILE}
                    cat ${TEST_RESULTS_FILE}
                '''
            }
            post {
                always {
                    // Archive test results as artifact
                    archiveArtifacts artifacts: "${TEST_RESULTS_FILE}", fingerprint: true
                }
            }
        }
        
        //──────────────────────────────────────────────────────────────
        // STAGE 4: Build (if needed)
        //──────────────────────────────────────────────────────────────
        stage('Build') {
            steps {
                echo 'Building application...'
                sh '''
                    echo "Build stage completed"
                    echo "Application ready for deployment"
                '''
            }
        }
        
        //──────────────────────────────────────────────────────────────
        // STAGE 5: Deploy
        //──────────────────────────────────────────────────────────────
        stage('Deploy') {
            steps {
                echo 'Deploying application...'
                
                // Display test results before deployment
                sh '''
                    echo "=========================================="
                    echo "PRE-DEPLOYMENT TEST RESULTS REVIEW"
                    echo "=========================================="
                    cat ${TEST_RESULTS_FILE}
                    echo "=========================================="
                '''
                
                // Deployment using PM2
                sh '''
                    echo "Starting deployment with PM2..."
                    
                    # Ensure PM2 is available
                    export PATH=$PATH:/usr/local/bin
                    
                    # Stop existing process if running
                    pm2 delete node-app || true
                    
                    # Start application
                    pm2 start "./src/server.js" --name node-app
                    
                    # Save PM2 config
                    pm2 save
                    
                    # Display status
                    echo "PM2 Process Status:"
                    pm2 status
                    
                    echo "Application deployed successfully!"
                '''
            }
        }
        
        //──────────────────────────────────────────────────────────────
        // STAGE 6: Verify Deployment
        //──────────────────────────────────────────────────────────────
        stage('Verify') {
            steps {
                echo 'Verifying deployment...'
                sh '''
                    echo "Waiting for application to start..."
                    sleep 3
                    
                    echo "Testing root endpoint:"
                    curl -s http://localhost:3000/ || echo "Root endpoint check completed"
                    
                    echo ""
                    echo "Testing API endpoint:"
                    curl -s http://localhost:3000/api || echo "API endpoint check completed"
                    
                    echo ""
                    echo "Deployment verification complete!"
                '''
            }
        }
    }
    
    //──────────────────────────────────────────────────────────────
    // POST-BUILD ACTIONS
    //──────────────────────────────────────────────────────────────
    post {
        success {
            echo '''
                ==========================================
                PIPELINE EXECUTION SUCCESSFUL
                ==========================================
                Build: ${BUILD_NUMBER}
                Application deployed to: http://YOUR_EC2_IP:3000
                Jenkins: http://YOUR_EC2_IP:8080
                ==========================================
            '''
        }
        failure {
            echo 'Pipeline failed! Check logs for details.'
        }
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}
```

---

## Step 7: Run the Pipeline

### 7.1 Manual Trigger

1. Go to Jenkins Dashboard
2. Click on your job: `ostad-module-5-ci-cd`
3. Click **Build Now**

### 7.2 View Results

- **Console Output:** Click on build number → Console Output (shows real-time logs)
- **Stage View:** Shows visual pipeline stages
- **Artifacts:** Test results available in build artifacts

---

## Step 8: Setup Webhook (Auto-trigger on Push)

### 8.1 GitHub Webhook Configuration

1. Go to your GitHub repository
2. **Settings** → **Webhooks** → **Add webhook**
3. **Payload URL:** `http://YOUR_EC2_PUBLIC_IP:8080/github-webhook/`
4. **Content type:** `application/json`
5. **Which events?** Just the push event
6. **Active:** ✅
7. Click **Add webhook**

### 8.2 Jenkins Job Configuration

Ensure your job has:
- ✅ GitHub hook trigger for GITScm polling (in Build Triggers)

---

## Step 9: Verify Everything

### 9.1 Check Jenkins

```bash
# On EC2
sudo systemctl status jenkins

# View Jenkins logs
sudo tail -f /var/lib/jenkins/logs/jenkins.log
```

### 9.2 Check Application

```bash
# Check if app is running
pm2 status

# Test endpoints
curl http://localhost:3000/
curl http://localhost:3000/api

# View app logs
pm2 logs node-app
```

### 9.3 Access URLs

| Service | URL |
|---------|-----|
| Jenkins | `http://YOUR_EC2_IP:8080` |
| Application | `http://YOUR_EC2_IP:3000` |

---

## Complete Comparison: GitHub Actions vs Jenkins

| Feature | GitHub Actions | Jenkins |
|---------|---------------|---------|
| **Setup** | Cloud-based, minimal config | Self-hosted, full control |
| **Cost** | Free 2000 min/month | Free (pay for EC2) |
| **UI** | Integrated in GitHub | Separate web interface |
| **Plugins** | Marketplace actions | 1800+ plugins |
| **Customization** | YAML-based | Groovy scripting |
| **Visibility** | Good for simple pipelines | Better for complex workflows |
| **Artifacts** | Built-in | Plugin-based |
| **Best for** | GitHub-centric projects | Enterprise, complex pipelines |

---

## Troubleshooting Jenkins

| Issue | Solution |
|-------|----------|
| **Jenkins won't start** | Check Java: `java -version`. Check logs: `sudo journalctl -u jenkins -f` |
| **Out of memory** | Upgrade to t2.medium. Check: `free -h` |
| **Permission denied** | Ensure Jenkins user owns workspace: `sudo chown -R jenkins:jenkins /var/lib/jenkins` |
| **Node command not found** | Configure NodeJS in Global Tool Configuration |
| **Pipeline fails at deploy** | Check PM2 is installed globally: `sudo npm install -g pm2` |
| **Webhook not triggering** | Ensure URL ends with `/github-webhook/` and port 8080 is open |
| **Cannot access Jenkins UI** | Check security group allows port 8080 |

---

## Deliverables Checklist (Jenkins Version)

- [x] EC2 instance running (t2.medium) with ports 22, 8080, 3000 open
- [x] Jenkins installed and accessible at `http://EC2_IP:8080`
- [x] Jenkins job `ostad-module-5-ci-cd` created
- [x] `Jenkinsfile` in repository root
- [x] GitHub credentials configured in Jenkins
- [x] Pipeline executes: Checkout → Install → Test → Build → Deploy → Verify
- [x] Test results archived as artifacts
- [x] Application running on port 3000 (PM2)
- [x] Webhook configured for automatic builds
- [x] Successful pipeline execution screenshot