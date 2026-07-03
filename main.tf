# Onboarding is the module's reason to exist: it flips the Log Analytics workspace into a Microsoft
# Sentinel workspace. Everything Sentinel (alert rules, automation rules, watchlists, connectors)
# hangs off an onboarded workspace, so downstream modules should be given this module's
# onboarding_id output, which they parse back to the workspace id, making the ordering explicit.
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  count = var.create_onboarding ? 1 : 0

  workspace_id                 = var.workspace_id
  customer_managed_key_enabled = var.customer_managed_key_enabled
}

# The SecurityInsights data plane is not ready the moment the onboarding returns: children created
# seconds later (watchlists, indicators) intermittently fail their read-after-create with
# "Root object was present, but now absent". The settle delay is threaded through the
# onboarding_id output, so every consumer of that output inherits the wait without knowing about it.
resource "time_sleep" "onboarding_settle" {
  count = var.create_onboarding ? 1 : 0

  create_duration = var.onboarding_settle_duration

  triggers = {
    onboarding_id = azurerm_sentinel_log_analytics_workspace_onboarding.this[0].id
  }
}

# Metadata attaches authorship, source, support, and dependency information to Sentinel content
# items (rules, playbooks, watchlists, and so on). Serialized after onboarding: the
# Microsoft.SecurityInsights provider paths only exist on an onboarded workspace.
resource "azurerm_sentinel_metadata" "this" {
  for_each = var.sentinel_metadata

  workspace_id = var.workspace_id
  name         = each.key
  content_id   = each.value.content_id
  kind         = each.value.kind
  parent_id    = each.value.parent_id

  content_schema_version     = each.value.content_schema_version
  custom_version             = each.value.custom_version
  dependency                 = each.value.dependency
  icon_id                    = each.value.icon_id
  preview_images             = each.value.preview_images
  preview_images_dark        = each.value.preview_images_dark
  providers                  = each.value.providers
  threat_analysis_tactics    = each.value.threat_analysis_tactics
  threat_analysis_techniques = each.value.threat_analysis_techniques
  version                    = each.value.version

  dynamic "author" {
    for_each = each.value.author != null ? [each.value.author] : []

    content {
      name  = author.value.name
      email = author.value.email
      link  = author.value.link
    }
  }

  dynamic "source" {
    for_each = each.value.source != null ? [each.value.source] : []

    content {
      kind = source.value.kind
      name = source.value.name
      id   = source.value.id
    }
  }

  dynamic "support" {
    for_each = each.value.support != null ? [each.value.support] : []

    content {
      tier  = support.value.tier
      name  = support.value.name
      email = support.value.email
      link  = support.value.link
    }
  }

  depends_on = [time_sleep.onboarding_settle]
}
