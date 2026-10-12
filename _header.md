# Azure PostgreSQL Flexible Server module

This is a Terraform module for PostgreSQL Flexible Server in the style of Azure Verified Modules.  For official modules please see <https://aka.ms/AVM>.

Use the `modules/database` submodule when application teams need to manage databases separately from the server lifecycle.

## Private endpoint compatibility

Endpoint `role_assignments` and `lock` settings are now applied; earlier versions accepted but ignored them. Review existing values before upgrading because they now create permissions and locks. Omitted/null settings create neither, `lock.kind = "None"` disables the endpoint lock, and the server's lock is not implicitly copied to endpoints.

Endpoint resource addresses, `pe-${name}`/`pse-${name}` defaults, per-endpoint tags and DNS-management selection are unchanged. Omitted/null subresource and IP member names remain `postgresqlServer`. Explicit `subresource_name` or IP `member_name` values are now honored and can replace an endpoint when they differ from those historical defaults. Use only values supported by PostgreSQL Private Link.

This AzureRM-based endpoint implementation still accepts a resource group **name**, not an ARM ID, and defaults `location` to the module's `location`. Tags are not inherited from the server. Endpoint role assignments use AzAPI: it performs no AzureRM directory preflight, so `skip_service_principal_aad_check` is accepted for interface compatibility but has no effect for either value. Set `principal_type` explicitly when required. Role definition lookup requires read access at the endpoint scope.

> [!IMPORTANT]
> As the overall AVM framework is not GA (generally available) yet - the CI framework and test automation is not fully functional and implemented across all supported languages yet - breaking changes are expected, and additional customer feedback is yet to be gathered and incorporated. Hence, modules **MUST NOT** be published at version `1.0.0` or higher at this time.
>
> All module **MUST** be published as a pre-release version (e.g., `0.1.0`, `0.1.1`, `0.2.0`, etc.) until the AVM framework becomes GA.
>
> However, it is important to note that this **DOES NOT** mean that the modules cannot be consumed and utilized. They **CAN** be leveraged in all types of environments (dev, test, prod etc.). Consumers can treat them just like any other IaC module and raise issues or feature requests against them as they learn from the usage of the module. Consumers should also read the release notes for each version, if considering updating to a more recent version of a module to see if there are any considerations or breaking changes etc.
