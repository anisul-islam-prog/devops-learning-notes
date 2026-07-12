.PHONY: up build deploy test smoke-test logs destroy validate

# ═══════════════════════════════════════════════════════════
# One-Command LocalStack Serverless Lab
# ═══════════════════════════════════════════════════════════

up: ## Start LocalStack and wait for healthy state
 @echo "🚀 Starting LocalStack..."
 docker compose up -d
 @sleep 3
 @./scripts/wait_for_localstack.sh

build: ## Package Lambda deployment artifacts
 @echo "🔨 Building Lambda packages..."
 ./lambda/build.sh

deploy: build ## Deploy all infrastructure via Terraform
 @echo "📦 Deploying infrastructure..."
 cd terraform && terraform init && terraform apply -auto-approve

validate: ## Run pre-flight health checks
 @echo "🔍 Running health checks..."
 @curl -sf http://localhost:4566/_localstack/health | jq '.services.lambda, .services.s3, .services.iam' || (echo "❌ LocalStack not ready"; exit 1)
 @awslocal lambda list-functions > /dev/null && echo "✅ Lambda accessible"
 @awslocal s3 ls > /dev/null && echo "✅ S3 accessible"

test: ## Upload test file and verify event chain
 @echo "🧪 Running integration test..."
 ./scripts/test_workflow.sh

smoke-test: deploy validate ## Full smoke test: deploy -> validate -> test
 @echo "💨 Running smoke test..."
 ./scripts/test_workflow.sh
 @echo "✅ Smoke test passed"

logs: ## Tail all Lambda logs
 @echo "📜 Tailing Lambda logs..."
 awslocal logs tail "/aws/lambda/s3-event-handler" --since 5m & \
 awslocal logs tail "/aws/lambda/response-formatter" --since 5m

destroy: ## Destroy all infrastructure and stop LocalStack
 @echo "🧹 Destroying infrastructure..."
 cd terraform && terraform destroy -auto-approve
 docker compose down

help: ## Display this help
 @awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)