# Deprecation And Migration Rules

Use these rules when renaming, replacing, removing, or splitting any
operator-facing or agent-facing contract.

## Applies to

- environment variables
- launchd labels or schedule model
- log file paths and naming
- tracked templates and generated-file flows
- human doc locations and names
- agent rule/context/workflow paths

## Non-negotiables

- Do not remove or rename a contract silently.
- When a rename or removal affects operators, document the migration path in the
  canonical human docs.
- When a rename or removal affects agent routing, update `AGENTS.md` and the
  relevant `agents/*/README.md` files in the same change.
- Keep stale references from surviving across docs, rules, workflows, and
  README routers.

## Migration expectations

- State what changed.
- State what replaces the old contract.
- State whether the change is automatic, manual, or requires regeneration of
  local files.
- State whether installed local launchd or newsyslog state must be refreshed.
- If compatibility is intentionally broken, say so explicitly.

## Review expectations

- Run `repo-review.md` when the migration affects repository behavior or human
  docs.
- Run `agent-review.md` when the migration affects agent routing or structure.
- Log review-driven cleanup changes separately with `change-logging.md`.
