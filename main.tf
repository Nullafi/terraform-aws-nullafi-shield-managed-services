# ------------------------------------------------------------------------------
# nullafi-shield-managed-services – VPC (single NAT), ECS cluster, service
# discovery, EFS, S3, NLB, 4x ECS services + managed ElastiCache Redis and
# Amazon OpenSearch. Shield Web UI exposed via NLB (TCP passthrough) with
# Let's Encrypt TLS. Other services use service discovery only.
#
# This is the module's root configuration. It does not configure a provider
# or backend — the caller (root config or example) owns those.
# ------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  azs = var.availability_zones != null ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
}

# ------------------------------------------------------------------------------
# VPC – single NAT gateway (cost savings); backend 8080, 443, 44509, 1344
# ------------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = local.azs
  single_nat_gateway   = true # single NAT for cost savings
  data_subnets_use_nat = var.data_subnets_use_nat

  tags = merge(var.tags, { Region = var.region })
}

# ------------------------------------------------------------------------------
# NLB – Shield Web UI (TCP passthrough; container handles TLS via Let's Encrypt)
# Port 80 → 8080 (ACME HTTP-01 challenges + HTTP), Port 443 → 443 (HTTPS)
# ------------------------------------------------------------------------------
resource "aws_lb" "shield_web" {
  name               = "${var.name_prefix}-shield"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnet_ids

  tags = merge(var.tags, { Name = "${var.name_prefix}-shield-nlb" })
}

resource "aws_lb_target_group" "shield_web_http" {
  name               = "${var.name_prefix}-shield-http"
  port               = 8080
  protocol           = "TCP"
  vpc_id             = module.vpc.vpc_id
  target_type        = "ip"

  health_check {
    enabled             = true
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = var.tags
}

resource "aws_lb_target_group" "shield_web_https" {
  name               = "${var.name_prefix}-shield-https"
  port               = 443
  protocol           = "TCP"
  vpc_id             = module.vpc.vpc_id
  target_type        = "ip"

  health_check {
    enabled             = true
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = var.tags
}

resource "aws_lb_listener" "shield_web_http" {
  load_balancer_arn = aws_lb.shield_web.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.shield_web_http.arn
  }
}

resource "aws_lb_listener" "shield_web_https" {
  load_balancer_arn = aws_lb.shield_web.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.shield_web_https.arn
  }
}

# ------------------------------------------------------------------------------
# Route53 A record (optional – auto-creates DNS when route53_zone_id is set)
# Points to the NLB so Let's Encrypt can reach the container.
# ------------------------------------------------------------------------------
resource "aws_route53_record" "shield_web" {
  count   = var.route53_zone_id != null && var.host_name != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.host_name
  type    = "A"

  alias {
    name                   = aws_lb.shield_web.dns_name
    zone_id                = aws_lb.shield_web.zone_id
    evaluate_target_health = true
  }
}

# ------------------------------------------------------------------------------
# Squid proxy – TCP passthrough on var.proxy_port via the same NLB
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "squid" {
  name               = "${var.name_prefix}-squid"
  port               = var.proxy_port
  protocol           = "TCP"
  vpc_id             = module.vpc.vpc_id
  target_type        = "ip"

  health_check {
    enabled             = true
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = var.tags
}

resource "aws_lb_listener" "squid" {
  load_balancer_arn = aws_lb.shield_web.arn
  port              = var.proxy_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.squid.arn
  }
}

# ------------------------------------------------------------------------------
# SSM Parameter Store – optional; pass ssm_parameters map
# ------------------------------------------------------------------------------
module "parameter_store" {
  source = "./modules/parameter-store"

  parameters = var.ssm_parameters
  tags       = var.tags
}

