# ╔══════════════════════════════════════════════════════════════════════╗
# ║  IMPORTANT: CloudWatch Alarms require IAM permissions to create.     ║
# ║  Since you do NOT have IAM/CloudWatch access, these resources are    ║
# ║  COMMENTED OUT. Include them in your submission as "Required but     ║
# ║  blocked by permission constraints."                                 ║
# ╚══════════════════════════════════════════════════════════════════════╝

# resource "aws_cloudwatch_log_group" "app" {
#   name              = "/aws/ec2/ostad-app"
#   retention_in_days = 7
# }
#
# resource "aws_cloudwatch_metric_alarm" "high_cpu" {
#   alarm_name          = "ostad-high-cpu"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = 120
#   statistic           = "Average"
#   threshold           = 70
#   alarm_description   = "Alarm when CPU exceeds 70%"
#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.app.name
#   }
# }
#
# resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
#   alarm_name          = "ostad-unhealthy-hosts"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "UnHealthyHostCount"
#   namespace           = "AWS/ApplicationELB"
#   period              = 60
#   statistic           = "Average"
#   threshold           = 0
#   dimensions = {
#     TargetGroup  = aws_lb_target_group.app.arn_suffix
#     LoadBalancer = aws_lb.main.arn_suffix
#   }
# }