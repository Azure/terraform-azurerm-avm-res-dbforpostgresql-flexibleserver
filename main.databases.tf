module "databases" {
  source   = "./modules/database"
  for_each = var.databases

  name                = each.value.name
  parent_id           = azapi_resource.this.id
  server_id           = azapi_resource.this.id
  charset             = each.value.charset
  collation           = each.value.collation
  enable_telemetry    = var.enable_telemetry
  location            = var.location
  timeouts            = each.value.timeouts != null ? each.value.timeouts : var.timeouts
  resource_types      = var.resource_types.dbforpostgresql_flexible_servers_databases
  ignore_body_changes = var.ignore_body_changes.dbforpostgresql_flexible_servers_databases
  retry               = var.retry
}
