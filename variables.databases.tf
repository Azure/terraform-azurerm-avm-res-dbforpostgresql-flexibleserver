variable "databases" {
  type = map(object({
    charset   = string
    collation = string
    name      = string
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      read   = optional(string)
    }))
  }))
  default     = {}
  description = <<-EOT
 - `charset` - (Required)  Specifies the Charset for the PostgreSQL Database, which needs [to be a valid PostgreSQL Charset](https://www.postgresql.org/docs/current/static/multibyte.html). Changing this forces a new resource to be created.
 - `collation` - (Required) Specifies the Collation for the PostgreSQL Database, which needs [to be a valid PostgreSQL Collation](https://www.postgresql.org/docs/current/static/collation.html). Note that Microsoft uses different [notation](https://msdn.microsoft.com/library/windows/desktop/dd373814.aspx)
 - `name` - (Required) Specifies the name of the PostgreSQL Database, which needs [to be a valid PostgreSQL identifier](https://www.postgresql.org/docs/current/static/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS). Changing this forces a new resource to be created.

 ---
 `timeouts` block supports the following:
 - `create` - (Defaults to 60 minutes) Used when creating the PostgreSQL Database.
 - `delete` - (Defaults to 60 minutes) Used when deleting the PostgreSQL Database.
 - `read` - (Defaults to 5 minutes) Used when retrieving the PostgreSQL Database.
EOT
  nullable    = false
}
