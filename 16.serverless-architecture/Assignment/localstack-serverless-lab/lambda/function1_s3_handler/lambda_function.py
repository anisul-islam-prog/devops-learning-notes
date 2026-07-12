"""
Lambda Function 1: S3 Event Handler
Triggered by: S3 ObjectCreated events
Responsibilities:
  - Parse S3 event for bucket name, object key, and size
  - Log event details
  - Invoke Function 2 with processed payload
"""

import json
import boto3
import os
import urllib.parse
import uuid


def lambda_handler(event, context):
    # Configure boto3 to use LocalStack endpoint when running locally
    endpoint_url = os.environ.get('AWS_ENDPOINT_URL')
    lambda_client = (
        boto3.client('lambda', endpoint_url=endpoint_url)
        if endpoint_url
        else boto3.client('lambda')
    )

    records_processed = 0

    for record in event.get('Records', []):

        correlation_id = str(uuid.uuid4())
        print(json.dumps({
            "level": "INFO",
            "correlation_id": correlation_id,
            "message": "Processing S3 upload event",
            "bucket": bucket_name,
            "key": object_key
        }))

        
        s3_info = record.get('s3', {})
        bucket_name = s3_info.get('bucket', {}).get('name')
        object_key = urllib.parse.unquote_plus(
            s3_info.get('object', {}).get('key', '')
        )
        object_size = s3_info.get('object', {}).get('size', 0)

        # Log to CloudWatch Logs (visible in LocalStack)
        print(f"📦 New upload detected:")
        print(f"   Bucket: {bucket_name}")
        print(f"   Key: {object_key}")
        print(f"   Size: {object_size} bytes")

        # Build payload for Function 2
        payload = {
            "bucket_name": bucket_name,
            "object_key": object_key,
            "object_size": object_size,
            "event_time": record.get('eventTime'),
            "correlation_id": correlation_id  # <-- Trace ID
        }
        
        # Invoke Function 2 synchronously
        function_2_name = os.environ.get('FUNCTION_2_NAME', 'response-formatter')
        try:
            response = lambda_client.invoke(
                FunctionName=function_2_name,
                InvocationType='RequestResponse',
                Payload=json.dumps(payload)
            )

            response_payload = json.loads(response['Payload'].read())
            print(f"✅ Function 2 response: {json.dumps(response_payload, indent=2)}")

        except Exception as e:
            print(f"❌ Error invoking Function 2: {str(e)}")
            raise

        records_processed += 1

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "S3 event processed successfully",
            "records_processed": records_processed
        })
    }