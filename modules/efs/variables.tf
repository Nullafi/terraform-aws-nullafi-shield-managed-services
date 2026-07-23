# ------------------------------------------------------------------------------
# EFS module – variables
# ------------------------------------------------------------------------------

variable "name_prefix" {
  description = "Name/creation token for the EFS file system."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for mount targets (typically private subnets where ECS tasks run)."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for mount targets (allow NFS 2049 from ECS tasks)."
  type        = list(string)
}

variable "encrypted" {
  description = "Enable encryption at rest."
  type        = bool
  default     = true
}

variable "access_point_path" {
  description = "If set, create an access point with this root path (e.g. /shield)."
  type        = string
  default     = null
}

variable "access_point_posix_uid" {
  description = "POSIX UID for access point root (used when access_point_path is set)."
  type        = number
  default     = 1000
}

variable "access_point_posix_gid" {
  description = "POSIX GID for access point root (used when access_point_path is set)."
  type        = number
  default     = 1000
}

variable "access_point_permissions" {
  description = "POSIX permissions for access point root (e.g. 0755)."
  type        = string
  default     = "0755"
}

variable "tags" {
  description = "Tags to apply to the file system."
  type        = map(string)
  default     = {}
}