# ------------------------------------------------------------------------------
# Secrets Manager – license key (read from file or raw value)
# ------------------------------------------------------------------------------
locals {
  # Non-sensitive flag: is a license key available (via raw value or file)?
  has_license_key = (var.nullafi_license_key != null && var.nullafi_license_key != "") || var.nullafi_license_key_file != null
  license_key_value = (
    var.nullafi_license_key != null && var.nullafi_license_key != "" ? trimspace(var.nullafi_license_key) :
    var.nullafi_license_key_file != null ? trimspace(file(var.nullafi_license_key_file)) :
    null
  )
  license_key_secret_string = local.has_license_key ? local.license_key_value : null

  # MITM cert/key for Squid proxy (read from file paths)
  has_mitm_cert     = var.proxy_mitm_cert != null && var.proxy_mitm_key != null
  mitm_cert_content = local.has_mitm_cert ? file(var.proxy_mitm_cert) : null
  mitm_key_content  = local.has_mitm_cert ? file(nonsensitive(var.proxy_mitm_key)) : null

  # Root CA cert (issuer of the MITM cert — clients and shield containers must trust this)
  has_root_ca     = var.proxy_root_ca != null
  root_ca_content = local.has_root_ca ? file(var.proxy_root_ca) : null

  # Collect secret names to create
  secret_names = toset(concat(
    ["elastic-password"],
    nonsensitive(local.has_license_key) ? ["license-key"] : [],
    nonsensitive(local.has_mitm_cert) ? ["mitm-cert", "mitm-key"] : [],
    local.has_root_ca ? ["root-ca"] : []
  ))

  # Collect secret values
  secrets_map = merge(
    { "elastic-password" = { value = "elastic", recovery_window_in_days = 0 } },
    local.has_license_key ? { "license-key" = { value = local.license_key_secret_string, recovery_window_in_days = 0 } } : {},
    local.has_mitm_cert ? {
      "mitm-cert" = { value = local.mitm_cert_content, recovery_window_in_days = 0 }
      "mitm-key"  = { value = local.mitm_key_content, recovery_window_in_days = 0 }
    } : {},
    local.has_root_ca ? {
      "root-ca" = { value = local.root_ca_content, recovery_window_in_days = 0 }
    } : {}
  )
}

module "secrets" {
  source = "./modules/secrets"

  name_prefix  = var.name_prefix
  secret_names = local.secret_names
  secrets      = local.secrets_map
  tags         = var.tags
}

# ------------------------------------------------------------------------------
# S3 – logs and backups (before ECS so task role can reference policy)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "logs_backups" {
  bucket        = "${var.name_prefix}-logs-backups-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-logs-backups" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_backups" {
  bucket = aws_s3_bucket.logs_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "logs_backups" {
  bucket = aws_s3_bucket.logs_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "logs_backups" {
  bucket = aws_s3_bucket.logs_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "logs_backups" {
  bucket        = aws_s3_bucket.logs_backups.id
  target_bucket = aws_s3_bucket.logs_backups.id
  target_prefix = "s3-access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_backups" {
  bucket = aws_s3_bucket.logs_backups.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {
      prefix = ""
    }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    expiration {
      days = 365
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Allow ELB service to write access logs to S3 + enforce TLS
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "logs_backups" {
  bucket = aws_s3_bucket.logs_backups.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs_backups.arn,
          "${aws_s3_bucket.logs_backups.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "ALBAccessLogsELBAccount"
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.main.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs_backups.arn}/alb-*/*"
      },
      {
        Sid       = "ALBAccessLogsDelivery"
        Effect    = "Allow"
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs_backups.arn}/alb-*/*"
      },
      {
        Sid       = "ALBAccessLogsAclCheck"
        Effect    = "Allow"
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs_backups.arn
      }
    ]
  })
}

