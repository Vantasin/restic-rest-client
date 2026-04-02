# lib

Internal shell helper libraries used by the repo's top-level scripts.

## Files

- `platform.sh`: shared truthy parsing, macOS power/clamshell detection, file
  checks, and timestamped subprocess logging helpers
- `notifications.sh`: sourced notification rendering, email sending, and
  failure-classification helpers used by `run_backup.sh`
- `tasks.sh`: sourced backup, prune, and logcleanup task bodies used by
  `run_backup.sh`
