mock_provider "azurerm" {
  mock_resource "azurerm_postgresql_flexible_server_database" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/shared-flex/databases/appdb"
      name = "appdb"
    }
  }
}

variables {
  charset   = "UTF8"
  collation = "en_US.utf8"
  name      = "appdb"
  server_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/shared-flex"
}

run "database_submodule_can_be_used_directly" {
  command = apply

  assert {
    condition     = output.name == "appdb"
    error_message = "The database submodule should expose the database name when used directly."
  }

  assert {
    condition     = output.resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/shared-flex/databases/appdb"
    error_message = "The database submodule should expose the database resource ID when used directly."
  }
}
