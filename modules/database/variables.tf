variable "name" {
  type        = string
  description = "Specifies the name of the PostgreSQL database."
}

variable "parent_id" {
  type        = string
  default     = null
  description = "The resource ID of the PostgreSQL Flexible Server parent resource."

  validation {
    condition     = var.parent_id == null || can(provider::azapi::parse_resource_id("Microsoft.DBforPostgreSQL/flexibleServers", var.parent_id))
    error_message = "`parent_id` must be a valid PostgreSQL Flexible Server resource ID."
  }
}

variable "server_id" {
  type        = string
  default     = null
  description = "(Deprecated: use `parent_id` instead) The resource ID of the PostgreSQL Flexible Server that will host the database."

  validation {
    condition     = var.server_id == null || can(provider::azapi::parse_resource_id("Microsoft.DBforPostgreSQL/flexibleServers", var.server_id))
    error_message = "`server_id` must be a valid PostgreSQL Flexible Server resource ID."
  }
}

variable "charset" {
  type        = string
  default     = null
  description = "The charset for the PostgreSQL database."
}

variable "collation" {
  type        = string
  default     = null
  description = "The collation for the PostgreSQL database."
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "location" {
  type        = string
  default     = null
  description = "The Azure region for this module's resources or telemetry deployment."

  validation {
    condition     = !var.enable_telemetry || var.location != null
    error_message = "The location must not be null when telemetry is enabled."
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
  description = "Optional timeout configuration for the PostgreSQL database resource."
}

variable "ignore_body_changes" {
  type = object({
    dbforpostgresql_flexible_servers_databases = optional(list(string), [])
  })
  default     = {}
  description = "Body paths whose changes AzAPI ignores for database resources."
  nullable    = false
}

variable "resource_types" {
  type = object({
    dbforpostgresql_flexible_servers_databases = optional(string, "Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01")
  })
  default     = {}
  description = "Override the AzAPI resource types and API versions used for database resources."
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = "Retry configuration for AzAPI database resources."
}
