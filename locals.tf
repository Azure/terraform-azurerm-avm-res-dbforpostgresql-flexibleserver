locals {
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
    { for key, endpoint in azurerm_private_endpoint.this_managed_dns_zone_groups : key => endpoint.id },
    { for key, endpoint in azurerm_private_endpoint.this_unmanaged_dns_zone_groups : key => endpoint.id },
  )
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
}
