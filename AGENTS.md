# Repository Guidelines

`Docs/` contains human-readable component documentation. `agents/` contains
agent-facing workflows, context, and rules. Keep this file thin and use it as a
router.

## Read Order

1. `agents/rules/core.md`
2. `agents/context/repo-map.md`
3. `agents/context/source-of-truth-matrix.md`
4. The relevant files in `agents/context/`
5. The relevant files in `agents/workflows/`

## Agent References

- `agents/rules/core.md`
- `agents/rules/verification.md`
- `agents/rules/documentation.md`
- `agents/rules/template-integrity.md`
- `agents/rules/scheduling-and-log-rotation.md`
- `agents/rules/client-server-boundaries.md`
- `agents/rules/deprecation-and-migration.md`
- `agents/workflows/review.md`
- `agents/workflows/agent-review.md`
- `agents/workflows/repo-review.md`
- `agents/workflows/change-logging.md`
- `agents/workflows/documentation.md`
- `agents/workflows/new-area.md`
- `agents/context/repo-map.md`
- `agents/context/source-of-truth-matrix.md`
- `agents/context/run-backup.md`
- `agents/context/config-and-templates.md`
- `agents/context/launchd-and-logging.md`
- `agents/context/newsyslog-and-log-files.md`
- `agents/context/bootstrap-and-setup.md`
- `agents/context/rest-server-integration.md`

## Canonical Human Docs

- `README.md`
- `Docs/RUN_BACKUP_SCRIPT.md`
- `Docs/RESTIC_ENV.md`
- `Docs/INCLUDE_EXCLUDE.md`
- `Docs/BOOTSTRAP.md`
- `Docs/SETUP_PASSWORD.md`
- `Docs/MAKEFILE.md`
- `Docs/GIT_HOOKS.md`
- `Docs/decisions/README.md`
- `Docs/RESTIC_RESTORE_README.md`
- `Docs/RESTIC_REST_SERVER_SETUP.md`
- `Docs/RESTIC_REST_SECURITY_MODEL.md`

## Repo-Wide Non-Negotiables

- Never commit populated secrets such as `restic.env` or
  `restic-repository.txt`.
- Treat generated local files as local state unless the task explicitly targets
  installed/generated assets.
- Update human docs when user-visible behavior, setup, or operational defaults
  change.
- Update `agents/` when repo rules, workflows, or component context change.
