resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.name
  server_id = var.server_id
  charset   = var.charset
  collation = var.collation

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
    }
  }
}
