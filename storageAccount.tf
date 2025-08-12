resource "azurerm_user_assigned_identity" "sta_splunk_mid" {
  name                = format("${var.managed_identity_name}%s", "-sta")
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = merge(
    try(var.tags),
    tomap({
      "Resource Type" = "Managed Identity"
    })
  )
}

resource "azurerm_role_assignment" "sta_splunk_mid" {
  principal_id                     = azurerm_user_assigned_identity.sta_splunk_mid.principal_id
  scope                            = data.azurerm_key_vault.this.id
  role_definition_name             = "Key Vault Crypto User"
  skip_service_principal_aad_check = false
}


module "storage_account" {
  depends_on = [azurerm_role_assignment.sta_splunk_mid]
  source     = "github.com/schubergphilis/terraform-azure-mcaf-storage-account.git?ref=v0.10.0"

  name                              = var.storage_account.name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  account_tier                      = var.storage_account.account_tier
  account_replication_type          = var.storage_account.account_replication_type
  account_kind                      = "StorageV2"
  access_tier                       = var.storage_account.access_tier
  infrastructure_encryption_enabled = var.storage_account.infrastructure_encryption_enabled
  cmk_key_vault_id                  = var.storage_account.cmk_key_vault_id
  cmk_key_name                      = var.storage_account.cmk_key_name
  system_assigned_identity_enabled  = var.storage_account.system_assigned_identity_enabled
  user_assigned_identities          = tolist([azurerm_user_assigned_identity.sta_splunk_mid.id])
  immutability_policy               = var.storage_account.immutability_policy
  shared_access_key_enabled         = true
  tags = merge(
    try(var.tags),
    tomap({
      "Resource Type" = "Storage Account"
    })
  )
  network_configuration = {
    ip_rules = try(var.storage_account.allowed_ips)
  }
}

resource "azurerm_storage_container" "this" {
  for_each              = var.splunk_storage_containers
  name                  = each.key
  storage_account_id    = module.storage_account.id
  container_access_type = "private"
}
