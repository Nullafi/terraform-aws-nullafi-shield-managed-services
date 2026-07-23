# secrets module

Creates AWS Secrets Manager secrets from a map. Each entry can have an optional initial value; if omitted, the secret is created without a version (you can set it later in the console or CLI). Useful for ECS task definitions (reference secret ARN in `secrets` / `valueFrom`) and other workloads that need `secretsmanager:GetSecretValue`.

## Usage

```hcl
module "secrets" {
  source = "Nullafi/nullafi-shield-managed-services/aws//modules/secrets"

  name_prefix = "myapp"
  secrets = {
    "license-key" = { value = "secret123", recovery_window_in_days = 30 }
    "api-key"     = { value = null }  # create secret only; set value later
  }
  tags = { Environment = "prod" }
}
```

From an example you can pass a variable (e.g. from tfvars):

```hcl
variable "secrets_manager_secrets" {
  type = map(object({
    value                   = optional(string)
    recovery_window_in_days = optional(number, 30)
  }))
  default = {}
}

module "secrets" {
  source      = "Nullafi/nullafi-shield-managed-services/aws//modules/secrets"
  name_prefix = var.name_prefix
  secrets     = var.secrets_manager_secrets
  tags        = var.tags
}
```

ECS task definitions: grant the execution role `secretsmanager:GetSecretValue` on the secret ARNs, then in the container definition:

```hcl
secrets = [
  { name = "LICENSE_KEY", valueFrom = module.secrets.secret_arns["license-key"] }
]
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.35.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_secretsmanager_secret.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ARN for encrypting secrets. Null uses the AWS-managed key. | `string` | `null` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for secret names in AWS (e.g. app or env). Full name = "{name\_prefix}/{key}". | `string` | n/a | yes |
| <a name="input_secret_names"></a> [secret\_names](#input\_secret\_names) | Set of secret key names to create. Use this instead of secrets when values are sensitive. | `set(string)` | `[]` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Map of secret key → { value = optional(string), recovery\_window\_in\_days = optional(number) }. Key becomes name suffix; value = null creates secret only (no version). | <pre>map(object({<br/>    value                   = optional(string)<br/>    recovery_window_in_days = optional(number, 30)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to each secret. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_secret_arns"></a> [secret\_arns](#output\_secret\_arns) | Map of secret key → ARN (for IAM policies and ECS task definition valueFrom). |
| <a name="output_secret_arns_list"></a> [secret\_arns\_list](#output\_secret\_arns\_list) | List of secret ARNs (for IAM policy Resource). |
| <a name="output_secret_names"></a> [secret\_names](#output\_secret\_names) | Map of secret key → full secret name in AWS. |
<!-- END_TF_DOCS -->
