# The PE resource when we are managing the private_dns_zone_group block:
resource "azurerm_private_endpoint" "this_managed_dns_zone_groups" {
  for_each = { for k, v in var.private_endpoints : k => v if var.private_endpoints_manage_dns_zone_group }

  location                      = each.value.location != null ? each.value.location : var.location
  name                          = each.value.name != null ? each.value.name : "pe-${var.name}"
  resource_group_name           = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name
  tags                          = each.value.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = each.value.private_service_connection_name != null ? each.value.private_service_connection_name : "pse-${var.name}"
    private_connection_resource_id = azurerm_postgresql_flexible_server.this.id
    subresource_names              = [coalesce(each.value.subresource_name, "postgresqlServer")]
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = coalesce(ip_configuration.value.member_name, "postgresqlServer")
      subresource_name   = coalesce(each.value.subresource_name, "postgresqlServer")
    }
  }

  dynamic "private_dns_zone_group" {
    for_each = length(each.value.private_dns_zone_resource_ids) > 0 ? ["this"] : []

    content {
      name                 = each.value.private_dns_zone_group_name
      private_dns_zone_ids = each.value.private_dns_zone_resource_ids
    }
  }
}

# The PE resource when we are managing **not** the private_dns_zone_group block
# An example use case is customers using Azure Policy to create private DNS zones
# e.g. <https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale>
resource "azurerm_private_endpoint" "this_unmanaged_dns_zone_groups" {
  for_each = { for k, v in var.private_endpoints : k => v if !var.private_endpoints_manage_dns_zone_group }

  location                      = each.value.location != null ? each.value.location : var.location
  name                          = each.value.name != null ? each.value.name : "pe-${var.name}"
  resource_group_name           = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name
  tags                          = each.value.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = each.value.private_service_connection_name != null ? each.value.private_service_connection_name : "pse-${var.name}"
    private_connection_resource_id = azurerm_postgresql_flexible_server.this.id
    subresource_names              = [coalesce(each.value.subresource_name, "postgresqlServer")]
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = coalesce(ip_configuration.value.member_name, "postgresqlServer")
      subresource_name   = coalesce(each.value.subresource_name, "postgresqlServer")
    }
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}

resource "azurerm_private_endpoint_application_security_group_association" "this" {
  for_each = local.private_endpoint_application_security_group_associations

  application_security_group_id = each.value.asg_resource_id
  private_endpoint_id           = var.private_endpoints_manage_dns_zone_group ? azurerm_private_endpoint.this_managed_dns_zone_groups[each.value.pe_key].id : azurerm_private_endpoint.this_unmanaged_dns_zone_groups[each.value.pe_key].id
}

data "azapi_resource_list" "private_endpoint_role_definitions" {
  for_each = { for key, endpoint in var.private_endpoints : key => endpoint if length(endpoint.role_assignments) > 0 }

  parent_id = local.private_endpoint_resource_ids[each.key]
  type      = var.resource_types.authorization_role_definitions
  response_export_values = {
    role_definitions = "value[].{id: id, name: properties.roleName}"
  }
  retry = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      read = timeouts.value.read
    }
  }
}

resource "random_uuid" "private_endpoint_role_assignment" {
  for_each = local.private_endpoint_role_assignments

  keepers = {
    scope              = local.private_endpoint_resource_ids[each.value.pe_key]
    principal_id       = each.value.assignment.principal_id
    role_definition_id = local.private_endpoint_role_definition_ids[each.key]
  }
}

resource "azapi_resource" "private_endpoint_role_assignments" {
  for_each = local.private_endpoint_role_assignments

  name      = coalesce(each.value.assignment.name, random_uuid.private_endpoint_role_assignment[each.key].result)
  parent_id = local.private_endpoint_resource_ids[each.value.pe_key]
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = { for key, value in {
      principalId                        = each.value.assignment.principal_id
      roleDefinitionId                   = local.private_endpoint_role_definition_ids[each.key]
      description                        = each.value.assignment.description
      condition                          = each.value.assignment.condition
      conditionVersion                   = each.value.assignment.condition_version
      delegatedManagedIdentityResourceId = each.value.assignment.delegated_managed_identity_resource_id
      principalType                      = each.value.assignment.principal_type
    } : key => value if value != null }
  }
  ignore_body_changes = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  replace_triggers_refs = [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.principalType",
    "properties.delegatedManagedIdentityResourceId",
  ]
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    precondition {
      condition     = local.private_endpoint_role_definition_ids[each.key] != null
      error_message = "The role definition '${each.value.assignment.role_definition_id_or_name}' was not found at the private endpoint scope. Supply a role definition resource ID or an available role name."
    }
  }
}

resource "azapi_resource" "private_endpoint_locks" {
  for_each = { for key, endpoint in var.private_endpoints : key => endpoint.lock if endpoint.lock == null ? false : endpoint.lock.kind != "None" }

  name      = coalesce(each.value.name, "lock-${each.value.kind}")
  parent_id = local.private_endpoint_resource_ids[each.key]
  type      = var.resource_types.authorization_locks
  body = {
    properties = { for key, value in {
      level = each.value.kind
      notes = each.value.notes
    } : key => value if value != null }
  }
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    precondition {
      condition     = contains(["CanNotDelete", "ReadOnly"], each.value.kind)
      error_message = "The private endpoint lock kind must be 'CanNotDelete' or 'ReadOnly'. Use null to omit the lock."
    }
  }
  depends_on = [
    azapi_resource.private_endpoint_role_assignments,
    azurerm_private_endpoint_application_security_group_association.this,
  ]
}
