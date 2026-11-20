resource "azapi_resource" "this" {
  type      = var.resource_types.dbforpostgresql_flexible_servers_databases
  name      = var.name
  parent_id = var.parent_id != null ? var.parent_id : var.server_id
  body = {
    properties = {
      charset   = var.charset
      collation = var.collation
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.dbforpostgresql_flexible_servers_databases) > 0 ? var.ignore_body_changes.dbforpostgresql_flexible_servers_databases : null
  locks                  = [var.parent_id != null ? var.parent_id : var.server_id]
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

moved {
  from = azurerm_postgresql_flexible_server_database.this
  to   = azapi_resource.this
}
