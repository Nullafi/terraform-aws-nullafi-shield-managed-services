# ------------------------------------------------------------------------------
# VPC module – variables
# ------------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for resource names (e.g. env or project name)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZ names (length 2 for 2 public, 2 backend, 2 data subnets)."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost-saving) or one per AZ (HA)."
  type        = bool
  default     = true
}

variable "data_subnets_use_nat" {
  description = "If true, data tier subnets get a default route via NAT (e.g. for updates). Set false for strict data-tier isolation."
  type        = bool
  default     = true
}

variable "public_inbound_ports" {
  description = "TCP ports the public tier accepts from the internet (e.g. ALB listeners: 80, 443, 44509 for Squid)."
  type        = list(number)
  default     = [80, 443, 44509]
}

variable "backend_app_ports" {
  description = "TCP ports the backend accepts from the public tier (e.g. 3128 Squid, 80/443 Shield Web, 1344 Shield ICAP)."
  type        = list(number)
  default     = [80, 443, 3000, 4000, 5000, 8080, 8443, 9000, 3128, 1344]
}

variable "data_ports" {
  description = "TCP ports the data tier accepts from the backend (e.g. 6379 Redis, 9200 Elasticsearch)."
  type        = list(number)
  default     = [1433, 27017, 3306, 5432, 5433, 5984, 6379, 7687, 8086, 9042, 9092, 9200, 9300, 11211]
}

variable "enable_nacls" {
  description = "Enable tiered Network ACLs (public, backend, data). Set false to use the VPC default NACL."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention in days for VPC Flow Logs CloudWatch log group (Checkov requires >= 365)."
  type        = number
  default     = 365
}

variable "flow_logs_kms_key_id" {
  description = "KMS key ARN for encrypting the VPC Flow Logs CloudWatch log group. Null uses default encryption."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
