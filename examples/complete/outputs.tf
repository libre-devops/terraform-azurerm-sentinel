output "onboarding_id" {
  description = "The Sentinel onboarding id (the handle the other sentinel-* modules take)."
  value       = module.sentinel.onboarding_id
}

output "sentinel_metadata_ids" {
  description = "Map of metadata name to id (from the metadata-only call)."
  value       = module.sentinel_metadata.sentinel_metadata_ids
}

output "threat_intelligence_indicator_guids" {
  description = "Map of indicator label to the guid Sentinel shows in the portal."
  value       = module.sentinel.threat_intelligence_indicator_guids
}

output "threat_intelligence_indicator_ids" {
  description = "Map of indicator label to id."
  value       = module.sentinel.threat_intelligence_indicator_ids
}

output "workspace_id" {
  description = "The onboarded Log Analytics workspace id."
  value       = module.sentinel.workspace_id
}
