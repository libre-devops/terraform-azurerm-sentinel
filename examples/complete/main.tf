# The full surface: a workspace onboarded to Sentinel, threat intelligence indicators exercising
# every STIX field, and a metadata-only second call describing content created after the onboarding
# (here a watchlist), which is the composition shape metadata exists for. Sentinel starts a 31 day
# free trial per workspace and the stack is applied then destroyed in one CI run.
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-sentinel" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

# The onboarding call: flips the workspace into a Sentinel workspace and seeds indicators.
# customer_managed_key_enabled stays on its false default: CMK onboarding needs a CMK-configured
# Log Analytics cluster and Key Vault first, and once onboarded with CMK a workspace cannot be
# re-onboarded without it.
module "sentinel" {
  source = "../../"

  workspace_id = module.log_analytics.workspace_ids[local.law_name]

  threat_intelligence_indicators = {
    # Every optional exercised: window, confidence, STIX metadata, references, markings, phases.
    "malicious-domain" = {
      pattern           = "evil.example.com"
      pattern_type      = "domain-name"
      validate_from_utc = "2026-01-01T00:00:00Z"

      validate_until_utc  = "2030-01-01T00:00:00Z"
      confidence          = 80
      created_by          = "platform@example.com"
      description         = "Known C2 domain used by the example threat actor."
      language            = "en"
      pattern_version     = "2.1"
      revoked             = false
      tags                = ["c2", "example"]
      threat_types        = ["malicious-activity"]
      kill_chain_phases   = ["command-and-control"]
      object_marking_refs = []

      external_references = [
        {
          source_name = "internal-ticket"
          description = "IOC imported from the incident record."
          url         = "https://example.com/incidents/4711"
        }
      ]

      granular_markings = [
        { selectors = ["pattern"] }
      ]
    }

    # A file-hash indicator: pattern uses the <HashName>:<Value> form the provider requires.
    "known-bad-installer" = {
      pattern           = "MD5:78ecc5c05cd8b79af480df2f8fba0b9d"
      pattern_type      = "file"
      validate_from_utc = "2026-01-01T00:00:00Z"
      display_name      = "Known bad installer"
      source            = "Incident 4711"
      confidence        = 100
      threat_types      = ["malware"]
    }

    # The minimal indicator shape: everything else defaulted (source stamps as Terraform, the map
    # key becomes the display name).
    "suspicious-ip" = {
      pattern           = "203.0.113.66"
      pattern_type      = "ipv4-addr"
      validate_from_utc = "2026-01-01T00:00:00Z"
    }
  }
}

# Content created after the onboarding: a watchlist the metadata below describes. Raw scaffolding
# here (the sentinel-watchlist module owns this properly); it waits on the onboarding because the
# SecurityInsights paths only exist on an onboarded workspace.
resource "azurerm_sentinel_watchlist" "vips" {
  log_analytics_workspace_id = module.log_analytics.workspace_ids[local.law_name]
  name                       = "wl-vip-users"
  display_name               = "VIP users"
  item_search_key            = "upn"
  description                = "High-value accounts referenced by analytics rules."

  depends_on = [module.sentinel]
}

# The metadata-only call: create_onboarding = false because the workspace above is already
# onboarded, and this call exists only to attach authorship, source, support, category, and
# dependency information to the watchlist.
module "sentinel_metadata" {
  source = "../../"

  workspace_id      = module.log_analytics.workspace_ids[local.law_name]
  create_onboarding = false

  sentinel_metadata = {
    "metadata-wl-vip-users" = {
      content_id = "b1946ac9-0000-4000-8000-000000000001"
      kind       = "Watchlist"
      parent_id  = azurerm_sentinel_watchlist.vips.id

      content_schema_version     = "2.0"
      custom_version             = "1.0.0"
      version                    = "1.0.0"
      first_publish_date         = "2026-07-03"
      last_publish_date          = "2026-07-03"
      providers                  = ["Libre DevOps"]
      threat_analysis_tactics    = ["InitialAccess", "CredentialAccess"]
      threat_analysis_techniques = ["T1078"]

      dependency = jsonencode({
        operator = "AND"
        criteria = [{ contentId = "AzureActiveDirectory", kind = "DataConnector" }]
      })

      author   = { name = "Libre DevOps", email = "info@libredevops.org", link = "https://libredevops.org" }
      category = { domains = ["Security - Threat Protection"], verticals = ["Technology"] }
      source   = { kind = "LocalWorkspace", name = local.law_name }
      support  = { tier = "Community", name = "Libre DevOps", link = "https://libredevops.org" }
    }
  }
}
