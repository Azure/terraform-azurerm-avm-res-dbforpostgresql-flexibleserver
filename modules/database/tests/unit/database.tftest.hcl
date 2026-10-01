mock_provider "azurerm" {
  mock_resource "azurerm_postgresql_flexible_server_database" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex/databases/appdb"
    }
  }
}

mock_provider "azapi" {}

variables {
  charset   = "UTF8"
  collation = "en_US.utf8"
  name      = "appdb"
  server_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
}

run "standalone_database_exposes_outputs" {
  command = apply

  assert {
    condition     = output.name == "appdb" && output.resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex/databases/appdb" && output.id == output.resource_id
    error_message = "The standalone database must preserve its name, resource ID, and legacy ID output."
  }
}
