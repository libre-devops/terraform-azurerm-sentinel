<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Sentinel

Onboards a Log Analytics workspace to Microsoft Sentinel, with optional content metadata.

[![CI](https://github.com/libre-devops/terraform-azurerm-sentinel/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-sentinel/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-sentinel?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-sentinel/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-sentinel)](./LICENSE)

---

## Overview

The root of the Libre DevOps Sentinel module family. Everything Sentinel (alert rules, automation
rules, watchlists, data connectors) hangs off an onboarded workspace, so this module owns the
onboarding and hands downstream modules its `onboarding_id`: they parse the workspace id back out
of it, which makes the onboarding dependency explicit in composition rather than implicit in
apply order.

- **Onboarding with a real opt-out.** `create_onboarding = true` on the one call that owns the
  workspace's Sentinel state; `false` for additional calls against an already onboarded workspace
  (a metadata-only call, for example). Customer-managed key onboarding is supported and its
  one-way nature (once onboarded with CMK, never without again) is documented on the variable.
- **Content metadata done right.** Authorship, source, support, category, tactics, and dependency
  metadata for content items, with the documented kind and tier enums validated up front and the
  recursive dependency criteria taken as JSON (build it with `jsonencode`). A check block warns
  when a `parent_id` lives in a different workspace, which almost always means a copy-paste.
- **Everything exported.** The onboarding id and the full metadata objects, plus `*_ids` and
  `*_ids_zipmap` maps for easy composition.

Threat intelligence indicators are deliberately NOT managed here: the azurerm resource's
read-after-create races in real pipelines ("Provider produced inconsistent result after apply ...
Root object was present, but now absent"), so indicator seeding through Terraform is not reliable.
Ingest TI through the threat_intelligence / microsoft_threat_intelligence / TAXII data connectors
(see the sentinel-data-connector module) or the upload indicators API instead.

Requires Terraform >= 1.9 and azurerm >= 4.0.

## Usage

```hcl
module "sentinel" {
  source  = "libre-devops/sentinel/azurerm"
  version = "~> 4.0"

  workspace_id = module.log_analytics.workspace_ids["log-ldo-uks-prd-001"]
}

# Downstream sentinel-* modules take the onboarding id and parse the workspace id from it.
# A second, metadata-only call describes content those modules created:
module "sentinel_metadata" {
  source  = "libre-devops/sentinel/azurerm"
  version = "~> 4.0"

  workspace_id      = module.log_analytics.workspace_ids["log-ldo-uks-prd-001"]
  create_onboarding = false

  sentinel_metadata = {
    "metadata-wl-vip-users" = {
      content_id = "b1946ac9-0000-4000-8000-000000000001"
      kind       = "Watchlist"
      parent_id  = module.sentinel_watchlist.watchlist_ids["wl-vip-users"]

      author  = { name = "Libre DevOps", link = "https://libredevops.org" }
      support = { tier = "Community", name = "Libre DevOps" }
    }
  }
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - a fresh workspace onboarded to Sentinel, nothing else.
- [`examples/complete`](./examples/complete) - the full surface: the onboarding plus a
  metadata-only second call describing a watchlist created after the onboarding.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in a `.trivyignore.yaml` (the machine-applied source of
truth, passed to Trivy with `--ignorefile`) and are mirrored in a table here so the reason is
auditable.

There are currently **no exceptions**: the module and its examples scan clean.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.0, < 1.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.9.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_sentinel_log_analytics_workspace_onboarding.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_log_analytics_workspace_onboarding) | resource |
| [azurerm_sentinel_metadata.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_metadata) | resource |
| [time_sleep.onboarding_settle](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_onboarding"></a> [create\_onboarding](#input\_create\_onboarding) | Whether this call onboards the workspace to Sentinel. Leave true on the one call that owns the<br/>onboarding; set false for additional calls against an already onboarded workspace (for example a<br/>metadata-only call describing content other modules created, which cannot live in the onboarding<br/>call when that content itself waits for the onboarding). | `bool` | `true` | no |
| <a name="input_customer_managed_key_enabled"></a> [customer\_managed\_key\_enabled](#input\_customer\_managed\_key\_enabled) | Whether the Sentinel workspace uses a customer-managed key. CMK must already be enabled on the<br/>Log Analytics workspace and the Key Vault access policy in place. NOTE: once a workspace is<br/>onboarded with this set to true it cannot be onboarded again with it set to false. | `bool` | `false` | no |
| <a name="input_onboarding_settle_duration"></a> [onboarding\_settle\_duration](#input\_onboarding\_settle\_duration) | How long to wait after onboarding before the onboarding\_id output resolves (and metadata is created). The SecurityInsights service intermittently fails read-after-create on children created seconds after a fresh onboarding; the delay is threaded through onboarding\_id so downstream modules inherit it. Set "0s" to disable. | `string` | `"30s"` | no |
| <a name="input_sentinel_metadata"></a> [sentinel\_metadata](#input\_sentinel\_metadata) | Sentinel metadata entries, keyed by the metadata name. Metadata attaches authorship, source,<br/>support, and dependency information to a content item (an analytics rule, playbook, watchlist,<br/>workbook, and so on) identified by parent\_id. `dependency` is a raw JSON string (pass it through<br/>jsonencode) because the ARM schema nests criteria recursively, which HCL object types cannot express. | <pre>map(object({<br/>    content_id = string<br/>    kind       = string<br/>    parent_id  = string<br/><br/>    content_schema_version     = optional(string)<br/>    custom_version             = optional(string)<br/>    dependency                 = optional(string)<br/>    first_publish_date         = optional(string)<br/>    icon_id                    = optional(string)<br/>    last_publish_date          = optional(string)<br/>    preview_images             = optional(list(string))<br/>    preview_images_dark        = optional(list(string))<br/>    providers                  = optional(list(string))<br/>    threat_analysis_tactics    = optional(list(string))<br/>    threat_analysis_techniques = optional(list(string))<br/>    version                    = optional(string)<br/><br/>    author = optional(object({<br/>      name  = optional(string)<br/>      email = optional(string)<br/>      link  = optional(string)<br/>    }))<br/><br/>    category = optional(object({<br/>      domains   = optional(list(string))<br/>      verticals = optional(list(string))<br/>    }))<br/><br/>    source = optional(object({<br/>      kind = string<br/>      name = optional(string)<br/>      id   = optional(string)<br/>    }))<br/><br/>    support = optional(object({<br/>      tier  = string<br/>      name  = optional(string)<br/>      email = optional(string)<br/>      link  = optional(string)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | The id of the Log Analytics workspace to onboard to Microsoft Sentinel. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_customer_managed_key_enabled"></a> [customer\_managed\_key\_enabled](#output\_customer\_managed\_key\_enabled) | Whether the Sentinel workspace was onboarded with a customer-managed key (null when create\_onboarding is false). |
| <a name="output_onboarding_id"></a> [onboarding\_id](#output\_onboarding\_id) | The id of the Sentinel workspace onboarding (an onboardingStates id), or null when create\_onboarding is false. Hand this to the other sentinel-* modules: they parse the workspace id back out of it, which makes the onboarding dependency (and the settle delay) explicit. |
| <a name="output_sentinel_metadata"></a> [sentinel\_metadata](#output\_sentinel\_metadata) | Map of metadata name to the full metadata object. |
| <a name="output_sentinel_metadata_ids"></a> [sentinel\_metadata\_ids](#output\_sentinel\_metadata\_ids) | Map of metadata name to its id. |
| <a name="output_sentinel_metadata_ids_zipmap"></a> [sentinel\_metadata\_ids\_zipmap](#output\_sentinel\_metadata\_ids\_zipmap) | Map of metadata name to { name, id }, for easy composition with other modules. |
| <a name="output_workspace_id"></a> [workspace\_id](#output\_workspace\_id) | The id of the onboarded Log Analytics workspace, passed through for composition. |
<!-- END_TF_DOCS -->
