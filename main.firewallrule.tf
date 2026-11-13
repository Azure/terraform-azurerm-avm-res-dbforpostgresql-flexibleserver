resource "azapi_resource" "firewall_rules" {
  for_each = var.firewall_rules

  name      = each.value.name
  parent_id = azapi_resource.this.id
  type      = var.resource_types.dbforpostgresql_flexible_servers_firewall_rules
  body = {
    properties = {
      endIpAddress   = each.value.end_ip_address
      startIpAddress = each.value.start_ip_address
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.dbforpostgresql_flexible_servers_firewall_rules) > 0 ? var.ignore_body_changes.dbforpostgresql_flexible_servers_firewall_rules : null
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
