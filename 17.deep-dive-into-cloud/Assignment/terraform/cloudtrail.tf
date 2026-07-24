# ╔══════════════════════════════════════════════════════════════════════╗
# ║  IMPORTANT: CloudTrail requires IAM + CloudTrail permissions.        ║
# ║  Include this as documentation of what SHOULD be implemented.        ║
# ╚══════════════════════════════════════════════════════════════════════╝

# resource "aws_cloudtrail" "main" {
#   name           = "ostad-cloudtrail"
#   s3_bucket_name = aws_s3_bucket.app.id
#   is_multi_region_trail = true
#   enable_logging = true
#
#   event_selector {
#     read_write_type                 = "All"
#     include_management_events       = true
#   }
# }