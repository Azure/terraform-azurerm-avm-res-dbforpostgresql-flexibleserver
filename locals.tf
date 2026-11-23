locals {
  sku_name = (
    var.sku_name == null ? null :
    startswith(var.sku_name, "B_") ? substr(var.sku_name, 2, -1) :
    startswith(var.sku_name, "GP_") ? substr(var.sku_name, 3, -1) :
    startswith(var.sku_name, "MO_") ? substr(var.sku_name, 3, -1) :
    var.sku_name
  )

  sku_tier = (
    var.sku_name == null ? null :
    startswith(var.sku_name, "B_") || startswith(var.sku_name, "Standard_B") ? "Burstable" :
    startswith(var.sku_name, "GP_") || startswith(var.sku_name, "Standard_D") ? "GeneralPurpose" :
    startswith(var.sku_name, "MO_") || startswith(var.sku_name, "Standard_E") ? "MemoryOptimized" :
    null
  )

  managed_identity_type = (
    var.managed_identities == null ? null :
    var.managed_identities.system_assigned && length(var.managed_identities.user_assigned_resource_ids) > 0 ? "SystemAssigned, UserAssigned" :
    var.managed_identities.system_assigned ? "SystemAssigned" :
    length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" :
    null
  )

  managed_identity_body = local.managed_identity_type == null ? null : {
    type                   = local.managed_identity_type
    userAssignedIdentities = length(var.managed_identities.user_assigned_resource_ids) > 0 ? { for id in var.managed_identities.user_assigned_resource_ids : id => {} } : null
  }

  network_body = (
    var.delegated_subnet_id == null && var.private_dns_zone_id == null && var.public_network_access_enabled == null
    ) ? null : {
    delegatedSubnetResourceId   = var.delegated_subnet_id
    privateDnsZoneArmResourceId = var.private_dns_zone_id
    publicNetworkAccess         = var.public_network_access_enabled == null ? null : (var.public_network_access_enabled ? "Enabled" : "Disabled")
  }

  storage_body = (
    var.storage_mb == null && var.auto_grow_enabled == null && var.storage_tier == null
    ) ? null : {
    storageSizeGB = var.storage_mb != null ? var.storage_mb / 1024 : null
    autoGrow      = var.auto_grow_enabled == null ? null : (var.auto_grow_enabled ? "Enabled" : "Disabled")
    tier          = var.storage_tier
  }

  backup_body = (
    var.backup_retention_days == null && var.geo_redundant_backup_enabled == null
    ) ? null : {
    backupRetentionDays = var.backup_retention_days
    geoRedundantBackup  = var.geo_redundant_backup_enabled == null ? null : (var.geo_redundant_backup_enabled ? "Enabled" : "Disabled")
  }

  ha_body = var.high_availability == null ? null : {
    mode                    = var.high_availability.mode
    standbyAvailabilityZone = var.high_availability.standby_availability_zone
  }

  maintenance_body = var.maintenance_window == null ? null : {
    customWindow = "Enabled"
    dayOfWeek    = var.maintenance_window.day_of_week != null ? tonumber(var.maintenance_window.day_of_week) : 0
    startHour    = var.maintenance_window.start_hour != null ? var.maintenance_window.start_hour : 0
    startMinute  = var.maintenance_window.start_minute != null ? var.maintenance_window.start_minute : 0
  }

  auth_body = var.authentication == null ? null : {
    activeDirectoryAuth = var.authentication.active_directory_auth_enabled == null ? null : (var.authentication.active_directory_auth_enabled ? "Enabled" : "Disabled")
    passwordAuth        = var.authentication.password_auth_enabled == null ? null : (var.authentication.password_auth_enabled ? "Enabled" : "Disabled")
    tenantId            = var.authentication.tenant_id
  }

  cmk_body = var.customer_managed_key == null ? null : {
    type                            = "AzureKeyVault"
    primaryKeyURI                   = var.customer_managed_key.key_vault_key_id
    primaryUserAssignedIdentityId   = var.customer_managed_key.primary_user_assigned_identity_id
    geoBackupKeyURI                 = var.customer_managed_key.geo_backup_key_vault_key_id
    geoBackupUserAssignedIdentityId = var.customer_managed_key.geo_backup_user_assigned_identity_id
  }

  managed_identities = {
    system_assigned_user_assigned = (var.managed_identities.system_assigned || length(var.managed_identities.user_assigned_resource_ids) > 0) ? {
      this = {
        type                       = var.managed_identities.system_assigned && length(var.managed_identities.user_assigned_resource_ids) > 0 ? "SystemAssigned, UserAssigned" : length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" : "SystemAssigned"
        user_assigned_resource_ids = var.managed_identities.user_assigned_resource_ids
      }
    } : {}
    system_assigned = var.managed_identities.system_assigned ? {
      this = {
        type = "SystemAssigned"
      }
    } : {}
    user_assigned = length(var.managed_identities.user_assigned_resource_ids) > 0 ? {
      this = {
        type                       = "UserAssigned"
        user_assigned_resource_ids = var.managed_identities.user_assigned_resource_ids
      }
    } : {}
  }
  # Private endpoint application security group associations.
  # We merge the nested maps from private endpoints and application security group associations into a single map.
  private_endpoint_application_security_group_associations = { for assoc in flatten([
    for pe_k, pe_v in var.private_endpoints : [
      for asg_k, asg_v in pe_v.application_security_group_associations : {
        asg_key         = asg_k
        pe_key          = pe_k
        asg_resource_id = asg_v
      }
    ]
  ]) : "${assoc.pe_key}-${assoc.asg_key}" => assoc }
  private_endpoint_resource_ids = merge(
    { for key, endpoint in azapi_resource.private_endpoints_managed_dns_zone_groups : key => endpoint.id },
    { for key, endpoint in azapi_resource.private_endpoints_unmanaged_dns_zone_groups : key => endpoint.id },
  )
  role_definition_ids = {
    for key, assignment in var.role_assignments : key => (
      strcontains(lower(assignment.role_definition_id_or_name), lower(local.role_definition_resource_substring))
      ? assignment.role_definition_id_or_name
      : lookup(
        { for definition in try(data.azapi_resource_list.role_definitions[0].output.role_definitions, []) : definition.name => definition.id },
        assignment.role_definition_id_or_name,
        null,
      )
    )
  }
  private_endpoint_role_assignments = { for entry in flatten([
    for pe_key, endpoint in var.private_endpoints : [
      for role_key, assignment in endpoint.role_assignments : {
        pe_key     = pe_key
        role_key   = role_key
        assignment = assignment
      }
    ]
  ]) : jsonencode([entry.pe_key, entry.role_key]) => entry }
  private_endpoint_role_definition_ids = {
    for key, entry in local.private_endpoint_role_assignments : key => (
      strcontains(lower(entry.assignment.role_definition_id_or_name), lower(local.role_definition_resource_substring))
      ? entry.assignment.role_definition_id_or_name
      : lookup(
        { for definition in data.azapi_resource_list.private_endpoint_role_definitions[entry.pe_key].output.role_definitions : definition.name => definition.id },
        entry.assignment.role_definition_id_or_name,
        null,
      )
    )
  }
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
  default_retry = {
    error_message_regex = [
      "ServerIsBusy",
      "Another operation is in progress",
      "AadAuthOperationCannotBePerformedWhenServerIsNotAccessible",
    ]
    interval_seconds     = 10
    max_interval_seconds = 60
  }
  retry = var.retry != null ? var.retry : local.default_retry
}
