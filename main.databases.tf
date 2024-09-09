resource "azurerm_postgresql_database" "this" {
  for_each = var.databases

  charset             = each.value.charset
  collation           = each.value.collation
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  server_name         = each.value.server_name

  dynamic "timeouts" {
    for_each = each.value.timeouts == null ? [] : [each.value.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
    }
  }
}

