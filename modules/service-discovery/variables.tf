# ------------------------------------------------------------------------------
# Service discovery module – variables
# ------------------------------------------------------------------------------

variable "namespace_name" {
  description = "Name of the private DNS namespace (e.g. nullafi.local)."
  type        = string
}

variable "namespace_description" {
  description = "Description for the namespace."
  type        = string
  default     = "Private DNS namespace for service discovery"
}

variable "vpc_id" {
  description = "VPC ID for the private DNS namespace."
  type        = string
}

variable "service_names" {
  description = "List of service names to create in the namespace (e.g. squid, shield-web)."
  type        = list(string)
  default     = []
}

variable "dns_ttl" {
  description = "TTL for DNS records in the namespace."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply to namespace and services."
  type        = map(string)
  default     = {}
}
