# Tests for the module. azurerm is mocked (no credentials, no cloud):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001"
}

# The default call: onboarding only, no CMK, no metadata.
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

}

# The full surface: CMK onboarding and a metadata entry with every block.
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



