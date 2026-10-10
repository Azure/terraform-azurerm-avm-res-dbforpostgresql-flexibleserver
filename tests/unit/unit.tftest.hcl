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

  mock_resource "azurerm_private_endpoint" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateEndpoints/test-private-endpoint"
    }
  }
}

mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}

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
    condition     = output.fqdn == "test-flex.postgres.database.azure.com" && output.resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
    error_message = "The root module should preserve the server FQDN and resource ID outputs."
  }

  assert {
    condition     = !azurerm_postgresql_flexible_server.this.public_network_access_enabled && one(azurerm_postgresql_flexible_server.this.high_availability).mode == "ZoneRedundant"
    error_message = "The default server should retain private access and zone-redundant high availability."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 0
    error_message = "Diagnostic settings should remain optional."
  }

  assert {
    condition     = output.database_name["app"].name == "appdb"
    error_message = "The root module should expose the created database name."
  }

  assert {
    condition     = output.database_resource_ids["app"].resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex/databases/appdb"
    error_message = "The root module should expose the created database resource ID."
  }
}

run "diagnostic_settings_enable_default_metrics" {
  command = apply

  variables {
    diagnostic_settings = {
      default = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/test-workspace"
      }
    }
  }

  assert {
    condition     = one(azurerm_monitor_diagnostic_setting.this["default"].enabled_metric).category == "AllMetrics"
    error_message = "The default AllMetrics category must use the enabled_metric block supported by AzureRM 4 and 5."
  }

  assert {
    condition     = one(azurerm_monitor_diagnostic_setting.this["default"].enabled_log).category_group == "allLogs"
    error_message = "The default allLogs group must remain enabled."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.this["default"].name == "diag-test-flex" && azurerm_monitor_diagnostic_setting.this["default"].target_resource_id == output.resource_id && azurerm_monitor_diagnostic_setting.this["default"].log_analytics_workspace_id == var.diagnostic_settings["default"].workspace_resource_id
    error_message = "Diagnostic settings must preserve their generated name, server target, and workspace destination."
  }
}

run "diagnostic_settings_allow_logs_without_metrics" {
  command = apply

  variables {
    diagnostic_settings = {
      logs = {
        name                  = "postgresql-logs"
        log_categories        = ["PostgreSQLLogs"]
        log_groups            = []
        metric_categories     = []
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/test-workspace"
      }
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this["logs"].enabled_metric) == 0
    error_message = "An empty metric_categories set must omit enabled_metric blocks."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.this["logs"].name == "postgresql-logs" && one(azurerm_monitor_diagnostic_setting.this["logs"].enabled_log).category == "PostgreSQLLogs"
    error_message = "Explicit diagnostic names and log categories must be preserved when metrics are disabled."
  }
}

run "customer_managed_keys_use_key_urls" {
  command = apply

  variables {
    customer_managed_key = {
      key_vault_key_id                     = "https://test-vault.vault.azure.net/keys/server-key/00000000000000000000000000000001"
      geo_backup_key_vault_key_id          = "https://test-vault.vault.azure.net/keys/backup-key/00000000000000000000000000000002"
      primary_user_assigned_identity_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/server-identity"
      geo_backup_user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/backup-identity"
    }
    managed_identities = {
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/server-identity",
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/backup-identity",
      ]
    }
    geo_redundant_backup_enabled = true
  }

  assert {
    condition     = one(azurerm_postgresql_flexible_server.this.customer_managed_key).key_vault_key_id == var.customer_managed_key.key_vault_key_id && one(azurerm_postgresql_flexible_server.this.customer_managed_key).geo_backup_key_vault_key_id == var.customer_managed_key.geo_backup_key_vault_key_id
    error_message = "Primary and backup Key Vault key URLs must remain compatible with AzureRM 5 validation."
  }
}

run "private_endpoints_manage_dns_zone_groups" {
  command = apply

  variables {
    private_endpoints = {
      app = {
        subnet_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/private-endpoints"
        private_dns_zone_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com"]
      }
    }
  }

  assert {
    condition     = length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 0 && toset(one(output.private_endpoints["app"].private_dns_zone_group).private_dns_zone_ids) == var.private_endpoints["app"].private_dns_zone_resource_ids
    error_message = "Managed private endpoints must preserve their DNS zone groups and output mapping."
  }
}

run "private_endpoints_allow_external_dns_management" {
  command = apply

  variables {
    private_endpoints_manage_dns_zone_group = false
    private_endpoints = {
      app = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/private-endpoints"
      }
    }
  }

  assert {
    condition     = length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 0 && length(output.private_endpoints["app"].private_dns_zone_group) == 0 && one(output.private_endpoints["app"].private_service_connection).private_connection_resource_id == output.resource_id
    error_message = "Externally managed DNS must omit the zone group while retaining the server connection and endpoint output."
  }
}

run "database_submodule_can_be_used_directly" {
  command = apply

  module {
    source = "./modules/database"
  }

  variables {
    charset   = "UTF8"
    collation = "en_US.utf8"
    name      = "appdb"
    server_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
  }

  assert {
    condition     = output.name == "appdb"
    error_message = "The database submodule should expose the database name when used directly."
  }

  assert {
    condition     = output.resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex/databases/appdb"
    error_message = "The database submodule should expose the database resource ID when used directly."
  }
}
