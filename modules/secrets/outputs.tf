# ------------------------------------------------------------------------------
# Secrets Manager module – outputs
# ------------------------------------------------------------------------------

output "secret_arns" {
  description = "Map of secret key → ARN (for IAM policies and ECS task definition valueFrom)."
  value       = { for k, s in aws_secretsmanager_secret.main : k => s.arn }
}

output "secret_names" {
  description = "Map of secret key → full secret name in AWS."
  value       = { for k, s in aws_secretsmanager_secret.main : k => s.name }
}

output "secret_arns_list" {
  description = "List of secret ARNs (for IAM policy Resource)."
  value       = [for s in aws_secretsmanager_secret.main : s.arn]
}
