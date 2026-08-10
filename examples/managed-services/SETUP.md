# Nullafi Shield — Basic (Managed DB) Deployment Guide

Deploys the Nullafi Shield stack on **AWS ECS Fargate** behind a **Network Load Balancer (NLB)**, with Redis replaced by **AWS ElastiCache** and Elasticsearch replaced by **Amazon OpenSearch Service**. Same general topology as `basic` but with AWS-managed data layer.

**What you get:**
- VPC with public + backend + data subnets (single NAT gateway)
- NLB terminating at Shield Web UI (TCP passthrough — container handles TLS)
- ECS Fargate cluster with 4 services: Shield Web UI, ICAP, Alert, Squid
- **ElastiCache Redis** (managed, replaces Redis container)
- **Amazon OpenSearch Service** (managed, replaces Activity/Elasticsearch container)
- Cloud Map service discovery for internal traffic
- EFS volumes for Shield config + certificates
- S3 bucket for logs/backups
- CloudWatch dashboard + alarms
- Autoscaling on CPU utilization
- HTTPS via Let's Encrypt (DNS-01 challenge only — see Step 3)

**When to use this vs `basic`:**

| Concern | `basic` | `managed-services` |
|---|---|---|
| Cost (monthly) | Lower (~$300 baseline) | Higher (~$500+ baseline due to ElastiCache + OpenSearch) |
| Ops burden | Patch/upgrade Redis + ES containers yourself | AWS handles patches, backups, failover |
| Data durability | EFS + in-container | Managed backups, snapshots, point-in-time |
| Scaling data layer | Requires task resizing | Native managed scaling |
| Best for | Cost-sensitive environments, self-managed preference | Production workloads, teams that prefer managed services |

---

## Step 1 — Prerequisites

Install these on your local machine:

| Tool | Version | Install |
|---|---|---|
| Terraform | ≥ 1.9 | <https://developer.hashicorp.com/terraform/install> |
| AWS CLI (optional, for troubleshooting) | ≥ 2.0 | <https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html> |

You also need:

- **An AWS account** with permissions to create VPC, ECS, NLB, EFS, ElastiCache, OpenSearch, S3, IAM, CloudWatch, Cloud Map, and (optional) Route53 resources
- **AWS access key + secret** for an IAM user with the above permissions
- **A Nullafi license key** (provided by Nullafi)
- **Container image URIs** for Shield Web UI, ICAP, Alert, Squid (public ECR or your own registry)
- **A Squid MITM certificate + private key** (optional — only needed if using the Squid proxy)
- **A public DNS hostname** you control (e.g. `shield.yourcompany.com`) — **required for HTTPS**
- **A DNS provider supported by the Shield container** for ACME DNS-01 (Route53, Cloudflare, Namecheap, etc.)
- **A hostname for the Squid proxy** (e.g. `proxy.yourcompany.com`) — `proxy_host_name` is optional, but required if you set `route53_zone_id` (Terraform validates this)

**Check for existing OpenSearch service-linked role** in your AWS account:

```bash
aws iam get-role --role-name AWSServiceRoleForAmazonOpenSearchService 2>&1 | head
```

If the role exists, set `create_opensearch_service_linked_role = false` in your tfvars (Step 3). If not, leave the default (Terraform will create it).

---

## Step 2 — Clone the repo and enter the folder

```bash
git clone git@github.com:Nullafi/terraform-aws-nullafi-shield-managed-services.git
cd terraform-aws-nullafi-shield-managed-services/examples/managed-services
```

If you're using Squid MITM, place the cert + key in this folder:

```bash
cp /path/to/cert.crt ./cert.crt
cp /path/to/cert.key ./cert.key
```

---

## Step 3 — Configure `terraform.tfvars`

Create `terraform.tfvars` in this folder. Minimum HTTPS-enabled config using Route53:

```hcl
region         = "us-east-1"
aws_access_key = "AKIA..."
aws_secret_key = "wJalr..."

# Container images (Shield services only — Redis + Elasticsearch are managed)
shield_web_ui_image = "repo.ecr.com/nullafi/shield:latest"
shield_icap_image   = "repo.ecr.com/nullafi/shield:latest"
shield_alert_image  = "repo.ecr.com/nullafi/shield:latest"
squid_image         = "repo.ecr.com/nullafi/proxy:latest"

# Nullafi license
nullafi_license_key = "FT7YC..."

# Public hostname (required for HTTPS)
host_name = "shield.yourcompany.com"

# Squid proxy hostname (required since route53_zone_id is set below)
proxy_host_name = "proxy.yourcompany.com"

# Let's Encrypt — DNS-01 only (see note below)
acme_challenge_type = "DNS-01"
acme_dns01_provider = "route53"
route53_zone_id     = "zoneid"   # your Route53 hosted zone ID

# Squid MITM (optional)
proxy_mitm_cert = "./cert.crt"
proxy_mitm_key  = "./cert.key"

# OpenSearch service-linked role: false if it already exists in your account
# create_opensearch_service_linked_role = false
```

