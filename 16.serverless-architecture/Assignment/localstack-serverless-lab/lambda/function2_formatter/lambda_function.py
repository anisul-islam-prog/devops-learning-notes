"""
Lambda Function 2: Response Formatter (UPDATED)
Triggered by: Direct invocation (from Function 1 or manually)
Responsibilities:
  - Receive processed S3 data
  - Add enhanced metadata (timestamp, extension, uppercase name)
  - Return a formatted JSON response
"""

import json
import os
from datetime import datetime, timezone
import uuid


def lambda_handler(event, context):
    print(f"📨 Received event: {json.dumps(event, indent=2)}")
    correlation_id = event.get('correlation_id', str(uuid.uuid4()))

    print(json.dumps({
        "level": "INFO",
        "correlation_id": correlation_id,
        "message": "Formatting response",
        "input_key": object_key
    }))

    # Extract base fields
    bucket_name = event.get('bucket_name', 'unknown')
    object_key = event.get('object_key', 'unknown')
    object_size = event.get('object_size', 0)

    # Extract file extension
    _, file_extension = os.path.splitext(object_key)
    file_extension = file_extension.lstrip('.').lower() if file_extension else 'none'

    # Extract filename (last part of key)
    filename = os.path.basename(object_key)

    # Generate current UTC timestamp
    current_timestamp = datetime.now(timezone.utc).isoformat()
    

    # Build enhanced response
    response = {
        "status": "success",
        "bucket": bucket_name,
        "key": object_key,
        "size_bytes": object_size,
        "filename": filename,
        "filename_uppercase": filename.upper(),
        "file_extension": file_extension,
        "processed_at": current_timestamp,
        "message": "File processed successfully with enhanced metadata",
        "version": "2.0",
        "correlation_id": correlation_id,
        "trace": f"{correlation_id} -> function2"
    }

    print(f"📤 Returning enhanced response: {json.dumps(response, indent=2)}")
    return response