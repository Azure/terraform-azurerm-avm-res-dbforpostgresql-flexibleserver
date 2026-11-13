mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
      output = {
        properties = {
          fullyQualifiedDomainName = "test-flex.postgres.database.azure.com"
        }
      }
    }
  }

  mock_resource "azapi_update_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
      output = {
        properties = {}
      }
    }
  }
}

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

  providers = {
    azapi  = azapi
    random = random
  }

  assert {
    condition = (
      azapi_resource.this.body.sku.name == "Standard_D2s_v3" &&
      azapi_resource.this.body.sku.tier == "GeneralPurpose" &&
      azapi_resource.this.body.properties.version == "16" &&
      azapi_resource.this.body.properties.administratorLogin == "psqladmin"
    )
    error_message = "Root server resource must normalize SKU name/tier and set administratorLogin."
  }

  assert {
    condition = (
      output.fqdn == "test-flex.postgres.database.azure.com" &&
      output.name == "test-flex" &&
      output.resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
    )
    error_message = "The root module should expose standard server outputs."
  }

  assert {
    condition = (
      length(azapi_resource.private_endpoints_managed_dns_zone_groups) == 0 &&
      length(azapi_resource.private_endpoints_unmanaged_dns_zone_groups) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0 &&
      length(azapi_resource.private_endpoint_locks) == 0
    )
    error_message = "Omitted private endpoints must not create endpoints, permissions or locks."
  }

  assert {
    condition     = output.database_name["app"].name == "appdb"
    error_message = "The root module should expose the created database name."
  }

  assert {
    condition     = output.database_resource_ids["app"].resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
    error_message = "The root module should expose the created database resource ID."
  }
}

run "root_module_subordinate_resources" {
  command = apply

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    ad_administrator = {
      admin = {
        object_id      = "00000000-0000-0000-0000-000000000001"
        principal_name = "sqladmin@example.com"
        principal_type = "User"
        tenant_id      = "00000000-0000-0000-0000-000000000002"
      }
    }
    firewall_rules = {
      allow_office = {
        name             = "allow_office"
        start_ip_address = "203.0.113.1"
        end_ip_address   = "203.0.113.10"
      }
    }
    server_configuration = {
      work_mem = {
        name   = "work_mem"
        config = "64MB"
      }
    }
    virtual_endpoint = {
      ve = {
        name              = "ve-reader"
        replica_server_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-replica"
        type              = "ReadWrite"
      }
    }
    maintenance_window = {
      day_of_week  = "1"
      start_hour   = 2
      start_minute = 30
    }
  }

  assert {
    condition = (
      azapi_resource.administrators["admin"].name == "00000000-0000-0000-0000-000000000001" &&
      azapi_resource.administrators["admin"].body.properties.principalName == "sqladmin@example.com" &&
      azapi_resource.administrators["admin"].body.properties.principalType == "User" &&
      azapi_resource.administrators["admin"].body.properties.tenantId == "00000000-0000-0000-0000-000000000002"
    )
    error_message = "Active Directory administrators must be properly declared as AzAPI child resources."
  }

  assert {
    condition = (
      azapi_resource.firewall_rules["allow_office"].name == "allow_office" &&
      azapi_resource.firewall_rules["allow_office"].body.properties.startIpAddress == "203.0.113.1" &&
      azapi_resource.firewall_rules["allow_office"].body.properties.endIpAddress == "203.0.113.10"
    )
    error_message = "Firewall rules must be properly declared as AzAPI child resources."
  }

  assert {
    condition = (
      azapi_update_resource.configurations["work_mem"].name == "work_mem" &&
      azapi_update_resource.configurations["work_mem"].body.properties.value == "64MB" &&
      azapi_update_resource.configurations["work_mem"].body.properties.source == "user-override"
    )
    error_message = "Configurations must be updated using azapi_update_resource."
  }

  assert {
    condition = (
      azapi_resource.virtual_endpoints["ve"].name == "ve-reader" &&
      azapi_resource.virtual_endpoints["ve"].body.properties.endpointType == "ReadWrite" &&
      azapi_resource.virtual_endpoints["ve"].body.properties.members[0] == "test-replica"
    )
    error_message = "Virtual endpoints must extract replica member server names."
  }

  assert {
    condition = (
      length(azapi_update_resource.maintenance_window) == 1 &&
      azapi_update_resource.maintenance_window[0].body.properties.maintenanceWindow.customWindow == "Enabled" &&
      azapi_update_resource.maintenance_window[0].body.properties.maintenanceWindow.dayOfWeek == 1 &&
      azapi_update_resource.maintenance_window[0].body.properties.maintenanceWindow.startHour == 2 &&
      azapi_update_resource.maintenance_window[0].body.properties.maintenanceWindow.startMinute == 30
    )
    error_message = "Maintenance window must be updated on the server using azapi_update_resource."
  }
}

run "database_submodule_can_be_used_directly" {
  command = apply

  providers = {
    azapi = azapi
  }

  module {
    source = "./modules/database"
  }

  variables {
    charset   = "UTF8"
    collation = "en_US.utf8"
    name      = "appdb"
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
  }

  assert {
    condition     = output.name == "appdb"
    error_message = "The database submodule should expose the database name when used directly."
  }

  assert {
    condition     = output.resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
    error_message = "The database submodule should expose the database resource ID when used directly."
  }
}