resource "aws_iam_policy" "s3_logs_backups" {
  name        = "${var.name_prefix}-ecs-task-s3-logs-backups"
  description = "Allow ECS tasks to write logs and backups to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.logs_backups.arn,
          "${aws_s3_bucket.logs_backups.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_efs" {
  name        = "${var.name_prefix}-ecs-task-efs"
  description = "Allow ECS tasks to mount EFS file systems (certs, config)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = [
          module.efs.file_system_arn,
          module.efs_certs.file_system_arn
        ]
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Route53 DNS-01 – allow ECS tasks to manage TXT records for ACME challenges
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "route53_dns01" {
  count       = var.route53_zone_id != null ? 1 : 0
  name        = "${var.name_prefix}-route53-dns01"
  description = "Allow ECS tasks to manage Route53 records for Let's Encrypt DNS-01 challenges"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        Effect   = "Allow"
        Action   = ["route53:GetChange", "route53:ListHostedZonesByName", "route53:ListHostedZones"]
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# ECS execution role – allow reading SSM parameters (for secrets in task definitions)
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "ecs_execution_ssm" {
  count = length(module.parameter_store.parameter_arns) > 0 ? 1 : 0

  name        = "${var.name_prefix}-ecs-execution-ssm"
  description = "Allow ECS task execution role to read SSM parameters for container secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameters"
        Resource = values(module.parameter_store.parameter_arns)
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# ECS execution role – allow reading Secrets Manager secrets (license key)
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "ecs_execution_secrets" {
  count = length(module.secrets.secret_arns_list) > 0 ? 1 : 0

  name        = "${var.name_prefix}-ecs-execution-secrets"
  description = "Allow ECS task execution role to read Secrets Manager secrets for container secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = module.secrets.secret_arns_list
      }
    ]
  })
}

# ECS execution role – allow creating/validating CloudWatch log group (fixes ResourceInitializationError)
resource "aws_iam_policy" "ecs_execution_logs" {
  name        = "${var.name_prefix}-ecs-execution-logs"
  description = "Allow ECS task execution role to create/describe CloudWatch log group for awslogs driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
        Resource = [
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.name_prefix}",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.name_prefix}:*"
        ]
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# ECS cluster and roles
# ------------------------------------------------------------------------------
module "ecs" {
  source = "./modules/ecs-fargate"

  name_prefix                = var.name_prefix
  log_retention_days         = var.ecs_log_retention_days
  container_insights_enabled = var.ecs_container_insights_enabled
  use_fargate_spot           = var.ecs_use_fargate_spot
  execution_role_policy_arns = merge(
    { "logs" = aws_iam_policy.ecs_execution_logs.arn },
    length(module.parameter_store.parameter_arns) > 0 ? { "ssm" = aws_iam_policy.ecs_execution_ssm[0].arn } : {},
    length(module.secrets.secret_arns_list) > 0 ? { "secrets" = aws_iam_policy.ecs_execution_secrets[0].arn } : {}
  )
  task_role_policy_arns = merge(
    {
      "s3-logs-backups" = aws_iam_policy.s3_logs_backups.arn
      "efs"             = aws_iam_policy.ecs_task_efs.arn
    },
    var.route53_zone_id != null ? { "route53" = aws_iam_policy.route53_dns01[0].arn } : {}
  )
  tags = merge(var.tags, { Region = var.region })
}

# ------------------------------------------------------------------------------
# Service discovery – namespace + services
# ------------------------------------------------------------------------------
module "service_discovery" {
  source = "./modules/service-discovery"

  namespace_name        = "${var.name_prefix}.local"
  namespace_description = "Private DNS namespace for ECS service discovery (internal)"
  vpc_id                = module.vpc.vpc_id
  service_names         = ["squid", "shield-web-ui", "shield-icap", "shield-alert"]

  tags = merge(var.tags, { Region = var.region })
}

# ------------------------------------------------------------------------------
# Security groups – backend (ECS), data (ECS), EFS mount targets
# NLB preserves client IPs so 8080/443 must allow 0.0.0.0/0 for external access.
# ------------------------------------------------------------------------------
resource "aws_security_group" "backend" {
  name_prefix = "${var.name_prefix}-backend-"
  description = "Backend ECS tasks (Squid, Shield Web UI, Shield ICAP, Shield Alert)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Shield Web UI (HTTP 8080) - NLB + VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Shield Web UI HTTPS (443) - NLB + VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Squid proxy (var.proxy_port) from VPC"
    from_port   = var.proxy_port
    to_port     = var.proxy_port
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description = "Shield ICAP"
    from_port   = 1344
    to_port     = 1344
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-backend" })
}

resource "aws_security_group" "efs" {
  name_prefix = "${var.name_prefix}-efs-"
  description = "EFS mount targets - NFS from backend"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "NFS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-efs" })
}

# ------------------------------------------------------------------------------
# VPC endpoint for CloudWatch Logs – ECS tasks in private subnets
# can reach the logs API without NAT
# ------------------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoint_logs" {
  name_prefix = "${var.name_prefix}-vpce-logs-"
  description = "CloudWatch Logs VPC endpoint - HTTPS from VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC for ECS tasks"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-vpce-logs" })
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.backend_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint_logs.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-logs-endpoint" })
}

