variable "ignore_body_changes" {
  type = object({
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body paths whose changes AzAPI ignores for private endpoint locks and role assignments. Non-empty values require Terraform 1.11 or later and take effect after apply. Ignored changes are not sent to Azure until the path is removed.

- `authorization_locks` - Ignored body paths for private endpoint locks.
- `authorization_role_assignments` - Ignored body paths for private endpoint role assignments.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2016-09-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    authorization_role_definitions = optional(string, "Microsoft.Authorization/roleDefinitions@2022-04-01")
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI resource types and API versions used for private endpoint authorization resources.

- `authorization_locks` - Private endpoint management locks.
- `authorization_role_assignments` - Private endpoint role assignments.
- `authorization_role_definitions` - Role definition lookups at each private endpoint scope.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration for AzAPI private endpoint locks, role assignments and role definition lookups. Defaults to null, using provider defaults.

- `error_message_regex` - Error message patterns that trigger a retry.
- `interval_seconds` - Initial interval between retries.
- `max_interval_seconds` - Maximum interval between retries.
DESCRIPTION
}
