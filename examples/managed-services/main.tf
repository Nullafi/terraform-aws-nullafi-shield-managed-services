# ------------------------------------------------------------------------------
# managed-services – example root config that calls the nullafi-shield-managed-services
# module with a managed data layer (ElastiCache Redis + Amazon OpenSearch).
# This is a standalone Terraform root config: it owns the provider and backend.
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

module "shield" {
  source = "../.."

  region               = var.region
  name_prefix          = var.name_prefix
  host_name            = var.host_name
  vpc_cidr             = var.vpc_cidr
  data_subnets_use_nat = var.data_subnets_use_nat
  availability_zones   = var.availability_zones

  ecs_container_insights_enabled = var.ecs_container_insights_enabled
  ecs_use_fargate_spot           = var.ecs_use_fargate_spot
  ecs_log_retention_days         = var.ecs_log_retention_days

  squid_image         = var.squid_image
  shield_web_ui_image = var.shield_web_ui_image
  shield_icap_image   = var.shield_icap_image
  shield_alert_image  = var.shield_alert_image

  redis_node_type      = var.redis_node_type
  redis_engine_version = var.redis_engine_version

  opensearch_instance_type              = var.opensearch_instance_type
  opensearch_engine_version             = var.opensearch_engine_version
  opensearch_volume_size                = var.opensearch_volume_size
  create_opensearch_service_linked_role = var.create_opensearch_service_linked_role

  nullafi_license_key_file = var.nullafi_license_key_file
  nullafi_license_key      = var.nullafi_license_key

  acme_challenge_type = var.acme_challenge_type
  acme_dns01_provider = var.acme_dns01_provider
  acme_dns01_env      = var.acme_dns01_env
  route53_zone_id     = var.route53_zone_id

  proxy_mitm_cert = var.proxy_mitm_cert
  proxy_mitm_key  = var.proxy_mitm_key
  proxy_root_ca   = var.proxy_root_ca
  proxy_port      = var.proxy_port

  autoscaling_min_capacity       = var.autoscaling_min_capacity
  autoscaling_max_capacity       = var.autoscaling_max_capacity
  autoscaling_capacity           = var.autoscaling_capacity
  autoscaling_target_cpu_percent = var.autoscaling_target_cpu_percent

  ssm_parameters = var.ssm_parameters

  tags = merge(var.tags, { Example = "managed-services" })
}
