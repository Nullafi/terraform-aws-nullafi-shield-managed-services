# ------------------------------------------------------------------------------
# ECS Fargate module – cluster and default capacity for Fargate tasks
# ------------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = var.name_prefix

  setting {
    name  = "containerInsights"
    value = var.container_insights_enabled ? "enabled" : "disabled"
  }

  tags = merge(var.tags, {
    Name = var.name_prefix
  })
}

locals {
  default_capacity_strategy = var.use_fargate_spot ? [
    { capacity_provider = "FARGATE_SPOT", weight = 70, base = 0 },
    { capacity_provider = "FARGATE", weight = 30, base = 1 }
    ] : [
    { capacity_provider = "FARGATE", weight = 100, base = 0 }
  ]
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = concat(
    var.use_fargate_spot ? ["FARGATE", "FARGATE_SPOT"] : ["FARGATE"],
    var.extra_capacity_providers
  )

  dynamic "default_capacity_provider_strategy" {
    for_each = local.default_capacity_strategy
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_group_kms_key_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-logs"
  })
}
