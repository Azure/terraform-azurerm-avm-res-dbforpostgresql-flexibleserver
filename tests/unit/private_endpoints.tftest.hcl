mock_provider "azurerm" {
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
    }
  }

  mock_resource "azurerm_private_endpoint" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-endpoints/providers/Microsoft.Network/privateEndpoints/pe-test"
    }
  }
}

mock_provider "azapi" {
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        role_definitions = [{
          id   = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          name = "Reader"
        }]
      }
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "22222222-2222-4222-8222-222222222222"
    }
  }
}

variables {
  enable_telemetry    = false
  location            = "eastus"
  name                = "test-flex"
  resource_group_name = "rg-test"
  server_version      = "16"
  sku_name            = "GP_Standard_D2s_v3"
  tags                = { server_only = "true" }
  private_endpoints = {
    supplied = {
      name                                    = "pe-custom"
      subnet_resource_id                      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
      subresource_name                        = "supplied-subresource"
      private_dns_zone_group_name             = "custom-zone-group"
      private_dns_zone_resource_ids           = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com"]
      application_security_group_associations = { clients = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/applicationSecurityGroups/clients" }
      private_service_connection_name         = "connection-custom"
      network_interface_name                  = "nic-custom"
      location                                = "westus2"
      resource_group_name                     = "rg-endpoints"
      tags                                    = { endpoint_only = "true" }
      ip_configurations = {
        supplied = {
          name               = "ip-custom"
          private_ip_address = "10.0.0.10"
          member_name        = "supplied-member"
        }
      }
      lock = {
        kind  = "ReadOnly"
        name  = "endpoint-lock"
        notes = "Endpoint lock notes"
      }
      role_assignments = {
        supplied = {
          name                                   = "11111111-1111-4111-8111-111111111111"
          role_definition_id_or_name             = "Reader"
          principal_id                           = "33333333-3333-4333-8333-333333333333"
          description                            = "Endpoint access"
          skip_service_principal_aad_check       = true
          condition                              = "!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})"
          condition_version                      = "2.0"
          delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
          principal_type                         = "Group"
        }
        generated = {
          role_definition_id_or_name       = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
          principal_id                     = "44444444-4444-4444-8444-444444444444"
          skip_service_principal_aad_check = false
        }
      }
    }
  }
}

run "managed_defaults" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    lock = { kind = "ReadOnly" }
    private_endpoints = {
      defaults = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        ip_configurations = {
          static = { name = "ip-default", private_ip_address = "10.0.0.11" }
        }
      }
    }
  }

  assert {
    condition = (
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 0 &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].name == "pe-test-flex" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].resource_group_name == "rg-test" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].location == "eastus" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].custom_network_interface_name == null &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].tags == null &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].private_service_connection).name == "pse-test-flex" &&
      one(one(azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].private_service_connection).subresource_names) == "postgresqlServer" &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].ip_configuration).member_name == "postgresqlServer" &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].ip_configuration).subresource_name == "postgresqlServer" &&
      length(azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].private_dns_zone_group) == 0
    )
    error_message = "Managed endpoint addresses, names, location, tags, NIC and PostgreSQL service/IP defaults must remain unchanged."
  }

  assert {
    condition = (
      length(azapi_resource.private_endpoint_locks) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0 &&
      length(random_uuid.private_endpoint_role_assignment) == 0 &&
      length(data.azapi_resource_list.private_endpoint_role_definitions) == 0
    )
    error_message = "Omitted endpoint locks and roles must create no attachments or lookups, even with a server lock."
  }
}

run "unmanaged_defaults" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints_manage_dns_zone_group = false
    private_endpoints = {
      defaults = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        ip_configurations = {
          static = { name = "ip-default", private_ip_address = "10.0.0.11", member_name = null }
        }
      }
    }
  }

  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 0 &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].name == "pe-test-flex" &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].resource_group_name == "rg-test" &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].location == "eastus" &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].custom_network_interface_name == null &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].tags == null &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].private_service_connection).name == "pse-test-flex" &&
      one(one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].private_service_connection).subresource_names) == "postgresqlServer" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].ip_configuration).member_name == "postgresqlServer" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].ip_configuration).subresource_name == "postgresqlServer" &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["defaults"].private_dns_zone_group) == 0 &&
      length(azapi_resource.private_endpoint_locks) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0
    )
    error_message = "Unmanaged endpoints must preserve the same historical defaults and must not manage DNS groups."
  }
}

