# ECS Fargate module

Creates an ECS cluster configured for Fargate (and optional Fargate Spot), plus IAM roles and a CloudWatch log group for tasks.

**Resources:**
- ECS cluster (Fargate / FARGATE_SPOT capacity providers)
- Task execution role (ECR pull, CloudWatch Logs) – use in task definitions
- Task role (for application permissions; attach policies via `task_role_policy_arns`)
- CloudWatch log group `/ecs/<name_prefix>`

Use this module together with the [VPC module](../vpc/README.md). Create task definitions and services elsewhere (or in a separate module) and reference this cluster and the execution/task role ARNs.

## Usage

```hcl
module "ecs" {
  source = "Nullafi/nullafi-shield-managed-services/aws//modules/ecs-fargate"

  name_prefix               = "prod-app"
  container_insights_enabled = false
  use_fargate_spot          = false
  log_retention_days        = 30
  # task_role_policy_arns   = { "s3" = aws_iam_policy.s3.arn }

  tags = { Environment = "prod" }
}
```

In your task definition (outside this module), set:
- `execution_role_arn` = `module.ecs.execution_role_arn`
- `task_role_arn`       = `module.ecs.task_role_arn`
- `log_configuration` to use `module.ecs.log_group_name` (e.g. `logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = module.ecs.log_group_name } }`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.33.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution_ecs_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.execution_custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.execution_ecr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_container_insights_enabled"></a> [container\_insights\_enabled](#input\_container\_insights\_enabled) | Enable Container Insights for the cluster. | `bool` | `false` | no |
| <a name="input_execution_role_policy_arns"></a> [execution\_role\_policy\_arns](#input\_execution\_role\_policy\_arns) | Map of label -> IAM policy ARN to attach to the ECS execution role (e.g. SSM Parameter Store read). Used for pulling secrets into task definitions. | `map(string)` | `{}` | no |
| <a name="input_extra_capacity_providers"></a> [extra\_capacity\_providers](#input\_extra\_capacity\_providers) | Additional capacity provider names to attach to the cluster (e.g. EC2 provider for Elasticsearch). | `list(string)` | `[]` | no |
| <a name="input_log_group_kms_key_id"></a> [log\_group\_kms\_key\_id](#input\_log\_group\_kms\_key\_id) | KMS key ARN for encrypting the CloudWatch log group. Null uses default encryption. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log group retention in days for ECS task logs (Checkov requires >= 365). | `number` | `365` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name prefix for the ECS cluster and related resources. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_task_role_policy_arns"></a> [task\_role\_policy\_arns](#input\_task\_role\_policy\_arns) | Map of label -> IAM policy ARN to attach to the ECS task role (e.g. { "s3-logs" = aws\_iam\_policy.s3.arn }). Keys must be known at plan time. | `map(string)` | `{}` | no |
| <a name="input_use_fargate_spot"></a> [use\_fargate\_spot](#input\_use\_fargate\_spot) | Use FARGATE\_SPOT as default capacity provider (with FARGATE as fallback). | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the ECS cluster. |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | ID of the ECS cluster. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster. |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | ARN of the ECS task execution role (for task definitions). |
| <a name="output_execution_role_name"></a> [execution\_role\_name](#output\_execution\_role\_name) | Name of the ECS task execution role. |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | ARN of the CloudWatch log group for ECS task logs. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the CloudWatch log group for ECS task logs. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ARN of the ECS task role (for task definitions). |
| <a name="output_task_role_name"></a> [task\_role\_name](#output\_task\_role\_name) | Name of the ECS task role. |
<!-- END_TF_DOCS -->
