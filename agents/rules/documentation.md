# Documentation Rules

## Canonical sources

- Human-facing behavior, setup, and operational documentation belongs in
  `Docs/` and `README.md`.
- Agent-facing process guidance belongs in `agents/`.

## Required doc updates

Update human docs when a change touches:

- `run_backup.sh` task behavior, exit handling, notifications, or power guards
- `launchd` schedules, agent names, or installed paths
- `restic.env.example` variables or expected configuration
- include/exclude defaults or backup-scope expectations
- bootstrap/install/uninstall behavior
- restore, server, or security behavior

## Required agent updates

Update `agents/` when a change touches:

- review procedure
- change logging expectations
- documentation workflow
- component boundaries or client/server architecture assumptions

## Writing guidance

- Link to the canonical human doc instead of restating it.
- Keep agent docs concise and operational.
- Prefer one clear owner document per topic to reduce drift.
- In tracked docs for this public repo, keep examples sanitized. Use placeholder
  or reserved-example values such as `example.com`, `backup`, and
  `you@example.com` rather than operator-specific domains, usernames, email
  addresses, or hostnames.
