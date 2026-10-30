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

  # Entra authentication must be enabled before user databases are created so that Entra
  # principals can own them: https://learn.microsoft.com/azure/postgresql/security/security-entra-concepts
  depends_on = [azurerm_postgresql_flexible_server_active_directory_administrator.this]
}

moved {
  from = azurerm_postgresql_flexible_server_database.this
  to   = module.databases.azurerm_postgresql_flexible_server_database.this
}
