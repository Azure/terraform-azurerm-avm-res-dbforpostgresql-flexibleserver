provider "azurerm" {
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.DBforPostgreSQL", "Microsoft.Insights", "Microsoft.OperationalInsights"]

  features {}
}

data "azapi_client_config" "this" {}

resource "random_string" "suffix" {
  length  = 10
  special = false
  upper   = false
}

resource "random_password" "administrator" {
  length  = 24
  special = false
}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-postgresql-diagnostics-${random_string.suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.this.subscription_id}"
  type                   = var.resource_types.resources_resource_groups
  ignore_body_changes    = length(var.ignore_body_changes.resources_resource_groups) > 0 ? var.ignore_body_changes.resources_resource_groups : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

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

resource "azapi_resource" "workspace" {
  location  = var.location
  name      = "law-postgresql-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.operationalinsights_workspaces
  body = {
    properties = {
      retentionInDays = 30
      sku = {
        name = "PerGB2018"
      }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.operationalinsights_workspaces) > 0 ? var.ignore_body_changes.operationalinsights_workspaces : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

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

module "server" {
  source = "../../"

  location               = azapi_resource.resource_group.location
  name                   = "psql-${random_string.suffix.result}"
  resource_group_name    = azapi_resource.resource_group.name
  administrator_login    = "psqladmin"
  administrator_password = random_password.administrator.result
  databases = {
    app = {
      charset   = "UTF8"
      collation = "en_US.utf8"
      name      = "appdb"
    }
  }
  diagnostic_settings = {
    monitoring = {
      workspace_resource_id = azapi_resource.workspace.id
    }
  }
  enable_telemetry             = var.enable_telemetry
  geo_redundant_backup_enabled = true
  high_availability = {
    mode                      = "ZoneRedundant"
    standby_availability_zone = 2
  }
  server_version = "16"
  sku_name       = "GP_Standard_D2s_v3"
  storage_mb     = 32768
  tags           = var.tags
  zone           = 1
}