run "explicit_nulls" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = {
      nulls = {
        name                                    = null
        subnet_resource_id                      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        subresource_name                        = null
        role_assignments                        = null
        lock                                    = null
        tags                                    = null
        private_dns_zone_group_name             = null
        private_dns_zone_resource_ids           = null
        application_security_group_associations = null
        private_service_connection_name         = null
        network_interface_name                  = null
        location                                = null
        resource_group_name                     = null
        ip_configurations                       = null
      }
    }
  }

  assert {
    condition = (
      azurerm_private_endpoint.this_managed_dns_zone_groups["nulls"].name == "pe-test-flex" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["nulls"].location == "eastus" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["nulls"].resource_group_name == "rg-test" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["nulls"].tags == null &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["nulls"].custom_network_interface_name == null &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["nulls"].private_service_connection).name == "pse-test-flex" &&
      one(one(azurerm_private_endpoint.this_managed_dns_zone_groups["nulls"].private_service_connection).subresource_names) == "postgresqlServer" &&
      length(azurerm_private_endpoint.this_managed_dns_zone_groups["nulls"].ip_configuration) == 0 &&
      length(azurerm_private_endpoint.this_managed_dns_zone_groups["nulls"].private_dns_zone_group) == 0 &&
      length(azurerm_private_endpoint_application_security_group_association.this) == 0 &&
      length(azapi_resource.private_endpoint_locks) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0 &&
      var.private_endpoints["nulls"].private_dns_zone_group_name == "default"
    )
    error_message = "Explicit nulls must retain legacy defaults without adding DNS groups, IPs, roles, locks or tags."
  }
}

run "managed_supplied_fields" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 5
      max_interval_seconds = 20
    }
    timeouts = { create = "10m", read = "2m", update = "10m", delete = "5m" }
  }

  assert {
    condition = (
      azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].name == "pe-custom" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].resource_group_name == "rg-endpoints" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].location == "westus2" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].custom_network_interface_name == "nic-custom" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].tags == tomap({ endpoint_only = "true" }) &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].private_service_connection).name == "connection-custom" &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].private_service_connection).private_connection_resource_id == azurerm_postgresql_flexible_server.this.id &&
      one(one(azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].private_service_connection).subresource_names) == "supplied-subresource" &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].ip_configuration).member_name == "supplied-member" &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].ip_configuration).subresource_name == "supplied-subresource" &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].ip_configuration).name == "ip-custom" &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].ip_configuration).private_ip_address == "10.0.0.10" &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].private_dns_zone_group).name == "custom-zone-group" &&
      toset(one(azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].private_dns_zone_group).private_dns_zone_ids) == var.private_endpoints["supplied"].private_dns_zone_resource_ids
    )
    error_message = "Managed endpoints must bind supplied fields, preserve endpoint-only tags, and retain DNS and IP selections."
  }

  assert {
    condition = (
      azurerm_private_endpoint_application_security_group_association.this["supplied-clients"].private_endpoint_id == azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].id &&
      azurerm_private_endpoint_application_security_group_association.this["supplied-clients"].application_security_group_id == var.private_endpoints["supplied"].application_security_group_associations["clients"] &&
      azapi_resource.private_endpoint_locks["supplied"].parent_id == azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].id &&
      azapi_resource.private_endpoint_locks["supplied"].name == "endpoint-lock" &&
      azapi_resource.private_endpoint_locks["supplied"].type == "Microsoft.Authorization/locks@2016-09-01" &&
      azapi_resource.private_endpoint_locks["supplied"].body.properties.level == "ReadOnly" &&
      azapi_resource.private_endpoint_locks["supplied"].body.properties.notes == "Endpoint lock notes" &&
      azapi_resource.private_endpoint_locks["supplied"].retry.interval_seconds == 5 &&
      azapi_resource.private_endpoint_locks["supplied"].timeouts.delete == "5m"
    )
    error_message = "The existing ASG key/scope and every supplied lock field must be honored."
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].parent_id == azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].id &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].name == "11111111-1111-4111-8111-111111111111" &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].type == "Microsoft.Authorization/roleAssignments@2022-04-01" &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].body.properties.roleDefinitionId == data.azapi_resource_list.private_endpoint_role_definitions["supplied"].output.role_definitions[0].id &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].body.properties.principalId == "33333333-3333-4333-8333-333333333333" &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].body.properties.principalType == "Group" &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].body.properties.description == "Endpoint access" &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].body.properties.condition == var.private_endpoints["supplied"].role_assignments["supplied"].condition &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].body.properties.conditionVersion == "2.0" &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].body.properties.delegatedManagedIdentityResourceId == var.private_endpoints["supplied"].role_assignments["supplied"].delegated_managed_identity_resource_id &&
      length(azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].body.properties) == 7 &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].retry.max_interval_seconds == 20 &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"supplied\"]"].timeouts.create == "10m"
    )
    error_message = "Named roles must resolve at the endpoint scope and bind name, principal, description, condition, delegation and principal type without inventing an ARM skip-AAD property."
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"generated\"]"].name == "22222222-2222-4222-8222-222222222222" &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"generated\"]"].body.properties.roleDefinitionId == var.private_endpoints["supplied"].role_assignments["generated"].role_definition_id_or_name &&
      azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"generated\"]"].body.properties.principalId == "44444444-4444-4444-8444-444444444444" &&
      length(azapi_resource.private_endpoint_role_assignments["[\"supplied\",\"generated\"]"].body.properties) == 2 &&
      data.azapi_resource_list.private_endpoint_role_definitions["supplied"].parent_id == azurerm_private_endpoint.this_managed_dns_zone_groups["supplied"].id &&
      data.azapi_resource_list.private_endpoint_role_definitions["supplied"].type == "Microsoft.Authorization/roleDefinitions@2022-04-01" &&
      data.azapi_resource_list.private_endpoint_role_definitions["supplied"].timeouts.read == "2m"
    )
    error_message = "Role IDs must pass through unchanged, omitted names must use UUIDs, and null optional properties must stay absent."
  }
}

