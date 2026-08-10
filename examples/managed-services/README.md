# managed-services

Example root config calling the [nullafi-shield-managed-services](../../) module with a managed data layer: **two NLBs** (TCP passthrough — one for Shield Web UI with Let's Encrypt TLS via DNS-01, one dedicated to the Squid proxy with static Elastic IPs), **VPC** (single NAT gateway for cost savings), **ECS Fargate** cluster running 4 services (Shield Web UI, ICAP, Alert, Squid), **Cloud Map service discovery**, **EFS** (Shield config + certs), **S3** (logs/backups), **ElastiCache Redis**, **Amazon OpenSearch Service**, autoscaling, and CloudWatch alarms + dashboard.

See [SETUP.md](./SETUP.md) for a full step-by-step deployment guide.

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

All services run on ECS Fargate in private subnets. Only Shield Web UI and Squid are externally accessible, each via its own NLB — Squid's NLB carries static Elastic IPs so proxy clients can allowlist a fixed set of addresses, and can be given its own DNS name via `proxy_host_name` (separate from `host_name`, Shield Web UI's own alias record). `proxy_host_name` is optional, but required whenever `route53_zone_id` is set — Terraform enforces this via variable validation. Redis and OpenSearch are AWS-managed instead of running as containers.

## Prerequisites

- Terraform >= 1.9
- AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, or an IAM role)
- ECR image URIs for Squid, Shield Web UI, Shield ICAP, Shield Alert
- A Route53 (or other DNS-01-capable provider) hosted zone if you want HTTPS

## Quick start

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your images, license key, hostname, proxy_host_name, etc.

# Load credentials (optional — you can also rely on your AWS profile/role)
set -a && source .env && set +a

terraform init
terraform plan
terraform apply
```

See [SETUP.md](./SETUP.md) for details on every variable, DNS setup, monitoring, and teardown.

## Outputs

All outputs of the [root module](../../outputs.tf) are passed through — see [outputs.tf](./outputs.tf) for the full list, including `shield_web_ui_url`, `nlb_dns_name`, `squid_nlb_dns_name`, `squid_eips`, `elasticache_redis_endpoint`, `opensearch_endpoint`, and `cloudwatch_dashboard_name`.
