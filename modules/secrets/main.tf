# ------------------------------------------------------------------------------
# AWS Secrets Manager – create secrets from a map; optional initial value
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "main" {
  for_each = var.secret_names

  name                    = "${var.name_prefix}/${each.value}"
  description             = "Managed by Terraform (secrets module)"
  recovery_window_in_days = try(nonsensitive(var.secrets[each.value].recovery_window_in_days), 30)
  kms_key_id              = var.kms_key_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${replace(each.value, "/", "-")}"
  })
}

resource "aws_secretsmanager_secret_version" "main" {
  for_each = var.secret_names

  secret_id     = aws_secretsmanager_secret.main[each.value].id
  secret_string = var.secrets[each.value].value
}
