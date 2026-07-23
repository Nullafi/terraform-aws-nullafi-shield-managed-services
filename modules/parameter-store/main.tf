# ------------------------------------------------------------------------------
# SSM Parameter Store – create parameters from a map; optional sensitive (SecureString)
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "main" {
  for_each = var.parameters

  name        = each.key
  description = "Managed by Terraform (parameter-store module)"
  type        = each.value.sensitive ? "SecureString" : "String"
  value       = each.value.value

  tags = merge(var.tags, {
    Name = replace(each.key, "/", "-")
  })
}
