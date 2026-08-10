# terraform-aws-nullafi-shield-managed-services

Terraform module that deploys the [Nullafi Shield](https://nullafi.com) stack on AWS ECS Fargate: **two NLBs** (TCP passthrough — one for Shield Web UI with Let's Encrypt TLS via ACME DNS-01, one dedicated to the Squid proxy with static Elastic IPs), **VPC** (single NAT gateway), **ECS Fargate** cluster running Shield Web UI / ICAP / Alert / Squid, **Cloud Map** service discovery, **EFS** (Shield config + certs), **S3** (logs/backups), **ElastiCache Redis**, **Amazon OpenSearch Service**, per-service autoscaling, and CloudWatch alarms + a dashboard.

## Architecture

```
Internet
  │
  ├─► Shield Web NLB (:80/:443 TCP passthrough) ──────┐
  │                                                    ▼
  └─► Squid NLB (:44509, static Elastic IPs) ──► ECS Fargate (backend subnets)
                                                  │       ├── Let's Encrypt TLS (ACME DNS-01)
                                                  │       └── Certs persisted on EFS
                                                  ▼
  Cloud Map (<name_prefix>.local)
  ├── squid.<name_prefix>.local:44509
  ├── shield-web-ui.<name_prefix>.local:8080
  ├── shield-icap.<name_prefix>.local:1344
  └── shield-alert.<name_prefix>.local

  ElastiCache Redis (data subnets)
  Amazon OpenSearch Service (data subnets)
```

Only Shield Web UI and Squid are externally reachable, each via its own NLB — Squid's NLB carries static Elastic IPs (`squid_eips` output) so proxy clients can allowlist a fixed set of addresses, and can be given its own DNS name via `proxy_host_name` (an alias record to the Squid NLB, separate from `host_name`, which is Shield Web UI's). Every other service communicates internally over Cloud Map service discovery. Redis and the Activity store (Elasticsearch-compatible) are AWS-managed rather than run as containers.

## Notes

- **Provider/backend**: this module does not declare a `provider` or `backend` block — configure both in your own root config (see [examples/managed-services](./examples/managed-services)). Authenticate via the standard AWS credential chain (env vars, shared profile, or an IAM role), not variables.
- **HTTPS**: only ACME **DNS-01** is supported (`acme_challenge_type`). The NLB won't route to a target until it's healthy, but the container can't get a cert without inbound traffic first (HTTP-01/TLS-ALPN-01 deadlock) — DNS-01 sidesteps this.
- **Secrets**: `nullafi_license_key`, `proxy_mitm_key`, and `acme_dns01_env` are marked `sensitive`; the license key and Squid MITM cert/key are stored in AWS Secrets Manager, not passed to containers as plain environment values.
- **Submodules**: reusable building blocks under [modules/](./modules) (`vpc`, `ecs-fargate`, `ecs-service`, `efs`, `secrets`, `parameter-store`, `service-discovery`) can also be sourced independently — see each module's README.

<!-- BEGIN_TF_DOCS -->
## Usage

```hcl
module "shield" {
  source  = "Nullafi/nullafi-shield-managed-services/aws"
  version = "~> 1.0"

  region      = "us-east-1"
  name_prefix = "shield"

  squid_image         = "repo.ecr.com/nullafi/proxy:latest"
  shield_web_ui_image = "repo.ecr.com/nullafi/shield:latest"
  shield_icap_image   = "repo.ecr.comnullafi/shield:latest"
  shield_alert_image  = "repo.ecr.com/nullafi/shield:latest"

  nullafi_license_key = var.nullafi_license_key

  host_name           = "shield.example.com"
  acme_dns01_provider = "route53"
  route53_zone_id     = "zone-id"

  tags = {
    Environment = "prod"
  }
}
```

