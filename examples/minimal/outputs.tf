output "onboarding_id" {
  description = "The Sentinel onboarding id (the handle the other sentinel-* modules take)."
  value       = module.sentinel.onboarding_id
}

output "workspace_id" {
  description = "The onboarded Log Analytics workspace id."
  value       = module.sentinel.workspace_id
}