# ------------------------------------------------------------------------------
# EFS – Shield config
# ------------------------------------------------------------------------------
module "efs" {
  source = "./modules/efs"

  name_prefix        = var.name_prefix
  subnet_ids         = module.vpc.backend_subnet_ids
  security_group_ids = [aws_security_group.efs.id]
  access_point_path  = "/shield"

  tags = var.tags
}

module "efs_certs" {
  source = "./modules/efs"

  name_prefix        = "${var.name_prefix}-certs"
  subnet_ids         = module.vpc.backend_subnet_ids
  security_group_ids = [aws_security_group.efs.id]
  access_point_path  = "/certs"

  tags = merge(var.tags, { Service = "shield-web-ui" })
}


# ------------------------------------------------------------------------------
# Container definition helpers (use existing ECR image URIs from variables)
# All 4 ECS services use awslogs -> CloudWatch log group for stdout/stderr.
# ------------------------------------------------------------------------------
locals {
  log_config = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = module.ecs.log_group_name
      "awslogs-region"        = var.region
      "awslogs-stream-prefix" = "ecs"
      "awslogs-create-group"  = "true"
    }
  }
  squid_image         = var.squid_image
  shield_web_ui_image = var.shield_web_ui_image
  shield_icap_image   = var.shield_icap_image
  shield_alert_image  = var.shield_alert_image

  # Per-service autoscaling min/max (defaults from autoscaling_min_capacity / autoscaling_max_capacity when not in map)
  service_capacity = {
    "squid"         = lookup(var.autoscaling_capacity, "squid", { min = var.autoscaling_min_capacity, max = var.autoscaling_max_capacity })
    "shield-web-ui" = lookup(var.autoscaling_capacity, "shield-web-ui", { min = var.autoscaling_min_capacity, max = var.autoscaling_max_capacity })
    "shield-icap"   = lookup(var.autoscaling_capacity, "shield-icap", { min = var.autoscaling_min_capacity, max = var.autoscaling_max_capacity })
    "shield-alert"  = lookup(var.autoscaling_capacity, "shield-alert", { min = var.autoscaling_min_capacity, max = var.autoscaling_max_capacity })
  }

  # SSM Parameter Store -> container secrets. Parameter path convention: /{name_prefix}/{service_name}/{ENV_VAR}
  # e.g. /nullafi/shield-web-ui/NULLAFI_ACTIVITY_DATABASE_URL -> env NULLAFI_ACTIVITY_DATABASE_URL in shield-web-ui
  service_ssm_secrets = {
    for svc in ["shield-web-ui", "shield-icap", "shield-alert", "squid"] :
    svc => [
      for path, arn in module.parameter_store.parameter_arns :
      { name = replace(path, "/${var.name_prefix}/${svc}/", ""), valueFrom = arn }
      if startswith(path, "/${var.name_prefix}/${svc}/")
    ]
  }

  # Secrets Manager -> container secrets for Shield services (license key as plain string)
  shield_secrets = local.has_license_key ? [
    { name = "NULLAFI_LICENSE_KEY_VALUE", valueFrom = module.secrets.secret_arns["license-key"] }
  ] : []

  shield_common_env = [
    { name = "NULLAFI_HTTP_CUSTOM_DOMAIN", value = var.host_name != null ? var.host_name : "" },
    { name = "NULLAFI_OPENSEARCH_AUTH_MODE", value = "aws_iam" },
    { name = "NULLAFI_ACTIVITY_DATABASE_URL", value = "https://${aws_opensearch_domain.activity.endpoint}:443" },
    { name = "NULLAFI_REDIS_URI", value = "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379/0" }
  ]

  # ACME/Let's Encrypt env vars for shield-web-ui
  shield_web_acme_env = var.host_name != null ? concat(
    [
      { name = "NULLAFI_HTTPS_ENABLED", value = "true" },
      { name = "NULLAFI_HTTPS_PORT", value = "443" },
      { name = "NULLAFI_HTTPS_ACME_CHALLENGE", value = var.acme_challenge_type },
      { name = "NULLAFI_HTTPS_ACME_CERT_DIR", value = "/data/certs" },
    ],
    var.acme_dns01_provider != null ? [
      { name = "NULLAFI_HTTPS_ACME_DNS01_PROVIDER", value = var.acme_dns01_provider },
    ] : [],
    var.route53_zone_id != null ? [
      { name = "AWS_HOSTED_ZONE_ID", value = var.route53_zone_id },
      { name = "AWS_REGION", value = var.region },
    ] : [],
    [for k, v in var.acme_dns01_env : { name = k, value = v }]
  ) : []

  # CA cert init container – writes root CA cert to shared volume for shield containers to trust
  ca_cert_init_container = local.has_root_ca ? [{
    name                   = "ca-cert-init"
    image                  = "public.ecr.aws/docker/library/busybox:latest"
    essential              = false
    readonlyRootFilesystem = true
    command                = ["sh", "-c", "echo \"$ROOT_CA\" > /ca-certs/nullafi-root-ca.crt"]
    mountPoints            = [{ sourceVolume = "ca-certs", containerPath = "/ca-certs", readOnly = false }]
    logConfiguration       = local.log_config
    secrets                = [{ name = "ROOT_CA", valueFrom = module.secrets.secret_arns["root-ca"] }]
  }] : []

  # Volume definition for CA certs (ephemeral, shared between init and main container)
  ca_certs_volume = local.has_root_ca ? [{
    name                     = "ca-certs"
    efs_volume_configuration = null
  }] : []

  # dependsOn for main container to wait for CA cert init
  ca_cert_depends_on = local.has_root_ca ? [{ containerName = "ca-cert-init", condition = "SUCCESS" }] : []

  # mountPoint for main container
  ca_cert_mount = local.has_root_ca ? [{ sourceVolume = "ca-certs", containerPath = "/usr/local/share/ca-certificates", readOnly = true }] : []
}

