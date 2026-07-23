# ------------------------------------------------------------------------------
# Parameter Store module – variables
# ------------------------------------------------------------------------------
#
# Pass a map of parameters from the example. Each key is the SSM parameter path
# (e.g. "/myapp/config"). Each value is an object:
#   - value     = string (plain or JSON; stored as-is)
#   - sensitive = bool   (true → SecureString, false → String; default true)
#
# Example in tfvars or in the module call:
#   parameters = {
#     "/nullafi-ha/app/settings" = {
#       value     = jsonencode({ "log_level" = "info", "timeout" = 30 })
#       sensitive = false
#     }
#     "/nullafi-ha/app/db-password" = {
#       value     = "secret123"
#       sensitive = true
#     }
#   }
# ------------------------------------------------------------------------------

variable "parameters" {
  description = "Map of SSM parameter path → { value = string, sensitive = bool }. value can be JSON; sensitive true uses SecureString."
  type = map(object({
    value     = string
    sensitive = optional(bool, true)
  }))
}

variable "tags" {
  description = "Tags to apply to each parameter."
  type        = map(string)
  default     = {}
}
