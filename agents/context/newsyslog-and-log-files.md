# Newsyslog And Log Files Context

Canonical human docs:

- `Docs/RUN_BACKUP_SCRIPT.md`
- `Docs/BOOTSTRAP.md`
- `Docs/GIT_HOOKS.md`

## Logging model

- `run_backup.sh` writes per-run task logs under
  `~/Library/Logs/restic-rest-client/`
- launchd jobs also write fixed daemon logs under the same directory
- `logcleanup` deletes old per-run logs only
- `newsyslog` rotates the fixed daemon logs only

## Ownership boundaries

- `run_backup.sh` owns log content and per-run file naming
- `launchd/*.plist.example` owns the daemon stdout/stderr targets
- `newsyslog/com.restic-rest-client.conf.example` owns daemon log rotation
  policy

## Agent concerns

- Changing daemon log paths affects launchd templates, newsyslog config, and
  human docs together.
- Changing per-run log naming affects scripts, troubleshooting guidance, and
  operator expectations.
- `logcleanup` and `newsyslog` solve different problems and should not be
  treated as interchangeable maintenance tasks.

## Common drift risk

- daemon log path changes in launchd without matching newsyslog updates
- docs describing one log model while the script or templates implement another
- changes to retention or rotation behavior not reflected in human docs
