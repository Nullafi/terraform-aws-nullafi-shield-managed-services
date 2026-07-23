# ------------------------------------------------------------------------------
# Service discovery module – Cloud Map private DNS namespace and services
# ------------------------------------------------------------------------------

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = var.namespace_name
  description = var.namespace_description
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "main" {
  for_each = toset(var.service_names)

  name = each.value

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.main.id
    routing_policy = "MULTIVALUE"
    dns_records {
      ttl  = var.dns_ttl
      type = "A"
    }
  }
}
