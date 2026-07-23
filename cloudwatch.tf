# ------------------------------------------------------------------------------
# CloudWatch alarms and dashboard for service health (no ALB widgets)
# ------------------------------------------------------------------------------

locals {
  cluster_name = module.ecs.cluster_name
  alarm_services = {
    squid         = module.ecs_squid.service_name
    shield_web_ui = module.ecs_shield_web.service_name
    shield_icap   = module.ecs_shield_icap.service_name
    shield_alert  = module.ecs_shield_alert.service_name
  }
  service_order = ["squid", "shield_web_ui", "shield_icap", "shield_alert"]
}

# CPU utilization high
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  for_each = local.alarm_services

  alarm_name          = "${var.name_prefix}-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    ClusterName = local.cluster_name
    ServiceName = each.value
  }

  alarm_description = "ECS service ${each.key} CPU utilization > 80%"
  tags              = merge(var.tags, { Service = each.key })
}

# Memory utilization high
resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  for_each = local.alarm_services

  alarm_name          = "${var.name_prefix}-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    ClusterName = local.cluster_name
    ServiceName = each.value
  }

  alarm_description = "ECS service ${each.key} memory utilization > 80%"
  tags              = merge(var.tags, { Service = each.key })
}

# Service failure: no running tasks
resource "aws_cloudwatch_metric_alarm" "ecs_no_tasks" {
  for_each = local.alarm_services

  alarm_name          = "${var.name_prefix}-${each.key}-no-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1

  dimensions = {
    ClusterName = local.cluster_name
    ServiceName = each.value
  }

  alarm_description = "ECS service ${each.key} has no running tasks"
  tags              = merge(var.tags, { Service = each.key })
}

# Log metric filters – count error/fatal log entries across all services
# Shield services (JSON: {"level":"error"} or {"level":"fatal"})
resource "aws_cloudwatch_log_metric_filter" "shield_errors" {
  name           = "${var.name_prefix}-shield-errors"
  log_group_name = module.ecs.log_group_name
  pattern        = "{ $.level = \"error\" || $.level = \"fatal\" }"

  metric_transformation {
    name          = "shield-error-count"
    namespace     = "${var.name_prefix}/Application"
    value         = "1"
    default_value = "0"
  }
}

# Squid and other plain-text errors
resource "aws_cloudwatch_log_metric_filter" "text_errors" {
  name           = "${var.name_prefix}-text-errors"
  log_group_name = module.ecs.log_group_name
  pattern        = "?\"ERROR:\" ?\"ERROR \""

  metric_transformation {
    name          = "text-error-count"
    namespace     = "${var.name_prefix}/Application"
    value         = "1"
    default_value = "0"
  }
}

# Dashboard – ECS service metrics only (no ALB widgets)
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.name_prefix

  dashboard_body = jsonencode({
    widgets = concat(
      # --- Row 0: Task counts + error log counts ---
      [{
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS - Running Tasks (all services)"
          region = var.region
          period = 60
          metrics = [
            for name in local.service_order :
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", local.cluster_name, "ServiceName", local.alarm_services[name], { stat = "Average", label = name }]
          ]
        }
        },
        {
          type   = "metric"
          x      = 12
          y      = 0
          width  = 12
          height = 6
          properties = {
            title  = "Application - Error Count (from logs)"
            region = var.region
            stat   = "Sum"
            period = 300
            metrics = [
              ["${var.name_prefix}/Application", "shield-error-count", { label = "Shield (error/fatal)", color = "#d13212" }],
              ["${var.name_prefix}/Application", "text-error-count", { label = "Squid/Other", color = "#1f77b4" }]
            ]
          }
      }],
      # --- Rows 1–2: CPU utilization per service ---
      [for idx, name in local.service_order : {
        type   = "metric"
        x      = (idx % 3) * 8
        y      = 6 + floor(idx / 3) * 6
        width  = 8
        height = 6
        properties = {
          title  = "ECS ${name} - CPU"
          region = var.region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", local.cluster_name, "ServiceName", local.alarm_services[name]]
          ]
        }
      }],
      # --- Rows 3–4: Memory utilization per service ---
      [for idx, name in local.service_order : {
        type   = "metric"
        x      = (idx % 3) * 8
        y      = 18 + floor(idx / 3) * 6
        width  = 8
        height = 6
        properties = {
          title  = "ECS ${name} - Memory"
          region = var.region
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", local.cluster_name, "ServiceName", local.alarm_services[name]]
          ]
        }
      }],
      # --- Rows 5–6: Running task count per service ---
      [for idx, name in local.service_order : {
        type   = "metric"
        x      = (idx % 3) * 8
        y      = 30 + floor(idx / 3) * 6
        width  = 8
        height = 6
        properties = {
          title  = "ECS ${name} - Running tasks"
          region = var.region
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", local.cluster_name, "ServiceName", local.alarm_services[name]]
          ]
        }
      }]
    )
  })
}
