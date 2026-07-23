# ------------------------------------------------------------------------------
# EFS module – outputs
# ------------------------------------------------------------------------------

output "file_system_id" {
  description = "ID of the EFS file system."
  value       = aws_efs_file_system.main.id
}

output "file_system_arn" {
  description = "ARN of the EFS file system."
  value       = aws_efs_file_system.main.arn
}

output "file_system_dns_name" {
  description = "DNS name of the EFS file system (for mount)."
  value       = aws_efs_file_system.main.dns_name
}

output "access_point_id" {
  description = "ID of the access point (if created)."
  value       = try(aws_efs_access_point.main[0].id, null)
}

output "access_point_arn" {
  description = "ARN of the access point (if created)."
  value       = try(aws_efs_access_point.main[0].arn, null)
}
