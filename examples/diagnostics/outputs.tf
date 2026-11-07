output "resource_group_name" {
  description = "Resource group used by the example."
  value       = azapi_resource.resource_group.name
}

output "server_resource_id" {
  description = "Resource ID of the PostgreSQL server."
  value       = module.server.resource_id
}

output "workspace_resource_id" {
  description = "Resource ID of the Log Analytics workspace receiving diagnostics."
  value       = azapi_resource.workspace.id
}
