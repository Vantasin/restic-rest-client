# Repository Map

This repo centers on a macOS restic client with local automation and an
external REST-server backend.

## Primary components

- `run_backup.sh`: single task entry point for backup, prune, log cleanup, and
  notification test tasks
- `lib/platform.sh`: shared truthy parsing, macOS power/clamshell detection,
  file checks, and timestamped subprocess logging helpers
- `lib/notifications.sh`: sourced notification formatting, email delivery, and
  failure-classification helpers used by `run_backup.sh`
- `lib/tasks.sh`: sourced backup, prune, and logcleanup task helpers used by
  `run_backup.sh`
- `bootstrap.sh`: generates local files from tracked templates and can install
  launchd/newsyslog assets
- `setup.sh`: curl-friendly onboarding entry point that can install missing
  Homebrew-managed dependencies, clone the repo, and start bootstrap/configure
- `configure_env.sh`: populates required REST settings in `restic.env`
- `init_repo.sh`: initializes the configured repository and verifies access
- `restore_latest.sh`: convenience restore helper for the latest snapshot into
  an empty local target directory
- `unlock_stale_locks.sh`: safe stale-lock cleanup helper for manual
  repository maintenance
- `setup_password.sh`: manages the Keychain-backed REST server and repository
  password flow
- `githooks/`: repo-managed Git hook checks for fast consistency validation
- `launchd/*.plist.example`: tracked launchd templates
- `restic.env.example`: tracked environment template
- `restic-include-macos.txt.example`: tracked backup root template
- `restic-exclude-macos.txt.example`: tracked exclude template
- `Makefile`: convenience wrapper for setup/install tasks, common
  `run_backup.sh` modes, restore/stale-lock maintenance, and repo validation
  helpers
- `Docs/`: canonical human-readable component documentation

## Generated local state

These are expected local/generated files and should not be treated as the main
committed source of truth unless the task explicitly targets installed state:

- `restic.env`
- `restic-include-macos.txt`
- `restic-exclude-macos.txt`
- `launchd/com.restic-rest-client.backup.plist`
- `launchd/com.restic-rest-client.prune.plist`
- `launchd/com.restic-rest-client.logcleanup.plist`
- `~/Library/LaunchAgents/com.restic-rest-client.*.plist`

## Human doc map

- `README.md`: top-level user overview
- `Docs/RUN_BACKUP_SCRIPT.md`: task behavior and script knobs
- `Docs/RESTIC_ENV.md`: configuration/env contract
- `Docs/INCLUDE_EXCLUDE.md`: backup scope contract
- `Docs/BOOTSTRAP.md`: generation/install flow
- `Docs/RESTIC_RESTORE_README.md`: restore workflows
- `Docs/RESTIC_REST_SERVER_SETUP.md`: REST-server onboarding and access model
- `Docs/RESTIC_REST_SECURITY_MODEL.md`: client/server security boundary
- `Docs/GIT_HOOKS.md`: local hook installation and fast consistency checks
- `Docs/decisions/README.md`: durable architectural and operational decisions

## Current architecture

- current focus: macOS client backup automation
- backend model: external `restic/rest-server` deployment documented elsewhere
- default access mode assumption: `--append-only --private-repos`
- default auth model: repository URL in `restic.env`, REST auth via
  `RESTIC_REST_*`, repository password via `RESTIC_PASSWORD_COMMAND`
- default repository model: derive `RESTIC_REPOSITORY` from
  `RESTIC_REPOSITORY_BASE_URL` and `RESTIC_REPOSITORY_NAME`
- keep client automation separate from server deployment implementation
