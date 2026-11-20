mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
    }
  }
}

mock_provider "random" {}

variables {
  enable_telemetry    = false
  location            = "eastus"
  name                = "test-flex"
  resource_group_name = "rg-test"
  server_version      = "16"
  sku_name            = "GP_Standard_D2s_v3"
}

run "encryption_and_identities_are_absent_by_default" {
  command = apply

  providers = {
    azapi  = azapi
    random = random
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.dataEncryption == null &&
      azapi_resource.this.body.identity == null
    )
    error_message = "Omitted encryption and identities must not create encryption or identity blocks."
  }
}

run "explicit_null_encryption_preserves_absence" {
  command = apply

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    customer_managed_key = null
    managed_identities   = null
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.dataEncryption == null &&
      azapi_resource.this.body.identity == null
    )
    error_message = "Explicit nulls must retain the original no-encryption, no-identity defaults."
  }
}

run "primary_key_uri_and_identity_arm_id_are_preserved" {
  command = apply

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    customer_managed_key = {
      key_vault_key_id                  = "https://primary.vault.azure.net/keys/postgres/11111111111111111111111111111111"
      primary_user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary"
    }
    managed_identities = {
      user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary"]
    }
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.dataEncryption.type == "AzureKeyVault" &&
      azapi_resource.this.body.properties.dataEncryption.primaryKeyURI == var.customer_managed_key.key_vault_key_id &&
      azapi_resource.this.body.properties.dataEncryption.primaryUserAssignedIdentityId == var.customer_managed_key.primary_user_assigned_identity_id &&
      azapi_resource.this.body.properties.dataEncryption.geoBackupKeyURI == null &&
      azapi_resource.this.body.properties.dataEncryption.geoBackupUserAssignedIdentityId == null &&
      azapi_resource.this.body.identity.type == "UserAssigned" &&
      toset(keys(azapi_resource.this.body.identity.userAssignedIdentities)) == var.managed_identities.user_assigned_resource_ids
    )
    error_message = "Primary key URI and identity ARM ID must pass through unchanged without creating geo-backup settings."
  }
}

run "geo_backup_key_and_identity_are_independent" {
  command = apply

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    geo_redundant_backup_enabled = true
    customer_managed_key = {
      key_vault_key_id                     = "https://primary.vault.azure.net/keys/postgres/11111111111111111111111111111111"
      primary_user_assigned_identity_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary"
      geo_backup_key_vault_key_id          = "https://backup.vault.azure.net/keys/postgres-backup/22222222222222222222222222222222"
      geo_backup_user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/backup"
    }
    managed_identities = {
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary",
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/backup",
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/unrelated",
      ]
    }
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.backup.geoRedundantBackup == "Enabled" &&
      azapi_resource.this.body.properties.dataEncryption.type == "AzureKeyVault" &&
      azapi_resource.this.body.properties.dataEncryption.primaryKeyURI == var.customer_managed_key.key_vault_key_id &&
      azapi_resource.this.body.properties.dataEncryption.primaryUserAssignedIdentityId == var.customer_managed_key.primary_user_assigned_identity_id &&
      azapi_resource.this.body.properties.dataEncryption.geoBackupKeyURI == var.customer_managed_key.geo_backup_key_vault_key_id &&
      azapi_resource.this.body.properties.dataEncryption.geoBackupUserAssignedIdentityId == var.customer_managed_key.geo_backup_user_assigned_identity_id &&
      toset(keys(azapi_resource.this.body.identity.userAssignedIdentities)) == var.managed_identities.user_assigned_resource_ids
    )
    error_message = "Distinct primary and geo-backup keys and identities, including unrelated assigned identities, must not be dropped, swapped or converted to client IDs."
  }
}

