# Module-4 Assignment
## Assignment: Deploy a 3-Tier Web Application on AWS
> Objective: The goal of this assignment is to deploy a 3-tier web application (Frontend, Backend, Database) on AWS using a single EC2 instance

**Git Repository**

You must use the following GitHub repository for this assignment:
🔗 Repository: https://github.com/md-sarowar-alam/single-server-3tier-webapp 

**Application Architecture**

The application consists of three tiers:
1. Frontend – User interface
2. Backend – Application logic / API
3. Database – Data storage

All three components must be properly configured and running.

**Deployment Options**

- Deploy on a Single EC2 Instance
- Use the default VPC
- Launch an EC2 instance
- Configure security group rules
- Deploy all tiers on the same EC2 instance

Task Requirements
1. Clone the given GitHub repository on the EC2 instance
2. Install all required dependencies (as per the application needs)
3. Configure:
   - Frontend
   - Backend
   - Database
4. Ensure:
   - Backend can communicate with the database
   - Frontend can communicate with the backend
5. Run the application successfully
6. Access the application from a browser using the public IP of the EC2 instance
## Screenshot Submission (Mandatory)
Students must submit screenshots as proof of work, including:
1. EC2 instance running (AWS Console)
   ![Instance-running](image.png)
2. VPC configuration (if VPC option is chosen)
   > Used Default VPC
3. Security Group inbound rules
   ![security-group](image-1.png)
4. Application running in the browser (Frontend UI)
   ![frontend-running](image-3.png)
5. Backend service running (terminal screenshot)
   ![backend-running](image-2.png)
6. Database service running (terminal screenshot)
   ![database-running](image-4.png)
-----
## 🚀 Complete AWS EC2 Deployment Guide
### Phase 1: AWS Infrastructure Setup
#### Step 1: Launch EC2 Instance
1. **Login to AWS Console** → Navigate to **EC2** → Click **Launch Instance**
2. **Configure Instance:**
- **Name:** ```bmi-health-tracker```
- **AMI:** Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
- **Instance Type:** t2.micro (Free Tier eligible)
- **Key Pair:** Create new or select existing (save the .pem file securely)
- **Network Settings:**
  - **VPC:** Default VPC
  - **Auto-assign public IP:** Enable
  - **Firewall (Security Group):** Create security group
1. **Security Group Rules (Critical - allows traffic):**

| Type       | Protocol | Port Range | Source     | Description               |
| ---------- | -------- | ---------- | ---------- | ------------------------- |
| SSH        | TCP      | 22         | Your IP/32 | Admin access              |
| HTTP       | TCP      | 80         | 0.0.0.0/0  | Frontend access           |
| HTTPS      | TCP      | 443        | 0.0.0.0/0  | Secure access (optional)  |
| Custom TCP | TCP      | 3000       | 0.0.0.0/0  | Backend API (for testing) |
4. **Storage:** 8-20 GB gp2 (default is fine)
5. Launch Instance → Note the **Public IP** and **Public DNS**

### Phase-2: Connect & Prepare Server
#### Step 2: SSH into EC2 Instance
```bash
# Set correct permissions on key file
chmod 400 your-key.pem

# Connect via SSH (replace with your instance's public IP)
ssh -i your-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

#### Step 3: System Update & Dependencies
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl git nginx build-essential

# Install Node.js 18.x (LTS)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
node -v  # Should show v18.x.x
npm -v   # Should show 9.x.x

# Install PM2 globally (process manager)
sudo npm install -g pm2

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### Phase 3: Database Setup
#### Step 4: Configure PostgreSQL

```bash
# Switch to postgres user
sudo -u postgres psql
```

Inside PostgreSQL prompt:

```sql
-- Create database user
CREATE USER bmi_user WITH PASSWORD 'your_secure_password'; 
-- itswargoing-24@7'

-- Create database
CREATE DATABASE bmidb OWNER bmi_user;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE bmidb TO bmi_user;

-- Exit
\q
```
#### Step 5: Configure PostgreSQL for Local Connections
```bash
# Edit PostgreSQL configuration to listen on localhost
sudo nano /etc/postgresql/16/main/postgresql.conf

# Find and ensure this line exists:
listen_addresses = 'localhost'

# Save and exit (Ctrl+X, Y, Enter)

# Restart PostgreSQL
sudo systemctl restart postgresql
```
### Phase 4: Application Deployment
#### Step 6: Clone Repository
```bash
# Create app directory
mkdir -p ~/app && cd ~/app

# Clone the repository
git clone https://github.com/md-sarowar-alam/single-server-3tier-webapp.git .

# Check the structure
ls -la
```
#### Step 7: Backend Setup
```bash
# Navigate to backend
cd ~/app/backend