### Managed service sizing (optional overrides)

Defaults are tuned for typical workloads. Adjust if needed:

```hcl
# ElastiCache Redis
redis_node_type       = "cache.t3.small"   # default
redis_engine_version  = "7.1"

# OpenSearch
opensearch_instance_type  = "t3.small.search"  # default
opensearch_engine_version = "OpenSearch_2.11"
opensearch_volume_size    = 20                 # GB, default
```

For production, consider `cache.m6g.large` or larger for Redis and `m6g.large.search` or larger for OpenSearch.

### Why DNS-01 only?

Same reason as `basic`: NLB + TCP passthrough means the container terminates TLS, but NLB won't route to unhealthy targets, and the container is unhealthy until it has a cert. DNS-01 breaks this chicken-and-egg via DNS API validation. Terraform's variable validation enforces `DNS-01`.

### DNS-01 with other providers

Same as `basic` — see that scenario's guide for Cloudflare/Namecheap examples.

---

## Step 4 — Deploy

```bash
terraform init
terraform plan    # review what will be created (~120 resources)
terraform apply   # type 'yes' to confirm
```

Apply takes **15–25 minutes** — OpenSearch provisioning alone is typically 10–15 min. When finished:

```
Outputs:
  shield_web_ui_url           = "https://shield.yourcompany.com/login"
  nlb_dns_name                = "managed-services-shield-xxxxx.elb.us-east-1.amazonaws.com"
  squid_nlb_dns_name          = "managed-services-squid-xxxxx.elb.us-east-1.amazonaws.com"
  squid_eips                  = ["203.0.113.10", "203.0.113.11"]
  elasticache_redis_endpoint  = "managed-services-redis.xxxxx.cache.amazonaws.com"
  opensearch_endpoint         = "vpc-managed-services-activity-xxxxx.us-east-1.es.amazonaws.com"
  opensearch_dashboard_endpoint = "vpc-managed-services-activity-xxxxx.us-east-1.es.amazonaws.com/_dashboards"
  squid_proxy_endpoint        = "managed-services-squid-xxxxx.elb.us-east-1.amazonaws.com:44509"
  ecs_cluster_name            = "managed-services"
  cloudwatch_dashboard_name   = "managed-services-shield"
```

---

## Step 5 — Point DNS at the NLB

**Skip if you used `route53_zone_id`** — the alias record was auto-created.

Otherwise, create an alias or CNAME in your DNS provider:

| Name | Type | Value |
|---|---|---|
| `shield.yourcompany.com` | CNAME | `managed-services-shield-xxxxx.elb.us-east-1.amazonaws.com` |

Verify:

```bash
dig +short shield.yourcompany.com
```

---

## Step 6 — Wait for services to come up and certificates to issue

Startup sequence:

1. ElastiCache Redis + OpenSearch come up (already ready at end of apply)
2. ECS services start Shield Web UI, ICAP, Alert, Squid
3. Shield Web UI connects to ElastiCache Redis + OpenSearch
4. Shield Web UI attempts Let's Encrypt DNS-01 certificate issuance
5. NLB health checks pass → HTTPS becomes reachable

**Total time after `terraform apply` completes: 5–15 minutes.**

Monitor:

- **ECS**: Clusters → `managed-services` → Services tab. All 4 should show `Running`.
- **CloudWatch Logs**: `aws logs tail /ecs/managed-services/shield-web-ui --follow`
- **NLB target health**: EC2 → Target groups → `managed-services-shield-https`

---

## Step 7 — Log in to the Shield Web UI

Open the `shield_web_ui_url` output:

```
https://shield.yourcompany.com/login
```

If you get a certificate warning, Let's Encrypt hasn't issued yet — wait a few more minutes.

---

## Step 8 — Access OpenSearch Dashboards (optional)

Use the `opensearch_dashboard_endpoint` output. OpenSearch is in private subnets, so you'll need to be on the VPC (via VPN, bastion, or AWS Client VPN) to reach it directly. For occasional admin access, set up a temporary bastion or use AWS SSM port forwarding:

```bash
aws ssm start-session \
  --target <ec2-or-ecs-exec-target> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="<opensearch-endpoint>",portNumber="443",localPortNumber="8443"
```

Then browse `https://localhost:8443/_dashboards`.

---

## Step 9 — Configure Squid proxy (optional)

