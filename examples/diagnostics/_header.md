# Diagnostic settings example

Deploys a PostgreSQL 16 server, an application database, and a diagnostic setting that sends `allLogs` and `AllMetrics` to a Log Analytics workspace. The resource group and workspace use AzAPI. The server uses a General Purpose SKU with zone-redundant high availability, geo-redundant backup, and the module's custom maintenance window.

Run `avm test e2e --example diagnostics` from the repository root to deploy, verify idempotency, and clean up this example. The Azure identity needs permission to register `Microsoft.DBforPostgreSQL`, `Microsoft.Insights`, and `Microsoft.OperationalInsights`.
