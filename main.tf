# Onboarding is the module's reason to exist: it flips the Log Analytics workspace into a Microsoft
# Sentinel workspace. Everything Sentinel (alert rules, automation rules, watchlists, connectors)
# hangs off an onboarded workspace, so downstream modules should be given this module's
# onboarding_id output, which they parse back to the workspace id, making the ordering explicit.
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  count = var.create_onboarding ? 1 : 0

  workspace_id                 = var.workspace_id
  customer_managed_key_enabled = var.customer_managed_key_enabled
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
  first_publish_date         = each.value.first_publish_date
  icon_id                    = each.value.icon_id
  last_publish_date          = each.value.last_publish_date
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

  dynamic "category" {
    for_each = each.value.category != null ? [each.value.category] : []

    content {
      domains   = category.value.domains
      verticals = category.value.verticals
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

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# Threat intelligence indicators seeded straight into the workspace. The provider builds the STIX
# pattern from the plain value (domain, IP, URL, or <HashName>:<Value> for files). Serialized after
# onboarding for the same reason as metadata.
resource "azurerm_sentinel_threat_intelligence_indicator" "this" {
  for_each = var.threat_intelligence_indicators

  workspace_id      = var.workspace_id
  display_name      = coalesce(each.value.display_name, each.key)
  pattern           = each.value.pattern
  pattern_type      = each.value.pattern_type
  source            = each.value.source
  validate_from_utc = each.value.validate_from_utc

  validate_until_utc  = each.value.validate_until_utc
  confidence          = each.value.confidence
  created_by          = each.value.created_by
  description         = each.value.description
  extension           = each.value.extension
  language            = each.value.language
  object_marking_refs = each.value.object_marking_refs
  pattern_version     = each.value.pattern_version
  revoked             = each.value.revoked
  tags                = each.value.tags
  threat_types        = each.value.threat_types

  dynamic "external_reference" {
    for_each = each.value.external_references

    content {
      description = external_reference.value.description
      hashes      = external_reference.value.hashes
      source_name = external_reference.value.source_name
      url         = external_reference.value.url
    }
  }

  dynamic "granular_marking" {
    for_each = each.value.granular_markings

    content {
      language    = granular_marking.value.language
      marking_ref = granular_marking.value.marking_ref
      selectors   = granular_marking.value.selectors
    }
  }

  dynamic "kill_chain_phase" {
    for_each = coalesce(each.value.kill_chain_phases, [])

    content {
      name = kill_chain_phase.value
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}
