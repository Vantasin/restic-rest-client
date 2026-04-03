# Template Integrity Rules

Use these rules when changing tracked templates, generated-file flows, or
backup-scope defaults.

## Source of truth

- Tracked `.example` files are the Git source of truth for generated local
  config.
- Local generated files are operational state and must not replace the tracked
  templates as the canonical change target by accident.

## Applies to

- `restic.env.example`
- `restic-include-macos.txt.example`
- `restic-exclude-macos.txt.example`
- `launchd/*.plist.example`
- `newsyslog/com.restic-rest-client.conf.example`

## Non-negotiables

- Do not commit populated secrets.
- Do not commit host-specific generated files in place of templates.
- If a change alters defaults, placeholders, or intended operator behavior,
  update the human docs that explain that template.
- If a change only affects local generated files, say that explicitly instead of
  implying the tracked template changed.

## Drift risks

- Updating generated local files without updating the tracked `.example`
- Updating a tracked template without updating the docs that describe it
- Changing include/exclude defaults without explicitly acknowledging the backup
  scope impact
- Changing launchd or newsyslog templates without accounting for installed local
  state
