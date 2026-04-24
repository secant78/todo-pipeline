output "sns_topic_arn"          { value = aws_sns_topic.alerts.arn }
output "backend_log_group_name"  { value = aws_cloudwatch_log_group.backend.name }
output "frontend_log_group_name" { value = aws_cloudwatch_log_group.frontend.name }
