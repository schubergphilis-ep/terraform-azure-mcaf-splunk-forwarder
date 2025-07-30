resource "azurerm_user_assigned_identity" "func_splunk_mid" {
  name                = format("${var.managed_identity_name}%s", "-func")
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = merge(
    try(var.tags),
    tomap({
      "Resource Type" = "Managed Identity"
    })
  )
}

resource "azurerm_role_assignment" "func_splunk_mid_sta_blob" {
  principal_id                     = azurerm_user_assigned_identity.func_splunk_mid.principal_id
  scope                            = module.storage_account.id
  role_definition_name             = "Storage Blob Data Contributor"
  skip_service_principal_aad_check = false
}

resource "azurerm_role_assignment" "func_splunk_mid_sta_file" {
  principal_id                     = azurerm_user_assigned_identity.func_splunk_mid.principal_id
  scope                            = module.storage_account.id
  role_definition_name             = "Storage File Data Privileged Contributor"
  skip_service_principal_aad_check = false
}

resource "azurerm_role_assignment" "func_splunk_mid_sta_queue" {
  principal_id                     = azurerm_user_assigned_identity.func_splunk_mid.principal_id
  scope                            = module.storage_account.id
  role_definition_name             = "Storage Queue Data Contributor"
  skip_service_principal_aad_check = false
}

resource "azurerm_role_assignment" "func_splunk_mid_sta_table" {
  principal_id                     = azurerm_user_assigned_identity.func_splunk_mid.principal_id
  scope                            = module.storage_account.id
  role_definition_name             = "Storage Table Data Contributor"
  skip_service_principal_aad_check = false
}

resource "azurerm_role_assignment" "func_splunk_mid_keyvault" {
  principal_id                     = azurerm_user_assigned_identity.func_splunk_mid.principal_id
  scope                            = data.azurerm_key_vault.this.id
  role_definition_name             = "Key Vault Secrets User"
  skip_service_principal_aad_check = false
}

resource "azurerm_role_assignment" "func_splunk_mid_eventhub" {
  principal_id                     = azurerm_user_assigned_identity.func_splunk_mid.principal_id
  scope                            = azurerm_eventhub_namespace.this.id
  role_definition_name             = "Azure Event Hubs Data Receiver"
  skip_service_principal_aad_check = false
}

resource "azurerm_linux_function_app" "this" {
  depends_on                                     = [module.storage_account, azurerm_role_assignment.func_splunk_mid_sta_file, azurerm_role_assignment.func_splunk_mid_sta_queue, azurerm_role_assignment.func_splunk_mid_sta_table, azurerm_role_assignment.func_splunk_mid_keyvault]
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  name                                           = var.function_app_name
  service_plan_id                                = var.function_app.service_plan_id
  virtual_network_subnet_id                      = var.function_app.vnet_subnet_id
  storage_account_name                           = module.storage_account.name
  storage_uses_managed_identity                  = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  public_network_access_enabled                  = false
  https_only                                     = true
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.func_splunk_mid.id]
  }
  key_vault_reference_identity_id = azurerm_user_assigned_identity.func_splunk_mid.id
  app_settings = {
    "AzureWebJobsStorage__blobServiceUri" = module.storage_account.endpoints.primary_blob_endpoint
    "AzureWebJobsStorage__clientId"       = azurerm_user_assigned_identity.func_splunk_mid.client_id
    "AzureWebJobsStorage__credential"     = "managedidentity"
    "EVHNS__fullyQualifiedNamespace"      = "${var.event_hub.namespace_name}.servicebus.windows.net"
    "EVHNS__clientId"                     = azurerm_user_assigned_identity.func_splunk_mid.client_id
    "EVHNS__credential"                   = "managedidentity"
    "EVH__NAME"                           = var.event_hub.hub_name
    "EVH__CONSUMERGROUP"                  = local.function_app_consumer_group
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = true
    "WEBSITE_ENABLE_SYNC_UPDATE_SITE"     = true
    "WEBSITE_RUN_FROM_PACKAGE"            = 1
    "SPLUNK_HEC_URL"                      = var.splunk_hec_url
    "SPLUNK_HEC_TOKEN"                    = "@Microsoft.KeyVault(SecretUri=${data.azurerm_key_vault_secret.splunk_hec_token.id})"
    "FUNCTIONS_WORKER_RUNTIME"            = "node"
    "FUNCTIONS_EXTENSION_VERSION"         = "~4"
  }
  site_config {
    always_on                              = false
    http2_enabled                          = true
    ftps_state                             = "Disabled"
    minimum_tls_version                    = "1.3"
    application_insights_connection_string = azurerm_application_insights.appr_appi.connection_string
    application_insights_key               = azurerm_application_insights.appr_appi.instrumentation_key
    vnet_route_all_enabled                 = true
    application_stack {
      node_version = "20-lts"
    }
  }


  storage_account {
    account_name = module.storage_account.name
    name         = module.storage_account.name
    type         = "AzureBlob"
    share_name   = "functionapp"
    access_key   = module.storage_account.access_keys.primary
  }
  tags = merge(
    try(var.tags),
    tomap({
      "Resource Type" = "Function App"
    })
  )
}

resource "azurerm_application_insights" "appr_appi" {
  name                = var.application_insights_name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "Node.JS"
  retention_in_days   = 30
  tags = merge(
    try(var.tags),
    tomap({
      "Resource Type" = "Application Insights"
    })
  )
  workspace_id = var.log_analytics_workspace_id

  internet_ingestion_enabled = false
  internet_query_enabled     = false
}
