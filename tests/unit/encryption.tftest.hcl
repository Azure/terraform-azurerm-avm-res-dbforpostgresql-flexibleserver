mock_provider "azurerm" {
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-flex"
    }
  }
}

mock_provider "azapi" {}

mock_provider "modtm" {}

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
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
  }

  assert {
    condition = (
      length(azurerm_postgresql_flexible_server.this.customer_managed_key) == 0 &&
      length(azurerm_postgresql_flexible_server.this.identity) == 0
    )
    error_message = "Omitted encryption and identities must not create encryption or identity blocks."
  }
}

run "explicit_null_encryption_preserves_absence" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
  }

  variables {
    customer_managed_key = null
    managed_identities   = null
  }

  assert {
    condition = (
      length(azurerm_postgresql_flexible_server.this.customer_managed_key) == 0 &&
      length(azurerm_postgresql_flexible_server.this.identity) == 0
    )
    error_message = "Explicit nulls must retain the original no-encryption, no-identity defaults."
  }
}

run "primary_key_uri_and_identity_arm_id_are_preserved" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).key_vault_key_id == var.customer_managed_key.key_vault_key_id &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).primary_user_assigned_identity_id == var.customer_managed_key.primary_user_assigned_identity_id &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).geo_backup_key_vault_key_id == null &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).geo_backup_user_assigned_identity_id == null &&
      one(azurerm_postgresql_flexible_server.this.identity).type == "UserAssigned" &&
      toset(one(azurerm_postgresql_flexible_server.this.identity).identity_ids) == var.managed_identities.user_assigned_resource_ids
    )
    error_message = "Primary key URI and identity ARM ID must pass through unchanged without creating geo-backup settings."
  }
}

run "geo_backup_key_and_identity_are_independent" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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
      azurerm_postgresql_flexible_server.this.geo_redundant_backup_enabled &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).key_vault_key_id == var.customer_managed_key.key_vault_key_id &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).primary_user_assigned_identity_id == var.customer_managed_key.primary_user_assigned_identity_id &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).geo_backup_key_vault_key_id == var.customer_managed_key.geo_backup_key_vault_key_id &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).geo_backup_user_assigned_identity_id == var.customer_managed_key.geo_backup_user_assigned_identity_id &&
      toset(one(azurerm_postgresql_flexible_server.this.identity).identity_ids) == var.managed_identities.user_assigned_resource_ids
    )
    error_message = "Distinct primary and geo-backup keys and identities, including unrelated assigned identities, must not be dropped, swapped or converted to client IDs."
  }
}

run "versionless_sovereign_key_uris_are_not_reconstructed" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).key_vault_key_id == "https://primary.vault.azure.cn/keys/postgres" &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).geo_backup_key_vault_key_id == "https://backup.vault.azure.cn/keys/postgres-backup" &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).primary_user_assigned_identity_id == var.customer_managed_key.primary_user_assigned_identity_id &&
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).geo_backup_user_assigned_identity_id == var.customer_managed_key.geo_backup_user_assigned_identity_id &&
      one(azurerm_postgresql_flexible_server.this.identity).type == "SystemAssigned, UserAssigned" &&
      toset(one(azurerm_postgresql_flexible_server.this.identity).identity_ids) == var.managed_identities.user_assigned_resource_ids
    )
    error_message = "Versionless key URIs, sovereign hosts and the combined identity type must be retained exactly."
  }
}

run "identity_membership_is_case_insensitive_without_rewriting_ids" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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
      one(azurerm_postgresql_flexible_server.this.customer_managed_key).primary_user_assigned_identity_id == var.customer_managed_key.primary_user_assigned_identity_id &&
      toset(one(azurerm_postgresql_flexible_server.this.identity).identity_ids) == var.managed_identities.user_assigned_resource_ids
    )
    error_message = "ARM ID membership checks must be case-insensitive without changing either caller-supplied ID."
  }
}

run "system_assigned_identity_without_encryption_is_preserved" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
  }

  variables {
    managed_identities = { system_assigned = true }
  }

  assert {
    condition = (
      one(azurerm_postgresql_flexible_server.this.identity).type == "SystemAssigned" &&
      length(azurerm_postgresql_flexible_server.this.customer_managed_key) == 0
    )
    error_message = "The existing system-assigned identity capability must not depend on configuring encryption."
  }
}

run "primary_identity_client_id_is_rejected" {
  command = plan

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
  }

  variables {
    managed_identities = { user_assigned_resource_ids = ["11111111-1111-4111-8111-111111111111"] }
  }

  expect_failures = [var.managed_identities]
}

run "unassigned_primary_identity_is_rejected" {
  command = plan

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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

  expect_failures = [azurerm_postgresql_flexible_server.this]
}

run "unassigned_geo_backup_identity_is_rejected" {
  command = plan

  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
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

  expect_failures = [azurerm_postgresql_flexible_server.this]
}