run "unmanaged_supplied_fields" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints_manage_dns_zone_group = false
  }

  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 0 &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].name == "pe-custom" &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].location == "westus2" &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].resource_group_name == "rg-endpoints" &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].custom_network_interface_name == "nic-custom" &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].tags == tomap({ endpoint_only = "true" }) &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].private_service_connection).name == "connection-custom" &&
      one(one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].private_service_connection).subresource_names) == "supplied-subresource" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].ip_configuration).member_name == "supplied-member" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].ip_configuration).subresource_name == "supplied-subresource" &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].private_dns_zone_group) == 0 &&
      azapi_resource.private_endpoint_locks["supplied"].parent_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].id &&
      azapi_resource.private_endpoint_locks["supplied"].body.properties.notes == "Endpoint lock notes" &&
      azurerm_private_endpoint_application_security_group_association.this["supplied-clients"].private_endpoint_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].id &&
      alltrue([for assignment in azapi_resource.private_endpoint_role_assignments : assignment.parent_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["supplied"].id])
    )
    error_message = "Unmanaged DNS selection must preserve all endpoint fields and correctly scope roles, locks and ASG associations without creating a DNS group."
  }
}

run "attachment_defaults_and_empty_tags" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = {
      defaults = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        tags               = {}
        lock               = { kind = "CanNotDelete", name = null, notes = null }
        role_assignments = {
          reader = {
            name                       = null
            principal_id               = "33333333-3333-4333-8333-333333333333"
            role_definition_id_or_name = "Reader"
          }
        }
        private_dns_zone_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com"]
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_locks["defaults"].name == "lock-CanNotDelete" &&
      azapi_resource.private_endpoint_locks["defaults"].body.properties.level == "CanNotDelete" &&
      length(azapi_resource.private_endpoint_locks["defaults"].body.properties) == 1 &&
      azapi_resource.private_endpoint_role_assignments["[\"defaults\",\"reader\"]"].name == "22222222-2222-4222-8222-222222222222" &&
      length(azapi_resource.private_endpoint_role_assignments["[\"defaults\",\"reader\"]"].body.properties) == 2 &&
      length(azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].tags) == 0 &&
      one(azurerm_private_endpoint.this_managed_dns_zone_groups["defaults"].private_dns_zone_group).name == "default"
    )
    error_message = "Default attachment names, absent optional ARM properties, empty endpoint tags and the existing DNS group name must be preserved."
  }
}

