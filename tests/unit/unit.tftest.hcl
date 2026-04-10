mock_provider "azurerm" {
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      fqdn                = "test-flex.postgres.database.azure.com"
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
      name                = "test-flex"
      resource_group_name = "rg-test"
    }
  }

  mock_resource "azurerm_postgresql_flexible_server_database" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex/databases/appdb"
      name = "appdb"
    }
  }
}

variables {
  administrator_login               = "psqladmin"
  administrator_password            = null
  administrator_password_wo         = "P@ssw0rd1234!"
  administrator_password_wo_version = "1"
  databases = {
    app = {
      charset   = "UTF8"
      collation = "en_US.utf8"
      name      = "appdb"
    }
  }
  enable_telemetry    = false
  location            = "eastus"
  name                = "test-flex"
  resource_group_name = "rg-test"
  server_version      = 16
  sku_name            = "GP_Standard_D2s_v3"
}

run "root_module_exposes_database_outputs" {
  command = apply

  assert {
    condition     = output.database_name["app"].name == "appdb"
    error_message = "The root module should expose the created database name."
  }

  assert {
    condition     = output.database_resource_ids["app"].resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex/databases/appdb"
    error_message = "The root module should expose the created database resource ID."
  }
}

