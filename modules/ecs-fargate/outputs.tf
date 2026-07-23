# ------------------------------------------------------------------------------
# ECS Fargate module – outputs
# ------------------------------------------------------------------------------

output "cluster_id" {
  description = "ID of the ECS cluster."
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.main.arn
}

output "execution_role_arn" {
  description = "ARN of the ECS task execution role (for task definitions)."
  value       = aws_iam_role.execution.arn
}

output "execution_role_name" {
  description = "Name of the ECS task execution role."
  value       = aws_iam_role.execution.name
}

output "task_role_arn" {
  description = "ARN of the ECS task role (for task definitions)."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Name of the ECS task role."
  value       = aws_iam_role.task.name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for ECS task logs."
  value       = aws_cloudwatch_log_group.ecs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for ECS task logs."
  value       = aws_cloudwatch_log_group.ecs.arn
}
