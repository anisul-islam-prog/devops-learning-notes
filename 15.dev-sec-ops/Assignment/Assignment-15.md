
# Assignment-15

## Assignment: Improving Quality, Security & Performance in CI/CD Pipelines

**Objective:** Enhance an existing application pipeline by integrating testing, code quality analysis, security scanning, and basic performance validation.

```markdown
### Part 1: Unit Testing & Code Quality

**Tasks:**

- Write unit tests for at least one module of your application.

  - Use a suitable framework (e.g., pytest, Jest, etc.).

- Integrate test execution into your CI pipeline.

  - Set up SonarQube or SonarCloud:
    - Analyze code quality
  - Fix at least 2 issues (bugs, code smells, or vulnerabilities)

**Deliverables:**

- Test files
- CI pipeline screenshot/log showing test execution
- Sonar report (before & after fixes)

### Part 2: Load Testing (Basic)

**Tasks:**

- Perform load testing using:
  - Locust OR
  - k6

- Simulate at least:
  - 50–100 virtual users

- Measure:
  - Response time
  - Failure rate

**Deliverables:**

- Load test script
- Summary of results (short explanation + screenshot)

### Part 3: Security in CI/CD

**Tasks:**

- Add security scanning to your pipeline using:
  - Trivy OR Snyk

- Scan your application or Docker image
- Identify at least 2 vulnerabilities and fix or explain them

**Deliverables:**

- Pipeline config with scanning step
- Vulnerability report
- Explanation of fixes or mitigation

### Part 4: Secrets Management

**Tasks:**

- Remove hardcoded secrets (API keys, DB passwords, etc.)
- Store secrets securely using:
- CI/CD environment variables OR
- Secret manager (optional)
- Update your application to read secrets from environment variables

**Deliverables:**

- Updated code snippet
- Explanation of how secrets are managed

### Part 5: Policy as Code (Intro)

**Tasks:**

- Use a simple policy tool like:
- Open Policy Agent
- Define one basic policy, such as:
- Disallow latest Docker tags
- Require resource limits in Kubernetes
- Integrate or simulate policy validation in CI

**Deliverables:**

- Policy file
- Short explanation of what it enforces

## Submission Requirements

- GitHub repository link
- README explaining:
  - Steps performed
  - Tools used
  - Key learnings
```

---

## The Infrastructure Architecture

Since your AWS account is restricted (no IAM, CodeCommit, CodeDeploy, RDS, CloudWatch), we will build a **"GitHub-Native CI/CD → AWS EC2"** pipeline. This is a real-world pattern for startups and restricted environments.

### Architecture Diagram (Text)

```plain
                ┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
                │   GitHub    │────▶│  GitHub Actions  │────▶│    S3       │
                │  (Source)   │     │   (CI/CD Engine) │     │ (Artifacts) │
                └─────────────┘     └──────────────────┘     └─────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │  SonarCloud      │
                                    │  (Code Quality)  │
                                    └──────────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │  Trivy / Snyk    │
                                    │  (Security Scan) │
                                    └──────────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │  OPA (Conftest)  │
                                    │  (Policy Check)  │
                                    └──────────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │   AWS EC2        │
                                    │ (App Deployment) │
                                    │  + SQLite DB     │
                                    └──────────────────┘
```

### Services Required

| Layer | Service | Purpose | Why This Choice |
| ------- | --------- | --------- | ----------------- |
| **Source Control** | GitHub | Git repo, PRs, collaboration | You don't have CodeCommit access |
| **CI/CD** | GitHub Actions | Build, test, scan, deploy | Free, no AWS IAM needed for orchestration |
| **Compute** | AWS EC2 | Host the application | You have access |
| **Storage** | AWS S3 | Store build artifacts (Docker tar, Terraform state) | You have access |
| **Network** | AWS VPC + Security Groups | Isolate and secure EC2 | You have access |
| **Quality** | SonarCloud | Static analysis, code smells, vulnerabilities | Free for public repos; no need to host SonarQube server |
| **Load Testing** | k6 (CLI in GitHub Actions) | Performance validation | Open source, runs headless in CI |
| **Security** | Trivy | Container & filesystem scanning | Open source, no SaaS signup required |
| **Secrets** | GitHub Secrets | Store API keys, DB creds | Native integration with Actions |
| **Policy** | OPA (Conftest) | Policy-as-code validation | Lightweight, runs in CI |
| **Database** | SQLite (local to EC2) | Simple persistent storage | You don't have RDS access |

### Terraform Infrastructure

Create a `terraform/` directory in your repo. This provisions the bare minimum.

**`terraform/main.tf`**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "ostad-devops-tfstate-unique"  # Create this bucket manually first
    key    = "assignment-15/terraform.tfstate"
    region = "us-east-1"                   # Change to your region
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC (Default is fine, but we define a security group)
resource "aws_security_group" "app_sg" {
  name_prefix = "ostad-app-sg-"
  description = "Security group for Ostad DevOps assignment"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Flask app port"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ostad-assignment-sg"
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_pair_name

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "ostad-devops-app"
  }
}

# S3 Bucket for artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifact_bucket_name
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

