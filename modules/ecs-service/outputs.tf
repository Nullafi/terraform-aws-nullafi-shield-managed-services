# ------------------------------------------------------------------------------
# ECS service module – outputs
# ------------------------------------------------------------------------------

output "task_definition_arn" {
  description = "Full ARN of the task definition (including revision)."
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  description = "Task definition family name."
  value       = aws_ecs_task_definition.main.family
}

output "service_id" {
  description = "ID of the ECS service."
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.main.name
}

output "service_arn" {
  description = "ARN of the ECS service."
  value       = aws_ecs_service.main.arn
}
