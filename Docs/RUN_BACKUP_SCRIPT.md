# run_backup.sh Summary

`run_backup.sh` is the single entry point for backups, pruning, log cleanup,
and notification testing. The launchd jobs call it with an explicit
subcommand.

For interactive use, the Makefile exposes matching convenience targets such as
`make backup`, `make prune`, `make logcleanup`, `make watch-backup-log`, and the `make test-...`
notification helpers.

For stale lock recovery, use `make unlock-stale-locks` or
`./unlock_stale_locks.sh`. That helper refuses to run while a `run_backup.sh`
or `restic` process is active.

## Commands

- `./run_backup.sh` or `./run_backup.sh backup`: run a backup.
- `./run_backup.sh prune`: run `forget --prune` when
  `RESTIC_PRUNE_ENABLED=true`.
- `./run_backup.sh logcleanup`: delete per-run logs older than the retention
  window.
- `./run_backup.sh test-email`: send a generic notification-path test email.
- `./run_backup.sh test-success-email`: send a success-style test email.
- `./run_backup.sh test-failure-email`: send a generic non-lock failure test
  email.
- `./run_backup.sh test-warning-email`: send a backup-warning test email for
  exit `3`.
- `./run_backup.sh test-lock-failure-email`: send a repository-lock failure
  test email.

## Key environment variables

- `RESTIC_HOST`
- `RESTIC_REPOSITORY_BASE_URL`
- `RESTIC_REPOSITORY_NAME`
- `RESTIC_REST_USERNAME`
- `RESTIC_REST_PASSWORD`
- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD` or `RESTIC_PASSWORD_COMMAND`
- `RESTIC_RETRY_LOCK` (default `10m`)
- `RESTIC_PRUNE_ENABLED` (default `false`)
- `RESTIC_NOTIFY_EMAIL`
- `RESTIC_NOTIFY_ON_FAILURE` (default `true`)
- `RESTIC_NOTIFY_ON_SUCCESS` (default `false`)
- `RESTIC_LOG_RETENTION_DAYS` (default `14`)
- `RESTIC_BACKUP_REQUIRE_AC_POWER`
- `RESTIC_BACKUP_SKIP_WHEN_CLAMSHELL_CLOSED`
- `RESTIC_PRUNE_REQUIRE_AC_POWER`
- `RESTIC_PRUNE_SKIP_WHEN_CLAMSHELL_CLOSED`
- `RESTIC_KEEP_DAILY`, `RESTIC_KEEP_WEEKLY`, `RESTIC_KEEP_MONTHLY`

## Logging

Per-run logs are written to:

```text
~/Library/Logs/restic-rest-client/backup_YYYY-MM-DD_HH-MM-SS.log
~/Library/Logs/restic-rest-client/prune_YYYY-MM-DD_HH-MM-SS.log
~/Library/Logs/restic-rest-client/logcleanup_YYYY-MM-DD_HH-MM-SS.log
~/Library/Logs/restic-rest-client/test-email_YYYY-MM-DD_HH-MM-SS.log
~/Library/Logs/restic-rest-client/test-success-email_YYYY-MM-DD_HH-MM-SS.log
~/Library/Logs/restic-rest-client/test-failure-email_YYYY-MM-DD_HH-MM-SS.log
~/Library/Logs/restic-rest-client/test-warning-email_YYYY-MM-DD_HH-MM-SS.log
~/Library/Logs/restic-rest-client/test-lock-failure-email_YYYY-MM-DD_HH-MM-SS.log
```

Daemon logs are rotated by `newsyslog` via
`/etc/newsyslog.d/com.restic-rest-client.conf`.

To follow only new daemon-log output from scheduled backup runs, use
`make watch-backup-log` or `./watch_backup_log.sh`.

## Behavior Notes

- `logcleanup` only deletes per-run logs. Fixed daemon logs are rotated by
  `newsyslog`.
- All script output is timestamped per line, including restic output.
- Each run ends with a terminal marker in the form
  `[STATE] run_backup.sh finished: task=<task> exit_code=<code>`. This lets
  helpers such as `make install-and-watch` stop cleanly even when the backup
  exits early.
- The script logs a masked repository URL and `env: RESTIC_REPOSITORY` as the
  source.
- Notification emails are multipart text+HTML messages with the per-run log
  attached as a text file.
- Notification test tasks do not touch the repository.
- Success and failure-style test tasks ignore
  `RESTIC_NOTIFY_ON_SUCCESS` and `RESTIC_NOTIFY_ON_FAILURE`; they are explicit
  operator tests.
- If `RESTIC_PRUNE_ENABLED` is not true, `prune` logs that it was skipped and
  exits `0` without contacting the repository.
- Backup exit `3` notifications are warning-style alerts rather than hard
  failures.
- Backup and prune failure emails add a stale-lock remediation note when restic
  exits `11` or the log clearly shows repository lock errors.
- Backup and prune can intentionally skip a run and exit `0` when power or
  clamshell guards block the task.
