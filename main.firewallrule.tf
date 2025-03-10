resource "azurerm_postgresql_flexible_server_firewall_rule" "this" {
  for_each = var.firewall_rules != null ? var.firewall_rules : {}

  end_ip_address   = each.value.end_ip_address
  name             = each.key
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = each.value.start_ip_address
}
