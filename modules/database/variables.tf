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

variable "timeouts" {
  type = object({
    create = optional(string)
    delete = optional(string)
    read   = optional(string)
  })
  default     = null
  description = "Optional timeout configuration for the PostgreSQL database resource."
}
