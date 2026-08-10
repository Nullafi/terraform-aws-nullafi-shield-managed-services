# ------------------------------------------------------------------------------
# Client-configurable: set in terraform.tfvars (e.g. region per client).
# Credentials: set aws_access_key and aws_secret_key in terraform.tfvars
# or use AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY from environment.
#
# NOTE: No ALB-related variables – this example uses service discovery only.
# ------------------------------------------------------------------------------

variable "region" {
  description = "AWS region (set per client in terraform.tfvars)."
  type        = string
}

variable "aws_access_key" {
  description = "AWS access key ID for the provider."
  type        = string
  default     = null
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret access key for the provider."
  type        = string
  default     = null
  sensitive   = true
}

variable "name_prefix" {
  description = "Prefix for resource names. Must differ from other deployments in the same account/region."
  type        = string
  default     = "managed-services"
}

variable "host_name" {
  description = "Host name for app config (e.g. NULLAFI_HTTP_CUSTOM_DOMAIN)."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "data_subnets_use_nat" {
  description = "If true, data tier subnets get a default route via NAT."
  type        = bool
  default     = true
}

variable "ecs_container_insights_enabled" {
  description = "Enable ECS Container Insights for container resource utilization metrics."
  type        = bool
  default     = true
}

variable "ecs_use_fargate_spot" {
  description = "Use Fargate Spot for ECS (with Fargate as fallback)."
  type        = bool
  default     = false
}

variable "ecs_log_retention_days" {
  description = "CloudWatch log retention in days for ECS task logs."
  type        = number
  default     = 365
}

variable "availability_zones" {
  description = "List of AZs. Leave null to use first 2 from data source."
  type        = list(string)
  default     = null
}

variable "squid_image" {
  description = "Existing ECR image URI for Squid (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-squid:latest)."
  type        = string
}

variable "shield_web_ui_image" {
  description = "Existing ECR image URI for Shield Web UI."
  type        = string
}

variable "shield_icap_image" {
  description = "Existing ECR image URI for Shield ICAP."
  type        = string
}

variable "shield_alert_image" {
  description = "Existing ECR image URI for Shield Alert."
  type        = string
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type."
  type        = string
  default     = "cache.t3.small"
}

variable "redis_engine_version" {
  description = "ElastiCache Redis engine version."
  type        = string
  default     = "7.1"
}

variable "opensearch_instance_type" {
  description = "OpenSearch instance type."
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_engine_version" {
  description = "OpenSearch engine version."
  type        = string
  default     = "OpenSearch_2.11"
}

variable "opensearch_volume_size" {
  description = "OpenSearch EBS volume size in GB."
  type        = number
  default     = 20
}

variable "create_opensearch_service_linked_role" {
  description = "Whether to create the OpenSearch service-linked role. Set to false if it already exists in the account."
  type        = bool
  default     = true
}

variable "nullafi_license_key_file" {
  description = "Path to Nullafi license key file (env value for NULLAFI_LICENSE_KEY_FILE)."
  type        = string
  default     = null
}

variable "nullafi_license_key" {
  description = "Raw Nullafi license key (env value for NULLAFI_LICENSE_KEY). Prefer SSM for secrets."
  type        = string
  default     = null
  sensitive   = true
}

variable "acme_challenge_type" {
  description = "ACME challenge type for Let's Encrypt. Only DNS-01 is supported for ECS Fargate + NLB deployments (HTTP-01 and TLS-ALPN-01 fail due to NLB health check gating — the container won't serve traffic until it has a cert, but can't get a cert without inbound traffic)."
  type        = string
  default     = "DNS-01"

  validation {
    condition     = var.acme_challenge_type == "DNS-01"
    error_message = "Only DNS-01 is supported for ECS Fargate + NLB deployments. HTTP-01 and TLS-ALPN-01 cannot work because NLB health checks prevent traffic from reaching the container before it has a certificate."
  }
}

variable "acme_dns01_provider" {
  description = "DNS provider name for DNS-01 challenge (e.g. cloudflare, route53). Only used when acme_challenge_type is DNS-01."
  type        = string
  default     = null
}

variable "acme_dns01_env" {
  description = "Environment variables for DNS-01 provider credentials. Keys and values depend on the provider (e.g. CF_API_TOKEN for Cloudflare, AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY for Route53)."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID. When set, Terraform auto-creates the A record and grants the ECS task role Route53 permissions for DNS-01 challenges."
  type        = string
  default     = null
}

variable "proxy_mitm_cert" {
  description = "Path to Squid MITM certificate (PROXY_MITM_CERT)."
  type        = string
  default     = null
}

variable "proxy_mitm_key" {
  description = "Path to Squid MITM private key (PROXY_MITM_KEY)."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxy_root_ca" {
  description = "Path to root CA certificate that issued the MITM cert. Installed as trusted CA in shield containers."
  type        = string
  default     = null
}

variable "proxy_port" {
  description = "Port the Squid proxy listens on and is exposed via the NLB (container port, target group, listener, and security group all use this)."
  type        = number
  default     = 44509
}

variable "proxy_host_name" {
  description = "Host name for the Squid proxy's own NLB (Route53 A record). Separate from host_name, which is used for Shield Web UI. Required when route53_zone_id is set."
  type        = string
  default     = null

  validation {
    condition     = var.route53_zone_id == null || var.proxy_host_name != null
    error_message = "proxy_host_name is required when route53_zone_id is set."
  }
}

variable "autoscaling_min_capacity" {
  description = "Default minimum number of tasks for scalable services (used when autoscaling_capacity does not specify per service)."
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Default maximum number of tasks for scalable services (used when autoscaling_capacity does not specify per service)."
  type        = number
  default     = 4
}

variable "autoscaling_capacity" {
  description = "Optional per-service min/max task count. Keys: squid, shield-web-ui, shield-icap, shield-alert. Omitted services use autoscaling_min_capacity and autoscaling_max_capacity."
  type = map(object({
    min = number
    max = number
  }))
  default = {}
}

variable "autoscaling_target_cpu_percent" {
  description = "Target CPU utilization percent for scaling (used by all scalable services)."
  type        = number
  default     = 70
}

variable "ssm_parameters" {
  description = "Optional SSM Parameter Store entries. Key = path (e.g. \"/nullafi/app/config\"), value = { value = string (plain or jsonencode()), sensitive = bool }. Set to {} to skip. Can pass from JSON: jsondecode(file(\"params.json\"))."
  type = map(object({
    value     = string
    sensitive = optional(bool, true)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
