# ------------------------------------------------------------------------------
# Service discovery module – outputs
# ------------------------------------------------------------------------------

output "namespace_id" {
  description = "ID of the private DNS namespace."
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "namespace_arn" {
  description = "ARN of the private DNS namespace."
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "service_arns" {
  description = "Map of service name to Cloud Map service ARN (for ECS service_registries)."
  value       = { for k, v in aws_service_discovery_service.main : k => v.arn }
}

output "service_ids" {
  description = "Map of service name to Cloud Map service ID."
  value       = { for k, v in aws_service_discovery_service.main : k => v.id }
}
