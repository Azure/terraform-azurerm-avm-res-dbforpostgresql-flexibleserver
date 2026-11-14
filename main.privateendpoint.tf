# The PE resource when we are managing the private_dns_zone_group block:
resource "azapi_resource" "private_endpoints_managed_dns_zone_groups" {
  for_each = { for k, v in var.private_endpoints : k => v if var.private_endpoints_manage_dns_zone_group }

  location  = each.value.location != null ? each.value.location : var.location
  name      = each.value.name != null ? each.value.name : "pe-${var.name}"
  parent_id = each.value.resource_group_name != null ? "${data.azapi_client_config.current.subscription_resource_id}/resourceGroups/${each.value.resource_group_name}" : "${data.azapi_client_config.current.subscription_resource_id}/resourceGroups/${var.resource_group_name}"
  tags      = each.value.tags
  type      = var.resource_types.network_private_endpoints

  body = {
    properties = {
      subnet = {
        id = each.value.subnet_resource_id
      }
      customNetworkInterfaceName = each.value.network_interface_name
      privateLinkServiceConnections = [
        {
          name = each.value.private_service_connection_name != null ? each.value.private_service_connection_name : "pse-${var.name}"
          properties = {
            privateLinkServiceId = azapi_resource.this.id
            groupIds             = [coalesce(each.value.subresource_name, "postgresqlServer")]
          }
        }
      ]
      ipConfigurations = length(each.value.ip_configurations) > 0 ? [
        for ip_k, ip_v in each.value.ip_configurations : {
          name = ip_v.name
          properties = {
            groupId          = coalesce(each.value.subresource_name, "postgresqlServer")
            memberName       = coalesce(ip_v.member_name, "postgresqlServer")
            privateIPAddress = ip_v.private_ip_address
          }
        }
      ] : null
      applicationSecurityGroups = length(each.value.application_security_group_associations) > 0 ? [
        for asg_k, asg_v in each.value.application_security_group_associations : {
          id = asg_v
        }
      ] : null
    }
  }

  ignore_body_changes    = length(var.ignore_body_changes.network_private_endpoints) > 0 ? var.ignore_body_changes.network_private_endpoints : null
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
}

# The PE resource when we are managing **not** the private_dns_zone_group block
# An example use case is customers using Azure Policy to create private DNS zones
# e.g. <https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale>
resource "azapi_resource" "private_endpoints_unmanaged_dns_zone_groups" {
  for_each = { for k, v in var.private_endpoints : k => v if !var.private_endpoints_manage_dns_zone_group }

  location  = each.value.location != null ? each.value.location : var.location
  name      = each.value.name != null ? each.value.name : "pe-${var.name}"
  parent_id = each.value.resource_group_name != null ? "${data.azapi_client_config.current.subscription_resource_id}/resourceGroups/${each.value.resource_group_name}" : "${data.azapi_client_config.current.subscription_resource_id}/resourceGroups/${var.resource_group_name}"
  tags      = each.value.tags
  type      = var.resource_types.network_private_endpoints

  body = {
    properties = {
      subnet = {
        id = each.value.subnet_resource_id
      }
      customNetworkInterfaceName = each.value.network_interface_name
      privateLinkServiceConnections = [
        {
          name = each.value.private_service_connection_name != null ? each.value.private_service_connection_name : "pse-${var.name}"
          properties = {
            privateLinkServiceId = azapi_resource.this.id
            groupIds             = [coalesce(each.value.subresource_name, "postgresqlServer")]
          }
        }
      ]
      ipConfigurations = length(each.value.ip_configurations) > 0 ? [
        for ip_k, ip_v in each.value.ip_configurations : {
          name = ip_v.name
          properties = {
            groupId          = coalesce(each.value.subresource_name, "postgresqlServer")
            memberName       = coalesce(ip_v.member_name, "postgresqlServer")
            privateIPAddress = ip_v.private_ip_address
          }
        }
      ] : null
      applicationSecurityGroups = length(each.value.application_security_group_associations) > 0 ? [
        for asg_k, asg_v in each.value.application_security_group_associations : {
          id = asg_v
        }
      ] : null
    }
  }

  ignore_body_changes    = length(var.ignore_body_changes.network_private_endpoints) > 0 ? var.ignore_body_changes.network_private_endpoints : null
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
}

resource "azapi_resource" "private_dns_zone_groups" {
  for_each = {
    for k, v in var.private_endpoints : k => v
    if var.private_endpoints_manage_dns_zone_group && length(v.private_dns_zone_resource_ids) > 0
  }

  name      = each.value.private_dns_zone_group_name != null ? each.value.private_dns_zone_group_name : "default"
  parent_id = azapi_resource.private_endpoints_managed_dns_zone_groups[each.key].id
  type      = var.resource_types.network_private_endpoints_private_dns_zone_groups
  body = {
    properties = {
      privateDnsZoneConfigs = [
        for zone_id in each.value.private_dns_zone_resource_ids : {
          name = replace(reverse(split("/", zone_id))[0], ".", "-")
          properties = {
            privateDnsZoneId = zone_id
          }
        }
      ]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_private_endpoints_private_dns_zone_groups) > 0 ? var.ignore_body_changes.network_private_endpoints_private_dns_zone_groups : null
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
  for_each = { for k, v in local.private_endpoint_role_assignments : k => v if(v.assignment.name == null || v.assignment.name == "") }

  keepers = {
    scope              = local.private_endpoint_resource_ids[each.value.pe_key]
    principal_id       = each.value.assignment.principal_id
    role_definition_id = local.private_endpoint_role_definition_ids[each.key]
  }
}

resource "azapi_resource" "private_endpoint_role_assignments" {
  for_each = local.private_endpoint_role_assignments

  name      = each.value.assignment.name != null ? each.value.assignment.name : random_uuid.private_endpoint_role_assignment[each.key].result
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
      principalType                      = each.value.assignment.principal_type != null ? each.value.assignment.principal_type : (each.value.assignment.skip_service_principal_aad_check ? "ServicePrincipal" : null)
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
    ignore_changes = [name]
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
    azapi_resource.private_dns_zone_groups,
  ]
}

removed {
  from = azurerm_private_endpoint_application_security_group_association.this

  lifecycle {
    destroy = false
  }
}
