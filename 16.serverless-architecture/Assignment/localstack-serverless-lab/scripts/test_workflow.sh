#!/bin/bash
set -euo pipefail

BUCKET_NAME="user-uploads-bucket"
TEST_FILE="test-files/sample-upload.txt"
LOCALSTACK_ENDPOINT="http://localhost:4566"

echo "═══════════════════════════════════════════════════════"
echo "  🧪 TESTING EVENT-DRIVEN SERVERLESS WORKFLOW"
echo "═══════════════════════════════════════════════════════"

# 1. Create a sample test file
mkdir -p test-files
echo "This is a sample file for LocalStack S3 upload testing." > "$TEST_FILE"
echo "Generated at: $(date)" >> "$TEST_FILE"
echo "✅ Test file created: $TEST_FILE"
echo ""

# 2. Upload file to S3
echo "📤 Uploading file to S3 bucket: $BUCKET_NAME"
awslocal s3 cp "$TEST_FILE" "s3://$BUCKET_NAME/sample-upload.txt"
echo "✅ Upload complete"
echo ""

# 3. List objects in bucket
echo "📋 Verifying object exists in bucket:"
awslocal s3 ls "s3://$BUCKET_NAME/"
echo ""

# 4. Check Lambda Function 1 logs
echo "📜 Lambda Function 1 Logs (S3 Event Handler):"
sleep 2  # Allow logs to propagate
awslocal logs describe-log-groups --log-group-name-prefix /aws/lambda/s3-event-handler || true
awslocal logs tail "/aws/lambda/s3-event-handler" --since 1m || echo "Logs may take a moment to appear..."
echo ""

# 5. Check Lambda Function 2 logs
echo "📜 Lambda Function 2 Logs (Response Formatter):"
awslocal logs tail "/aws/lambda/response-formatter" --since 1m || echo "Logs may take a moment to appear..."
echo ""

# 6. Invoke Function 2 manually for direct verification
echo "🔍 Manually invoking Function 2 with test payload:"
awslocal lambda invoke \
  --function-name response-formatter \
  --payload '{"bucket_name":"user-uploads-bucket","object_key":"sample-upload.txt","object_size":1024}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/lambda2-response.json

echo "✅ Function 2 direct invocation response:"
cat /tmp/lambda2-response.json | jq .
echo ""

echo "═══════════════════════════════════════════════════════"
echo "  ✅ WORKFLOW TEST COMPLETE"
echo "═══════════════════════════════════════════════════════"