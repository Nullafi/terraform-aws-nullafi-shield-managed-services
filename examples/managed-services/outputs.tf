# ------------------------------------------------------------------------------
# managed-services – outputs (pass-through from the module)
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.shield.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.shield.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.shield.public_subnet_ids
}

output "backend_subnet_ids" {
  description = "IDs of the backend (private) subnets."
  value       = module.shield.backend_subnet_ids
}

output "data_subnet_ids" {
  description = "IDs of the data (private) subnets."
  value       = module.shield.data_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways (single NAT for cost savings)."
  value       = module.shield.nat_gateway_ids
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.shield.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = module.shield.ecs_cluster_arn
}

output "service_discovery_namespace" {
  description = "Cloud Map private DNS namespace (e.g. nullafi.local)."
  value       = module.shield.service_discovery_namespace
}

output "service_discovery_internal_dns" {
  description = "Internal DNS hostnames for each service (resolved within VPC via Cloud Map)."
  value       = module.shield.service_discovery_internal_dns
}

output "service_discovery_endpoints" {
  description = "Service discovery endpoints with ports (for client configuration)."
  value       = module.shield.service_discovery_endpoints
}

output "container_images" {
  description = "Container image URIs in use (existing ECR images from variables)."
  value       = module.shield.container_images
}

output "efs_file_system_id" {
  description = "EFS file system ID (Shield config)."
  value       = module.shield.efs_file_system_id
}

output "elasticache_redis_endpoint" {
  description = "ElastiCache Redis primary endpoint."
  value       = module.shield.elasticache_redis_endpoint
}

output "opensearch_endpoint" {
  description = "Amazon OpenSearch domain endpoint."
  value       = module.shield.opensearch_endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "Amazon OpenSearch Dashboards endpoint."
  value       = module.shield.opensearch_dashboard_endpoint
}

output "efs_certs_file_system_id" {
  description = "EFS file system ID for Shield Web UI ACME/Let's Encrypt certs."
  value       = module.shield.efs_certs_file_system_id
}

output "s3_logs_backups_bucket" {
  description = "S3 bucket name for logs and backups."
  value       = module.shield.s3_logs_backups_bucket
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name for ECS service metrics."
  value       = module.shield.cloudwatch_dashboard_name
}

output "ssm_parameter_arns" {
  description = "ARNs of SSM parameters created via ssm_parameters (for IAM policies)."
  value       = module.shield.ssm_parameter_arns
}

output "nlb_dns_name" {
  description = "Shield Web UI NLB DNS name (ports 80/443)."
  value       = module.shield.nlb_dns_name
}

output "nlb_zone_id" {
  description = "Shield Web UI NLB Route53 zone ID (for alias records)."
  value       = module.shield.nlb_zone_id
}

output "squid_nlb_dns_name" {
  description = "Squid proxy NLB DNS name (var.proxy_port)."
  value       = module.shield.squid_nlb_dns_name
}

output "squid_nlb_zone_id" {
  description = "Squid proxy NLB Route53 zone ID (for alias records)."
  value       = module.shield.squid_nlb_zone_id
}

output "squid_eips" {
  description = "Elastic IP addresses assigned to the Squid proxy NLB (one per public subnet)."
  value       = module.shield.squid_eips
}

output "shield_web_ui_url" {
  description = "Shield Web UI URL."
  value       = module.shield.shield_web_ui_url
}

output "dns_instructions" {
  description = "DNS setup instructions for Let's Encrypt."
  value       = module.shield.dns_instructions
}

output "squid_proxy_endpoint" {
  description = "Squid proxy endpoint (configure as HTTP proxy)."
  value       = module.shield.squid_proxy_endpoint
}
