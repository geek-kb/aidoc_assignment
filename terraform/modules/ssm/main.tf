resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name        = each.value.name
  type        = each.value.type
  value       = each.value.value
  description = lookup(each.value, "description", null)
  key_id      = lookup(each.value, "key_id", null)
  overwrite   = lookup(each.value, "overwrite", false)

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {})
  )
}

