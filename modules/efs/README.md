# EFS module

Creates an EFS file system, mount targets (one per subnet), and an access point. Used for persistent container storage (e.g. Shield config, ACME certs) across ECS Fargate task restarts.

## Usage

```hcl
module "efs" {
  source = "Nullafi/nullafi-shield-managed-services/aws//modules/efs"

  name_prefix        = "prod-app"
  subnet_ids         = module.vpc.backend_subnet_ids
  security_group_ids = [aws_security_group.efs.id]
  access_point_path  = "/data"

  tags = { Environment = "prod" }
}
```

Mount in an ECS task definition volume:

```hcl
volumes = [{
  name = "app-data"
  efs_volume_configuration = {
    file_system_id  = module.efs.file_system_id
    root_directory  = "/"
    access_point_id = module.efs.access_point_id
  }
}]
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
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_efs_access_point.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point) | resource |
| [aws_efs_file_system.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_point_path"></a> [access\_point\_path](#input\_access\_point\_path) | If set, create an access point with this root path (e.g. /shield). | `string` | `null` | no |
| <a name="input_access_point_permissions"></a> [access\_point\_permissions](#input\_access\_point\_permissions) | POSIX permissions for access point root (e.g. 0755). | `string` | `"0755"` | no |
| <a name="input_access_point_posix_gid"></a> [access\_point\_posix\_gid](#input\_access\_point\_posix\_gid) | POSIX GID for access point root (used when access\_point\_path is set). | `number` | `1000` | no |
| <a name="input_access_point_posix_uid"></a> [access\_point\_posix\_uid](#input\_access\_point\_posix\_uid) | POSIX UID for access point root (used when access\_point\_path is set). | `number` | `1000` | no |
| <a name="input_encrypted"></a> [encrypted](#input\_encrypted) | Enable encryption at rest. | `bool` | `true` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name/creation token for the EFS file system. | `string` | n/a | yes |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security group IDs for mount targets (allow NFS 2049 from ECS tasks). | `list(string)` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for mount targets (typically private subnets where ECS tasks run). | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the file system. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_point_arn"></a> [access\_point\_arn](#output\_access\_point\_arn) | ARN of the access point (if created). |
| <a name="output_access_point_id"></a> [access\_point\_id](#output\_access\_point\_id) | ID of the access point (if created). |
| <a name="output_file_system_arn"></a> [file\_system\_arn](#output\_file\_system\_arn) | ARN of the EFS file system. |
| <a name="output_file_system_dns_name"></a> [file\_system\_dns\_name](#output\_file\_system\_dns\_name) | DNS name of the EFS file system (for mount). |
| <a name="output_file_system_id"></a> [file\_system\_id](#output\_file\_system\_id) | ID of the EFS file system. |
<!-- END_TF_DOCS -->