The Squid proxy has its own NLB (separate from Shield Web UI's) and is reachable at `<squid_nlb_dns_name>:44509`, or the static `squid_eips` addresses directly. Set `proxy_host_name`, independent of `host_name` (which only covers Shield Web UI), to get an auto-created alias A record pointing it at the Squid NLB — required if `route53_zone_id` is set, optional otherwise. Install the MITM certificate (`cert.crt`) as a trusted root CA on any client routing traffic through it.

---

## Step 10 — Review CloudWatch monitoring

Dashboard name is the `cloudwatch_dashboard_name` output (default: `managed-services-shield`). Shows:

- Running task counts for 4 ECS services
- CPU and memory per service
- Error counts from Shield logs

Managed services come with their own CloudWatch metrics:

- **ElastiCache**: AWS namespace `AWS/ElastiCache` — cluster name is in `elasticache_redis_endpoint`
- **OpenSearch**: AWS namespace `AWS/ES` — domain name matches the prefix in `opensearch_endpoint`

Alarms are created for ECS services only. Add alarms for ElastiCache/OpenSearch via console if needed (e.g. CPU, storage, free memory).

---

## Updating the deployment

Rolling update for container images:

```hcl
shield_web_ui_image = "public.ecr.aws/nullafi/shield:v1.2.3"
```

```bash
terraform apply
```

**Managed service upgrades**:
- **ElastiCache engine version**: Change `redis_engine_version`. AWS performs the upgrade during the next maintenance window — can cause brief connection disruption.
- **OpenSearch engine version**: Change `opensearch_engine_version`. AWS performs blue/green upgrade (no downtime but takes 1–2 hours).

---

## Tearing down

```bash
terraform destroy
```

**Notes:**
- Destroy takes **20–40 minutes** — OpenSearch deletion alone can take 10–20 min.
- ElastiCache and OpenSearch may create final snapshots by default. If you want to skip those, edit the module configs (outside the scope of this guide).
- Any manually-created DNS records must be deleted manually.
- S3 log bucket may need `aws s3 rm s3://<bucket> --recursive` first.

---

## Troubleshooting

### Shield won't connect to Redis / OpenSearch

1. Check Shield logs: `aws logs tail /ecs/managed-services/shield-web-ui --follow`.
2. Verify endpoints in outputs match what Shield is configured with (injected as env vars automatically).
3. Verify security groups allow ECS task subnets → Redis (port 6379) and OpenSearch (port 443).

### OpenSearch creation fails with "service-linked role already exists"

Set `create_opensearch_service_linked_role = false` in tfvars. This happens when another stack (or earlier deploy) created the role.

### Let's Encrypt certificate never issues

Same as `basic` — check:
- `acme_dns01_provider` + credentials in `acme_dns01_env`
- `route53_zone_id` matches the zone containing `host_name`
- NACL UDP 53 + ephemeral rules are in place (Terraform adds them automatically)
- Not hitting Let's Encrypt rate limits (5 duplicate certs per domain per week)

### ECS tasks keep restarting

1. ECS → Clusters → `managed-services` → Services → your service → Events tab.
2. Container logs: `aws logs tail /ecs/managed-services/<service> --follow`.
3. Common causes: OOM, Redis/OpenSearch not reachable, license key invalid.

### OpenSearch "Too Many Requests" or "InvalidChangeBatch"

OpenSearch is sensitive to concurrent changes. Wait 5–10 minutes between `terraform apply` runs if possible.

---

## Variable reference

See `variables.tf` for all variables. Most-used:

| Variable | Required | Default | Description |
|---|---|---|---|
| `region` | yes | — | AWS region |
| `aws_access_key` / `aws_secret_key` | yes | — | AWS credentials |
| `shield_web_ui_image` | yes | — | Shield Web UI image |
| `shield_icap_image` | yes | — | Shield ICAP image |
| `shield_alert_image` | yes | — | Shield Alert image |
| `squid_image` | yes | — | Squid proxy image |
| `nullafi_license_key` | yes | — | Nullafi license key |
| `host_name` | required for HTTPS | `null` | Public hostname |
| `acme_challenge_type` | no | `DNS-01` | DNS-01 only (enforced) |
| `acme_dns01_provider` | yes (for HTTPS) | `null` | e.g. `route53`, `cloudflare` |
| `acme_dns01_env` | conditional | `{}` | Provider credentials (sensitive) |
| `route53_zone_id` | recommended if Route53 | `null` | Auto-creates A record + IAM |
| `proxy_host_name` | required if `route53_zone_id` set | `null` | Squid proxy hostname (its own NLB/A record, separate from `host_name`) |
| `proxy_mitm_cert` / `proxy_mitm_key` | no | `null` | Squid MITM cert files |
| `redis_node_type` | no | `cache.t3.small` | ElastiCache node size |
| `redis_engine_version` | no | `7.1` | Redis version |
| `opensearch_instance_type` | no | `t3.small.search` | OpenSearch node size |
| `opensearch_engine_version` | no | `OpenSearch_2.11` | OpenSearch version |
| `opensearch_volume_size` | no | `20` | EBS volume in GB |
| `create_opensearch_service_linked_role` | no | `true` | Set `false` if role exists |
| `name_prefix` | no | `managed-services` | Resource name prefix |
| `vpc_cidr` | no | `10.0.0.0/16` | VPC CIDR |
| `autoscaling_min_capacity` / `_max_capacity` | no | `1` / `4` | Default task count |
| `autoscaling_capacity` | no | `{}` | Per-service min/max overrides |
| `ecs_use_fargate_spot` | no | `false` | Use Fargate Spot |
| `ssm_parameters` | no | `{}` | Extra SSM Parameter Store entries |
| `tags` | no | `{}` | Tags applied to all resources |
