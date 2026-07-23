# ------------------------------------------------------------------------------
# Secrets Manager module – variables
# ------------------------------------------------------------------------------
#
# Pass a map of secrets. Each key is a short name (e.g. "license-key"); the
# full secret name in AWS will be "{name_prefix}/{key}". Each value:
#   - value                    = optional string; if set, creates a secret version (plain string).
#   - recovery_window_in_days  = optional number; 0 = immediate delete, 7–30 = days to retain (default 30).
#
# Example:
#   secrets = {
#     "license-key" = { value = "secret123", recovery_window_in_days = 30 }
#     "api-key"     = { value = null }  # secret created, no version; set value later in console/CLI
#   }
# ------------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for secret names in AWS (e.g. app or env). Full name = \"{name_prefix}/{key}\"."
  type        = string
}

variable "secret_names" {
  description = "Set of secret key names to create. Use this instead of secrets when values are sensitive."
  type        = set(string)
  default     = []
}

variable "secrets" {
  description = "Map of secret key → { value = optional(string), recovery_window_in_days = optional(number) }. Key becomes name suffix; value = null creates secret only (no version)."
  type = map(object({
    value                   = optional(string)
    recovery_window_in_days = optional(number, 30)
  }))
  default   = {}
  sensitive = true
}

variable "kms_key_id" {
  description = "KMS key ARN for encrypting secrets. Null uses the AWS-managed key."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to each secret."
  type        = map(string)
  default     = {}
}
