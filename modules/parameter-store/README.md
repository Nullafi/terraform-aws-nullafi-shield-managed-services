# parameter-store module

Creates AWS SSM Parameter Store parameters from a map. Supports passing JSON (as a string) and choosing **sensitive** (SecureString) or non-sensitive (String) per parameter.

## Usage

```hcl
module "parameter_store" {
  source = "Nullafi/nullafi-shield-managed-services/aws//modules/parameter-store"

  parameters = {
    "/myapp/config" = {
      value     = jsonencode({ log_level = "info", timeout = 30 })
      sensitive = false
    }
    "/myapp/db-password" = {
      value     = "secret123"
      sensitive = true
    }
  }
  tags = { Environment = "prod" }
}
```

From an example you can pass a variable (e.g. from tfvars or from JSON):

```hcl
# In variables.tf
variable "ssm_parameters" {
  type = map(object({
    value     = string
    sensitive = optional(bool, true)
  }))
  default = {}
}

# In main.tf
module "parameter_store" {
  source     = "Nullafi/nullafi-shield-managed-services/aws//modules/parameter-store"
  parameters = var.ssm_parameters
  tags       = var.tags
}
```

Then in `terraform.tfvars` or via `-var-file` / `jsondecode(file("params.json"))`:

- **value**: Any string; use `jsonencode({ ... })` in Terraform for JSON, or a literal JSON string.
- **sensitive**: `true` → stored as **SecureString** (KMS-encrypted); `false` → **String** (plain).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_parameter.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | Map of SSM parameter path → { value = string, sensitive = bool }. value can be JSON; sensitive true uses SecureString. | <pre>map(object({<br/>    value     = string<br/>    sensitive = optional(bool, true)<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to each parameter. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_parameter_arns"></a> [parameter\_arns](#output\_parameter\_arns) | Map of parameter path → ARN. |
| <a name="output_parameter_names"></a> [parameter\_names](#output\_parameter\_names) | Map of parameter path → name (same as path). |
| <a name="output_parameter_names_list"></a> [parameter\_names\_list](#output\_parameter\_names\_list) | List of parameter names (paths) for IAM policy etc. |
<!-- END_TF_DOCS -->
