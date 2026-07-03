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

variable "sentinel_metadata" {
  description = <<DESC
Sentinel metadata entries, keyed by the metadata name. Metadata attaches authorship, source,
support, and dependency information to a content item (an analytics rule, playbook, watchlist,
workbook, and so on) identified by parent_id. `dependency` is a raw JSON string (pass it through
jsonencode) because the ARM schema nests criteria recursively, which HCL object types cannot express.
DESC

  type = map(object({
    content_id = string
    kind       = string
    parent_id  = string

    content_schema_version     = optional(string)
    custom_version             = optional(string)
    dependency                 = optional(string)
    first_publish_date         = optional(string)
    icon_id                    = optional(string)
    last_publish_date          = optional(string)
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

    category = optional(object({
      domains   = optional(list(string))
      verticals = optional(list(string))
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
        "Playbook", "PlaybookTemplate", "Solution", "Watchlist", "WatchlistTemplate", "Workbook",
        "WorkbookTemplate"
      ], m.kind)
    ])
    error_message = "kind must be one of the Sentinel metadata content kinds (AnalyticsRule, AutomationRule, DataConnector, HuntingQuery, Playbook, Solution, Watchlist, Workbook, their *Template variants, AzureFunction, DataType, InvestigationQuery, LogicAppsCustomConnector, Parser)."
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