**`terraform/variables.tf`**

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Ubuntu 24.04 LTS AMI ID for your region"
  type        = string
  default     = "ami-0f8a61b66d1accaee"  # Ubuntu 24.04 us-east-1; verify in console
}

variable "key_pair_name" {
  description = "Existing EC2 Key Pair name for SSH"
  type        = string
}

variable "artifact_bucket_name" {
  description = "Globally unique S3 bucket name for artifacts"
  type        = string
}
```

**`terraform/outputs.tf`**

```hcl
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "s3_bucket_name" {
  description = "Name of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.bucket
}
```

### Terraform Execution Steps

```bash
# 1. Create the bucket (us-east-1 does NOT require LocationConstraint)
aws s3api create-bucket \
    --bucket ostad-devops-tfstate-unique \
    --region us-east-1

# 2. Enable versioning (critical for Terraform state recovery)
aws s3api put-bucket-versioning \
    --bucket ostad-devops-tfstate-unique \
    --versioning-configuration Status=Enabled

# 3. Enable server-side encryption (security best practice)
aws s3api put-bucket-encryption \
    --bucket ostad-devops-tfstate-unique \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'

# 4. Block all public access (security hardening)
aws s3api put-public-access-block \
    --bucket ostad-devops-tfstate-unique \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 5. Run terraform
cd terraform
terraform init
terraform plan -var="key_pair_name=your-key-name"
terraform apply -var="key_pair_name=your-key-name"
```

---

## 1. Application Scaffold

We will use a **Python Flask** application with **SQLite**. This is ideal because:

- Easy to unit test with `pytest`
- Easy to containerize
- No external DB (RDS) needed
- Simple enough to focus on DevOps tooling

**Project Structure:**

```plain
assignment-15/
├── .github/
│   └── workflows/
│       └── ci-cd.yml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── models.py
│   └── config.py
├── tests/
│   └── test_app.py
├── policies/
│   └── docker.rego
├── load-tests/
│   └── load-test.js
├── Dockerfile
├── requirements.txt
├── sonar-project.properties
└── README.md
```

**`app/main.py`** (The application)

```python
import os
from flask import Flask, jsonify, request
from app.models import db, Task

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'sqlite:///app.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/tasks', methods=['GET'])
def get_tasks():
    tasks = Task.query.all()
    return jsonify([{"id": t.id, "title": t.title, "done": t.done} for t in tasks])

@app.route('/tasks', methods=['POST'])
def create_task():
    data = request.get_json()
    if not data or 'title' not in data:
        return jsonify({"error": "Title is required"}), 400
    
    task = Task(title=data['title'], done=data.get('done', False))
    db.session.add(task)
    db.session.commit()
    return jsonify({"id": task.id, "title": task.title, "done": task.done}), 201

@app.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    task = Task.query.get_or_404(task_id)
    db.session.delete(task)
    db.session.commit()
    return jsonify({"message": "Deleted"}), 200

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=3000)
```

**`app/models.py`**

```python
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

class Task(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    done = db.Column(db.Boolean, default=False)
```

**`app/config.py`**

```python
import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret-key')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL', 'sqlite:///app.db')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
```

**`requirements.txt`**

```txt
Flask==3.0.3
Flask-SQLAlchemy==3.1.1
pytest==8.2.0
pytest-flask==1.3.0
gunicorn==22.0.0
```

**`Dockerfile`**

```dockerfile
FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=sqlite:///data/app.db

EXPOSE 3000

CMD ["gunicorn", "--bind", "0.0.0.0:3000", "app.main:app"]
```

---

## Unit Testing & Code Quality

### Step 2.1: Write Unit Tests

**`tests/test_app.py`**

```python
import pytest
from app.main import app, db
from app.models import Task

@pytest.fixture
def client():
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
            yield client
            db.drop_all()

