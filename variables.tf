variable "create_onboarding" {
  description = <<DESC
Whether this call onboards the workspace to Sentinel. Leave true on the one call that owns the
onboarding; set false for additional calls against an already onboarded workspace (for example a
metadata-only call describing content other modules created, which cannot live in the onboarding
call when that content itself waits for the onboarding).
DESC

  type     = bool
  default  = true
  nullable = false
}

variable "customer_managed_key_enabled" {
  description = <<DESC
Whether the Sentinel workspace uses a customer-managed key. CMK must already be enabled on the
Log Analytics workspace and the Key Vault access policy in place. NOTE: once a workspace is
onboarded with this set to true it cannot be onboarded again with it set to false.
DESC

  type     = bool
  default  = false
  nullable = false
}

variable "onboarding_settle_duration" {
  description = "How long to wait after onboarding before the onboarding_id output resolves (and metadata is created). The SecurityInsights service intermittently fails read-after-create on children created seconds after a fresh onboarding; the delay is threaded through onboarding_id so downstream modules inherit it. Set \"0s\" to disable."
  type        = string
  default     = "30s"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.onboarding_settle_duration))
    error_message = "onboarding_settle_duration must be a Go-style duration like 30s, 2m, or 0s."
  }
}

variable "sentinel_metadata" {
  description = <<DESC
Sentinel metadata entries, keyed by the metadata name. Metadata attaches authorship, source,
support, and dependency information to a content item (an analytics rule, playbook, watchlist,
workbook, and so on) identified by parent_id. `dependency` is a raw JSON string (pass it through
jsonencode) because the ARM schema nests criteria recursively, which HCL object types cannot express.

The service enforces rules it does not document (verified empirically); the module enforces them
at plan instead of letting the apply 400:
- source.kind = "LocalWorkspace" requires source.name to be the workspace's actual name.
- kind = "Solution" (solution packaging) is rejected: the packaging contract requires parentId to
  be the bare content id, which the azurerm provider cannot express (it insists on parsing
  parent_id as an ARM resource id). The packaging-only fields (categories, publish dates) are
  therefore not offered either; package solutions with the solution tooling, not this module.
DESC

  type = map(object({
    content_id = string
    kind       = string
    parent_id  = string

    content_schema_version     = optional(string)
    custom_version             = optional(string)
    dependency                 = optional(string)
    icon_id                    = optional(string)
    preview_images             = optional(list(string))
    preview_images_dark        = optional(list(string))
    providers                  = optional(list(string))
    threat_analysis_tactics    = optional(list(string))
    threat_analysis_techniques = optional(list(string))
    version                    = optional(string)

    author = optional(object({
      name  = optional(string)
      email = optional(string)
      link  = optional(string)
    }))

    source = optional(object({
      kind = string
      name = optional(string)
      id   = optional(string)
    }))

    support = optional(object({
      tier  = string
      name  = optional(string)
      email = optional(string)
      link  = optional(string)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for m in values(var.sentinel_metadata) : contains([
        "AnalyticsRule", "AnalyticsRuleTemplate", "AutomationRule", "AzureFunction", "DataConnector",
        "DataType", "HuntingQuery", "InvestigationQuery", "LogicAppsCustomConnector", "Parser",
        "Playbook", "PlaybookTemplate", "Watchlist", "WatchlistTemplate", "Workbook",
        "WorkbookTemplate"
      ], m.kind)
    ])
    error_message = "kind must be one of the Sentinel metadata content kinds (AnalyticsRule, AutomationRule, DataConnector, HuntingQuery, Playbook, Watchlist, Workbook, their *Template variants, AzureFunction, DataType, InvestigationQuery, LogicAppsCustomConnector, Parser). Solution packaging is not supported."
  }

  validation {
    condition = alltrue([
      for m in values(var.sentinel_metadata) :
      m.source == null ? true : contains(["Community", "LocalWorkspace", "Solution", "SourceRepository"], m.source.kind)
    ])
    error_message = "source.kind must be one of Community, LocalWorkspace, Solution, SourceRepository."
  }

  validation {
    condition = alltrue([
      for m in values(var.sentinel_metadata) :
      m.support == null ? true : contains(["Microsoft", "Partner", "Community"], m.support.tier)
    ])
    error_message = "support.tier must be one of Microsoft, Partner, Community."
  }

  validation {
    condition     = alltrue([for m in values(var.sentinel_metadata) : m.kind != "Solution"])
    error_message = "Solution packaging metadata is not supported: the packaging contract requires parentId to be the bare content id, which the azurerm provider cannot express. Package solutions with the solution tooling; this module handles content metadata."
  }

  validation {
    condition = alltrue([
      for m in values(var.sentinel_metadata) :
      try(m.source.kind, null) != "LocalWorkspace" ? true : (
        m.source.name != null && can(regex("(?i)/workspaces/([^/]+)$", var.workspace_id)) &&
        lower(m.source.name) == lower(regex("(?i)/workspaces/([^/]+)$", var.workspace_id)[0])
      )
    ])
    error_message = "A LocalWorkspace source requires source.name to be the workspace's actual name (the service rejects anything else)."
  }

  validation {
    condition = alltrue([
      for m in values(var.sentinel_metadata) : alltrue([
        for t in coalesce(m.threat_analysis_tactics, []) : contains([
          "Reconnaissance", "ResourceDevelopment", "InitialAccess", "Execution", "Persistence",
          "PrivilegeEscalation", "DefenseEvasion", "CredentialAccess", "Discovery", "LateralMovement",
          "Collection", "CommandAndControl", "Exfiltration", "Impact", "ImpairProcessControl",
          "InhibitResponseFunction"
        ], t)
      ])
    ])
    error_message = "threat_analysis_tactics entries must be MITRE ATT&CK tactic names in the Sentinel form (for example InitialAccess, PrivilegeEscalation, CommandAndControl)."
  }

  validation {
    condition     = alltrue([for m in values(var.sentinel_metadata) : m.dependency == null ? true : can(jsondecode(m.dependency))])
    error_message = "dependency must be a valid JSON string (build it with jsonencode)."
  }
}

variable "workspace_id" {
  description = "The id of the Log Analytics workspace to onboard to Microsoft Sentinel."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("(?i)/providers/Microsoft.OperationalInsights/workspaces/", var.workspace_id))
    error_message = "workspace_id must be an azurerm_log_analytics_workspace resource id (/.../providers/Microsoft.OperationalInsights/workspaces/<name>)."
  }
}