# Install dependencies
npm install

# Create environment file
cat > .env << 'EOF'
PORT=3000
DATABASE_URL=postgresql://bmi_user:your_secure_password@localhost:5432/bmidb
NODE_ENV=production
EOF

# Run database migrations
psql -U bmi_user -d bmidb -h localhost -f migrations/001_create_measurements.sql

# If there's a second migration file, run it too
psql -U bmi_user -d bmidb -h localhost -f migrations/002_add_measurement_date.sql 2>/dev/null || echo "Migration 2 not found, skipping"

# Test backend manually first
npm start &
# Wait 5 seconds, then test
curl http://localhost:3000/health
# Should return: {"status":"ok","database":"connected"}

# Stop the manual process
pkill -f "node src/server.js"
```
#### Step 8: Frontend Setup
```bash
# Navigate to frontend
cd ~/app/frontend

# Install dependencies
npm install

# Build for production
npm run build

# Verify build was created
ls -la dist/

# Create directory in standard web location
sudo mkdir -p /var/www/bmi-health-tracker
sudo cp -r /home/ubuntu/app/frontend/dist/* /var/www/bmi-health-tracker/

# Set ownership
sudo chown -R www-data:www-data /var/www/bmi-health-tracker
sudo chmod -R 755 /var/www/bmi-health-tracker

# Update Nginx config to point to new location
sudo nano /etc/nginx/sites-available/bmi-health-tracker

```
### Phase 5: Process Management & Web Server
#### Step 9: Configure PM2 for Backend
```bash
# Navigate to backend
cd ~/app/backend

# Start backend with PM2
pm2 start src/server.js --name bmi-backend

# Save PM2 configuration to restart on boot
pm2 save
pm2 startup systemd
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Check status
pm2 status
pm2 logs bmi-backend --lines 20
```
#### Step 10: Configure Nginx (Reverse Proxy)
```bash
# Remove default Nginx site
sudo rm -f /etc/nginx/sites-enabled/default

# Create new Nginx configuration
sudo nano /etc/nginx/sites-available/bmi-health-tracker
```
Paste this configuration:
```nginx
server {
    listen 80;
    server_name _;  # Accept any server name

    # Frontend - Static files
    location / {
        root /var/www/bmi-health-tracker;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # Backend API - Proxy to Node.js
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://localhost:3000/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```
Enable the site and restart Nginx:
```bash
# Create symbolic link
sudo ln -s /etc/nginx/sites-available/bmi-health-tracker /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```
### Phase 6: Verification & Testing
#### Step 11: Test All Components
```bash
# Test 1: Backend Health (via Nginx)
curl http://localhost/health
# Expected: {"status":"ok","database":"connected"}

# Test 2: API Endpoint (via Nginx)
curl http://localhost/api/measurements
# Expected: [] (empty array)

# Test 3: Create a test measurement
curl -X POST http://localhost/api/measurements \
  -H "Content-Type: application/json" \
  -d '{
    "heightCm": 175,
    "weightKg": 70,
    "age": 30,
    "sex": "male",
    "activity": "moderate",
    "measurementDate": "2025-03-29"
  }'

# Test 4: Verify data was saved
curl http://localhost/api/measurements
# Should return the created record
```
#### Step 12: Access from Browser
Open your browser and navigate to:
```plain
http://YOUR_EC2_PUBLIC_IP
```
You should see the BMI & Health Tracker application.

**Test the full flow:**
- Enter height (cm), weight (kg), age, gender, activity level
- Click "Calculate & Save"
- Verify stats appear and chart updates
### Phase 7: Security Hardening (Optional but Recommended)
#### Step 13: Configure Firewall (UFW)
```bash
# Allow only necessary ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS (future use)
sudo ufw enable

# Check status
sudo ufw status
```
#### Step 14: Secure PostgreSQL
```bash
# Ensure PostgreSQL only listens on localhost
sudo nano /etc/postgresql/16/main/postgresql.conf
# listen_addresses = 'localhost'

# Restrict pg_hba.conf to local connections only
sudo nano /etc/postgresql/16/main/pg_hba.conf
# Ensure these lines exist:
local   all             postgres                                peer
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256

# Restart PostgreSQL
sudo systemctl restart postgresql
```
### Phase 8: Monitoring & Maintenance
Useful Commands for Management
```bash
# View application logs
pm2 logs bmi-backend

# Monitor resources
pm2 monit

# Restart backend
pm2 restart bmi-backend

# View Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Database backup
pg_dump -U bmi_user -h localhost bmidb > backup_$(date +%Y%m%d).sql

# Check disk space
df -h

# Check memory usage
free -h
```

UFW Status:
![ufw_status](image-5.png)