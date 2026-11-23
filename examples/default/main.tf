terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azapi" {}

data "azapi_client_config" "current" {}

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azapi"
  version = "~> 0.1"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"
}

# This is required for resource modules
resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = module.naming.resource_group.name_unique
  parent_id = data.azapi_client_config.current.subscription_resource_id
  location  = "australiaeast"
}

resource "random_password" "myadminpassword" {
  length           = 16
  override_special = "_%@"
  special          = true
}

# This is the module call
module "test" {
  source = "../../"

  location                     = azapi_resource.resource_group.location
  name                         = module.naming.postgresql_server.name_unique
  resource_group_name          = azapi_resource.resource_group.name
  administrator_login          = "psqladmin"
  administrator_password       = random_password.myadminpassword.result
  enable_telemetry             = var.enable_telemetry
  geo_redundant_backup_enabled = true
  high_availability = {
    mode                      = "ZoneRedundant"
    standby_availability_zone = 2
  }
  server_version = 16
  sku_name       = "GP_Standard_D2s_v3"
  tags           = null
  zone           = 1
}
