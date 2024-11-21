output "database_name" {
  description = "A map of database keys to database name."
  sensitive   = true
  value = { for dk, dv in azurerm_postgresql_flexible_server_database.this : dk => {
    name = dv.name
  } if azurerm_postgresql_flexible_server_database.this != null }
}

output "database_resource_ids" {
  description = "A map of database keys to resource ids."
  value = { for dk, dv in azurerm_postgresql_flexible_server_database.this : dk => {
    resource_id = dv.id
    id          = dv.id
    } if azurerm_postgresql_flexible_server_database.this != null
  }
}

# Module owners should only include computed attributes from the base resource (with the exception of 'name')
# https://azure.github.io/Azure-Verified-Modules/specs/terraform/#id-tffr2---category-outputs---additional-terraform-outputs
output "fqdn" {
  description = "The fully qualified domain name of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "name" {
  description = "The resource ID for the resource."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "private_endpoints" {
  description = <<DESCRIPTION
  A map of the private endpoints created.
  DESCRIPTION
  value       = var.private_endpoints_manage_dns_zone_group ? azurerm_private_endpoint.this_managed_dns_zone_groups : azurerm_private_endpoint.this_unmanaged_dns_zone_groups
}

output "resource_id" {
  description = "The resource ID for the resource."
  value       = azurerm_postgresql_flexible_server.this.id
}