run "null_endpoint_map" {
  command = plan

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = null
  }

  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 0 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 0 &&
      length(azapi_resource.private_endpoint_locks) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0
    )
    error_message = "A null endpoint map must continue to use the empty default."
  }
}

run "disabled_lock" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = {
      disabled = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        lock               = { kind = "None" }
      }
    }
  }

  assert {
    condition     = length(azapi_resource.private_endpoint_locks) == 0
    error_message = "The documented None lock value must disable the endpoint lock."
  }
}

run "azapi_control_overrides" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = {
      controls = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        lock               = { kind = "CanNotDelete" }
        role_assignments = {
          reader = {
            principal_id               = "33333333-3333-4333-8333-333333333333"
            role_definition_id_or_name = "Reader"
          }
        }
      }
    }
    resource_types = {
      authorization_locks            = "Microsoft.Authorization/locks@2015-01-01"
      authorization_role_assignments = "Microsoft.Authorization/roleAssignments@2015-07-01"
      authorization_role_definitions = "Microsoft.Authorization/roleDefinitions@2015-07-01"
    }
    ignore_body_changes = {
      authorization_locks            = ["properties.notes"]
      authorization_role_assignments = ["properties.description"]
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_locks["controls"].type == "Microsoft.Authorization/locks@2015-01-01" &&
      azapi_resource.private_endpoint_role_assignments["[\"controls\",\"reader\"]"].type == "Microsoft.Authorization/roleAssignments@2015-07-01" &&
      data.azapi_resource_list.private_endpoint_role_definitions["controls"].type == "Microsoft.Authorization/roleDefinitions@2015-07-01" &&
      azapi_resource.private_endpoint_locks["controls"].ignore_body_changes == null &&
      azapi_resource.private_endpoint_role_assignments["[\"controls\",\"reader\"]"].ignore_body_changes == null
    )
    error_message = "AzAPI type overrides must reach each resource and lookup, and write-only ignored paths must not be stored in state."
  }
}

run "invalid_subnet" {
  command = plan

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = { invalid = { subnet_resource_id = "not-a-subnet-id" } }
  }

  expect_failures = [var.private_endpoints]
}

run "invalid_dns_zone" {
  command = plan

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = {
      invalid = {
        subnet_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        private_dns_zone_resource_ids = ["not-a-zone-id"]
      }
    }
  }

  expect_failures = [var.private_endpoints]
}

run "invalid_application_security_group" {
  command = plan

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = {
      invalid = {
        subnet_resource_id                      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        application_security_group_associations = { clients = "not-an-asg-id" }
      }
    }
  }

  expect_failures = [var.private_endpoints]
}

run "invalid_delegated_identity" {
  command = plan

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = {
      invalid = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        role_assignments = {
          invalid = {
            role_definition_id_or_name             = "Reader"
            principal_id                           = "33333333-3333-4333-8333-333333333333"
            delegated_managed_identity_resource_id = "not-an-identity-id"
          }
        }
      }
    }
  }

  expect_failures = [var.private_endpoints]
}

run "unknown_role_name" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = {
      invalid = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        role_assignments = {
          unknown = {
            role_definition_id_or_name = "Not a defined role"
            principal_id               = "33333333-3333-4333-8333-333333333333"
          }
        }
      }
    }
  }

  expect_failures = [azapi_resource.private_endpoint_role_assignments]
}

run "role_keys_do_not_collide" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm

    random = random
  }

  variables {
    private_endpoints = {
      a-b = {
        name               = "pe-ab"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        role_assignments = {
          c = {
            principal_id               = "33333333-3333-4333-8333-333333333333"
            role_definition_id_or_name = "Reader"
          }
        }
      }
      a = {
        name               = "pe-a"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/endpoints"
        role_assignments = {
          b-c = {
            principal_id               = "44444444-4444-4444-8444-444444444444"
            role_definition_id_or_name = "Reader"
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(azapi_resource.private_endpoint_role_assignments) == 2 &&
      azapi_resource.private_endpoint_role_assignments["[\"a-b\",\"c\"]"].body.properties.principalId == "33333333-3333-4333-8333-333333333333" &&
      azapi_resource.private_endpoint_role_assignments["[\"a\",\"b-c\"]"].body.properties.principalId == "44444444-4444-4444-8444-444444444444"
    )
    error_message = "Distinct arbitrary endpoint and role map keys must not collide when flattened."
  }
}
