variable "location" {
  type        = string
  description = "Location of the deployed Resources"
}

variable "tags" {
  description = "A map of tags to assign to the resource."
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  type        = string
  description = "The Resource Group that will be used the deployment"
}

variable "function_app_name" {
  type        = string
  description = "The name of the Function App to be deployed"
}

variable "application_insights_name" {
  type        = string
  description = "The name of the Application Insights to be deployed"
}

variable "managed_identity_name" {
  type        = string
  description = "The name of the Managed Identity to be deployed"
}

variable "event_hub" {
  description = "The properties of the Event Hub to be deployed"
  type = object({
    namespace_name     = string
    sku                = optional(string, "Premium")
    capacity           = optional(number, 2)
    hub_name           = string
    authorization_rule = string
    consumer_group     = string
  })
}

variable "event_hub_namespace" {
  description = "The properties of the Event Hub Namespace to be deployed"
  type = object({
    diagnostics_policy_authorization_rule_name = string
  })
}

variable "function_app" {
  description = "The parameters to be used for the Function App deployment. Inludes the ID of the App Service Plan to be used and the ID of the subent for regional VNET integration"
  type = object({
    service_plan_id = string
    vnet_subnet_id  = string
  })
}

variable "key_vault" {
  description = "The properties of the Key Vault to be used to store secrets"
  type = object({
    name                = string
    resource_group_name = string
  })
  default = null
}

variable "key_vault_secret_splunk_hec_token_name" {
  type        = string
  description = "The name of the Key Vault secret containing the Splunk HEC token"
  default     = "splunk-hec-token"
}

variable "splunk_hec_url" {
  description = "Splunk HEC endpoint"
  type        = string
}

variable "key_vault_secret_cmk_key_name" {
  type    = string
  default = "cmkrsa"
}

variable "storage_account" {
  description = "The configuration of the Storage Account to be deployed as storage for the Function App"
  type = object({
    name                              = string
    public_network_access_enabled     = optional(bool, false)
    account_tier                      = optional(string, "Standard")
    account_replication_type          = optional(string, "ZRS")
    access_tier                       = optional(string, "Hot")
    log_retention_days                = optional(number, null)
    move_to_cold_after_days           = optional(number, null)
    move_to_archive_after_days        = optional(number, null)
    snapshot_retention_days           = optional(number, 90)
    infrastructure_encryption_enabled = optional(bool, true)
    cmk_key_vault_id                  = optional(string, null)
    cmk_key_name                      = optional(string, "cmkrsa")
    system_assigned_identity_enabled  = optional(bool, false)
    user_assigned_identities          = optional(list(string), [])
    enable_law_data_export            = optional(bool, false)
    immutability_policy = optional(object({
      state                         = optional(string, "Unlocked")
      allow_protected_append_writes = optional(bool, true)
      period_since_creation_in_days = optional(number, 14)
    }), null)
  })
  default = null
}

variable "splunk_storage_containers" {
  description = "Blob Containers to be created in the Storage Account"
  type        = set(string)
}

variable "event_hub_authorization_rules" {
  description = "Event Hub authorization rules"
  type = map(
    object({
      listen = bool
      send   = bool
      manage = bool
    })
  )
}

variable "enable_event_hub_cmk_encryption" {
  type        = bool
  description = "Whether or not encryption is enabled on the hub using a CMK"
  default     = true
}

variable "event_hub_consumer_groups" {
  description = "Event Hub consumer groups"
  type        = set(string)
}

variable "windows_azure_security_resource_provider_id" {
  type        = string
  description = "Optional: This is used to enable Defender export to Event Hub. The Windows Azure Security resource provider ID can be found under Enterprise Applications."
  default     = null
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "The resource id of the log analytics workspace to which application insights logs should be sent"
}
