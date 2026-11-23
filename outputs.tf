output "database_name" {
  description = "A map of database keys to database name."
  sensitive   = true
  value = {
    for dk, dv in module.databases : dk => {
      name = dv.name
    }
  }
}

output "database_resource_ids" {
  description = "A map of database keys to resource ids."
  value = {
    for dk, dv in module.databases : dk => {
      resource_id = dv.resource_id
      id          = dv.id
    }
  }
}

# Module owners should only include computed attributes from the base resource (with the exception of 'name')
# https://azure.github.io/Azure-Verified-Modules/specs/terraform/#id-tffr2---category-outputs---additional-terraform-outputs
output "fqdn" {
  description = "The fully qualified domain name of the PostgreSQL Flexible Server."
  value       = try(azapi_resource.this.output.properties.fullyQualifiedDomainName, null)
}

output "name" {
  description = "The name of the PostgreSQL Flexible Server."
  value       = azapi_resource.this.name
}

output "private_endpoints" {
  description = <<DESCRIPTION
A map of the private endpoints created.
DESCRIPTION
  value       = var.private_endpoints_manage_dns_zone_group ? azapi_resource.private_endpoints_managed_dns_zone_groups : azapi_resource.private_endpoints_unmanaged_dns_zone_groups
}

output "resource_id" {
  description = "The resource ID for the resource."
  value       = azapi_resource.this.id
}
