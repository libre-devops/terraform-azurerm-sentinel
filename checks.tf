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
