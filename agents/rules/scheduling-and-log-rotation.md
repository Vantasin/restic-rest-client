# Scheduling And Log Rotation Rules

Use these rules when changing launchd schedules, power guards, log paths, or
newsyslog behavior.

## Scope

- `launchd/*.plist.example`
- `run_backup.sh`
- `newsyslog/com.restic-rest-client.conf.example`
- docs that describe scheduling, power behavior, or log handling

## Non-negotiables

- Keep backup, prune, and logcleanup responsibilities distinct.
- Keep prune install behavior aligned with `RESTIC_PRUNE_ENABLED`.
- Treat schedule changes as operator-visible changes that require doc updates.
- Treat power-guard changes as behavioral changes, not minor implementation
  tweaks.
- Keep the distinction between per-run logs and daemon logs explicit.
- Keep `logcleanup` scoped to per-run logs unless the logging model is
  intentionally redesigned.
- Keep `newsyslog` responsible for daemon log rotation unless the logging model
  is intentionally redesigned.

## Timing rules

- Do not describe `StartInterval` and `StartCalendarInterval` as interchangeable.
- When timing changes on laptops, account for sleep/wake behavior explicitly.
- When AC-power or clamshell behavior changes, update both implementation and
  docs together.

## Drift risks

- Changing launchd timing without updating human docs
- Changing log filenames or locations in one place only
- Letting power-guard behavior drift away from the documented operator
  expectation
- Mixing up tracked template changes with installed local launch-agent state
