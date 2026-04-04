# Source Of Truth Matrix

Use this matrix to decide where changes belong, which docs must stay aligned,
and what minimum verification should run.

| Area | Implementation / Source Files | Canonical Human Docs | Agent Context / Rules | Minimum Verification |
| --- | --- | --- | --- | --- |
| Backup, prune, logcleanup, and notification-test behavior | `run_backup.sh`, `lib/platform.sh`, `lib/notifications.sh`, `lib/tasks.sh` | `Docs/RUN_BACKUP_SCRIPT.md`, `README.md`, `Docs/RESTIC_ENV.md` | `agents/context/run-backup.md`, `agents/rules/scheduling-and-log-rotation.md`, `agents/context/rest-server-integration.md` | `make verify`, `zsh -n run_backup.sh`, `zsh -n lib/platform.sh`, `zsh -n lib/notifications.sh`, `zsh -n lib/tasks.sh` |
| Manual repository maintenance and restore | `unlock_stale_locks.sh`, `restore_latest.sh`, `Makefile` | `README.md`, `Docs/MAKEFILE.md`, `Docs/RUN_BACKUP_SCRIPT.md`, `Docs/RESTIC_RESTORE_README.md` | `agents/context/repo-map.md`, `agents/context/run-backup.md` | `make verify`, `zsh -n unlock_stale_locks.sh`, `zsh -n restore_latest.sh` |
| Env and config defaults | `restic.env.example` | `Docs/RESTIC_ENV.md`, `Docs/RESTIC_REST_SERVER_SETUP.md`, `Docs/RESTIC_REST_SECURITY_MODEL.md` | `agents/context/config-and-templates.md`, `agents/context/rest-server-integration.md`, `agents/rules/template-integrity.md`, `agents/rules/client-server-boundaries.md` | `make verify` |
| Include/exclude scope | `restic-include-macos.txt.example`, `restic-exclude-macos.txt.example` | `Docs/INCLUDE_EXCLUDE.md` | `agents/context/config-and-templates.md`, `agents/rules/template-integrity.md` | `make verify` |
| Launchd automation | `launchd/*.plist.example` | `Docs/BOOTSTRAP.md`, `Docs/RUN_BACKUP_SCRIPT.md`, `launchd/README.md` | `agents/context/launchd-and-logging.md`, `agents/rules/scheduling-and-log-rotation.md` | `make verify`, `plutil -lint launchd/*.plist.example` |
| Daemon log rotation | `newsyslog/com.restic-rest-client.conf.example` | `Docs/BOOTSTRAP.md`, `Docs/RUN_BACKUP_SCRIPT.md`, `newsyslog/README.md` | `agents/context/newsyslog-and-log-files.md`, `agents/rules/scheduling-and-log-rotation.md`, `agents/rules/template-integrity.md` | `make verify` |
| Bootstrap and setup flow | `setup.sh`, `bootstrap.sh`, `configure_env.sh`, `init_repo.sh`, `setup_password.sh`, `Makefile` | `Docs/BOOTSTRAP.md`, `Docs/RESTIC_ENV.md`, `Docs/SETUP_PASSWORD.md`, `Docs/MAKEFILE.md`, `README.md`, `Docs/RESTIC_REST_SERVER_SETUP.md` | `agents/context/bootstrap-and-setup.md` | `make verify`, `zsh -n setup.sh`, `zsh -n bootstrap.sh`, `zsh -n configure_env.sh`, `zsh -n init_repo.sh`, `zsh -n setup_password.sh` |
| Git hook verification | `githooks/pre-commit`, `verify_repo.sh`, `Makefile` | `Docs/GIT_HOOKS.md`, `Docs/MAKEFILE.md`, `githooks/README.md` | `agents/context/repo-map.md`, `agents/rules/verification.md` | `make verify`, `zsh -n githooks/pre-commit`, `zsh -n verify_repo.sh` |
| Agent guidance layer | `AGENTS.md`, `agents/` | `Docs/README.md` for human doc map only | `agents/workflows/agent-review.md`, `agents/rules/core.md` | `make verify`, agent review |

## Notes

- Tracked `.example` files are the Git source of truth for generated local
  config.
- Local generated files are operational state and should not be treated as the
  canonical implementation target unless the task explicitly says so.
- If a change spans multiple matrix rows, update all affected human docs and
  run both the relevant review and the relevant verification checks.