# ------------------------------------------------------------------------------
# ECS services – 4x ecs-service (no load_balancer blocks – service discovery only)
# ------------------------------------------------------------------------------
module "ecs_squid" {
  source = "./modules/ecs-service"

  family                         = "${var.name_prefix}-squid"
  cluster_arn                    = module.ecs.cluster_arn
  cpu                            = 256
  memory                         = 512 # compose mem_limit: 400m; Fargate min for 256 CPU is 512
  execution_role_arn             = module.ecs.execution_role_arn
  task_role_arn                  = module.ecs.task_role_arn
  subnet_ids                     = module.vpc.backend_subnet_ids
  security_group_ids             = [aws_security_group.backend.id]
  assign_public_ip               = false
  desired_count                  = local.service_capacity["squid"].min
  min_capacity                   = local.service_capacity["squid"].min
  max_capacity                   = local.service_capacity["squid"].max
  autoscaling_target_cpu_percent = var.autoscaling_target_cpu_percent
  service_registry_arn           = module.service_discovery.service_arns["squid"]

  volumes = [{
    name                     = "squid-certs"
    efs_volume_configuration = null
  }]

  load_balancer = {
    target_group_arn = aws_lb_target_group.squid.arn
    container_name   = "squid"
    container_port   = var.proxy_port
  }

