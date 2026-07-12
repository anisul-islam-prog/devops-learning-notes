#!/bin/bash
set -euo pipefail

echo "🧹 Cleaning up LocalStack resources..."

cd terraform
terraform destroy -auto-approve

echo "✅ All resources destroyed."
echo "🛑 You can now stop LocalStack: docker compose down"