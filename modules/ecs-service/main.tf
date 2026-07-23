# ------------------------------------------------------------------------------
# ECS service module – task definition + ECS service, optional ALB/NLB + Cloud Map
# ------------------------------------------------------------------------------

locals {
  load_balancers = concat(
    var.load_balancer != null ? [var.load_balancer] : [],
    var.load_balancers
  )
}

resource "aws_ecs_task_definition" "main" {
  family                   = var.family
  network_mode             = "awsvpc"
  requires_compatibilities = var.requires_compatibilities
  cpu                      = var.cpu
  memory                   = var.memory

  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn

  container_definitions = var.container_definitions

  dynamic "volume" {
    for_each = var.volumes
    content {
      name      = volume.value.name
      host_path = volume.value.host_path

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id     = efs_volume_configuration.value.file_system_id
          root_directory     = lookup(efs_volume_configuration.value, "root_directory", "/")
          transit_encryption = lookup(efs_volume_configuration.value, "transit_encryption", "ENABLED")

          dynamic "authorization_config" {
            for_each = lookup(efs_volume_configuration.value, "access_point_id", null) != null ? [1] : []
            content {
              access_point_id = efs_volume_configuration.value.access_point_id
              iam             = "ENABLED"
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_ecs_service" "main" {
  name                   = coalesce(var.service_name, var.family)
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.main.arn
  desired_count          = var.desired_count
  enable_execute_command = var.enable_execute_command
  force_new_deployment   = var.force_new_deployment

  launch_type = var.capacity_provider_strategy != null ? null : "FARGATE"

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy != null ? var.capacity_provider_strategy : []
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = lookup(capacity_provider_strategy.value, "weight", 1)
      base              = lookup(capacity_provider_strategy.value, "base", 0)
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = local.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.service_registry_arn != null ? [1] : []
    content {
      registry_arn = var.service_registry_arn
    }
  }

  dynamic "deployment_circuit_breaker" {
    for_each = var.enable_deployment_circuit_breaker ? [1] : []
    content {
      enable   = true
      rollback = true
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Application Auto Scaling (optional)
# ------------------------------------------------------------------------------
resource "aws_appautoscaling_target" "main" {
  count = var.min_capacity != null && var.max_capacity != null ? 1 : 0

  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${split("/", var.cluster_arn)[1]}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count = var.min_capacity != null && var.max_capacity != null ? 1 : 0

  name               = "${aws_ecs_service.main.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main[0].resource_id
  scalable_dimension = aws_appautoscaling_target.main[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.main[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_target_cpu_percent
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
