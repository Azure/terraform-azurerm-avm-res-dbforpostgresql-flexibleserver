module "databases" {
  source   = "./modules/database"
  for_each = var.databases

  location         = var.location
  name             = each.value.name
  server_id        = azurerm_postgresql_flexible_server.this.id
  charset          = each.value.charset
  collation        = each.value.collation
  enable_telemetry = var.enable_telemetry
  timeouts         = each.value.timeouts
}

moved {
  from = azurerm_postgresql_flexible_server_database.this
  to   = module.databases.azurerm_postgresql_flexible_server_database.this
}
