# Azure PostgreSQL Flexible Server module

This is a Terraform module for PostgreSQL Flexible Server in the style of Azure Verified Modules.  For official modules please see <https://aka.ms/AVM>.

Use the `modules/database` submodule when application teams need to manage databases separately from the server lifecycle.

## AzureRM provider compatibility

The server module supports AzureRM `>= 4.31, < 6.0`, including AzureRM 5.x. AzureRM 4.31 is the minimum version that supports the `enabled_metric` diagnostic setting block required by AzureRM 5. Consumers using AzureRM 4.12–4.30 must upgrade their provider. The standalone database submodule continues to support AzureRM `>= 4.12, < 6.0`.

AzureRM 5 defaults to no automatic resource provider registration. Register `Microsoft.DBforPostgreSQL` in the subscription before deployment, or include it in `resource_providers_to_register` in the consuming configuration's AzureRM provider. Register `Microsoft.Network` and `Microsoft.Insights` when using private endpoints and diagnostic settings, respectively. The examples explicitly register `Microsoft.DBforPostgreSQL` and require subscription permissions to do so.

When upgrading from AzureRM 4, run `terraform init -upgrade` and review a normal plan with refresh enabled. Resource addresses and module inputs and outputs are unchanged; no module state moves are required. Existing diagnostic metrics are read back by the provider into `enabled_metric`. Follow the [AzureRM 5 upgrade guide](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/5.0-upgrade-guide) for provider-level changes, including the removal of `skip_provider_registration` and the relocation of enhanced validation configuration into `features`.

AzureRM 5 also validates that `customer_managed_key.key_vault_key_id` and `geo_backup_key_vault_key_id` are Key Vault or Managed HSM **key** URLs. Secret and certificate URLs are not accepted.

> [!IMPORTANT]
> As the overall AVM framework is not GA (generally available) yet - the CI framework and test automation is not fully functional and implemented across all supported languages yet - breaking changes are expected, and additional customer feedback is yet to be gathered and incorporated. Hence, modules **MUST NOT** be published at version `1.0.0` or higher at this time.
>
> All module **MUST** be published as a pre-release version (e.g., `0.1.0`, `0.1.1`, `0.2.0`, etc.) until the AVM framework becomes GA.
>
> However, it is important to note that this **DOES NOT** mean that the modules cannot be consumed and utilized. They **CAN** be leveraged in all types of environments (dev, test, prod etc.). Consumers can treat them just like any other IaC module and raise issues or feature requests against them as they learn from the usage of the module. Consumers should also read the release notes for each version, if considering updating to a more recent version of a module to see if there are any considerations or breaking changes etc.
