data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "this" {
  name                = var.key_vault.name
  resource_group_name = var.key_vault.resource_group_name
}

data "azurerm_key_vault_secret" "splunk_hec_token" {
  name         = var.key_vault_secret_splunk_hec_token_name
  key_vault_id = data.azurerm_key_vault.this.id
}

data "azurerm_key_vault_key" "cmk_encryption_key" {
  name         = var.key_vault_secret_cmk_key_name
  key_vault_id = data.azurerm_key_vault.this.id
}