See [examples/managed-services](./examples/managed-services) for a complete, deployable root config (provider + backend) that calls this module with a managed data layer (ElastiCache Redis + Amazon OpenSearch).

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.56.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_ecs"></a> [ecs](#module\_ecs) | ./modules/ecs-fargate | n/a |
| <a name="module_ecs_shield_alert"></a> [ecs\_shield\_alert](#module\_ecs\_shield\_alert) | ./modules/ecs-service | n/a |
| <a name="module_ecs_shield_icap"></a> [ecs\_shield\_icap](#module\_ecs\_shield\_icap) | ./modules/ecs-service | n/a |
| <a name="module_ecs_shield_web"></a> [ecs\_shield\_web](#module\_ecs\_shield\_web) | ./modules/ecs-service | n/a |
| <a name="module_ecs_squid"></a> [ecs\_squid](#module\_ecs\_squid) | ./modules/ecs-service | n/a |
| <a name="module_efs"></a> [efs](#module\_efs) | ./modules/efs | n/a |
| <a name="module_efs_certs"></a> [efs\_certs](#module\_efs\_certs) | ./modules/efs | n/a |
| <a name="module_parameter_store"></a> [parameter\_store](#module\_parameter\_store) | ./modules/parameter-store | n/a |
| <a name="module_secrets"></a> [secrets](#module\_secrets) | ./modules/secrets | n/a |
| <a name="module_service_discovery"></a> [service\_discovery](#module\_service\_discovery) | ./modules/service-discovery | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./modules/vpc | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_dashboard.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_log_metric_filter.shield_errors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_log_metric_filter.text_errors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_metric_alarm.ecs_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.ecs_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.ecs_no_tasks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_eip.squid](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_elasticache_replication_group.redis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.redis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_iam_policy.ecs_execution_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ecs_execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ecs_execution_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ecs_task_efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.route53_dns01](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.s3_logs_backups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_service_linked_role.opensearch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_lb.shield_web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb.squid](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.shield_web_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.shield_web_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.squid](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.shield_web_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.shield_web_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.squid](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_opensearch_domain.activity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearch_domain) | resource |
| [aws_route53_record.shield_web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.squid](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.logs_backups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs_backups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.logs_backups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.logs_backups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.logs_backups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.logs_backups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.logs_backups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.opensearch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.redis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc_endpoint_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acme_challenge_type"></a> [acme\_challenge\_type](#input\_acme\_challenge\_type) | ACME challenge type for Let's Encrypt. Only DNS-01 is supported for ECS Fargate + NLB deployments (HTTP-01 and TLS-ALPN-01 fail due to NLB health check gating — the container won't serve traffic until it has a cert, but can't get a cert without inbound traffic). | `string` | `"DNS-01"` | no |
| <a name="input_acme_dns01_env"></a> [acme\_dns01\_env](#input\_acme\_dns01\_env) | Environment variables for DNS-01 provider credentials. Keys and values depend on the provider (e.g. CF\_API\_TOKEN for Cloudflare, AWS\_ACCESS\_KEY\_ID/AWS\_SECRET\_ACCESS\_KEY for Route53). | `map(string)` | `{}` | no |
| <a name="input_acme_dns01_provider"></a> [acme\_dns01\_provider](#input\_acme\_dns01\_provider) | DNS provider name for DNS-01 challenge (e.g. cloudflare, route53). Only used when acme\_challenge\_type is DNS-01. | `string` | `null` | no |
| <a name="input_autoscaling_capacity"></a> [autoscaling\_capacity](#input\_autoscaling\_capacity) | Optional per-service min/max task count. Keys: squid, shield-web-ui, shield-icap, shield-alert. Omitted services use autoscaling\_min\_capacity and autoscaling\_max\_capacity. | <pre>map(object({<br/>    min = number<br/>    max = number<br/>  }))</pre> | `{}` | no |
| <a name="input_autoscaling_max_capacity"></a> [autoscaling\_max\_capacity](#input\_autoscaling\_max\_capacity) | Default maximum number of tasks for scalable services (used when autoscaling\_capacity does not specify per service). | `number` | `4` | no |
| <a name="input_autoscaling_min_capacity"></a> [autoscaling\_min\_capacity](#input\_autoscaling\_min\_capacity) | Default minimum number of tasks for scalable services (used when autoscaling\_capacity does not specify per service). | `number` | `1` | no |
| <a name="input_autoscaling_target_cpu_percent"></a> [autoscaling\_target\_cpu\_percent](#input\_autoscaling\_target\_cpu\_percent) | Target CPU utilization percent for scaling (used by all scalable services). | `number` | `70` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of AZs. Leave null to use first 2 from data source. | `list(string)` | `null` | no |
| <a name="input_create_opensearch_service_linked_role"></a> [create\_opensearch\_service\_linked\_role](#input\_create\_opensearch\_service\_linked\_role) | Whether to create the OpenSearch service-linked role. Set to false if it already exists in the account. | `bool` | `true` | no |
| <a name="input_data_subnets_use_nat"></a> [data\_subnets\_use\_nat](#input\_data\_subnets\_use\_nat) | If true, data tier subnets get a default route via NAT. | `bool` | `true` | no |
| <a name="input_ecs_container_insights_enabled"></a> [ecs\_container\_insights\_enabled](#input\_ecs\_container\_insights\_enabled) | Enable ECS Container Insights for container resource utilization metrics. | `bool` | `true` | no |
| <a name="input_ecs_log_retention_days"></a> [ecs\_log\_retention\_days](#input\_ecs\_log\_retention\_days) | CloudWatch log retention in days for ECS task logs. | `number` | `365` | no |
| <a name="input_ecs_use_fargate_spot"></a> [ecs\_use\_fargate\_spot](#input\_ecs\_use\_fargate\_spot) | Use Fargate Spot for ECS (with Fargate as fallback). | `bool` | `false` | no |
| <a name="input_host_name"></a> [host\_name](#input\_host\_name) | Host name for app config (e.g. NULLAFI\_HTTP\_CUSTOM\_DOMAIN). | `string` | `null` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names. Must differ from other deployments in the same account/region. | `string` | `"shield"` | no |
| <a name="input_nullafi_license_key"></a> [nullafi\_license\_key](#input\_nullafi\_license\_key) | Raw Nullafi license key (env value for NULLAFI\_LICENSE\_KEY). Prefer SSM for secrets. | `string` | `null` | no |
| <a name="input_nullafi_license_key_file"></a> [nullafi\_license\_key\_file](#input\_nullafi\_license\_key\_file) | Path to Nullafi license key file (env value for NULLAFI\_LICENSE\_KEY\_FILE). | `string` | `null` | no |
| <a name="input_opensearch_engine_version"></a> [opensearch\_engine\_version](#input\_opensearch\_engine\_version) | OpenSearch engine version. | `string` | `"OpenSearch_2.11"` | no |
| <a name="input_opensearch_instance_type"></a> [opensearch\_instance\_type](#input\_opensearch\_instance\_type) | OpenSearch instance type. | `string` | `"t3.small.search"` | no |
| <a name="input_opensearch_volume_size"></a> [opensearch\_volume\_size](#input\_opensearch\_volume\_size) | OpenSearch EBS volume size in GB. | `number` | `20` | no |
| <a name="input_proxy_host_name"></a> [proxy\_host\_name](#input\_proxy\_host\_name) | Host name for the Squid proxy's own NLB (Route53 A record). Separate from host\_name, which is used for Shield Web UI. | `string` | `null` | no |
| <a name="input_proxy_mitm_cert"></a> [proxy\_mitm\_cert](#input\_proxy\_mitm\_cert) | Path to Squid MITM certificate (PROXY\_MITM\_CERT). | `string` | `null` | no |
| <a name="input_proxy_mitm_key"></a> [proxy\_mitm\_key](#input\_proxy\_mitm\_key) | Path to Squid MITM private key (PROXY\_MITM\_KEY). | `string` | `null` | no |
| <a name="input_proxy_port"></a> [proxy\_port](#input\_proxy\_port) | Port the Squid proxy listens on and is exposed via the NLB (container port, target group, listener, and security group all use this). | `number` | `44509` | no |
| <a name="input_proxy_root_ca"></a> [proxy\_root\_ca](#input\_proxy\_root\_ca) | Path to root CA certificate that issued the MITM cert. Installed as trusted CA in shield containers. | `string` | `null` | no |
| <a name="input_redis_engine_version"></a> [redis\_engine\_version](#input\_redis\_engine\_version) | ElastiCache Redis engine version. | `string` | `"7.1"` | no |
| <a name="input_redis_node_type"></a> [redis\_node\_type](#input\_redis\_node\_type) | ElastiCache Redis node type. | `string` | `"cache.t3.small"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region. Must match the region the caller's AWS provider is configured for (used to build ARNs and VPC endpoint service names). | `string` | n/a | yes |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 hosted zone ID. When set, Terraform auto-creates the A record and grants the ECS task role Route53 permissions for DNS-01 challenges. | `string` | `null` | no |
| <a name="input_shield_alert_image"></a> [shield\_alert\_image](#input\_shield\_alert\_image) | Existing ECR image URI for Shield Alert. | `string` | n/a | yes |
| <a name="input_shield_icap_image"></a> [shield\_icap\_image](#input\_shield\_icap\_image) | Existing ECR image URI for Shield ICAP. | `string` | n/a | yes |
| <a name="input_shield_web_ui_image"></a> [shield\_web\_ui\_image](#input\_shield\_web\_ui\_image) | Existing ECR image URI for Shield Web UI. | `string` | n/a | yes |
| <a name="input_squid_image"></a> [squid\_image](#input\_squid\_image) | Existing ECR image URI for Squid (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-squid:latest). | `string` | n/a | yes |
| <a name="input_ssm_parameters"></a> [ssm\_parameters](#input\_ssm\_parameters) | Optional SSM Parameter Store entries. Key = path (e.g. "/nullafi/app/config"), value = { value = string (plain or jsonencode()), sensitive = bool }. Set to {} to skip. Can pass from JSON: jsondecode(file("params.json")). | <pre>map(object({<br/>    value     = string<br/>    sensitive = optional(bool, true)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backend_subnet_ids"></a> [backend\_subnet\_ids](#output\_backend\_subnet\_ids) | IDs of the backend (private) subnets. |
| <a name="output_cloudwatch_dashboard_name"></a> [cloudwatch\_dashboard\_name](#output\_cloudwatch\_dashboard\_name) | CloudWatch dashboard name for ECS service metrics. |
| <a name="output_container_images"></a> [container\_images](#output\_container\_images) | Container image URIs in use (existing ECR images from variables). |
| <a name="output_data_subnet_ids"></a> [data\_subnet\_ids](#output\_data\_subnet\_ids) | IDs of the data (private) subnets. |
| <a name="output_dns_instructions"></a> [dns\_instructions](#output\_dns\_instructions) | DNS setup instructions for Let's Encrypt. |
| <a name="output_ecs_cluster_arn"></a> [ecs\_cluster\_arn](#output\_ecs\_cluster\_arn) | ARN of the ECS cluster. |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | Name of the ECS cluster. |
| <a name="output_efs_certs_file_system_id"></a> [efs\_certs\_file\_system\_id](#output\_efs\_certs\_file\_system\_id) | EFS file system ID for Shield Web UI ACME/Let's Encrypt certs. |
| <a name="output_efs_file_system_id"></a> [efs\_file\_system\_id](#output\_efs\_file\_system\_id) | EFS file system ID (Shield config). |
| <a name="output_elasticache_redis_endpoint"></a> [elasticache\_redis\_endpoint](#output\_elasticache\_redis\_endpoint) | ElastiCache Redis primary endpoint. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | IDs of the NAT gateways (single NAT for cost savings). |
| <a name="output_nlb_dns_name"></a> [nlb\_dns\_name](#output\_nlb\_dns\_name) | Shield Web UI NLB DNS name (ports 80/443). |
| <a name="output_nlb_zone_id"></a> [nlb\_zone\_id](#output\_nlb\_zone\_id) | Shield Web UI NLB Route53 zone ID (for alias records). |
| <a name="output_opensearch_dashboard_endpoint"></a> [opensearch\_dashboard\_endpoint](#output\_opensearch\_dashboard\_endpoint) | Amazon OpenSearch Dashboards endpoint. |
| <a name="output_opensearch_endpoint"></a> [opensearch\_endpoint](#output\_opensearch\_endpoint) | Amazon OpenSearch domain endpoint. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | IDs of the public subnets. |
| <a name="output_s3_logs_backups_bucket"></a> [s3\_logs\_backups\_bucket](#output\_s3\_logs\_backups\_bucket) | S3 bucket name for logs and backups. |
| <a name="output_service_discovery_endpoints"></a> [service\_discovery\_endpoints](#output\_service\_discovery\_endpoints) | Service discovery endpoints with ports (for client configuration). |
| <a name="output_service_discovery_internal_dns"></a> [service\_discovery\_internal\_dns](#output\_service\_discovery\_internal\_dns) | Internal DNS hostnames for each service (resolved within VPC via Cloud Map). |
| <a name="output_service_discovery_namespace"></a> [service\_discovery\_namespace](#output\_service\_discovery\_namespace) | Cloud Map private DNS namespace (e.g. nullafi.local). |
| <a name="output_shield_web_ui_url"></a> [shield\_web\_ui\_url](#output\_shield\_web\_ui\_url) | Shield Web UI URL. |
| <a name="output_squid_eips"></a> [squid\_eips](#output\_squid\_eips) | Elastic IP addresses assigned to the Squid proxy NLB (one per public subnet). |
| <a name="output_squid_nlb_dns_name"></a> [squid\_nlb\_dns\_name](#output\_squid\_nlb\_dns\_name) | Squid proxy NLB DNS name (var.proxy\_port). |
| <a name="output_squid_nlb_zone_id"></a> [squid\_nlb\_zone\_id](#output\_squid\_nlb\_zone\_id) | Squid proxy NLB Route53 zone ID (for alias records). |
| <a name="output_squid_proxy_endpoint"></a> [squid\_proxy\_endpoint](#output\_squid\_proxy\_endpoint) | Squid proxy endpoint (configure as HTTP proxy). |
| <a name="output_ssm_parameter_arns"></a> [ssm\_parameter\_arns](#output\_ssm\_parameter\_arns) | ARNs of SSM parameters created via ssm\_parameters (for IAM policies). |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR block of the VPC. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->

## License

Apache 2.0, see [LICENSE](./LICENSE).
