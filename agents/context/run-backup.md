# run_backup.sh Context

Canonical human doc: `Docs/RUN_BACKUP_SCRIPT.md`

## Responsibilities

- Load environment and local config
- Resolve the repository location from `RESTIC_REPOSITORY`
- Use `RESTIC_REST_*` environment variables for REST-server auth when present
- Run `backup`, `prune`, `logcleanup`, or notification test tasks
- Source `lib/platform.sh` for shared truthy parsing, macOS power/clamshell
  checks, file checks, and timestamped subprocess logging helpers
- Source `lib/notifications.sh` for notification rendering, email delivery, and
  failure-classification helpers
- Source `lib/tasks.sh` for backup, prune, and logcleanup task bodies
- Timestamp log output
- Apply retry-lock behavior
- Apply power/clamshell guards
- Mask REST URL credentials in log and notification output
- Send multipart text+HTML notifications with attached per-run logs when
  configured

## Agent concerns

- Changes here often require matching updates to `Docs/RUN_BACKUP_SCRIPT.md`
  and `Docs/RESTIC_ENV.md`.
- Stale-lock operator guidance should stay aligned between
  `lib/notifications.sh`, `Docs/RUN_BACKUP_SCRIPT.md`, and
  `unlock_stale_locks.sh`.
- Repository derivation changes belong to the env template/configure flow, not
  to `run_backup.sh`, unless runtime repository resolution itself changes.
- Backup and prune changes can alter operational safety, lock behavior, or job
  timing; treat them as high-impact.
- Exit-code handling matters because operators use logs and notifications to
  distinguish success, partial backup, skipped tasks, and hard failures.

## Current behavior themes

- `backup` and `prune` support AC-power and clamshell guards.
- `logcleanup` and notification test tasks are local-only and intentionally
  simpler.
- Prune is long-running, lock-sensitive, and intentionally disabled by default.
- Backup behavior interacts with macOS privacy restrictions and cloud-managed
  files.
