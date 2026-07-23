# ------------------------------------------------------------------------------
# managed-services – outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "backend_subnet_ids" {
  description = "IDs of the backend (private) subnets."
  value       = module.vpc.backend_subnet_ids
}

output "data_subnet_ids" {
  description = "IDs of the data (private) subnets."
  value       = module.vpc.data_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways (single NAT for cost savings)."
  value       = module.vpc.nat_gateway_ids
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = module.ecs.cluster_arn
}

output "service_discovery_namespace" {
  description = "Cloud Map private DNS namespace (e.g. nullafi.local)."
  value       = "${var.name_prefix}.local"
}

output "service_discovery_internal_dns" {
  description = "Internal DNS hostnames for each service (resolved within VPC via Cloud Map)."
  value = {
    squid         = "squid.${var.name_prefix}.local"
    shield_web_ui = "shield-web-ui.${var.name_prefix}.local"
    shield_icap   = "shield-icap.${var.name_prefix}.local"
    shield_alert  = "shield-alert.${var.name_prefix}.local"
  }
}

output "service_discovery_endpoints" {
  description = "Service discovery endpoints with ports (for client configuration)."
  value = {
    squid_proxy   = "squid.${var.name_prefix}.local:${var.proxy_port}"
    shield_web_ui = "shield-web-ui.${var.name_prefix}.local:8080"
    shield_icap   = "shield-icap.${var.name_prefix}.local:1344"
  }
}

output "container_images" {
  description = "Container image URIs in use (existing ECR images from variables)."
  value = {
    squid         = var.squid_image
    shield_web_ui = var.shield_web_ui_image
    shield_icap   = var.shield_icap_image
    shield_alert  = var.shield_alert_image
  }
}

output "efs_file_system_id" {
  description = "EFS file system ID (Shield config)."
  value       = module.efs.file_system_id
}

output "elasticache_redis_endpoint" {
  description = "ElastiCache Redis primary endpoint."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "opensearch_endpoint" {
  description = "Amazon OpenSearch domain endpoint."
  value       = aws_opensearch_domain.activity.endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "Amazon OpenSearch Dashboards endpoint."
  value       = "${aws_opensearch_domain.activity.endpoint}/_dashboards"
}

output "efs_certs_file_system_id" {
  description = "EFS file system ID for Shield Web UI ACME/Let's Encrypt certs."
  value       = module.efs_certs.file_system_id
}

output "s3_logs_backups_bucket" {
  description = "S3 bucket name for logs and backups."
  value       = aws_s3_bucket.logs_backups.id
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name for ECS service metrics."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "ssm_parameter_arns" {
  description = "ARNs of SSM parameters created via ssm_parameters (for IAM policies)."
  value       = module.parameter_store.parameter_arns
}

output "nlb_dns_name" {
  description = "NLB DNS name (Shield Web UI on ports 80/443, Squid proxy on var.proxy_port)."
  value       = aws_lb.shield_web.dns_name
}

output "nlb_zone_id" {
  description = "NLB Route53 zone ID (for alias records)."
  value       = aws_lb.shield_web.zone_id
}

output "shield_web_ui_url" {
  description = "Shield Web UI URL."
  value       = var.host_name != null ? "https://${var.host_name}/login" : "http://${aws_lb.shield_web.dns_name}/login"
}

output "dns_instructions" {
  description = "DNS setup instructions for Let's Encrypt."
  value       = var.route53_zone_id != null ? "Route53 A record auto-created for ${var.host_name}" : var.host_name != null ? "Create a DNS CNAME or alias record: ${var.host_name} → ${aws_lb.shield_web.dns_name}" : "No hostname set — HTTPS disabled. Set host_name to enable Let's Encrypt."
}

output "squid_proxy_endpoint" {
  description = "Squid proxy endpoint (configure as HTTP proxy)."
  value       = "${aws_lb.shield_web.dns_name}:${var.proxy_port}"
}