def test_health_endpoint(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'

def test_create_task(client):
    response = client.post('/tasks', json={"title": "Learn DevOps"})
    assert response.status_code == 201
    data = response.get_json()
    assert data['title'] == "Learn DevOps"
    assert data['done'] is False

def test_create_task_missing_title(client):
    response = client.post('/tasks', json={})
    assert response.status_code == 400
    data = response.get_json()
    assert 'error' in data

def test_get_tasks(client):
    client.post('/tasks', json={"title": "Task 1"})
    client.post('/tasks', json={"title": "Task 2"})
    response = client.get('/tasks')
    assert response.status_code == 200
    data = response.get_json()
    assert len(data) == 2

def test_delete_task(client):
    create_resp = client.post('/tasks', json={"title": "Delete me"})
    task_id = create_resp.get_json()['id']
    
    delete_resp = client.delete(f'/tasks/{task_id}')
    assert delete_resp.status_code == 200
    
    get_resp = client.get('/tasks')
    assert len(get_resp.get_json()) == 0
```

Run locally to verify:

```bash
# 1. Verify Python 3.14 is available
python3.14 --version

# 2. Create a virtual environment (recommended, avoids system-wide conflicts)
python3.14 -m venv .venv

# 3. Activate the virtual environment
source .venv/bin/activate

# 4. Verify you're using the correct Python
which python
python --version   # Should show 3.14.x

# 5. Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# 6. Initialize the SQLite database (first run only)
python -c "from app.main import app; from app.models import db; app.app_context().push(); db.create_all()"

# 7. Run the Flask application
python -m app.main

# App will start at http://localhost:3000
# Test: curl http://localhost:3000/health

# Open New window in terminal

# 8. Activate the same virtual environment
source .venv/bin/activate

# 9. Run the test suite
python -m pytest tests/ -v --tb=short

# 10. Run tests with coverage report (optional, for SonarCloud)
python -m pytest tests/ -v --cov=app --cov-report=xml --cov-report=term
```

### Step 2.2: Integrate Tests into CI Pipeline

**`.github/workflows/ci-cd.yml`** (Initial test stage)

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.14'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt

      - name: Run pytest
        run: |
          python -m pytest tests/ -v --cov=app --cov-report=xml

      - name: Upload coverage to SonarCloud
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage.xml
```

### Step 2.3: Set Up SonarCloud

1. Go to [sonarcloud.io](https://sonarcloud.io) → Log in with GitHub → Add your repository (free for public repos).
2. Note your `SONAR_TOKEN` (from SonarCloud → Administration → Analysis Method → GitHub Actions).
3. Add `SONAR_TOKEN` to your GitHub repository secrets (Settings → Secrets → Actions).

**`sonar-project.properties`** (in repo root)

```properties
sonar.projectKey=your-github-username_assignment-15
sonar.organization=your-github-username
sonar.sources=app
sonar.tests=tests
sonar.python.coverage.reportPaths=coverage.xml
sonar.python.version=3.14
sonar.exclusions=terraform/**,.github/**,tests/**
```

Update the CI workflow to include the SonarCloud scan:

```yaml
      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

### Step 2.4: Fix 2 SonarQube Issues

After the first scan, SonarCloud will likely flag these common issues in a Flask app:

**Issue 1: Code Smell — Hardcoded IP / Debug Mode**
If you had `app.run(debug=True)` or `host='0.0.0.0'` hardcoded without configuration, Sonar flags this.

*Fix:* Use environment variables in `main.py`:

```python
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    debug_mode = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    app.run(host='0.0.0.0', port=3000, debug=debug_mode)
```

**Issue 2: Bug / Vulnerability — SQL Injection Risk or Weak Secret**
SonarCloud may flag `SECRET_KEY` hardcoded or SQLAlchemy queries that could be unsafe.

*Fix:* Ensure `SECRET_KEY` is always from env in `config.py`:

```python
import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY')
    if not SECRET_KEY:
        raise ValueError("No SECRET_KEY set for Flask application")
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL', 'sqlite:///app.db')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
```

Update `main.py` to use the config:

```python
app.config.from_object('app.config.Config')
```

---

## 3. Part 2: Load Testing (Basic)

We use **k6** because it is:

- Open-source and runs headless in CI/CD
- JavaScript-based (easy to write)
- Native GitHub Action available
- Industry standard for load testing in 2026

### Step 3.1: Write the Load Test Script

**`load-tests/load-test.js`**

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

// Test configuration: ramp up to 100 VUs over 2 minutes
export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp up to 50 users
    { duration: '1m', target: 100 },   // Ramp up to 100 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],   // 95% of requests under 500ms
    http_req_failed: ['rate<0.05'],     // Error rate under 5%
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  // Test 1: Health check
  let healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, {
    'health status is 200': (r) => r.status === 200,
    'health response time < 200ms': (r) => r.timings.duration < 200,
  });

  // Test 2: Create a task
  let payload = JSON.stringify({ title: `Task ${__VU}-${__ITER}`, done: false });
  let headers = { 'Content-Type': 'application/json' };
  let createRes = http.post(`${BASE_URL}/tasks`, payload, { headers });
  check(createRes, {
    'create status is 201': (r) => r.status === 201,
    'create response time < 500ms': (r) => r.timings.duration < 500,
  });

  // Test 3: Get all tasks
  let getRes = http.get(`${BASE_URL}/tasks`);
  check(getRes, {
    'get status is 200': (r) => r.status === 200,
    'get response time < 300ms': (r) => r.timings.duration < 300,
  });

  sleep(1); // Think time between iterations
}
```

### Step 3.2: Run Locally (Before CI)

```bash
# Start the app locally
docker build -t ostad-app .
docker run -d -p 3000:3000 --name ostad-app ostad-app

# Install k6 (if not already installed)
# macOS: brew install k6
# Linux: sudo gpg -k && sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69 && echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list && sudo apt-get update && sudo apt-get install k6

# Run load test
k6 run --env BASE_URL=http://localhost:3000 load-tests/load-test.js
```

### Step 3.3: Integrate k6 into CI Pipeline

Add a new job to your `.github/workflows/ci-cd.yml`. This job runs **after** the build and deploy stages (we'll add deploy later), but for the assignment, you can also run it against a staging EC2 instance or the local Docker container in CI.

For the assignment, we use a **two-stage approach**:

1. Build and run the app in a service container during the load test job
2. Run k6 against it

Updated workflow snippet for load testing:

```yaml
  load-test:
    name: Load Testing with k6
    runs-on: ubuntu-latest
    needs: build-and-push  # We'll define this in Part 3
    services:
      app:
        image: ghcr.io/${{ github.repository }}/ostad-app:${{ github.sha }}
        ports:
          - 3000:3000
        env:
          DATABASE_URL: sqlite:///data/app.db
          SECRET_KEY: test-secret-key
        options: >-
          --health-cmd "curl -f http://localhost:3000/health || exit 1"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run k6 load test
        uses: grafana/k6-action@v0.3.1
        with:
          filename: load-tests/load-test.js
          flags: --env BASE_URL=http://localhost:3000
```

**Alternative (Simpler for Assignment):** Run k6 against your deployed EC2 after deployment. We'll cover this in Part 4 when we wire up the full deploy stage.

### Step 3.4: Results Summary

After running k6, you will see output like:

```plain
     checks.........................: 100.00% ✓ 4500      ✗ 0
     data_received..................: 1.2 MB  10 kB/s
     data_sent......................: 890 kB  7.4 kB/s
     http_req_blocked...............: avg=1.23ms  min=0s      med=0s      max=45ms
     http_req_connecting............: avg=0.98ms  min=0s      med=0s      max=32ms
     http_req_duration..............: avg=45ms    min=12ms    med=38ms    max=234ms
       { expected_response:true }...: avg=45ms    min=12ms    med=38ms    max=234ms
     http_req_failed................: 0.00%   ✓ 0         ✗ 1500
     http_req_receiving.............: avg=0.12ms  min=0s      med=0s      max=5ms
     http_req_sending...............: avg=0.08ms  min=0s      med=0s      max=3ms
     http_req_waiting...............: avg=44ms    min=12ms    med=37ms    max=233ms
     http_reqs......................: 1500    12.5/s
     iteration_duration.............: avg=1.04s   min=1.01s   med=1.04s   max=1.23s
     iterations.....................: 500     4.16/s
     vus............................: 100     min=100     max=100
     vus_max........................: 100     min=100     max=100
```

**Deliverables for Part 2:**

- `load-tests/load-test.js` → Load test script
- Screenshot of k6 terminal output or GitHub Actions log showing:
  - 50–100 VUs simulated
  - Response time metrics (avg, p95)
  - Failure rate (should be 0% or <5%)
![alt text](image-5.png)
- Short written summary (3–4 sentences) explaining the results:

#### Load Test Summary

**Test Configuration:** k6 simulated up to **100 virtual users** over **2 minutes** across three stages (ramp to 50 VUs, sustain 100 VUs, ramp down). The test targeted a local Flask application backed by SQLite.

**Overall Result:** **Partially Failed** — The **p(95) latency threshold** (`< 500 ms`) was breached, while the **error rate threshold** (`< 5%`) passed comfortably.

---

#### Key Metrics

| Metric | Value | Assessment |
| -------- | ------- | ------------ |
| **Total Requests** | 14,535 | ~121 req/s throughput |
| **Iterations** | 4,845 | Each iteration = 3 requests (health + create + get) |
| **Error Rate** | **0.00%** | Excellent — only 1 HTTP request failed across the entire test |
| **Avg Response Time** | 136.39 ms | Acceptable under load |
| **p(95) Response Time** | **691.18 ms** | **Failed** threshold of 500 ms |
| **Max Response Time** | 6.22 s | Indicates sporadic latency spikes |

---

#### Check-Level Breakdown

| Check | Pass Rate | Notes |
| ------- | ----------- | ------- |
| Health status `200` | 100% | App remained reachable |
| Health response `< 200 ms` | 100% | Lightweight endpoint performed well |
| Create task status `201` | 99% | 1 failure (likely a transient timeout or CSRF/token issue at peak load) |
| Create task response `< 500 ms` | **84%** | **Primary bottleneck** — 739 requests exceeded 500 ms |
| Get tasks status `200` | 100% | Read operations succeeded |
| Get tasks response `< 300 ms` | **80%** | 927 requests exceeded 300 ms |

---

#### Analysis

1. **Functional Stability:** The application did not crash. With a **0.00% HTTP failure rate**, the Flask app handled the concurrency functionally.
2. **Latency Degradation:** Under 100 VUs, the **p(95) latency hit 691 ms**, breaching the 500 ms threshold. The worst offenders were the **POST /tasks** and **GET /tasks** endpoints.
3. **Root Cause (Likely):** SQLite uses file-level locking. With 100 concurrent VUs hitting write operations (`POST`) and reads (`GET`) against a local SQLite database, contention and I/O blocking cause the observed tail latency (p95/p99) and the 6.22 s max spike. This is expected for a local file-based database under load.

---

#### Recommendation

For a production-like setup, replace SQLite with a proper RDBMS (PostgreSQL/MySQL) or use an in-memory store for load testing. For this assignment, the results are valid: you successfully simulated 100 users, measured response times, identified a latency threshold breach, and demonstrated that the application remains functionally stable (0% failures) even when performance degrades.

---

## 4. Part 3: Security in CI/CD

We use **Trivy** because:

- Open-source, no API key required
- Scans Docker images, filesystems, and IaC
- Native GitHub Action available
- Detects OS packages, language packages, and misconfigurations

### Step 4.1: Add Trivy to CI Pipeline

Add these jobs to `.github/workflows/ci-cd.yml`:

```yaml
  security-scan-fs:
    name: Trivy Filesystem Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner (fs)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-fs-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy FS scan results
        uses: actions/upload-artifact@v4
        with:
          name: trivy-fs-report
          path: trivy-fs-results.sarif

  security-scan-image:
    name: Trivy Docker Image Scan
    runs-on: ubuntu-latest
    needs: build-and-push
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t ostad-app:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner (image)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'ostad-app:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-image-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy image scan results
        uses: actions/upload-artifact@v4
        with:
          name: trivy-image-report
          path: trivy-image-results.sarif
```

### Step 4.2: Identify and Fix 2 Vulnerabilities

After the first Trivy scan, you will likely find these common issues:

#### Vulnerability 1: Outdated Base Image (OS-level CVEs)

**Issue:** `python:3.11-slim` may have outdated system packages (e.g., `openssl`, `libssl`) with known CVEs.

**Fix:** Pin to a specific patched digest and update regularly, or use `python:3.11-slim-bookworm` with `apt-get upgrade`:

Updated `Dockerfile`:

```dockerfile
FROM python:3.14-slim-bookworm

# Update system packages to patch known CVEs
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends gcc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=sqlite:///data/app.db

# Run as non-root user for security
RUN useradd -m -u 1000 appuser && mkdir -p /app/data && chown -R appuser:appuser /app
USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:3000/health')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:3000", "--workers", "2", "--timeout", "60", "app.main:app"]
```

#### Vulnerability 2: Hardcoded Credentials or Weak Permissions

**Issue:** Trivy filesystem scan may flag hardcoded secrets or detect that the Dockerfile runs as `root`.

**Fix:**

1. Remove any hardcoded secrets (covered in Part 4)
2. Add `USER appuser` to the Dockerfile (already added above)
3. Ensure no `.env` files are committed to git (add to `.gitignore`)

**`.gitignore`**

```plain
__pycache__/
*.pyc
.env
*.db
.terraform/
*.tfstate*
coverage.xml
.trivy/
```

**Deliverables for Part 3:**

- Updated `.github/workflows/ci-cd.yml` with Trivy scan steps
- `trivy-fs-results.sarif` and/or `trivy-image-results.sarif` → Vulnerability reports
- Screenshot of Trivy output showing vulnerabilities **before** fix
- Screenshot of Trivy output showing vulnerabilities **after** fix (or reduced severity)
- Written explanation of the 2 vulnerabilities found and how you fixed/mitigated them

---

## Current CI/CD Workflow (So Far)

Here is the cumulative `.github/workflows/ci-cd.yml` up to this point:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/ostad-app

jobs:
  test:
    name: Unit Tests & Coverage
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Required for SonarCloud

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install pytest-cov

      - name: Run pytest with coverage
        run: |
          python -m pytest tests/ -v --cov=app --cov-report=xml

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage.xml

      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

  security-scan-fs:
    name: Trivy Filesystem Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner (fs)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-fs-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy FS scan results
        uses: actions/upload-artifact@v4
        with:
          name: trivy-fs-report
          path: trivy-fs-results.sarif

  build-and-push:
    name: Build & Push Docker Image
    runs-on: ubuntu-latest
    needs: [test, security-scan-fs]
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  security-scan-image:
    name: Trivy Docker Image Scan
    runs-on: ubuntu-latest
    needs: build-and-push
    steps:
      - name: Run Trivy vulnerability scanner (image)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: '${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-image-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy image scan results
        uses: actions/upload-artifact@v4
        with:
          name: trivy-image-report
          path: trivy-image-results.sarif

  load-test:
    name: Load Testing with k6
    runs-on: ubuntu-latest
    needs: build-and-push
    services:
      app:
        image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        ports:
          - 3000:3000
        env:
          DATABASE_URL: sqlite:///data/app.db
          SECRET_KEY: test-secret-key
        options: >-
          --health-cmd "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:3000/health')\""
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run k6 load test
        uses: grafana/k6-action@v0.3.1
        with:
          filename: load-tests/load-test.js
          flags: --env BASE_URL=http://localhost:3000
```

---

## 5. Part 4: Secrets Management

### Step 5.1: Identify and Remove Hardcoded Secrets

Before the fix, your code might have looked like this (intentionally showing the **bad pattern** so you can demonstrate the "before" state in your README):

**`app/config.py` (BEFORE — DO NOT USE)**

```python
# BAD PRACTICE — Hardcoded secrets
class Config:
    SECRET_KEY = 'my-super-secret-key-12345'  # ❌ HARDCODED
    DATABASE_URL = 'sqlite:///app.db'
    API_KEY = 'sk-live-abc123xyz'  # ❌ HARDCODED
```

**`app/config.py` (AFTER — USE THIS)**

```python
import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY')
    if not SECRET_KEY:
        raise ValueError("SECRET_KEY environment variable is required")
    
    DATABASE_URL = os.environ.get('DATABASE_URL', 'sqlite:///data/app.db')
    
    # Optional external API key (example)
    API_KEY = os.environ.get('API_KEY')
```

**`app/main.py` (AFTER — updated to use config)**

```python
import os
from flask import Flask
from app.models import db
from app.config import Config

app = Flask(__name__)
app.config.from_object(Config)
db.init_app(app)

# ... rest of routes
```

### Step 5.2: Store Secrets in GitHub Actions

Navigate to your GitHub repository → **Settings → Secrets and variables → Actions → New repository secret**

Add these secrets:

| Secret Name | Value Example | Purpose |
| ------------- | --------------- | --------- |
| `SECRET_KEY` | `a-very-long-random-string-32-chars-min` | Flask session security |
| `DATABASE_URL` | `sqlite:///data/app.db` | Database path |
| `AWS_ACCESS_KEY_ID` | `AKIA...` | AWS credentials for deployment |
| `AWS_SECRET_ACCESS_KEY` | `wJalrXUtnFEMI...` | AWS credentials for deployment |
| `EC2_HOST` | `43.204.XX.XX` | Public IP from Terraform output |
| `EC2_SSH_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | Private key for SSH (paste full key) |
| `SONAR_TOKEN` | `sqp_...` | SonarCloud authentication |

### Step 5.3: Update CI/CD to Inject Secrets

The workflow already references these via `${{ secrets.XXX }}`. Here is the updated `build-and-push` job showing proper secret injection:

```yaml
  build-and-push:
    name: Build & Push Docker Image
    runs-on: ubuntu-latest
    needs: [test, security-scan-fs]
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          build-args: |
            BUILD_DATE=${{ github.event.head_commit.timestamp }}
            VCS_REF=${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Step 5.4: Runtime Secret Injection on EC2

We will use a `docker-compose.yml` on the EC2 instance to read secrets from environment variables passed during deployment.

**`docker-compose.yml`**

```yaml
version: '3.8'

services:
  app:
    image: ${IMAGE_TAG}
    container_name: ostad-app
    restart: unless-stopped
    ports:
      - "80:3000"
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - DATABASE_URL=${DATABASE_URL}
      - API_KEY=${API_KEY}
    volumes:
      - app-data:/app/data
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:3000/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

volumes:
  app-data:
```

**Deliverables for Part 4:**

- Updated `app/config.py` showing environment variable usage (with `raise ValueError` guard)
- Screenshot of GitHub Secrets page (redact actual values)
- Explanation: "Secrets are stored in GitHub Encrypted Secrets, injected at build time as Docker build-args and at runtime as container environment variables. No secrets exist in source code. The application crashes on startup if `SECRET_KEY` is missing, enforcing the fail-closed principle."

---

## 6. Part 5: Policy as Code (Intro)

We use **Open Policy Agent (OPA)** via **Conftest**, which is a lightweight OPA wrapper specifically designed for testing configuration files in CI/CD.

### Step 6.1: Define the Policy

**`policies/docker.rego`**

```rego
package main

# Deny: Do not use 'latest' tag in FROM images
deny[msg] {
    input[i].Cmd == "from"
    val := input[i].Value
    contains(val[i], ":latest")
    msg := sprintf("Line %d: Do not use 'latest' tag in FROM image: %s", [i, val])
}

# Deny: Do not run as root (USER instruction must be present)
deny[msg] {
    not any_user_instruction
    msg := "Dockerfile must include a USER instruction (do not run as root)"
}

any_user_instruction {
    input[i].Cmd == "user"
}

# Deny: Must include HEALTHCHECK instruction
deny[msg] {
    not any_healthcheck
    msg := "Dockerfile must include a HEALTHCHECK instruction"
}

any_healthcheck {
    input[i].Cmd == "healthcheck"
}

# Warn: Resource limits should be defined (for docker-compose or K8s)
# This is a placeholder for K8s manifests; for Dockerfile we check EXPOSE
warn[msg] {
    not any_expose
    msg := "Dockerfile should expose a port for the application"
}

any_expose {
    input[i].Cmd == "expose"
}
```

### Step 6.2: Integrate Conftest into CI

Add a new job to `.github/workflows/ci-cd.yml`:

```yaml
  policy-check:
    name: OPA Policy Check (Conftest)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Conftest
        run: |
          wget https://github.com/open-policy-agent/conftest/releases/download/v0.49.1/conftest_0.49.1_Linux_x86_64.tar.gz
          tar xzf conftest_0.49.1_Linux_x86_64.tar.gz
          sudo mv conftest /usr/local/bin/

      - name: Run Conftest on Dockerfile
        run: |
          conftest test Dockerfile --policy policies/docker.rego

      - name: Run Conftest on docker-compose.yml
        run: |
          conftest test docker-compose.yml --policy policies/docker.rego || true
```

### Step 6.3: What This Policy Enforces

| Rule | Severity | Explanation |
| ------ | ---------- | ------------- |
| No `latest` tag | Deny | Prevents non-reproducible builds; ensures traceability |
| Must have `USER` | Deny | Prevents container running as root (privilege escalation risk) |
| Must have `HEALTHCHECK` | Deny | Ensures runtime health monitoring |
| Should have `EXPOSE` | Warn | Best practice for container documentation |

**Deliverables for Part 5:**

- `policies/docker.rego` → Policy file
- Screenshot of Conftest passing in GitHub Actions
- Short explanation (2–3 sentences): "This policy enforces container security best practices: no mutable `latest` tags, mandatory non-root user execution, and health check probes. It prevents common Dockerfile anti-patterns before image build."

---

## 7. Deployment to AWS EC2

Since you don't have CodeDeploy, we use **SSH-based deployment** from GitHub Actions directly to the EC2 instance. This is a pragmatic "poor man's deployment" that works perfectly for assignments and small projects.

### Step 7.1: Pre-Deployment Setup on EC2

SSH into your EC2 instance (from Terraform output) and run:

```bash
# SSH into EC2
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>

# Install Docker and Docker Compose
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo usermod -aG docker ubuntu
newgrp docker

# Create app directory
mkdir -p ~/ostad-app
```

### Step 7.2: Add Deploy Job to CI/CD

```yaml
  deploy:
    name: Deploy to AWS EC2
    runs-on: ubuntu-latest
    needs: [build-and-push, security-scan-image, policy-check]
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to EC2 via SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            # Login to GitHub Container Registry
            echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
            
            # Pull latest image
            docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            
            # Stop and remove old container
            docker stop ostad-app || true
            docker rm ostad-app || true
            
            # Run new container with secrets from environment
            docker run -d \
              --name ostad-app \
              --restart unless-stopped \
              -p 80:3000 \
              -e SECRET_KEY="${{ secrets.SECRET_KEY }}" \
              -e DATABASE_URL="sqlite:///data/app.db" \
              -v ostad-data:/app/data \
              ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            
            # Cleanup old images
            docker image prune -f
            
            # Verify deployment
            sleep 5
            curl -f http://localhost:80/health || exit 1
```

### Step 7.3: Alternative: Using docker-compose on EC2

For a cleaner approach, copy `docker-compose.yml` to EC2 and use it:

```yaml
      - name: Copy docker-compose to EC2
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          source: "docker-compose.yml"
          target: "~/ostad-app/"

      - name: Deploy with Docker Compose
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
            export IMAGE_TAG=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            export SECRET_KEY="${{ secrets.SECRET_KEY }}"
            export DATABASE_URL="sqlite:///data/app.db"
            cd ~/ostad-app
            docker-compose down || true
            docker-compose up -d
            docker-compose ps
            sleep 5
            curl -f http://localhost:80/health || exit 1
```

---

## 8. The Complete CI/CD Pipeline

Here is the fully assembled `.github/workflows/ci-cd.yml`. Every stage gates the next — this is **fail-fast** design.

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/ostad-app

jobs:
  # ─────────────────────────────────────────
  # STAGE 1: Quality Gate — Tests + SonarCloud
  # ─────────────────────────────────────────
  test:
    name: Unit Tests & Coverage
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.14'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install pytest-cov

      - name: Run pytest with coverage
        run: |
          python -m pytest tests/ -v --cov=app --cov-report=xml

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage.xml

      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

  # ─────────────────────────────────────────
  # STAGE 2: Security Gate — Trivy FS Scan
  # ─────────────────────────────────────────
  security-scan-fs:
    name: Trivy Filesystem Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner (fs)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-fs-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy FS scan results
        uses: actions/upload-artifact@v4
        with:
          name: trivy-fs-report
          path: trivy-fs-results.sarif

  # ─────────────────────────────────────────
  # STAGE 3: Policy Gate — OPA Conftest
  # ─────────────────────────────────────────
  policy-check:
    name: OPA Policy Check (Conftest)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Conftest
        run: |
          wget -q https://github.com/open-policy-agent/conftest/releases/download/v0.49.1/conftest_0.49.1_Linux_x86_64.tar.gz
          tar xzf conftest_0.49.1_Linux_x86_64.tar.gz
          sudo mv conftest /usr/local/bin/

      - name: Run Conftest on Dockerfile
        run: conftest test Dockerfile --policy policies/docker.rego

  # ─────────────────────────────────────────
  # STAGE 4: Build & Push Docker Image
  # ─────────────────────────────────────────
  build-and-push:
    name: Build & Push Docker Image
    runs-on: ubuntu-latest
    needs: [test, security-scan-fs, policy-check]
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          build-args: |
            BUILD_DATE=${{ github.event.head_commit.timestamp }}
            VCS_REF=${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ─────────────────────────────────────────
  # STAGE 5: Security Gate — Trivy Image Scan
  # ─────────────────────────────────────────
  security-scan-image:
    name: Trivy Docker Image Scan
    runs-on: ubuntu-latest
    needs: build-and-push
    steps:
      - name: Run Trivy vulnerability scanner (image)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: '${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-image-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy image scan results
        uses: actions/upload-artifact@v4
        with:
          name: trivy-image-report
          path: trivy-image-results.sarif

  # ─────────────────────────────────────────
  # STAGE 6: Performance Gate — k6 Load Test
  # ─────────────────────────────────────────
  load-test:
    name: Load Testing with k6
    runs-on: ubuntu-latest
    needs: build-and-push
    services:
      app:
        image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        ports:
          - 3000:3000
        env:
          DATABASE_URL: sqlite:///data/app.db
          SECRET_KEY: test-secret-key-for-load-test-only
        options: >-
          --health-cmd "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:3000/health')\""
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run k6 load test
        uses: grafana/k6-action@v0.3.1
        with:
          filename: load-tests/load-test.js
          flags: --env BASE_URL=http://localhost:3000

  # ─────────────────────────────────────────
  # STAGE 7: Deploy to AWS EC2
  # ─────────────────────────────────────────
  deploy:
    name: Deploy to AWS EC2
    runs-on: ubuntu-latest
    needs: [build-and-push, security-scan-image, load-test, policy-check]
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Copy docker-compose to EC2
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          source: "docker-compose.yml"
          target: "~/ostad-app/"

      - name: Deploy with Docker Compose
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
            export IMAGE_TAG=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            export SECRET_KEY="${{ secrets.SECRET_KEY }}"
            export DATABASE_URL="sqlite:///data/app.db"
            cd ~/ostad-app
            docker-compose down || true
            docker-compose pull
            docker-compose up -d
            docker-compose ps
            sleep 5
            curl -f http://localhost:80/health || exit 1
```

---

## 9. Bonus: The "One-Man Army" Edge

> **Best Practice to make your submission stand out:** **Implement a "Canary / Blue-Green Deployment" simulation using Docker Compose labels and a rollback mechanism.**

Since we cannot use CodeDeploy or Kubernetes, simulate a production-grade deployment strategy on a single EC2 instance using **Docker Compose with health-checked rolling updates**.

### What This Adds

| Feature | Why It Impresses |
| --------- | ------------------ |
| Zero-downtime deployment | Blue container stays up until green passes health check |
| Automatic rollback | If green fails health check, traffic stays on blue |
| Container labeling | `ostad-app-blue` / `ostad-app-green` for clear identification |
| Port switching | Nginx or direct port mapping swap |

### Implementation

**`docker-compose.canary.yml`** (Optional advanced file)

```yaml
version: '3.8'

services:
  app-blue:
    image: ${IMAGE_TAG}
    container_name: ostad-app-blue
    restart: unless-stopped
    ports:
      - "5001:3000"
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - DATABASE_URL=${DATABASE_URL}
    volumes:
      - app-data:/app/data
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:3000/health')"]
      interval: 10s
      timeout: 5s
      retries: 3

  app-green:
    image: ${IMAGE_TAG}
    container_name: ostad-app-green
    restart: unless-stopped
    ports:
      - "5002:3000"
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - DATABASE_URL=${DATABASE_URL}
    volumes:
      - app-data:/app/data
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:3000/health')"]
      interval: 10s
      timeout: 5s
      retries: 3

  nginx:
    image: nginx:alpine
    container_name: ostad-nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app-blue

volumes:
  app-data:
```

**`nginx.conf`** (Simple reverse proxy)

```nginx
events { worker_connections 1024; }
http {
    upstream backend {
        server app-blue:3000;
        # server app-green:3000;  # Switch comment to promote green
    }
    server {
        listen 80;
        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

---

## 11. Final Submission Checklist

Before submitting, verify every box:

github url: [Github Repo](https://github.com/anisul-islam-prog/assignment-15)

### Code & Config

- [x] `tests/test_app.py` — at least 5 test cases, all passing
![alt text](image.png)
- [x] `app/config.py` — no hardcoded secrets, `ValueError` guard on `SECRET_KEY`
![alt text](image-3.png)
- [x] `Dockerfile` — non-root user, healthcheck, no `latest` tag, patched base image
- [x] `docker-compose.yml` — secrets via env vars, volume for data persistence
- [x] `policies/docker.rego` — 3 deny rules, 1 warn rule
- [x] `load-tests/load-test.js` — 50–100 VUs, thresholds defined
- [x] `.github/workflows/ci-cd.yml` — complete pipeline with all 7 stages
- [x] `terraform/` — EC2, S3, Security Group
- [x] `sonar-project.properties` — configured for SonarCloud

### Screenshots

- [x] pytest passing in Actions
![alt text](image-1.png)
- [x] SonarCloud before (showing issues)
![alt text](image-2.png)
- [x] SonarCloud after (issues resolved)
![alt text](image-4.png)
- [x] Trivy FS scan report
![alt text](image-7.png)
- [x] Trivy image scan report
![alt text](image-8.png)
- [x] k6 results summary
![alt text](image-9.png)
- [x] Conftest passing
![alt text](image-6.png)
- [x] App running on EC2 public IP
![alt text](image-10.png)
![alt text](image-11.png)
- [x] GitHub Secrets page (redacted)
![alt text](image-12.png)

### Documentation

- [x] `README.md` filled out with your details
- [x] All 5 parts explained with tools used
- [x] Key learnings section completed
- [ ] Bonus section included (canary deployment)

### GitHub Repository

- [x] Repo is **public** (required for SonarCloud free tier)
- [x] All files committed and pushed
- [x] At least one successful full pipeline run on `main` branch

---

## 12. Quick Reference: Commands

```bash
# Terraform
cd terraform
terraform init
terraform plan -var="key_pair_name=your-key"
terraform apply -var="key_pair_name=your-key"

# Local testing
pytest tests/ -v --cov=app
k6 run --env BASE_URL=http://localhost:3000 load-tests/load-test.js
conftest test Dockerfile --policy policies/docker.rego

# Docker
docker build -t ostad-app .
docker run -d -p 3000:3000 -e SECRET_KEY=test ostad-app
```
