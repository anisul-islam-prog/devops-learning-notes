# Three-Tier EKS Deployment — Assignment 14

## Architecture Overview

Production-grade three-tier application (React + Node.js + PostgreSQL) 
deployed on Amazon EKS v1.29 with Terraform + eksctl.

### Tool Split

| Layer | Tool | Reason |
|-------|------|--------|
| VPC, Subnets, NAT, IGW, SGs | Terraform | No IAM role creation required |
| EKS Cluster, Node Group | eksctl | CloudFormation handles IAM roles |

### Network Topology

- VPC CIDR: 10.0.0.0/16
- Public Subnets: 10.0.101.0/24 (1a), 10.0.102.0/24 (1b) — for LoadBalancers
- Private Subnets: 10.0.1.0/24 (1a), 10.0.2.0/24 (1b) — for worker nodes
- NAT Gateway: HighlyAvailable (one per AZ)
- Internet Gateway: Shared, attached to VPC

### Security Groups

| Name | Port | Source |
|------|------|--------|
| frontend-sg | 80 | 0.0.0.0/0 |
| backend-sg | 3000 | frontend-sg |
| database-sg | 5432 | backend-sg |

### Kubernetes Workloads

| Tier | Type | Replicas | Service | Storage |
|------|------|----------|---------|---------|
| Frontend | Deployment | 2 | LoadBalancer (NLB) | — |
| Backend | Deployment | 3 | ClusterIP | — |
| Database | StatefulSet | 1 | ClusterIP | gp2 PVC 10Gi |

## Prerequisites

- AWS CLI configured
- Terraform >= 1.5.0
- eksctl >= 0.180.0
- kubectl >= 1.29

## Deployment Steps

### Step 1: Terraform (VPC + Security Groups)

```bash
cd terraform/
terraform init
terraform apply
```

### Step 2: Capture Terraform Outputs

```bash
terraform output vpc_id
terraform output private_subnets
terraform output public_subnets
```

### Step 3: Update eksctl-cluster.yaml

Replace placeholders with actual values from Step 2.

### Step 4: eksctl (EKS Cluster)

```bash
cd ..
eksctl create cluster -f eksctl-cluster.yaml
```

### Step 5: Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name three-tier-eks
```

### Step 6: Apply Kubernetes Manifests

```bash
kubectl apply -f k8s-manifests/01-namespace.yaml
kubectl apply -f k8s-manifests/02-secrets.yaml
kubectl apply -f k8s-manifests/03-configmap.yaml
kubectl apply -f k8s-manifests/04-database/
kubectl apply -f k8s-manifests/05-backend/
kubectl apply -f k8s-manifests/06-frontend/
```

### Step 7: Verify

```bash
kubectl get pods -n three-tier -o wide
kubectl get svc -n three-tier
```

## Validation Checklist

- [ ] 2 nodes in Ready state
- [ ] 3 backend pods distributed across both nodes
- [ ] Frontend LoadBalancer URL renders React app
- [ ] Database PVC bound to gp2 volume
- [ ] HPA active on backend deployment

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace three-tier

# Delete EKS cluster
eksctl delete cluster --name three-tier-eks --region us-east-1

# Delete VPC and security groups
cd terraform/
terraform destroy
```

## Cost Estimate (us-east-1)

| Resource | Hourly | Monthly |
|----------|--------|---------|
| EKS Control Plane | $0.10 | $73 |
| 2× t3.medium | $0.0832 | $60 |
| NAT Gateway ×2 | $0.09 | $65 |
| **Total if running** | — | **~$198/month** |
| **Assignment (~4h)** | — | **~$1.50** |

> Cleanup is mandatory to avoid charges.
