output "customer_managed_key_enabled" {
  description = "Whether the Sentinel workspace was onboarded with a customer-managed key (null when create_onboarding is false)."
  value       = one(azurerm_sentinel_log_analytics_workspace_onboarding.this[*].customer_managed_key_enabled)
}

output "onboarding_id" {
  description = "The id of the Sentinel workspace onboarding (an onboardingStates id), or null when create_onboarding is false. Hand this to the other sentinel-* modules: they parse the workspace id back out of it, which makes the onboarding dependency (and the settle delay) explicit."
  value       = one(time_sleep.onboarding_settle[*].triggers.onboarding_id)
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

output "workspace_id" {
  description = "The id of the onboarded Log Analytics workspace, passed through for composition."
  value       = var.workspace_id
}
