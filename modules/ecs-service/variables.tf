# ------------------------------------------------------------------------------
# ECS service module – variables
# ------------------------------------------------------------------------------

variable "family" {
  description = "Task definition family name."
  type        = string
}

variable "service_name" {
  description = "ECS service name (defaults to family if not set)."
  type        = string
  default     = null
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster."
  type        = string
}

variable "cpu" {
  description = "Task CPU units (256, 512, 1024, 2048, 4096)."
  type        = number
}

variable "memory" {
  description = "Task memory in MiB (512–30720 in steps)."
  type        = number
}

variable "container_definitions" {
  description = "JSON string of container definitions (e.g. jsonencode([...]))."
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of the ECS task execution role (pull images, logs)."
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role (optional, for app permissions)."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs for the service (private or public)."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for the service tasks."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign public IP to tasks (typically false in private subnets)."
  type        = bool
  default     = false
}

variable "desired_count" {
  description = "Number of tasks to run (initial; use autoscaling min/max for scaling)."
  type        = number
  default     = 1
}

variable "enable_deployment_circuit_breaker" {
  description = "Enable ECS deployment circuit breaker (rollback on failure)."
  type        = bool
  default     = true
}

variable "enable_execute_command" {
  description = "Enable ECS Exec (run commands in running containers via aws ecs execute-command)."
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of tasks (for Application Auto Scaling). Set with max_capacity to enable autoscaling."
  type        = number
  default     = null
}

variable "max_capacity" {
  description = "Maximum number of tasks (for Application Auto Scaling). Set with min_capacity to enable autoscaling."
  type        = number
  default     = null
}

variable "autoscaling_target_cpu_percent" {
  description = "Target CPU utilization percent for scaling (e.g. 70). Used when min_capacity and max_capacity are set."
  type        = number
  default     = 70
}

variable "load_balancer" {
  description = "Optional load balancer attachment: target_group_arn, container_name, container_port."
  type = object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  })
  default = null
}

variable "load_balancers" {
  description = "List of load balancer attachments (for services needing multiple target groups, e.g. HTTP + HTTPS)."
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
  default = []
}

variable "service_registry_arn" {
  description = "Optional Cloud Map service registry ARN for service discovery."
  type        = string
  default     = null
}

variable "volumes" {
  description = "Optional list of volumes (e.g. EFS or host bind mounts). Each may have efs_volume_configuration or host_path (for EC2 bind mounts)."
  type = list(object({
    name      = string
    host_path = optional(string)
    efs_volume_configuration = optional(object({
      file_system_id     = string
      root_directory     = optional(string, "/")
      transit_encryption = optional(string, "ENABLED")
      access_point_id    = optional(string)
    }))
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to the task definition and service."
  type        = map(string)
  default     = {}
}

variable "requires_compatibilities" {
  description = "Task definition compatibility (FARGATE or EC2). Default FARGATE."
  type        = list(string)
  default     = ["FARGATE"]
}

variable "capacity_provider_strategy" {
  description = "Optional capacity provider strategy (use instead of launch_type when set, e.g. for EC2)."
  type = list(object({
    capacity_provider = string
    weight            = optional(number, 1)
    base              = optional(number, 0)
  }))
  default = null
}

variable "force_new_deployment" {
  description = "Force a new deployment of the service (e.g. when switching to capacity_provider_strategy)."
  type        = bool
  default     = false
}