run "versionless_sovereign_key_uris_are_not_reconstructed" {
  command = apply

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    geo_redundant_backup_enabled = true
    customer_managed_key = {
      key_vault_key_id                     = "https://primary.vault.azure.cn/keys/postgres"
      primary_user_assigned_identity_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary"
      geo_backup_key_vault_key_id          = "https://backup.vault.azure.cn/keys/postgres-backup"
      geo_backup_user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/backup"
    }
    managed_identities = {
      system_assigned = true
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary",
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/backup",
      ]
    }
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.dataEncryption.type == "AzureKeyVault" &&
      azapi_resource.this.body.properties.dataEncryption.primaryKeyURI == "https://primary.vault.azure.cn/keys/postgres" &&
      azapi_resource.this.body.properties.dataEncryption.geoBackupKeyURI == "https://backup.vault.azure.cn/keys/postgres-backup" &&
      azapi_resource.this.body.properties.dataEncryption.primaryUserAssignedIdentityId == var.customer_managed_key.primary_user_assigned_identity_id &&
      azapi_resource.this.body.properties.dataEncryption.geoBackupUserAssignedIdentityId == var.customer_managed_key.geo_backup_user_assigned_identity_id &&
      azapi_resource.this.body.identity.type == "SystemAssigned, UserAssigned" &&
      toset(keys(azapi_resource.this.body.identity.userAssignedIdentities)) == var.managed_identities.user_assigned_resource_ids
    )
    error_message = "Versionless key URIs, sovereign hosts and the combined identity type must be retained exactly."
  }
}

run "identity_membership_is_case_insensitive_without_rewriting_ids" {
  command = apply

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    customer_managed_key = {
      key_vault_key_id                  = "https://primary.vault.azure.net/keys/postgres"
      primary_user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-TEST/providers/Microsoft.ManagedIdentity/userAssignedIdentities/PRIMARY"
    }
    managed_identities = {
      user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary"]
    }
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.dataEncryption.primaryUserAssignedIdentityId == var.customer_managed_key.primary_user_assigned_identity_id &&
      toset(keys(azapi_resource.this.body.identity.userAssignedIdentities)) == var.managed_identities.user_assigned_resource_ids
    )
    error_message = "ARM ID membership checks must be case-insensitive without changing either caller-supplied ID."
  }
}

run "system_assigned_identity_without_encryption_is_preserved" {
  command = apply

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    managed_identities = { system_assigned = true }
  }

  assert {
    condition = (
      azapi_resource.this.body.identity.type == "SystemAssigned" &&
      azapi_resource.this.body.properties.dataEncryption == null
    )
    error_message = "The existing system-assigned identity capability must not depend on configuring encryption."
  }
}

run "primary_identity_client_id_is_rejected" {
  command = plan

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    customer_managed_key = {
      key_vault_key_id                  = "https://primary.vault.azure.net/keys/postgres"
      primary_user_assigned_identity_id = "11111111-1111-4111-8111-111111111111"
    }
  }

  expect_failures = [var.customer_managed_key]
}

run "geo_backup_identity_client_id_is_rejected" {
  command = plan

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    customer_managed_key = {
      key_vault_key_id                     = "https://primary.vault.azure.net/keys/postgres"
      geo_backup_key_vault_key_id          = "https://backup.vault.azure.net/keys/postgres-backup"
      geo_backup_user_assigned_identity_id = "22222222-2222-4222-8222-222222222222"
    }
  }

  expect_failures = [var.customer_managed_key]
}

run "primary_key_arm_id_is_rejected" {
  command = plan

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    customer_managed_key = {
      key_vault_key_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/primary/keys/postgres"
    }
  }

  expect_failures = [var.customer_managed_key]
}

run "geo_backup_secret_uri_is_rejected" {
  command = plan

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    customer_managed_key = {
      key_vault_key_id            = "https://primary.vault.azure.net/keys/postgres"
      geo_backup_key_vault_key_id = "https://backup.vault.azure.net/secrets/not-a-key"
    }
  }

  expect_failures = [var.customer_managed_key]
}

run "managed_identity_client_id_is_rejected" {
  command = plan

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    managed_identities = { user_assigned_resource_ids = ["11111111-1111-4111-8111-111111111111"] }
  }

  expect_failures = [var.managed_identities]
}

run "unassigned_primary_identity_is_rejected" {
  command = plan

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    customer_managed_key = {
      key_vault_key_id                  = "https://primary.vault.azure.net/keys/postgres"
      primary_user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary"
    }
    managed_identities = {
      user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/unrelated"]
    }
  }

  expect_failures = [azapi_resource.this]
}

run "unassigned_geo_backup_identity_is_rejected" {
  command = plan

  providers = {
    azapi  = azapi
    random = random
  }

  variables {
    customer_managed_key = {
      key_vault_key_id                     = "https://primary.vault.azure.net/keys/postgres"
      primary_user_assigned_identity_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary"
      geo_backup_key_vault_key_id          = "https://backup.vault.azure.net/keys/postgres-backup"
      geo_backup_user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/backup"
    }
    managed_identities = {
      user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/primary"]
    }
  }

  expect_failures = [azapi_resource.this]
}
