terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}


## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = "~> 0.8"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = "australiaeast" #module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

resource "random_password" "myadminpassword" {
  length           = 16
  override_special = "_%@"
  special          = true
}

# This is the module call
# Do not specify location here due to the randomization above.
# Leaving location as `null` will cause the module to use the resource group location
# with a data source.
module "test" {
  source = "../../"

  location               = azurerm_resource_group.this.location
  name                   = module.naming.postgresql_server.name_unique
  resource_group_name    = azurerm_resource_group.this.name
  administrator_login    = "psqladmin"
  administrator_password = random_password.myadminpassword.result
  enable_telemetry       = var.enable_telemetry
  high_availability = {
    mode                      = "ZoneRedundant"
    standby_availability_zone = 2
  }
  server_version = 16
  sku_name       = "GP_Standard_D2s_v3"
  tags           = null
  zone           = 1
}
