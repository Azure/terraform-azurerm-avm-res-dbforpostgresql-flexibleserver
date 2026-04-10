module "databases" {
  source   = "./modules/database"
  for_each = var.databases

  name      = each.value.name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = each.value.charset
  collation = each.value.collation
  timeouts  = each.value.timeouts
}

moved {
  from = azurerm_postgresql_flexible_server_database.this
  to   = module.databases.azurerm_postgresql_flexible_server_database.this
}

