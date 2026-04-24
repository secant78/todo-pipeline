resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/todo-${var.env}/backend"
  retention_in_days = var.env == "prod" ? 90 : 14
  tags              = var.common_tags
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/todo-${var.env}/frontend"
  retention_in_days = var.env == "prod" ? 90 : 14
  tags              = var.common_tags
}

resource "aws_sns_topic" "alerts" {
  name = "todo-${var.env}-alerts"
  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "todo-${var.env}-backend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CpuUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Backend CPU above 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.backend_service_name
  }
  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "backend_memory_high" {
  alarm_name          = "todo-${var.env}-backend-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.memory * 0.8
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.backend_service_name
  }
  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "todo-${var.env}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "backend_unhealthy" {
  alarm_name          = "todo-${var.env}-backend-no-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.backend_tg_arn_suffix
  }
  tags = var.common_tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "todo-${var.env}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "Backend CPU & Memory"
          region  = var.aws_region
          period  = 60
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", var.cluster_name, "ServiceName", var.backend_service_name],
            ["ECS/ContainerInsights", "MemoryUtilized", "ClusterName", var.cluster_name, "ServiceName", var.backend_service_name],
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "ALB Request Count & 5xx Errors"
          region  = var.aws_region
          period  = 60
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
          ]
        }
      },
      {
        type = "log"
        properties = {
          title  = "Backend Logs (last 20 lines)"
          query  = "SOURCE '/ecs/todo-${var.env}/backend' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = var.aws_region
          view   = "table"
        }
      }
    ]
  })
}
