# ── CloudWatch Log Groups ─────────────────────────────────────────────────────
# Logs from both containers flow here via the awslogs driver defined in the task
# definitions.  Gunicorn's --access-logfile and --error-logfile flags ensure
# every HTTP request and Python exception is captured.

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/todo-${local.env}/backend"
  retention_in_days = local.env == "prod" ? 90 : 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/todo-${local.env}/frontend"
  retention_in_days = local.env == "prod" ? 90 : 14
  tags              = local.common_tags
}

# ── SNS topic for alarm notifications ────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "todo-${local.env}-alerts"
  tags = local.common_tags
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────
# Container Insights (enabled on the cluster) feeds these metrics automatically.

resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "todo-${local.env}-backend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CpuUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Backend CPU above 80% — consider scaling up desired_count"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "backend_memory_high" {
  alarm_name          = "todo-${local.env}-backend-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  # Alert at 80% of the configured memory limit
  threshold     = local.config.memory * 0.8
  alarm_actions = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  tags = local.common_tags
}

# ALB 5xx error rate — a spike here usually means the app is crashing or
# the new deployment introduced a regression.
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "todo-${local.env}-alb-5xx"
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
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.common_tags
}

# ALB target healthy host count — if this drops to 0 the app is completely down.
resource "aws_cloudwatch_metric_alarm" "backend_unhealthy" {
  alarm_name          = "todo-${local.env}-backend-no-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }

  tags = local.common_tags
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "todo-${local.env}"

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
            ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.backend.name],
            ["ECS/ContainerInsights", "MemoryUtilized", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.backend.name],
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
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix],
          ]
        }
      },
      {
        type = "log"
        properties = {
          title  = "Backend Logs (last 20 lines)"
          query  = "SOURCE '${aws_cloudwatch_log_group.backend.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = var.aws_region
          view   = "table"
        }
      }
    ]
  })
}
