<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

Every feature of the module. A workspace onboarded to Sentinel and a metadata-only second call
(`create_onboarding = false`) attaching authorship, source, support, category, and dependency
metadata to a watchlist created after the onboarding, which is the composition shape metadata
exists for. Run it with `just e2e complete`,
which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# The full surface: a workspace onboarded to Sentinel and a metadata-only second call describing
# content created after the onboarding (here a watchlist), which is the composition shape metadata
# exists for. Sentinel starts a 31 day free trial per workspace and the stack is applied then
# destroyed in one CI run.
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
# onboarded, and this call exists only to attach authorship, source, support, and dependency
# information to the watchlist.
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
      providers                  = ["Libre DevOps"]
      threat_analysis_tactics    = ["InitialAccess", "CredentialAccess"]
      threat_analysis_techniques = ["T1078"]

      dependency = jsonencode({
        operator = "AND"
        criteria = [{ contentId = "AzureActiveDirectory", kind = "DataConnector" }]
      })

      # source.name must be the workspace's actual name for a LocalWorkspace source; the module
      # validates that at plan (solution packaging fields are not offered at all: the provider
      # cannot express the packaging contract).
      author  = { name = "Libre DevOps", email = "info@libredevops.org", link = "https://libredevops.org" }
      source  = { kind = "LocalWorkspace", name = local.law_name }
      support = { tier = "Community", name = "Libre DevOps", link = "https://libredevops.org" }
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_sentinel"></a> [sentinel](#module\_sentinel) | ../../ | n/a |
| <a name="module_sentinel_metadata"></a> [sentinel\_metadata](#module\_sentinel\_metadata) | ../../ | n/a |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_sentinel_watchlist.vips](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_watchlist) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_onboarding_id"></a> [onboarding\_id](#output\_onboarding\_id) | The Sentinel onboarding id (the handle the other sentinel-* modules take). |
| <a name="output_sentinel_metadata_ids"></a> [sentinel\_metadata\_ids](#output\_sentinel\_metadata\_ids) | Map of metadata name to id (from the metadata-only call). |
| <a name="output_workspace_id"></a> [workspace\_id](#output\_workspace\_id) | The onboarded Log Analytics workspace id. |
<!-- END_TF_DOCS -->
