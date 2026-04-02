# Launchd And Logging Context

Canonical human docs:

- `Docs/BOOTSTRAP.md`
- `Docs/RUN_BACKUP_SCRIPT.md`

Related agent context:

- `agents/context/newsyslog-and-log-files.md`

## Launchd jobs

- `com.restic-rest-client.backup`
- `com.restic-rest-client.prune`
- `com.restic-rest-client.logcleanup`

Tracked templates live in `launchd/*.plist.example`. Installed local agents live
under `~/Library/LaunchAgents/`.

## Logging model

- Per-run logs: `~/Library/Logs/restic-rest-client/{backup,prune,logcleanup,test-email,test-success-email,test-failure-email,test-warning-email,test-lock-failure-email}_*.log`
- Daemon logs: `~/Library/Logs/restic-rest-client/daemon_{backup,prune,logcleanup}.log`
- Daemon logs are rotated by `newsyslog`

## Agent concerns

- Distinguish tracked plist changes from installed local agent changes.
- Prune is mode-dependent: the plist exists as a tracked template, but install
  only loads it when `RESTIC_PRUNE_ENABLED=true`.
- Schedule changes are operationally significant and must be documented.
- Treat daemon log rotation as a separate concern from launchd scheduling and
  stdout/stderr targets.
- `StartInterval` and `StartCalendarInterval` behave differently on sleeping
  laptops; timing assumptions should be explicit in docs and summaries.
- When analyzing failures, confirm whether the issue came from launchd timing,
  locks, power state, permissions, or backend connectivity.