  container_definitions = jsonencode(concat(
    # Init container: write MITM cert/key from Secrets Manager to shared volume
    local.has_mitm_cert ? [{
      name                   = "cert-init"
      image                  = "public.ecr.aws/docker/library/busybox:latest"
      essential              = false
      readonlyRootFilesystem = true
      command                = ["sh", "-c", "echo \"$MITM_CERT_CONTENT\" > /certs/custom.crt && echo \"$MITM_KEY_CONTENT\" > /certs/custom.pem && chmod 600 /certs/custom.pem"]
      mountPoints            = [{ sourceVolume = "squid-certs", containerPath = "/certs", readOnly = false }]
      logConfiguration       = local.log_config
      secrets = [
        { name = "MITM_CERT_CONTENT", valueFrom = module.secrets.secret_arns["mitm-cert"] },
        { name = "MITM_KEY_CONTENT", valueFrom = module.secrets.secret_arns["mitm-key"] }
      ]
    }] : [],
    # Main Squid container
    [{
      name                   = "squid"
      image                  = local.squid_image
      essential              = true
      readonlyRootFilesystem = false # Squid needs writable root for ssl_cert dir, cache, passwords
      portMappings           = [{ containerPort = var.proxy_port, protocol = "tcp" }]
      mountPoints            = [{ sourceVolume = "squid-certs", containerPath = "/etc/squid6/certs", readOnly = true }]
      logConfiguration       = local.log_config
      dependsOn              = local.has_mitm_cert ? [{ containerName = "cert-init", condition = "SUCCESS" }] : []
      environment = [
        { name = "BYPASS_URLS", value = "/etc/squid6/urls.txt" },
        { name = "MITM_CERT", value = "/etc/squid6/certs/custom.crt" },
        { name = "MITM_KEY", value = "/etc/squid6/certs/custom.pem" },
        { name = "ICAP_URL", value = "icap://shield-icap.${var.name_prefix}.local:1344" },
        { name = "ENABLE_ICAP", value = "yes" },
        { name = "MITM_PROXY", value = "yes" }
      ]
      secrets = local.service_ssm_secrets["squid"]
    }]
  ))

  tags = var.tags
}

module "ecs_shield_web" {
  source = "./modules/ecs-service"

  family                         = "${var.name_prefix}-shield-web-ui"
  cluster_arn                    = module.ecs.cluster_arn
  cpu                            = 512
  memory                         = 1024
  execution_role_arn             = module.ecs.execution_role_arn
  task_role_arn                  = module.ecs.task_role_arn
  subnet_ids                     = module.vpc.backend_subnet_ids
  security_group_ids             = [aws_security_group.backend.id]
  assign_public_ip               = false
  desired_count                  = local.service_capacity["shield-web-ui"].min
  min_capacity                   = local.service_capacity["shield-web-ui"].min
  max_capacity                   = local.service_capacity["shield-web-ui"].max
  autoscaling_target_cpu_percent = var.autoscaling_target_cpu_percent
  service_registry_arn           = module.service_discovery.service_arns["shield-web-ui"]

  load_balancers = [
    { target_group_arn = aws_lb_target_group.shield_web_http.arn, container_name = "shield-web-ui", container_port = 8080 },
    { target_group_arn = aws_lb_target_group.shield_web_https.arn, container_name = "shield-web-ui", container_port = 443 }
  ]

  volumes = concat(local.ca_certs_volume, [{
    name = "shield-certs"
    efs_volume_configuration = {
      file_system_id  = module.efs_certs.file_system_id
      root_directory  = "/"
      access_point_id = module.efs_certs.access_point_id
    }
  }])

  container_definitions = jsonencode(concat(local.ca_cert_init_container, [{
    name                   = "shield-web-ui"
    image                  = local.shield_web_ui_image
    essential              = true
    readonlyRootFilesystem = true
    portMappings = [
      { containerPort = 8080, protocol = "tcp" },
      { containerPort = 443, protocol = "tcp" }
    ]
    mountPoints = concat(local.ca_cert_mount, [
      { sourceVolume = "shield-certs", containerPath = "/data/certs", readOnly = false }
    ])
    logConfiguration = local.log_config
    dependsOn        = local.ca_cert_depends_on
    environment = concat(local.shield_common_env, local.shield_web_acme_env, [
      { name = "NULLAFI_SERVERMODE", value = "web" }
    ])
    secrets = concat(local.service_ssm_secrets["shield-web-ui"], local.shield_secrets)
  }]))

  tags = var.tags
}

module "ecs_shield_icap" {
  source = "./modules/ecs-service"

  family                         = "${var.name_prefix}-shield-icap"
  cluster_arn                    = module.ecs.cluster_arn
  cpu                            = 512
  memory                         = 1024 # 1 GB (compose mem_limit: 1g)
  execution_role_arn             = module.ecs.execution_role_arn
  task_role_arn                  = module.ecs.task_role_arn
  subnet_ids                     = module.vpc.backend_subnet_ids
  security_group_ids             = [aws_security_group.backend.id]
  assign_public_ip               = false
  desired_count                  = local.service_capacity["shield-icap"].min
  min_capacity                   = local.service_capacity["shield-icap"].min
  max_capacity                   = local.service_capacity["shield-icap"].max
  autoscaling_target_cpu_percent = var.autoscaling_target_cpu_percent
  service_registry_arn           = module.service_discovery.service_arns["shield-icap"]

