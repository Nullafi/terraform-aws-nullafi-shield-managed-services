# ECS service module

Creates an ECS Fargate task definition and service, with optional ALB/NLB target group attachment(s), Cloud Map service registry, and CPU-based autoscaling. Use alongside the [ecs-fargate module](../ecs-fargate/README.md) (cluster + IAM roles) and, optionally, the [service-discovery module](../service-discovery/README.md).

## Usage

```hcl
module "ecs_service" {
  source = "Nullafi/nullafi-shield-managed-services/aws//modules/ecs-service"

  family              = "prod-app"
  cluster_arn         = module.ecs.cluster_arn
  cpu                 = 256
  memory              = 512
  execution_role_arn  = module.ecs.execution_role_arn
  task_role_arn       = module.ecs.task_role_arn
  subnet_ids          = module.vpc.backend_subnet_ids
  security_group_ids  = [aws_security_group.backend.id]
  desired_count       = 1
  min_capacity        = 1
  max_capacity        = 4

  container_definitions = jsonencode([{
    name          = "app"
    image         = "123456789012.dkr.ecr.us-east-1.amazonaws.com/app:latest"
    essential     = true
    portMappings  = [{ containerPort = 8080, protocol = "tcp" }]
  }])

  tags = { Environment = "prod" }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_appautoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_ecs_service.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Assign public IP to tasks (typically false in private subnets). | `bool` | `false` | no |
| <a name="input_autoscaling_target_cpu_percent"></a> [autoscaling\_target\_cpu\_percent](#input\_autoscaling\_target\_cpu\_percent) | Target CPU utilization percent for scaling (e.g. 70). Used when min\_capacity and max\_capacity are set. | `number` | `70` | no |
| <a name="input_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#input\_capacity\_provider\_strategy) | Optional capacity provider strategy (use instead of launch\_type when set, e.g. for EC2). | <pre>list(object({<br/>    capacity_provider = string<br/>    weight            = optional(number, 1)<br/>    base              = optional(number, 0)<br/>  }))</pre> | `null` | no |
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | ARN of the ECS cluster. | `string` | n/a | yes |
| <a name="input_container_definitions"></a> [container\_definitions](#input\_container\_definitions) | JSON string of container definitions (e.g. jsonencode([...])). | `string` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Task CPU units (256, 512, 1024, 2048, 4096). | `number` | n/a | yes |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of tasks to run (initial; use autoscaling min/max for scaling). | `number` | `1` | no |
| <a name="input_enable_deployment_circuit_breaker"></a> [enable\_deployment\_circuit\_breaker](#input\_enable\_deployment\_circuit\_breaker) | Enable ECS deployment circuit breaker (rollback on failure). | `bool` | `true` | no |
| <a name="input_enable_execute_command"></a> [enable\_execute\_command](#input\_enable\_execute\_command) | Enable ECS Exec (run commands in running containers via aws ecs execute-command). | `bool` | `true` | no |
| <a name="input_execution_role_arn"></a> [execution\_role\_arn](#input\_execution\_role\_arn) | ARN of the ECS task execution role (pull images, logs). | `string` | n/a | yes |
| <a name="input_family"></a> [family](#input\_family) | Task definition family name. | `string` | n/a | yes |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | Force a new deployment of the service (e.g. when switching to capacity\_provider\_strategy). | `bool` | `false` | no |
| <a name="input_load_balancer"></a> [load\_balancer](#input\_load\_balancer) | Optional load balancer attachment: target\_group\_arn, container\_name, container\_port. | <pre>object({<br/>    target_group_arn = string<br/>    container_name   = string<br/>    container_port   = number<br/>  })</pre> | `null` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | List of load balancer attachments (for services needing multiple target groups, e.g. HTTP + HTTPS). | <pre>list(object({<br/>    target_group_arn = string<br/>    container_name   = string<br/>    container_port   = number<br/>  }))</pre> | `[]` | no |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Maximum number of tasks (for Application Auto Scaling). Set with min\_capacity to enable autoscaling. | `number` | `null` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Task memory in MiB (512–30720 in steps). | `number` | n/a | yes |
| <a name="input_min_capacity"></a> [min\_capacity](#input\_min\_capacity) | Minimum number of tasks (for Application Auto Scaling). Set with max\_capacity to enable autoscaling. | `number` | `null` | no |
| <a name="input_requires_compatibilities"></a> [requires\_compatibilities](#input\_requires\_compatibilities) | Task definition compatibility (FARGATE or EC2). Default FARGATE. | `list(string)` | <pre>[<br/>  "FARGATE"<br/>]</pre> | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security group IDs for the service tasks. | `list(string)` | n/a | yes |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | ECS service name (defaults to family if not set). | `string` | `null` | no |
| <a name="input_service_registry_arn"></a> [service\_registry\_arn](#input\_service\_registry\_arn) | Optional Cloud Map service registry ARN for service discovery. | `string` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the service (private or public). | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the task definition and service. | `map(string)` | `{}` | no |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | ARN of the ECS task role (optional, for app permissions). | `string` | `null` | no |
| <a name="input_volumes"></a> [volumes](#input\_volumes) | Optional list of volumes (e.g. EFS or host bind mounts). Each may have efs\_volume\_configuration or host\_path (for EC2 bind mounts). | <pre>list(object({<br/>    name      = string<br/>    host_path = optional(string)<br/>    efs_volume_configuration = optional(object({<br/>      file_system_id     = string<br/>      root_directory     = optional(string, "/")<br/>      transit_encryption = optional(string, "ENABLED")<br/>      access_point_id    = optional(string)<br/>    }))<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_service_arn"></a> [service\_arn](#output\_service\_arn) | ARN of the ECS service. |
| <a name="output_service_id"></a> [service\_id](#output\_service\_id) | ID of the ECS service. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the ECS service. |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | Full ARN of the task definition (including revision). |
| <a name="output_task_definition_family"></a> [task\_definition\_family](#output\_task\_definition\_family) | Task definition family name. |
<!-- END_TF_DOCS -->
