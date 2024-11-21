variable "firewall_rules" {
  type = map(object({
    name             = string
    end_ip_address   = string
    start_ip_address = string
  }))
  default = {
    rule1 = {
      name             = "AllowAllFireWallRule"
      end_ip_address   = "255.255.255.255"
      start_ip_address = "0.0.0.0"
    }
  }
  description = <<-EOT
 - `name` - (Optional) The name which should be used for this PostgreSQL Flexible Server Firewall Rule.  
 - `start_ip_address` - (Optional) The Start IP Address associated with this PostgreSQL Flexible Server Firewall Rule.  
 - `end_ip_address` - (Optional) The End IP Address associated with this PostgreSQL Flexible Server Firewall Rule.   
EOT
}
