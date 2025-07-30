resource "azurerm_user_assigned_identity" "ehns_splunk_mid" {
  name                = format("${var.managed_identity_name}%s", "-ehns")
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = merge(
    try(var.tags),
    tomap({
      "Resource Type" = "Managed Identity"
    })
  )
}

resource "azurerm_role_assignment" "ehns_splunk_mid" {
  principal_id                     = azurerm_user_assigned_identity.ehns_splunk_mid.principal_id
  scope                            = data.azurerm_key_vault.this.id
  role_definition_name             = "Key Vault Crypto User"
  skip_service_principal_aad_check = false
}

resource "azurerm_role_assignment" "security_provider" {
  count                            = var.windows_azure_security_resource_provider_id != null ? 1 : 0
  principal_id                     = var.windows_azure_security_resource_provider_id # Windows Azure Security Resource Provider
  scope                            = resource.azurerm_eventhub_namespace.this.id
  role_definition_name             = "Azure Event Hubs Data Sender"
  skip_service_principal_aad_check = false
}

resource "azurerm_eventhub_namespace" "this" {
  location                      = var.location
  resource_group_name           = var.resource_group_name
  name                          = var.event_hub.namespace_name
  sku                           = var.event_hub.sku
  capacity                      = var.event_hub.capacity
  public_network_access_enabled = false

  network_rulesets {
    public_network_access_enabled  = false # should be false
    default_action                 = "Deny"
    trusted_service_access_enabled = true
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ehns_splunk_mid.id]
  }

  tags = merge(
    try(var.tags),
    tomap({
      "Resource Type" = "Event Hub Namespace"
    })
  )
}

resource "azurerm_eventhub_namespace_customer_managed_key" "this" {
  count =  var.enable_event_hub_cmk_encryption ? 1 : 0

  eventhub_namespace_id             = azurerm_eventhub_namespace.this.id
  key_vault_key_ids                 = [data.azurerm_key_vault_key.cmk_encryption_key.id]
  user_assigned_identity_id         = azurerm_user_assigned_identity.ehns_splunk_mid.id
  infrastructure_encryption_enabled = true
}

resource "azurerm_eventhub" "this" {
  name              = var.event_hub.hub_name
  namespace_id      = azurerm_eventhub_namespace.this.id
  partition_count   = 4
  message_retention = 7
  depends_on        = [azurerm_eventhub_namespace_customer_managed_key.this[0]]
}

resource "azurerm_eventhub_namespace_authorization_rule" "this" {
  name                = var.event_hub_namespace.diagnostics_policy_authorization_rule_name
  namespace_name      = azurerm_eventhub_namespace.this.name
  resource_group_name = var.resource_group_name

  listen = false
  send   = true
  manage = false
}

resource "azurerm_eventhub_authorization_rule" "this" {
  for_each            = var.event_hub_authorization_rules
  name                = "${var.event_hub.authorization_rule}-${each.key}"
  namespace_name      = azurerm_eventhub_namespace.this.name
  eventhub_name       = azurerm_eventhub.this.name
  resource_group_name = var.resource_group_name
  listen              = each.value.listen
  send                = each.value.send
  manage              = each.value.manage
}

resource "azurerm_role_assignment" "this" {
  principal_id                     = data.azurerm_client_config.current.object_id
  scope                            = azurerm_eventhub.this.id
  role_definition_name             = "Azure Event Hubs Data Owner"
  skip_service_principal_aad_check = false
}

resource "azurerm_eventhub_consumer_group" "this" {
  for_each            = var.event_hub_consumer_groups
  name                = "${var.event_hub.consumer_group}-${each.key}"
  namespace_name      = azurerm_eventhub_namespace.this.name
  eventhub_name       = azurerm_eventhub.this.name
  resource_group_name = var.resource_group_name
}
