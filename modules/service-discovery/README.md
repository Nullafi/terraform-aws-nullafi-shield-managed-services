# Service discovery module

Creates a Cloud Map private DNS namespace and one service per name in `service_names`, for internal service-to-service discovery between ECS tasks (e.g. `<service>.<namespace>`).

## Usage

```hcl
module "service_discovery" {
  source = "Nullafi/nullafi-shield-managed-services/aws//modules/service-discovery"

  namespace_name        = "prod-app.local"
  namespace_description = "Private DNS namespace for ECS service discovery"
  vpc_id                = module.vpc.vpc_id
  service_names         = ["api", "worker"]

  tags = { Environment = "prod" }
}
```

Reference a service's registry ARN when creating an ECS service (in the `ecs-service` module or directly):

```hcl
service_registry_arn = module.service_discovery.service_arns["api"]
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
| [aws_service_discovery_private_dns_namespace.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_service_discovery_service.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dns_ttl"></a> [dns\_ttl](#input\_dns\_ttl) | TTL for DNS records in the namespace. | `number` | `10` | no |
| <a name="input_namespace_description"></a> [namespace\_description](#input\_namespace\_description) | Description for the namespace. | `string` | `"Private DNS namespace for service discovery"` | no |
| <a name="input_namespace_name"></a> [namespace\_name](#input\_namespace\_name) | Name of the private DNS namespace (e.g. nullafi.local). | `string` | n/a | yes |
| <a name="input_service_names"></a> [service\_names](#input\_service\_names) | List of service names to create in the namespace (e.g. squid, shield-web). | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to namespace and services. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for the private DNS namespace. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_namespace_arn"></a> [namespace\_arn](#output\_namespace\_arn) | ARN of the private DNS namespace. |
| <a name="output_namespace_id"></a> [namespace\_id](#output\_namespace\_id) | ID of the private DNS namespace. |
| <a name="output_service_arns"></a> [service\_arns](#output\_service\_arns) | Map of service name to Cloud Map service ARN (for ECS service\_registries). |
| <a name="output_service_ids"></a> [service\_ids](#output\_service\_ids) | Map of service name to Cloud Map service ID. |
<!-- END_TF_DOCS -->
