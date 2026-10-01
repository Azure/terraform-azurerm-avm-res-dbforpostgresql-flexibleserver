variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "Whether to enable module telemetry. See https://aka.ms/avm/telemetryinfo."
}

variable "ignore_body_changes" {
  type = object({
    resources_resource_groups      = optional(list(string), [])
    operationalinsights_workspaces = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative dot-notation paths to ignore. Ignored configuration is not sent to Azure and changes take effect after apply.

- `resources_resource_groups` - Paths ignored on the resource group.
- `operationalinsights_workspaces` - Paths ignored on the Log Analytics workspace.
DESCRIPTION
  nullable    = false
}

variable "location" {
  type        = string
  default     = "australiaeast"
  description = "Azure region for the example resources."
  nullable    = false
}

variable "resource_types" {
  type = object({
    resources_resource_groups      = optional(string, "Microsoft.Resources/resourceGroups@2025-04-01")
    operationalinsights_workspaces = optional(string, "Microsoft.OperationalInsights/workspaces@2023-09-01")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions used by this example.

- `resources_resource_groups` - Resource type and API version for the resource group.
- `operationalinsights_workspaces` - Resource type and API version for the Log Analytics workspace.
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
  description = "AzAPI retry configuration for the resource group and workspace."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the example resources."
  nullable    = false
}

variable "timeouts" {
  type = object({
    create = optional(string)
    delete = optional(string)
    read   = optional(string)
    update = optional(string)
  })
  default     = null
  description = "AzAPI operation timeouts for the resource group and workspace."
}
