#!/bin/bash
set -euo pipefail

# Navigate to the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Building Lambda deployment packages..."

# Ensure dist directory exists (in terraform/)
mkdir -p ../terraform/dist

# Package Function 1
cd function1_s3_handler
zip -q -r ../../terraform/dist/function1.zip lambda_function.py
cd ..

# Package Function 2
cd function2_formatter
zip -q -r ../../terraform/dist/function2.zip lambda_function.py
cd ..

echo "✅ Build complete. Artifacts in terraform/dist/"
echo "📦 function1.zip -> S3 Event Handler"
echo "📦 function2.zip -> Response Formatter"