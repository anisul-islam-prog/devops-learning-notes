# 🚀 GitHub Actions: Complete Learning Guide & Cheat Sheet

## 📚 Table of Contents
1. [What is GitHub Actions?](#what-is-github-actions)
2. [Core Concepts & Architecture](#core-concepts--architecture)
3. [Why Use GitHub Actions?](#why-use-github-actions)
4. [Workflow Structure Deep Dive](#workflow-structure-deep-dive)
5. [10+ Practical Usage Patterns](#practical-usage-patterns)
6. [Advanced Patterns & Strategies](#advanced-patterns--strategies)
7. [Security Best Practices](#security-best-practices)
8. [Performance Optimization](#performance-optimization)
9. [Troubleshooting Guide](#troubleshooting-guide)

---

## What is GitHub Actions?

**GitHub Actions** is a **continuous integration and continuous delivery (CI/CD) platform** that allows you to automate your build, test, and deployment pipeline directly within your GitHub repository . It enables you to create workflows that respond to events in your repository (like pushes, pull requests, or issues) and run automated tasks.

### Key Characteristics:
- **Event-driven**: Workflows trigger based on GitHub events
- **YAML-based**: Configuration stored as code in `.github/workflows/`
- **Container-native**: Runs on virtual machines or in containers
- **Extensible**: 20,000+ pre-built actions in the GitHub Marketplace
- **Free tier**: 2,000 minutes/month for public repositories

---

## Core Concepts & Architecture

### The 5 Core Components :

```
┌─────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS ARCHITECTURE              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. WORKFLOW  → Automated process defined in YAML           │
│     └─ Triggered by EVENTS                                  │
│                                                             │
│  2. EVENT     → Activity that triggers workflow             │
│     └─ push, pull_request, schedule, manual, etc.           │
│                                                             │
│  3. JOB       → Set of steps running on same runner         │
│     └─ Parallel by default, sequential via 'needs'          │
│                                                             │
│  4. RUNNER    → Virtual machine/container that executes     │
│     └─ ubuntu-latest, windows-latest, macos-latest          │
│                                                             │
│  5. ACTION    → Reusable unit of code (pre-built or custom) │
│     └─ actions/checkout, actions/setup-node, etc.           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Visual Workflow Example:

```yaml
# .github/workflows/example.yml
name: CI Pipeline                    # Workflow name

on:                                  # EVENT trigger
  push:
    branches: [main, develop]

jobs:                                # JOBS collection
  test:                              # JOB 1: Test
    runs-on: ubuntu-latest           # RUNNER
    steps:                           # STEPS
      - uses: actions/checkout@v4     # ACTION 1
      - uses: actions/setup-node@v4   # ACTION 2
      - run: npm test                # Custom command

  deploy:                            # JOB 2: Deploy
    needs: test                      # Depends on test job
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying..."
```

---

## Why Use GitHub Actions?

### 1. **Native GitHub Integration**
- No external CI/CD tools needed
- Automatic authentication to GitHub
- Deep integration with PRs, issues, releases

### 2. **Infrastructure as Code**
- Workflows version-controlled with your code
- Easy to review, rollback, and audit

### 3. **Massive Ecosystem**
- 20,000+ pre-built actions in Marketplace
- Community-contributed solutions for everything

### 4. **Matrix Builds & Parallelization**
- Test across multiple OS/language versions simultaneously
- Speed up feedback loops

### 5. **Cost-Effective**
- Free for public repositories
- Self-hosted runners for private infrastructure

---

## Workflow Structure Deep Dive

### Complete YAML Syntax Reference:

```yaml
name: Workflow Name                          # Optional, appears in UI

on:                                          # Event triggers (REQUIRED)
  push:                                      # Trigger on push
    branches: [main, develop]                # Specific branches
    paths: ['src/**', 'tests/**']            # Only when these files change
  pull_request:                              # Trigger on PR
    types: [opened, synchronize, closed]   # Specific PR events
  schedule:                                  # Cron schedule
    - cron: '0 2 * * *'                      # Daily at 2 AM UTC
  workflow_dispatch:                         # Manual trigger
    inputs:                                  # Custom inputs
      environment:
        description: 'Environment'
        required: true
        default: 'staging'
  release:                                   # Trigger on release
    types: [published]

env:                                         # Global environment variables
  NODE_VERSION: '18'
  DATABASE_URL: ${{ secrets.DATABASE_URL }}

defaults:                                    # Default settings for all jobs
  run:
    shell: bash
    working-directory: ./src

concurrency:                                 # Prevent parallel runs
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:                                 # Security permissions 
  contents: read                             # Read repository contents
  issues: write                              # Write to issues
  pull-requests: write                       # Write to PRs

jobs:                                        # Job definitions (REQUIRED)
  #──────────────────────────────────────────────────────────────
  # JOB 1: Build & Test
  #──────────────────────────────────────────────────────────────
  build:
    name: Build Application                  # Display name in UI
    runs-on: ubuntu-latest                   # Runner type
    timeout-minutes: 30                      # Fail if exceeds 30 min
    
    outputs:                                 # Data to pass to other jobs
      version: ${{ steps.version.outputs.value }}
      build-status: ${{ job.status }}
    
    services:                                # Sidecar containers (DBs, etc.)
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    strategy:                                # Matrix strategy
      fail-fast: false                       # Don't cancel other jobs if one fails
      matrix:
        node-version: [16, 18, 20]           # Test multiple versions
        os: [ubuntu-latest, windows-latest]
        include:                             # Additional combinations
          - node-version: 19
            os: macos-latest
            experimental: true
        exclude:                             # Skip combinations
          - node-version: 16
            os: windows-latest
    
    steps:                                   # Sequential steps
      # Step 1: Checkout code
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0                     # Full history for tags
          token: ${{ secrets.GITHUB_TOKEN }}
      
      # Step 2: Setup Node.js
      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'                       # Auto-caches npm dependencies
      
      # Step 3: Install dependencies
      - name: Install dependencies
        run: npm ci                          # Clean install from lock file
      
      # Step 4: Run linting
      - name: Run ESLint
        run: npm run lint
        continue-on-error: true              # Don't fail job if linting fails
      
      # Step 5: Run tests with coverage
      - name: Run tests
        id: test                             # Step ID for referencing
        run: npm run test:coverage
        env:
          CI: true
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
      
      # Step 6: Upload coverage
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          fail_ci_if_error: false
      
      # Step 7: Build application
      - name: Build
        run: npm run build
      
      # Step 8: Upload build artifact
      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ matrix.os }}-${{ matrix.node-version }}
          path: |
            ./dist
            ./package.json
          retention-days: 5
      
      # Step 9: Set output for other jobs
      - name: Set version output
        id: version
        run: echo "value=$(node -p "require('./package.json').version")" >> $GITHUB_OUTPUT

  #──────────────────────────────────────────────────────────────
  # JOB 2: Security Scan
  #──────────────────────────────────────────────────────────────
  security:
    name: Security Audit
    runs-on: ubuntu-latest
    needs: build                             # Runs after build completes
    if: github.event_name == 'pull_request'  # Only on PRs
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  #──────────────────────────────────────────────────────────────
  # JOB 3: Deploy to Production
  #──────────────────────────────────────────────────────────────
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [build, security]                 # Wait for both jobs
    if: github.ref == 'refs/heads/main'      # Only on main branch
    
    environment:                             # GitHub Environment protection
      name: production
      url: https://myapp.com                 # Appears in PR/deployments
    env:
      DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
    
    steps:
      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: build-ubuntu-latest-18
          path: ./dist
      
      - name: Deploy to server
        run: |
          echo "Deploying version ${{ needs.build.outputs.version }}"
          # Deployment commands here
      
      - name: Notify Slack
        if: always()                           # Run even if previous steps fail
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Deploy ${{ job.status }}: ${{ github.repository }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## Practical Usage Patterns

### Pattern 1: **CI for Pull Requests** 
*Ensure code quality before merging*

```yaml
name: PR Validation

on:
  pull_request:
    branches: [main, develop]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 18
          cache: 'npm'
      
      - run: npm ci
      - run: npm run lint        # Code style check
      - run: npm run type-check  # TypeScript validation
      - run: npm test -- --coverage
```

**Why use it:** Prevents broken code from entering main branch, provides immediate feedback to developers.

---

### Pattern 2: **Monorepo Path Filtering** 
*Run workflows only when specific directories change*

```yaml
name: Frontend CI

on:
  push:
    paths:
      - 'frontend/**'           # Only trigger on frontend changes
      - 'shared/**'             # Or shared components
    branches: [main]

jobs:
  build-frontend:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./frontend
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build
```

**Why use it:** Saves CI minutes, reduces noise, faster feedback for large codebases.

---

### Pattern 3: **Multi-Environment Deployment Pipeline** 
*Progressive deployment: Dev → Staging → Production*

```yaml
name: Multi-Stage Deployment

on:
  push:
    branches: [main]

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.myapp.com
    steps:
      - run: echo "Deploying to staging..."

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment:
      name: production
      url: https://myapp.com
    steps:
      - run: echo "Deploying to production..."
```

**Why use it:** Enforces staging validation, requires manual approval for production, tracks deployments.

---

### Pattern 4: **Matrix Testing Across Platforms**
*Test on multiple OS and language versions*

```yaml
name: Cross-Platform Test

on: [push]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node: [16, 18, 20]
        include:
          - os: ubuntu-latest
            node: 20
            coverage: true
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm ci
      - run: npm test
      - if: matrix.coverage
        uses: codecov/codecov-action@v3
```

**Why use it:** Catches OS-specific bugs, ensures compatibility, tests multiple Node versions.

---

### Pattern 5: **Container Image Build & Push** 
*Automated Docker builds with caching*

```yaml
name: Docker Build

on:
  push:
    tags: ['v*']
    branches: [main]

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: myapp/myimage
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
      
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Why use it:** Automated releases, versioned images, layer caching for fast builds.

---

### Pattern 6: **Scheduled Jobs (Cron)** 
*Nightly builds, backups, or maintenance tasks*

```yaml
name: Nightly Tasks

on:
  schedule:
    - cron: '0 2 * * *'          # Daily at 2 AM UTC
    - cron: '0 0 * * 0'          # Weekly on Sunday
  workflow_dispatch:             # Manual trigger option

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Cleanup old artifacts
        run: |
          # Script to delete artifacts older than 30 days
          gh api repos/${{ github.repository }}/actions/artifacts \
            --paginate | jq '.artifacts[] | select(.created_at < (now - 2592000 | strftime("%Y-%m-%dT%H:%M:%SZ")))' | jq -r '.id' | \
            xargs -I {} gh api repos/${{ github.repository }}/actions/artifacts/{} -X DELETE
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Dependency vulnerability scan
        run: npm audit --audit-level=moderate
```

**Why use it:** Automated maintenance, regular security scans, resource cleanup.

---

### Pattern 7: **Reusable Workflows**
*DRY principle across repositories*

```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deployment

on:
  workflow_call:                   # Makes it reusable
    inputs:
      environment:
        required: true
        type: string
      version:
        required: false
        type: string
        default: 'latest'
    secrets:
      DEPLOY_TOKEN:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - run: |
          echo "Deploying ${{ inputs.version }} to ${{ inputs.environment }}"
          # Deployment logic using ${{ secrets.DEPLOY_TOKEN }}
```

**Caller workflow:**
```yaml
name: Deploy Production

on:
  push:
    branches: [main]

jobs:
  call-reusable:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production
      version: ${{ github.sha }}
    secrets:
      DEPLOY_TOKEN: ${{ secrets.PROD_TOKEN }}
```

**Why use it:** Standardization, easier maintenance, consistency across projects.

---

### Pattern 8: **Composite Actions**
*Bundle multiple steps into reusable action*

```yaml
# .github/actions/setup-project/action.yml
name: 'Setup Project'
description: 'Sets up Node.js, installs deps, and runs lint'

inputs:
  node-version:
    description: 'Node version'
    default: '18'
    required: false

runs:
  using: composite
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'
    
    - run: npm ci
      shell: bash
    
    - run: npm run lint
      shell: bash
```

**Usage in workflow:**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-project
        with:
          node-version: '20'
      - run: npm run build
```

**Why use it:** Encapsulates complex setup, reduces workflow file size, easier to maintain.

---

### Pattern 9: **OIDC Authentication with Cloud Providers** 
*Secure, credential-less cloud authentication*

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

permissions:
  id-token: write                  # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/GitHubActionsRole
          aws-region: us-east-1
      
      - name: Deploy to S3
        run: aws s3 sync ./dist s3://my-bucket
```

**Why use it:** No long-lived secrets, temporary credentials, more secure, meets compliance requirements.

---

### Pattern 10: **Dynamic Job Generation**
*Create jobs based on changed files*

```yaml
name: Dynamic Matrix

on:
  pull_request:
    paths: ['packages/**']

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      packages: ${{ steps.changes.outputs.packages }}
    steps:
      - uses: actions/checkout@v4
      - id: changes
        run: |
          # Detect which packages changed
          PACKAGES=$(git diff --name-only HEAD^ HEAD | grep '^packages/' | cut -d'/' -f2 | sort -u | jq -R . | jq -s .)
          echo "packages=$PACKAGES" >> $GITHUB_OUTPUT

  build-packages:
    needs: detect-changes
    strategy:
      matrix:
        package: ${{ fromJson(needs.detect-changes.outputs.packages) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          echo "Building ${{ matrix.package }}"
          cd packages/${{ matrix.package }}
          npm ci && npm run build
```

**Why use it:** Efficient monorepo CI, only build what changed, scalable for large codebases.

---

### Pattern 11: **GitHub Pages Documentation Deployment** 
*Auto-deploy docs on every merge*

```yaml
name: Deploy Documentation

on:
  push:
    branches: [main]
    paths: ['docs/**', 'mkdocs.yml']

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-python@v4
        with:
          python-version: 3.x
      
      - run: pip install mkdocs-material
      
      - run: mkdocs build
      
      - uses: actions/upload-pages-artifact@v3
        with:
          path: ./site

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

**Why use it:** Living documentation, always up-to-date, versioned with code.

---

## Advanced Patterns & Strategies

### Strategy 1: **Caching for Performance** 

```yaml
name: Optimized Build

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Cache Node modules
      - uses: actions/cache@v4
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-
      
      # Cache build outputs
      - uses: actions/cache@v4
        with:
          path: |
            ./dist
            ./.next/cache
          key: ${{ runner.os }}-build-${{ github.sha }}
          restore-keys: |
            ${{ runner.os }}-build-
      
      - run: npm ci
      - run: npm run build
```

**Key principle:** Cache keys based on file hashes ensure cache is invalidated when dependencies change .

---

### Strategy 2: **Deployment Gates & Manual Approvals** 

```yaml
name: Controlled Deployment

on:
  push:
    branches: [main]

jobs:
  staging:
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - run: deploy-to-staging.sh

  production:
    runs-on: ubuntu-latest
    needs: staging
    environment:
      name: production
      url: https://example.com
    steps:
      - run: deploy-to-production.sh
```

**Setup:** In GitHub repo → Settings → Environments → Production → Protection rules → Required reviewers (e.g., 2 people must approve).

---

### Strategy 3: **Blue/Green Deployment** 

```yaml
name: Blue/Green Deploy

on:
  workflow_dispatch:

jobs:
  deploy-green:
    runs-on: ubuntu-latest
    steps:
      - run: |
          # Deploy to green environment
          kubectl apply -f k8s/green/
          # Wait for health check
          kubectl rollout status deployment/green

  switch-traffic:
    needs: deploy-green
    runs-on: ubuntu-latest
    steps:
      - run: |
          # Switch load balancer to green
          kubectl patch service production -p '{"spec":{"selector":{"version":"green"}}}'
      
      - name: Notify on failure
        if: failure()
        run: |
          # Rollback: switch back to blue
          kubectl patch service production -p '{"spec":{"selector":{"version":"blue"}}}'
```

---

## Security Best Practices 

### 1. **Secret Management**
```yaml
env:
  API_KEY: ${{ secrets.API_KEY }}              # ✓ Good: Use secrets
  PASSWORD: "hardcoded123"                     # ✗ Bad: Never hardcode
```

### 2. **Least Privilege Permissions**
```yaml
permissions:
  contents: read                               # Default to read-only
  pull-requests: write                         # Only when needed
  id-token: write                              # For OIDC
```

### 3. **Pin Actions to SHA**
```yaml
# ✓ Good: Pin to specific commit
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1

# ✗ Bad: Floating version
- uses: actions/checkout@v4
```

### 4. **OIDC for Cloud Auth** (No long-lived secrets)
```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
      aws-region: us-east-1
```

---

## Performance Optimization 

| Technique | Implementation | Impact |
|-----------|---------------|--------|
| **Shallow clones** | `fetch-depth: 1` | 90% faster checkout |
| **Dependency caching** | `actions/cache` | 50-80% faster builds |
| **Matrix builds** | `strategy.matrix` | Parallel testing |
| **Conditional jobs** | `if: github.event_name == 'push'` | Skip unnecessary work |
| **Artifact retention** | `retention-days: 5` | Save storage costs |
| **Self-hosted runners** | `runs-on: self-hosted` | Custom hardware |

---

## Troubleshooting Guide 

| Symptom | Solution |
|---------|----------|
| **Workflow not triggering** | Check YAML syntax, event filters, branch names |
| **Job stuck/queued** | Check runner availability, concurrency limits |
| **Permission denied** | Verify `permissions` block, secret names |
| **Cache not hitting** | Check cache key format, restore-keys order |
| **Flaky tests** | Add retries, check test isolation, use services |
| **Out of disk space** | Clean up artifacts, use `rm -rf`, enable caching |
| **Secrets exposed in logs** | GitHub masks secrets automatically, avoid `echo ${{ secrets }}` |

---

## Quick Reference: Common Actions

| Action | Purpose | Example |
|--------|---------|---------|
| `actions/checkout@v4` | Clone repository | `uses: actions/checkout@v4` |
| `actions/setup-node@v4` | Setup Node.js | `with: {node-version: '18'}` |
| `actions/cache@v4` | Cache dependencies | `with: {path: '~/.npm', key: 'npm'}` |
| `actions/upload-artifact@v4` | Save build outputs | `with: {name: 'build', path: './dist'}` |
| `actions/download-artifact@v4` | Retrieve artifacts | `with: {name: 'build'}` |
| `docker/build-push-action@v5` | Build Docker images | `with: {push: true, tags: 'myapp:latest'}` |
| `slackapi/slack-github-action@v1` | Send Slack notifications | `with: {payload: '...'}` |

---

## Summary: When to Use What?

| Scenario | Recommended Pattern |
|----------|-------------------|
| Simple PR checks | Pattern 1: Basic CI |
| Large monorepo | Pattern 2: Path filtering + Pattern 10: Dynamic jobs |
| Multi-stage deployment | Pattern 3: Environments + Pattern 7: Reusable workflows |
| Library/framework | Pattern 4: Matrix testing |
| Containerized app | Pattern 5: Docker build |
| Maintenance tasks | Pattern 6: Scheduled jobs |
| Cross-repo standardization | Pattern 7: Reusable workflows |
| Complex setup steps | Pattern 8: Composite actions |
| Cloud deployment | Pattern 9: OIDC authentication |
| Documentation site | Pattern 11: GitHub Pages |

---

> This guide covers GitHub Actions from basics to advanced patterns. Start with simple CI workflows, then gradually adopt reusable workflows, OIDC, and matrix strategies as your needs grow.