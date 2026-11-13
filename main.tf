data "azapi_client_config" "current" {}

resource "azapi_resource" "this" {
  type      = var.resource_types.dbforpostgresql_flexible_servers
  name      = var.name
  parent_id = "${data.azapi_client_config.current.subscription_resource_id}/resourceGroups/${var.resource_group_name}"
  location  = var.location
  tags      = var.tags

  body = {
    sku = var.sku_name == null ? null : {
      name = local.sku_name
      tier = local.sku_tier
    }
    identity = local.managed_identity_body
    properties = {
      version                = var.server_version != null ? tostring(var.server_version) : null
      administratorLogin     = var.administrator_login
      createMode             = var.create_mode
      sourceServerResourceId = var.source_server_id
      pointInTimeUTC         = var.point_in_time_restore_time_in_utc
      availabilityZone       = var.zone
      replicationRole        = var.replication_role
      network                = local.network_body
      storage                = local.storage_body
      backup                 = local.backup_body
      highAvailability       = local.ha_body
      authConfig             = local.auth_body
      dataEncryption         = local.cmk_body
    }
  }
  sensitive_body = (var.administrator_password != null || var.administrator_password_wo != null) ? {
    properties = {
      administratorLoginPassword = coalesce(var.administrator_password, var.administrator_password_wo)
    }
  } : null
  sensitive_body_version = var.administrator_password_wo_version != null ? {
    "properties.administratorLoginPassword" = tostring(var.administrator_password_wo_version)
  } : null

  ignore_body_changes = length(var.ignore_body_changes.dbforpostgresql_flexible_servers) > 0 ? var.ignore_body_changes.dbforpostgresql_flexible_servers : null
  replace_triggers_refs = [
    "properties.administratorLogin",
    "properties.createMode",
    "properties.pointInTimeUTC",
    "properties.sourceServerResourceId",
  ]
  response_export_values = ["properties.fullyQualifiedDomainName"]
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
      condition     = var.customer_managed_key == null ? true : var.customer_managed_key.primary_user_assigned_identity_id == null ? true : contains([for id in var.managed_identities.user_assigned_resource_ids : lower(id)], lower(var.customer_managed_key.primary_user_assigned_identity_id))
      error_message = "`customer_managed_key.primary_user_assigned_identity_id` must also be included in `managed_identities.user_assigned_resource_ids`."
    }
    precondition {
      condition     = var.customer_managed_key == null ? true : var.customer_managed_key.geo_backup_user_assigned_identity_id == null ? true : contains([for id in var.managed_identities.user_assigned_resource_ids : lower(id)], lower(var.customer_managed_key.geo_backup_user_assigned_identity_id))
      error_message = "`customer_managed_key.geo_backup_user_assigned_identity_id` must also be included in `managed_identities.user_assigned_resource_ids`."
    }
  }
}

# required AVM resources interfaces
resource "azapi_resource" "locks" {
  count = var.lock != null ? 1 : 0

  name      = coalesce(var.lock.name, "lock-${var.lock.kind}")
  parent_id = azapi_resource.this.id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = var.lock.kind
      notes = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
    }
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
      condition     = contains(["CanNotDelete", "ReadOnly"], var.lock.kind)
      error_message = "The lock level must be one of: 'CanNotDelete', or 'ReadOnly'."
    }
  }
}

data "azapi_resource_list" "role_definitions" {
  count = length(var.role_assignments) > 0 ? 1 : 0

  parent_id = azapi_resource.this.id
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

resource "random_uuid" "role_assignment" {
  for_each = var.role_assignments

  keepers = {
    scope              = azapi_resource.this.id
    principal_id       = each.value.principal_id
    role_definition_id = local.role_definition_ids[each.key]
  }
}

resource "azapi_resource" "role_assignments" {
  for_each = var.role_assignments

  name      = random_uuid.role_assignment[each.key].result
  parent_id = azapi_resource.this.id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = { for key, value in {
      principalId                        = each.value.principal_id
      roleDefinitionId                   = local.role_definition_ids[each.key]
      description                        = each.value.description
      condition                          = each.value.condition
      conditionVersion                   = each.value.condition_version
      delegatedManagedIdentityResourceId = each.value.delegated_managed_identity_resource_id
      principalType                      = each.value.principal_type != null ? each.value.principal_type : (each.value.skip_service_principal_aad_check ? "ServicePrincipal" : null)
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
      condition     = local.role_definition_ids[each.key] != null
      error_message = "The role definition '${each.value.role_definition_id_or_name}' was not found at the server scope. Supply a role definition resource ID or an available role name."
    }
  }
}

resource "azapi_resource" "diagnostic_settings" {
  for_each = var.diagnostic_settings

  name      = each.value.name != null ? each.value.name : "diag-${var.name}"
  parent_id = azapi_resource.this.id
  type      = var.resource_types.insights_diagnostic_settings
  body = {
    properties = {
      storageAccountId            = each.value.storage_account_resource_id
      workspaceId                 = each.value.workspace_resource_id
      eventHubName                = each.value.event_hub_name
      eventHubAuthorizationRuleId = each.value.event_hub_authorization_rule_resource_id
      marketplacePartnerId        = each.value.marketplace_partner_resource_id
      logAnalyticsDestinationType = each.value.log_analytics_destination_type
      logs = concat(
        [for cat in each.value.log_categories : {
          category = cat
          enabled  = true
        }],
        [for grp in each.value.log_groups : {
          categoryGroup = grp
          enabled       = true
        }]
      )
      metrics = [for metric in each.value.metric_categories : {
        category = metric
        enabled  = true
      }]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.insights_diagnostic_settings) > 0 ? var.ignore_body_changes.insights_diagnostic_settings : null
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

resource "azapi_resource" "administrators" {
  for_each = var.ad_administrator

  name      = each.value.object_id
  parent_id = azapi_resource.this.id
  type      = var.resource_types.dbforpostgresql_flexible_servers_administrators
  body = {
    properties = {
      principalName = each.value.principal_name
      principalType = each.value.principal_type
      tenantId      = each.value.tenant_id
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.dbforpostgresql_flexible_servers_administrators) > 0 ? var.ignore_body_changes.dbforpostgresql_flexible_servers_administrators : null
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

resource "azapi_update_resource" "configurations" {
  for_each = var.server_configuration

  name      = each.value.name
  parent_id = azapi_resource.this.id
  type      = var.resource_types.dbforpostgresql_flexible_servers_configurations
  body = {
    properties = {
      source = "user-override"
      value  = each.value.config
    }
  }
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

resource "azapi_resource" "virtual_endpoints" {
  for_each = var.virtual_endpoint

  name      = each.value.name
  parent_id = azapi_resource.this.id
  type      = var.resource_types.dbforpostgresql_flexible_servers_virtual_endpoints
  body = {
    properties = {
      endpointType = each.value.type
      members      = [try(provider::azapi::parse_resource_id("Microsoft.DBforPostgreSQL/flexibleServers", each.value.replica_server_id).resource_name, element(split("/", each.value.replica_server_id), length(split("/", each.value.replica_server_id)) - 1))]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.dbforpostgresql_flexible_servers_virtual_endpoints) > 0 ? var.ignore_body_changes.dbforpostgresql_flexible_servers_virtual_endpoints : null
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

resource "azapi_update_resource" "maintenance_window" {
  count = var.maintenance_window == null ? 0 : 1

  resource_id = azapi_resource.this.id
  type        = var.resource_types.dbforpostgresql_flexible_servers
  body = {
    properties = {
      maintenanceWindow = local.maintenance_body
    }
  }
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
