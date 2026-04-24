output "sns_topic_arn"          { value = aws_sns_topic.alerts.arn }
output "backend_log_group_name"  { value = aws_cloudwatch_log_group.backend.name }
output "frontend_log_group_name" { value = aws_cloudwatch_log_group.frontend.name }

# Alarms CodeDeploy monitors during a deployment — fires = auto-rollback
output "rollback_alarm_names" {
  value = [
    aws_cloudwatch_metric_alarm.alb_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.backend_unhealthy.alarm_name,
  ]
}
