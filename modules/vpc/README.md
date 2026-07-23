# VPC module

VPC layout with three tiers and Network ACLs:

- **2 public subnets** – ALB, NAT Gateway(s)
- **2 private backend subnets** – ECS tasks, app servers
- **2 private data subnets** – RDS, ElastiCache, etc.

Includes an Internet Gateway, NAT Gateway(s), route tables, and **tiered Network ACLs** for defense in depth.

## Usage

```hcl
module "vpc" {
  source = "Nullafi/nullafi-shield-managed-services/aws//modules/vpc"

  name_prefix         = "prod"
  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = ["us-east-1a", "us-east-1b"]
  single_nat_gateway  = true
  data_subnets_use_nat = false   # optional: lock data tier to no internet
  # Optional: override defaults. Defaults allow common app and DB ports (see below).
  # backend_app_ports   = [80, 443, 3000, 8080, ...]
  # data_ports          = [3306, 5432, 6379, 27017, ...]

  tags = { Environment = "prod" }
}
```

## Network ACLs – why and how

**Why use NACLs when you have security groups?**

- **Defense in depth:** Security groups are attached to ENIs (instance/interface level). NACLs apply at the **subnet** boundary. If a misconfigured SG or new resource opens something by mistake, NACLs still restrict what can enter or leave the subnet.
- **Explicit allow-list:** This module uses **custom NACLs per tier** with explicit allow rules. Traffic that doesn’t match a rule is denied (default deny for custom NACLs when you don’t use the default NACL).
- **Security product posture:** For a security-focused product, showing that you segment tiers and limit traffic at the subnet layer is a strong signal.

**Important NACL behavior**

1. **Stateless** – You must allow **both** directions of a flow:
   - Inbound on port 443 from 0.0.0.0/0
   - Outbound on **ephemeral ports** (1024–65535) to 0.0.0.0/0 for return traffic
2. **Rule order** – First match wins. Rules are numbered with gaps (10, 20, 30…) so you can insert rules later without renumbering.
3. **Tier-to-tier** – Public can reach backend on app ports; backend can reach data only on DB ports; data accepts only from backend (and optional ephemeral return). No direct internet → data or public → data on DB ports.

**What this module does**

| Tier    | Inbound allow                                                                 | Outbound allow                                                         |
|---------|-------------------------------------------------------------------------------|------------------------------------------------------------------------|
| Public  | HTTP/HTTPS + ephemeral from 0.0.0.0/0; all from VPC                            | HTTP/HTTPS + ephemeral to 0.0.0.0/0; all to VPC                         |
| Backend | From public on `backend_app_ports` + ephemeral; from VPC; ephemeral from internet | To data on `data_ports`; ephemeral to 0.0.0.0/0; all to VPC             |
| Data    | From backend on `data_ports` + ephemeral                                      | Ephemeral to VPC; optionally ephemeral to 0.0.0.0/0 if `data_subnets_use_nat` |

Override `backend_app_ports` or `data_ports` to restrict to only what you use. Set `data_subnets_use_nat = false` for strict data-tier isolation (no internet path).

### Default ports (clients can use different runtimes and databases)

**Backend (public → backend):** `80, 443, 3000, 4000, 5000, 8080, 8443, 9000`  
- 80/443 – HTTP/HTTPS (app listening directly)  
- 3000 – Node/Express, many dev servers  
- 4000 – Phoenix/Elixir  
- 5000 – Flask, some Python apps  
- 8080/8443 – Common ALB target and alt HTTPS  
- 9000 – PHP-FPM, some app servers  

