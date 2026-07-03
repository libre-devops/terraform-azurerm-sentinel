# Tests for the module. azurerm is mocked (no credentials, no cloud):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001"
}

# The default call: onboarding only, no CMK, no metadata, no indicators.
run "onboarding_defaults" {
  command = apply

  assert {
    condition     = azurerm_sentinel_log_analytics_workspace_onboarding.this[0].workspace_id == var.workspace_id
    error_message = "The onboarding should target the given workspace."
  }

  assert {
    condition     = azurerm_sentinel_log_analytics_workspace_onboarding.this[0].customer_managed_key_enabled == false
    error_message = "customer_managed_key_enabled should default to false."
  }

  assert {
    condition     = length(azurerm_sentinel_metadata.this) == 0 && length(azurerm_sentinel_threat_intelligence_indicator.this) == 0
    error_message = "No metadata or indicators should be created by default."
  }
}

# The full surface: CMK onboarding, a metadata entry with every block, and indicators exercising the
# label-as-display-name default, the source default, and the nested STIX blocks.
run "full_surface" {
  command = apply

  variables {
    customer_managed_key_enabled = true

    sentinel_metadata = {
      "metadata-rule-001" = {
        content_id = "8b647f8e-0000-0000-0000-000000000001"
        kind       = "AnalyticsRule"
        parent_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001/providers/Microsoft.SecurityInsights/alertRules/rule-001"

        content_schema_version     = "2.0"
        custom_version             = "1.0.0"
        dependency                 = jsonencode({ operator = "AND", criteria = [{ contentId = "dep-001", kind = "DataConnector" }] })
        first_publish_date         = "2026-01-01"
        last_publish_date          = "2026-07-01"
        icon_id                    = "00000000-0000-0000-0000-00000000abcd"
        preview_images             = ["light.png"]
        preview_images_dark        = ["dark.png"]
        providers                  = ["Libre DevOps"]
        threat_analysis_tactics    = ["InitialAccess", "CommandAndControl"]
        threat_analysis_techniques = ["T1078"]
        version                    = "1.0.0"

        author   = { name = "Libre DevOps", email = "info@libredevops.org", link = "https://libredevops.org" }
        category = { domains = ["Security - Threat Protection"], verticals = ["Technology"] }
        source   = { kind = "LocalWorkspace", name = "log-ldo-uks-tst-001" }
        support  = { tier = "Community", name = "Libre DevOps", link = "https://libredevops.org" }
      }
    }

    threat_intelligence_indicators = {
      "malicious-domain" = {
        pattern           = "evil.example.com"
        pattern_type      = "domain-name"
        validate_from_utc = "2026-07-03T00:00:00Z"

        validate_until_utc = "2027-07-03T00:00:00Z"
        confidence         = 80
        description        = "Known C2 domain."
        threat_types       = ["malicious-activity"]
        tags               = ["c2"]
        kill_chain_phases  = ["command-and-control"]

        external_references = [{ source_name = "internal", url = "https://example.com/ioc/1" }]
        granular_markings   = [{ selectors = ["pattern"] }]
      }

      "bad-hash" = {
        pattern           = "MD5:78ecc5c05cd8b79af480df2f8fba0b9d"
        pattern_type      = "file"
        validate_from_utc = "2026-07-03T00:00:00Z"
        display_name      = "known bad installer"
        source            = "Incident 4711"
      }
    }
  }

  assert {
    condition     = azurerm_sentinel_log_analytics_workspace_onboarding.this[0].customer_managed_key_enabled == true
    error_message = "customer_managed_key_enabled should pass through."
  }

  assert {
    condition     = azurerm_sentinel_metadata.this["metadata-rule-001"].kind == "AnalyticsRule"
    error_message = "Metadata kind should pass through."
  }

  assert {
    condition     = azurerm_sentinel_metadata.this["metadata-rule-001"].support[0].tier == "Community"
    error_message = "The support block should be created with its tier."
  }

  assert {
    condition     = azurerm_sentinel_threat_intelligence_indicator.this["malicious-domain"].display_name == "malicious-domain"
    error_message = "An indicator's display name should default to its map key."
  }

  assert {
    condition     = azurerm_sentinel_threat_intelligence_indicator.this["malicious-domain"].source == "Terraform"
    error_message = "An indicator's source should default to Terraform."
  }

  assert {
    condition     = azurerm_sentinel_threat_intelligence_indicator.this["bad-hash"].display_name == "known bad installer"
    error_message = "An explicit display_name should win over the map key."
  }

  assert {
    condition     = azurerm_sentinel_threat_intelligence_indicator.this["bad-hash"].source == "Incident 4711"
    error_message = "An explicit source should win over the default."
  }

  assert {
    condition     = azurerm_sentinel_threat_intelligence_indicator.this["malicious-domain"].kill_chain_phase[0].name == "command-and-control"
    error_message = "kill_chain_phases should map onto kill_chain_phase blocks."
  }
}

