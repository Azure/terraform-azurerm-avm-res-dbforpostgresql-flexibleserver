variable "administrator_login" {
  type        = string
  default     = null
  description = "(Optional) The Administrator login for the PostgreSQL Flexible Server. Required when `create_mode` is `Default` and `authentication.password_auth_enabled` is `true`."
}

variable "administrator_password" {
  type        = string
  default     = null
  description = "(Optional) The Password associated with the `administrator_login` for the PostgreSQL Flexible Server. Required when `create_mode` is `Default` and `authentication.password_auth_enabled` is `true`."
  sensitive   = true
}

variable "authentication" {
  type = object({
    active_directory_auth_enabled = optional(bool)
    password_auth_enabled         = optional(bool)
    tenant_id                     = optional(string)
  })
  default     = null
  description = <<-EOT
 - `active_directory_auth_enabled` - (Optional)  Whether or not Active Directory authentication is allowed to access the PostgreSQL Flexible Server. Defaults to `false`.
 - `password_auth_enabled` - (Optional) Whether or not password authentication is allowed to access the PostgreSQL Flexible Server. Defaults to `true`.
 - `tenant_id` - (Optional) The Tenant ID of the Azure Active Directory which is used by the Active Directory authentication. `active_directory_auth_enabled` must be set to `true`.
EOT
}

variable "auto_grow_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Is the storage auto grow for PostgreSQL Flexible Server enabled? Defaults to `false`."
}

variable "backup_retention_days" {
  type        = number
  default     = null
  description = "(Optional) The backup retention days for the PostgreSQL Flexible Server. Possible values are between `7` and `35` days."
}

variable "create_mode" {
  type        = string
  default     = null
  description = "(Optional) The creation mode which can be used to restore or replicate existing servers. Possible values are `Default`, `GeoRestore`, `PointInTimeRestore`, `Replica` and `Update`."
}

variable "delegated_subnet_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of the virtual network subnet to create the PostgreSQL Flexible Server. The provided subnet should not have any other resource deployed in it and this subnet will be delegated to the PostgreSQL Flexible Server, if not already delegated. Changing this forces a new PostgreSQL Flexible Server to be created."
}

variable "geo_redundant_backup_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Is Geo-Redundant backup enabled on the PostgreSQL Flexible Server. Defaults to `false`. Changing this forces a new PostgreSQL Flexible Server to be created."
}

variable "high_availability" {
  type = object({
    mode                      = string
    standby_availability_zone = optional(string)
  })
  default = {
    mode = "ZoneRedundant"
  }
  description = <<-EOT
 - `mode` - (Required) The high availability mode for the PostgreSQL Flexible Server. Possible value are `SameZone` or `ZoneRedundant`.
 - `standby_availability_zone` - (Optional) Specifies the Availability Zone in which the standby Flexible Server should be located.
EOT
}

variable "maintenance_window" {
  type = object({
    day_of_week  = optional(string)
    start_hour   = optional(number)
    start_minute = optional(number)
  })
  default = {
    day_of_week  = "0"
    start_hour   = 0
    start_minute = 0
  }
  description = <<-EOT
 - `day_of_week` - (Optional) The day of week for maintenance window, where the week starts on a Sunday, i.e. Sunday = `0`, Monday = `1`. Defaults to `0`.
 - `start_hour` - (Optional) The start hour for maintenance window. Defaults to `0`.
 - `start_minute` - (Optional) The start minute for maintenance window. Defaults to `0`.
EOT
}

variable "point_in_time_restore_time_in_utc" {
  type        = string
  default     = null
  description = "(Optional) The point in time to restore from `source_server_id` when `create_mode` is `GeoRestore`, `PointInTimeRestore`. Changing this forces a new PostgreSQL Flexible Server to be created."
}

variable "private_dns_zone_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of the private DNS zone to create the PostgreSQL Flexible Server."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = false
  description = "(Optional) Whether the server is publicly accessible.  Defaults to `false`."
}

variable "replication_role" {
  type        = string
  default     = null
  description = "(Optional) The replication role for the PostgreSQL Flexible Server. Possible value is `None`."
}

variable "server_version" {
  type        = string
  default     = null
  description = "(Optional) The version of PostgreSQL Flexible Server to use. Possible values are `11`,`12`, `13`, `14`, `15` and `16`. Required when `create_mode` is `Default`."
}

variable "sku_name" {
  type        = string
  default     = null
  description = "(Optional) The SKU Name for the PostgreSQL Flexible Server. The name of the SKU, follows the `tier` + `name` pattern (e.g. `B_Standard_B1ms`, `GP_Standard_D2s_v3`, `MO_Standard_E4s_v3`)."
}

variable "source_server_id" {
  type        = string
  default     = null
  description = "(Optional) The resource ID of the source PostgreSQL Flexible Server to be restored. Required when `create_mode` is `GeoRestore`, `PointInTimeRestore` or `Replica`. Changing this forces a new PostgreSQL Flexible Server to be created."
}

variable "storage_mb" {
  type        = number
  default     = null
  description = "(Optional) The max storage allowed for the PostgreSQL Flexible Server. Possible values are `32768`, `65536`, `131072`, `262144`, `524288`, `1048576`, `2097152`, `4193280`, `4194304`, `8388608`, `16777216` and `33553408`."
}

variable "storage_tier" {
  type        = string
  default     = null
  description = "(Optional) The storage tier for the PostgreSQL Flexible Server. Possible values are `P4`, `P6`, `P10`, `P15`, `P20`, `P30`, `P40`, `P50`, `P60`, `P70` or `P80`."

  validation {
    condition     = var.storage_tier != null ? contains(["P4", "P6", "P10", "P15", "P20", "P30", "P40", "P50", "P60", "P70", "P80"], var.storage_tier) : true
    error_message = "The storage_tier must be one of the following values: P4, P6, P10, P15, P20, P30, P40, P50, P60, P70, P80."
  }
}

variable "timeouts" {
  type = object({
    create = optional(string)
    delete = optional(string)
    read   = optional(string)
    update = optional(string)
  })
  default     = null
  description = <<-EOT
 - `create` - (Defaults to 1 hour) Used when creating the PostgreSQL Flexible Server.
 - `delete` - (Defaults to 1 hour) Used when deleting the PostgreSQL Flexible Server.
 - `read` - (Defaults to 5 minutes) Used when retrieving the PostgreSQL Flexible Server.
 - `update` - (Defaults to 1 hour) Used when updating the PostgreSQL Flexible Server.
EOT
}

variable "zone" {
  type        = string
  default     = null
  description = "(Optional) Specifies the Availability Zone in which the PostgreSQL Flexible Server should be located."
}