**Data (backend → data):** `1433, 27017, 3306, 5432, 5433, 5984, 6379, 7687, 8086, 9042, 9092, 9200, 9300, 11211`  
- 1433 – SQL Server  
- 27017 – MongoDB  
- 3306 – MySQL / MariaDB  
- 5432/5433 – PostgreSQL / Citus  
- 5984 – CouchDB  
- 6379 – Redis  
- 7687 – Neo4j Bolt  
- 8086 – InfluxDB  
- 9042 – Cassandra  
- 9092 – Kafka  
- 9200/9300 – Elasticsearch HTTP / transport  
- 11211 – Memcached  

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.33.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_network_acl.backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl_rule.backend_in_data_ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_in_ephemeral_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_in_public_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_in_public_ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_in_self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_in_udp_ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_out_data_db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_out_dns_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_out_ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_out_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_out_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.backend_out_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.data_in_ephemeral_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.data_in_from_backend_db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.data_in_from_backend_ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.data_out_ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.data_out_ephemeral_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.data_out_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_in_dns_udp_return](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_in_ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_in_ports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_in_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_out_dns_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_out_ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_out_ports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_out_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_route_table.backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of AZ names (length 2 for 2 public, 2 backend, 2 data subnets). | `list(string)` | n/a | yes |
| <a name="input_backend_app_ports"></a> [backend\_app\_ports](#input\_backend\_app\_ports) | TCP ports the backend accepts from the public tier (e.g. 3128 Squid, 80/443 Shield Web, 1344 Shield ICAP). | `list(number)` | <pre>[<br/>  80,<br/>  443,<br/>  3000,<br/>  4000,<br/>  5000,<br/>  8080,<br/>  8443,<br/>  9000,<br/>  3128,<br/>  1344<br/>]</pre> | no |
| <a name="input_data_ports"></a> [data\_ports](#input\_data\_ports) | TCP ports the data tier accepts from the backend (e.g. 6379 Redis, 9200 Elasticsearch). | `list(number)` | <pre>[<br/>  1433,<br/>  27017,<br/>  3306,<br/>  5432,<br/>  5433,<br/>  5984,<br/>  6379,<br/>  7687,<br/>  8086,<br/>  9042,<br/>  9092,<br/>  9200,<br/>  9300,<br/>  11211<br/>]</pre> | no |
| <a name="input_data_subnets_use_nat"></a> [data\_subnets\_use\_nat](#input\_data\_subnets\_use\_nat) | If true, data tier subnets get a default route via NAT (e.g. for updates). Set false for strict data-tier isolation. | `bool` | `true` | no |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Enable VPC Flow Logs to CloudWatch Logs. | `bool` | `true` | no |
| <a name="input_enable_nacls"></a> [enable\_nacls](#input\_enable\_nacls) | Enable tiered Network ACLs (public, backend, data). Set false to use the VPC default NACL. | `bool` | `true` | no |
| <a name="input_flow_logs_kms_key_id"></a> [flow\_logs\_kms\_key\_id](#input\_flow\_logs\_kms\_key\_id) | KMS key ARN for encrypting the VPC Flow Logs CloudWatch log group. Null uses default encryption. | `string` | `null` | no |
| <a name="input_flow_logs_retention_days"></a> [flow\_logs\_retention\_days](#input\_flow\_logs\_retention\_days) | Retention in days for VPC Flow Logs CloudWatch log group (Checkov requires >= 365). | `number` | `365` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names (e.g. env or project name). | `string` | n/a | yes |
| <a name="input_public_inbound_ports"></a> [public\_inbound\_ports](#input\_public\_inbound\_ports) | TCP ports the public tier accepts from the internet (e.g. ALB listeners: 80, 443, 44509 for Squid). | `list(number)` | <pre>[<br/>  80,<br/>  443,<br/>  44509<br/>]</pre> | no |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Use a single NAT gateway (cost-saving) or one per AZ (HA). | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backend_subnet_cidrs"></a> [backend\_subnet\_cidrs](#output\_backend\_subnet\_cidrs) | CIDR blocks of the backend subnets. |
| <a name="output_backend_subnet_ids"></a> [backend\_subnet\_ids](#output\_backend\_subnet\_ids) | IDs of the backend (private) subnets. |
| <a name="output_data_subnet_cidrs"></a> [data\_subnet\_cidrs](#output\_data\_subnet\_cidrs) | CIDR blocks of the data subnets. |
| <a name="output_data_subnet_ids"></a> [data\_subnet\_ids](#output\_data\_subnet\_ids) | IDs of the data (private) subnets. |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | ID of the Internet Gateway. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | IDs of the NAT gateways. |
| <a name="output_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#output\_public\_subnet\_cidrs) | CIDR blocks of the public subnets. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | IDs of the public subnets. |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR block of the VPC. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->
