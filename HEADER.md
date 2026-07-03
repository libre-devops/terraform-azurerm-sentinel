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
