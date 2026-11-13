moved {
  from = azurerm_postgresql_flexible_server.this
  to   = azapi_resource.this
}

moved {
  from = azurerm_management_lock.this
  to   = azapi_resource.locks
}

moved {
  from = azurerm_role_assignment.this
  to   = azapi_resource.role_assignments
}

moved {
  from = azurerm_monitor_diagnostic_setting.this
  to   = azapi_resource.diagnostic_settings
}

moved {
  from = azurerm_postgresql_flexible_server_active_directory_administrator.this
  to   = azapi_resource.administrators
}

moved {
  from = azurerm_postgresql_flexible_server_configuration.this
  to   = azapi_update_resource.configurations
}

moved {
  from = azurerm_postgresql_flexible_server_virtual_endpoint.this
  to   = azapi_resource.virtual_endpoints
}

moved {
  from = azurerm_postgresql_flexible_server_firewall_rule.this
  to   = azapi_resource.firewall_rules
}

moved {
  from = azurerm_private_endpoint.this_managed_dns_zone_groups
  to   = azapi_resource.private_endpoints_managed_dns_zone_groups
}

moved {
  from = azurerm_private_endpoint.this_unmanaged_dns_zone_groups
  to   = azapi_resource.private_endpoints_unmanaged_dns_zone_groups
}
