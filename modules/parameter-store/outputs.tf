# ------------------------------------------------------------------------------
# Parameter Store module – outputs
# ------------------------------------------------------------------------------

output "parameter_arns" {
  description = "Map of parameter path → ARN."
  value       = { for k, p in aws_ssm_parameter.main : k => p.arn }
}

output "parameter_names" {
  description = "Map of parameter path → name (same as path)."
  value       = { for k, p in aws_ssm_parameter.main : k => p.name }
}

output "parameter_names_list" {
  description = "List of parameter names (paths) for IAM policy etc."
  value       = [for p in aws_ssm_parameter.main : p.name]
}
