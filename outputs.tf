output "customer_managed_key_enabled" {
  description = "Whether the Sentinel workspace was onboarded with a customer-managed key (null when create_onboarding is false)."
  value       = one(azurerm_sentinel_log_analytics_workspace_onboarding.this[*].customer_managed_key_enabled)
}

output "onboarding_id" {
  description = "The id of the Sentinel workspace onboarding (an onboardingStates id), or null when create_onboarding is false. Hand this to the other sentinel-* modules: they parse the workspace id back out of it, which makes the onboarding dependency explicit."
  value       = one(azurerm_sentinel_log_analytics_workspace_onboarding.this[*].id)
}

output "sentinel_metadata" {
  description = "Map of metadata name to the full metadata object."
  value       = azurerm_sentinel_metadata.this
}

output "sentinel_metadata_ids" {
  description = "Map of metadata name to its id."
  value       = { for k, m in azurerm_sentinel_metadata.this : k => m.id }
}

output "sentinel_metadata_ids_zipmap" {
  description = "Map of metadata name to { name, id }, for easy composition with other modules."
  value       = { for k, m in azurerm_sentinel_metadata.this : k => { name = m.name, id = m.id } }
}

output "threat_intelligence_indicator_guids" {
  description = "Map of indicator label to the indicator's guid (the id Sentinel shows in the portal)."
  value       = { for k, i in azurerm_sentinel_threat_intelligence_indicator.this : k => i.guid }
}

output "threat_intelligence_indicator_ids" {
  description = "Map of indicator label to its id."
  value       = { for k, i in azurerm_sentinel_threat_intelligence_indicator.this : k => i.id }
}

output "threat_intelligence_indicator_ids_zipmap" {
  description = "Map of indicator label to { name, id }, for easy composition with other modules."
  value       = { for k, i in azurerm_sentinel_threat_intelligence_indicator.this : k => { name = i.display_name, id = i.id } }
}

output "threat_intelligence_indicators" {
  description = "Map of indicator label to the full indicator object (including the computed guid, parsed pattern, and defanged flag)."
  value       = azurerm_sentinel_threat_intelligence_indicator.this
}

output "workspace_id" {
  description = "The id of the onboarded Log Analytics workspace, passed through for composition."
  value       = var.workspace_id
}
