#!/bin/bash
set -euo pipefail

BUCKET_NAME="user-uploads-bucket"
TEST_FILE="test-files/updated-test-DOCUMENT.PDF"
LOCALSTACK_ENDPOINT="http://localhost:4566"

echo "═══════════════════════════════════════════════════════"
echo "  🔄 TESTING UPDATED WORKFLOW (v2.0)"
echo "═══════════════════════════════════════════════════════"

# Create a test file with extension to verify new features
echo "Updated test content for enhanced metadata." > "$TEST_FILE"
echo "Timestamp: $(date)" >> "$TEST_FILE"

echo "📤 Uploading file with extension: $TEST_FILE"
awslocal s3 cp "$TEST_FILE" "s3://$BUCKET_NAME/updated-test-DOCUMENT.PDF"
echo ""

# Wait and check logs
sleep 3

echo "📜 Function 1 Logs (should show Function 2 enhanced response):"
awslocal logs tail "/aws/lambda/s3-event-handler" --since 2m || true
echo ""

echo "📜 Function 2 Logs (should show enhanced metadata):"
awslocal logs tail "/aws/lambda/response-formatter" --since 2m || true
echo ""

# Direct invoke to see clean JSON output
echo "🔍 Direct invoke of updated Function 2:"
awslocal lambda invoke \
  --function-name response-formatter \
  --payload '{"bucket_name":"user-uploads-bucket","object_key":"updated-test-DOCUMENT.PDF","object_size":2048}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/lambda2-updated-response.json

echo "✅ Updated Function 2 response:"
cat /tmp/lambda2-updated-response.json | jq .
echo ""

echo "═══════════════════════════════════════════════════════"
echo "  ✅ UPDATED WORKFLOW TEST COMPLETE"
echo "═══════════════════════════════════════════════════════"