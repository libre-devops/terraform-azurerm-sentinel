# check blocks run after every plan and apply and warn (without blocking) on configuration that would
# quietly misbehave.

# Metadata should describe content in the workspace being onboarded: a parent_id under a different
# workspace almost always means a copy-paste from another stack.
check "metadata_parents_in_workspace" {
  assert {
    condition = alltrue([
      for m in values(var.sentinel_metadata) : startswith(lower(m.parent_id), lower(var.workspace_id))
    ])
    error_message = "One or more sentinel_metadata parent_id values live under a different workspace than workspace_id."
  }
}

# An indicator window should be ordered: validate_from_utc on or after validate_until_utc silently
# yields an indicator that is never active. timecmp compares the instants; try() keeps an unparseable
# date from aborting the check (the variable validation already rejects malformed dates harder).
check "indicator_windows_are_ordered" {
  assert {
    condition = alltrue([
      for i in values(var.threat_intelligence_indicators) :
      i.validate_until_utc == null ? true : try(timecmp(i.validate_from_utc, i.validate_until_utc) < 0, true)
    ])
    error_message = "One or more threat intelligence indicators have validate_from_utc on or after validate_until_utc, so they would never be active."
  }
}