# A metadata-only call against an already onboarded workspace: no onboarding resource, and the
# onboarding outputs go null instead of erroring.
run "metadata_only_call" {
  command = apply

  variables {
    create_onboarding = false

    sentinel_metadata = {
      "metadata-watchlist-001" = {
        content_id = "8b647f8e-0000-0000-0000-000000000002"
        kind       = "Watchlist"
        parent_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001/providers/Microsoft.SecurityInsights/watchlists/wl-001"
      }
    }
  }

  assert {
    condition     = length(azurerm_sentinel_log_analytics_workspace_onboarding.this) == 0
    error_message = "No onboarding should be created when create_onboarding is false."
  }

  assert {
    condition     = output.onboarding_id == null
    error_message = "onboarding_id should be null when create_onboarding is false."
  }

  assert {
    condition     = length(azurerm_sentinel_metadata.this) == 1
    error_message = "The metadata entry should still be created."
  }
}

# A workspace_id that is not a Log Analytics workspace id is rejected.
run "rejects_wrong_workspace_id" {
  command = plan

  variables {
    workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-x/providers/Microsoft.KeyVault/vaults/kv-x"
  }

  expect_failures = [var.workspace_id]
}

# A metadata kind outside the documented set is rejected.
run "rejects_bad_metadata_kind" {
  command = plan

  variables {
    sentinel_metadata = {
      bad = {
        content_id = "x"
        kind       = "NotAKind"
        parent_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001/providers/Microsoft.SecurityInsights/alertRules/r"
      }
    }
  }

  expect_failures = [var.sentinel_metadata]
}

# A file indicator without the <HashName>:<Value> pattern form is rejected.
run "rejects_bad_file_pattern" {
  command = plan

  variables {
    threat_intelligence_indicators = {
      bad = {
        pattern           = "not-a-hash"
        pattern_type      = "file"
        validate_from_utc = "2026-07-03T00:00:00Z"
      }
    }
  }

  expect_failures = [var.threat_intelligence_indicators]
}

# An out-of-range confidence is rejected.
run "rejects_bad_confidence" {
  command = plan

  variables {
    threat_intelligence_indicators = {
      bad = {
        pattern           = "1.2.3.4"
        pattern_type      = "ipv4-addr"
        validate_from_utc = "2026-07-03T00:00:00Z"
        confidence        = 101
      }
    }
  }

  expect_failures = [var.threat_intelligence_indicators]
}

# A reversed indicator validity window trips the ordering check (a warning surfaced as a failed
# check assertion under terraform test).
run "flags_reversed_indicator_window" {
  command = apply

  variables {
    threat_intelligence_indicators = {
      reversed = {
        pattern            = "1.2.3.4"
        pattern_type       = "ipv4-addr"
        validate_from_utc  = "2027-07-03T00:00:00Z"
        validate_until_utc = "2026-07-03T00:00:00Z"
      }
    }
  }

  expect_failures = [check.indicator_windows_are_ordered]
}
