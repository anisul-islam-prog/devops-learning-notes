#!/bin/bash
set -euo pipefail

# ==========================================
# BLUE/GREEN DEPLOYMENT ORCHESTRATOR
# ==========================================

ASG_BLUE="ostad-assignment-09-backend-blue-asg"
ASG_GREEN="ostad-assignment-09-backend-green-asg"
TG_BLUE="arn:aws:elasticloadbalancing:..."
TG_GREEN="arn:aws:elasticloadbalancing:..."
LISTENER_ARN="arn:aws:elasticloadbalancing:..."

NEW_VERSION=$1  # e.g., "2.0.0"
AMI_ID=$2       # New golden AMI

echo "🚀 Starting Blue/Green Deployment v$NEW_VERSION"

# Step 1: Launch GREEN environment with new AMI
echo "📦 Launching GREEN environment..."
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name $ASG_GREEN \
  --launch-template "LaunchTemplateId=$LT_ID,Version=\$Latest"

aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $ASG_GREEN \
  --desired-capacity 1

# Step 2: Wait for GREEN to be healthy
echo "⏳ Waiting for GREEN instances to be healthy..."
sleep 60

while true; do
  HEALTHY=$(aws elbv2 describe-target-health \
    --target-group-arn $TG_GREEN \
    --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`].Target.Id' \
    --output text)
  
  if [ -n "$HEALTHY" ]; then
    echo "✅ GREEN is healthy: $HEALTHY"
    break
  fi
  echo "Still waiting..."
  sleep 15
done

# Step 3: Verify /api/deployment-info on GREEN
GREEN_INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids $HEALTHY \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

DEPLOY_INFO=$(curl -s http://$GREEN_INSTANCE_IP:8080/api/deployment-info)
echo "GREEN Deployment Info: $DEPLOY_INFO"

# Step 4: Canary — Shift 10% traffic to GREEN
echo "🐤 Canary: Shifting 10% traffic to GREEN..."
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,ForwardConfig="{
    TargetGroups=[
      {TargetGroupArn=$TG_BLUE,Weight=90},
      {TargetGroupArn=$TG_GREEN,Weight=10}
    ]
  }"

sleep 120  # Observe metrics

# Step 5: Full cutover — 100% GREEN
echo "🎯 Full cutover to GREEN..."
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,ForwardConfig="{
    TargetGroups=[
      {TargetGroupArn=$TG_BLUE,Weight=0},
      {TargetGroupArn=$TG_GREEN,Weight=100}
    ]
  }"

# Step 6: Scale down BLUE
echo "🔻 Scaling down BLUE..."
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $ASG_BLUE \
  --desired-capacity 0

echo "✅ Blue/Green Deployment Complete!"
echo "BLUE (old): 0 instances"
echo "GREEN (new v$NEW_VERSION): 1 instance"