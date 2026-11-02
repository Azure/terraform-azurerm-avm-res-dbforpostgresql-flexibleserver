variable "name" {
  type        = string
  description = "Specifies the name of the PostgreSQL database."
}

variable "server_id" {
  type        = string
  description = "The resource ID of the PostgreSQL Flexible Server that will host the database."
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
  })
  default     = null
  description = "Optional timeout configuration for the PostgreSQL database resource."
}
