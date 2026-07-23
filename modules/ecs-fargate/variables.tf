# ------------------------------------------------------------------------------
# ECS Fargate module – variables
# ------------------------------------------------------------------------------

variable "name_prefix" {
  description = "Name prefix for the ECS cluster and related resources."
  type        = string
}

variable "container_insights_enabled" {
  description = "Enable Container Insights for the cluster."
  type        = bool
  default     = false
}

variable "use_fargate_spot" {
  description = "Use FARGATE_SPOT as default capacity provider (with FARGATE as fallback)."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days for ECS task logs (Checkov requires >= 365)."
  type        = number
  default     = 365
}

variable "log_group_kms_key_id" {
  description = "KMS key ARN for encrypting the CloudWatch log group. Null uses default encryption."
  type        = string
  default     = null
}

variable "execution_role_policy_arns" {
  description = "Map of label -> IAM policy ARN to attach to the ECS execution role (e.g. SSM Parameter Store read). Used for pulling secrets into task definitions."
  type        = map(string)
  default     = {}
}

variable "task_role_policy_arns" {
  description = "Map of label -> IAM policy ARN to attach to the ECS task role (e.g. { \"s3-logs\" = aws_iam_policy.s3.arn }). Keys must be known at plan time."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "extra_capacity_providers" {
  description = "Additional capacity provider names to attach to the cluster (e.g. EC2 provider for Elasticsearch)."
  type        = list(string)
  default     = []
}
