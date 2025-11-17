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

resource "azurerm_role_assignment" "func_splunk_mid_eventhub_owner" {
  principal_id                     = azurerm_user_assigned_identity.func_splunk_mid.principal_id
  scope                            = azurerm_eventhub_namespace.this.id
  role_definition_name             = "Azure Event Hubs Data Owner"
  skip_service_principal_aad_check = false
}

resource "azurerm_function_app_flex_consumption" "this" {
  depends_on                                     = [azurerm_role_assignment.func_splunk_mid_sta_file, azurerm_role_assignment.func_splunk_mid_sta_queue, azurerm_role_assignment.func_splunk_mid_sta_table, azurerm_role_assignment.func_splunk_mid_keyvault]
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  name                                           = var.function_app_name
  service_plan_id                                = var.function_app.service_plan_id
  virtual_network_subnet_id                      = var.function_app.vnet_subnet_id
  instance_memory_in_mb                          = var.instance_memory_mb
  webdeploy_publish_basic_authentication_enabled = false
  public_network_access_enabled                  = false
  https_only                                     = true
  runtime_name                                   = "node"
  runtime_version                                = "22"
  maximum_instance_count                         = var.maximum_instance_count

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.func_splunk_mid.id]
  }
  app_settings = {
    # https://github.com/hashicorp/terraform-provider-azurerm/issues/30732 open issue and we need to set an empty variable to properly use the managed identity
    "AzureWebJobsStorage"                  = ""
    "AzureWebJobsStorage__blobServiceUri"  = module.storage_account.endpoints.primary_blob_endpoint
    "AzureWebJobsStorage__queueServiceUri" = module.storage_account.endpoints.primary_queue_endpoint
    "AzureWebJobsStorage__tableServiceUri" = module.storage_account.endpoints.primary_table_endpoint
    "AzureWebJobsStorage__fileServiceUri"  = module.storage_account.endpoints.primary_file_endpoint
    "AzureWebJobsStorage__credential"      = "ManagedIdentity"
    "AzureWebJobsStorage__clientId"        = azurerm_user_assigned_identity.func_splunk_mid.client_id
    "AzureWebJobsStorage__accountName"     = module.storage_account.name

    "EventHubConnection__fullyQualifiedNamespace" = "${var.event_hub.namespace_name}.servicebus.windows.net"
    "EventHubConnection__clientId"                = azurerm_user_assigned_identity.func_splunk_mid.client_id
    "EventHubConnection__credential"              = "managedIdentity"

    "SPLUNK_HEC_URL"                   = var.splunk_hec_url
    "SPLUNK_HEC_TOKEN"                 = "@Microsoft.KeyVault(SecretUri=${data.azurerm_key_vault_secret.splunk_hec_token.id})"

    "AAD_LOG_HUB_NAME"                                = var.event_hub.hub_name
    "AAD_LOG_CONSUMER_GROUP"                          = "${var.event_hub.hub_name}cg-aad_log"
    "AAD_LOG_SOURCETYPE"                              = "entra_log"
    "AAD_NON_INTERACTIVE_SIGNIN_LOG_HUB_NAME"         = var.event_hub.hub_name
    "AAD_NON_INTERACTIVE_SIGNIN_LOG_CONSUMER_GROUP"   = "${var.event_hub.hub_name}cg-ni_signin_log"
    "AAD_NON_INTERACTIVE_SIGNIN_LOG_SOURCETYPE"       = "entra_log"
    "AAD_SERVICE_PRINCIPAL_SIGNIN_LOG_HUB_NAME"       = var.event_hub.hub_name
    "AAD_SERVICE_PRINCIPAL_SIGNIN_LOG_CONSUMER_GROUP" = "${var.event_hub.hub_name}cg-sp_signin_log"
    "AAD_SERVICE_PRINCIPAL_SIGNIN_LOG_SOURCETYPE"     = "entra_log"
    "ACTIVITY_LOG_HUB_NAME"                           = var.event_hub.hub_name
    "ACTIVITY_LOG_CONSUMER_GROUP"                     = "${var.event_hub.hub_name}cg-activity_log"
    "ACTIVITY_LOG_SOURCETYPE"                         = "azure_activity_log"
    "DIAGNOSTIC_LOG_HUB_NAME"                         = var.event_hub.hub_name
    "DIAGNOSTIC_LOG_CONSUMER_GROUP"                   = "${var.event_hub.hub_name}cg-diagnostic_log"
    "DIAGNOSTIC_LOG_SOURCETYPE"                       = "azure_diagnostic_log"
    "METRICS_LOG_HUB_NAME"                            = var.event_hub.hub_name
    "METRICS_LOG_CONSUMER_GROUP"                      = "${var.event_hub.hub_name}cg-metrics_log"
    "METRICS_LOG_SOURCETYPE"                          = "azure_metrics_log"
    "CUSTOM_TRUSTED_CA_BASE64"                        = var.splunk_custom_ca != null ? "@Microsoft.KeyVault(SecretUri=${data.azurerm_key_vault_secret.splunk_custom_ca[0].id})" : ""
  }

  site_config {
    http2_enabled                          = false
    minimum_tls_version                    = var.function_app.minimum_tls_version
    application_insights_connection_string = azurerm_application_insights.appr_appi.connection_string
    application_insights_key               = azurerm_application_insights.appr_appi.instrumentation_key
    vnet_route_all_enabled                 = true
  }

  storage_container_type            = "blobContainer"
  storage_container_endpoint        = "${module.storage_account.endpoints.primary_blob_endpoint}${module.storage_account.name}"
  storage_authentication_type       = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.func_splunk_mid.id
  # storage_authentication_type = "StorageAccountConnectionString"
  # storage_access_key          = module.storage_account.access_keys.primary

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