  volumes = local.ca_certs_volume

  container_definitions = jsonencode(concat(local.ca_cert_init_container, [{
    name                   = "shield-icap"
    image                  = local.shield_icap_image
    essential              = true
    readonlyRootFilesystem = true
    portMappings           = [{ containerPort = 1344, protocol = "tcp" }]
    mountPoints            = local.ca_cert_mount
    logConfiguration       = local.log_config
    dependsOn              = local.ca_cert_depends_on
    environment = concat(local.shield_common_env, [
      { name = "NULLAFI_SERVERMODE", value = "icap" },
      { name = "NULLAFI_NODE_NAME", value = "Policy 1" }
    ])
    secrets = concat(local.service_ssm_secrets["shield-icap"], local.shield_secrets)
  }]))

  tags = var.tags
}

module "ecs_shield_alert" {
  source = "./modules/ecs-service"

  family                         = "${var.name_prefix}-shield-alert"
  cluster_arn                    = module.ecs.cluster_arn
  cpu                            = 256
  memory                         = 512
  execution_role_arn             = module.ecs.execution_role_arn
  task_role_arn                  = module.ecs.task_role_arn
  subnet_ids                     = module.vpc.backend_subnet_ids
  security_group_ids             = [aws_security_group.backend.id]
  assign_public_ip               = false
  desired_count                  = local.service_capacity["shield-alert"].min
  min_capacity                   = local.service_capacity["shield-alert"].min
  max_capacity                   = local.service_capacity["shield-alert"].max
  autoscaling_target_cpu_percent = var.autoscaling_target_cpu_percent
  service_registry_arn           = module.service_discovery.service_arns["shield-alert"]

  volumes = local.ca_certs_volume

  container_definitions = jsonencode(concat(local.ca_cert_init_container, [{
    name                   = "shield-alert"
    image                  = local.shield_alert_image
    essential              = true
    readonlyRootFilesystem = true
    portMappings           = []
    mountPoints            = local.ca_cert_mount
    logConfiguration       = local.log_config
    dependsOn              = local.ca_cert_depends_on
    environment = concat(local.shield_common_env, [
      { name = "NULLAFI_SERVERMODE", value = "alert" }
    ])
    secrets = concat(local.service_ssm_secrets["shield-alert"], local.shield_secrets)
  }]))

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Amazon ElastiCache Redis
# ------------------------------------------------------------------------------
resource "aws_security_group" "redis" {
  name_prefix = "${var.name_prefix}-redis-"
  description = "ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Redis from backend"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-redis" })
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name_prefix}-redis"
  subnet_ids = module.vpc.data_subnet_ids
  tags       = var.tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "${var.name_prefix} ElastiCache Redis"
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_clusters   = 1
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-redis" })
}

# ------------------------------------------------------------------------------
# Amazon OpenSearch Service (Activity / Elasticsearch replacement)
# ------------------------------------------------------------------------------
resource "aws_security_group" "opensearch" {
  name_prefix = "${var.name_prefix}-opensearch-"
  description = "Amazon OpenSearch Service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTPS from backend"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-opensearch" })
}

resource "aws_iam_service_linked_role" "opensearch" {
  count            = var.create_opensearch_service_linked_role ? 1 : 0
  aws_service_name = "opensearchservice.amazonaws.com"
}

resource "aws_opensearch_domain" "activity" {
  domain_name    = "${var.name_prefix}-activity"
  engine_version = var.opensearch_engine_version

  cluster_config {
    instance_type  = var.opensearch_instance_type
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.opensearch_volume_size
  }

  vpc_options {
    subnet_ids         = [module.vpc.data_subnet_ids[0]]
    security_group_ids = [aws_security_group.opensearch.id]
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "es:*"
      Resource  = "arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.name_prefix}-activity/*"
    }]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-activity" })

  depends_on = [aws_iam_service_linked_role.opensearch]
}
