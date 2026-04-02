# Documentation Workflow

Use this workflow when implementation changes require doc updates.

## Sequence

1. Identify the canonical human doc in `Docs/` or `README.md`.
2. Update the human doc first.
3. Update `.example` templates if the user-facing defaults or examples changed.
4. Update `agents/` only if workflows, rules, or component context changed.
5. Verify that links and terminology are consistent across the touched files.

## Mapping

- `run_backup.sh` behavior: `Docs/RUN_BACKUP_SCRIPT.md`
- env vars and notification knobs: `Docs/RESTIC_ENV.md`
- include/exclude scope: `Docs/INCLUDE_EXCLUDE.md`
- bootstrap/install flow: `Docs/BOOTSTRAP.md`
- restore behavior: `Docs/RESTIC_RESTORE_README.md`
- REST-server onboarding: `Docs/RESTIC_REST_SERVER_SETUP.md`
- REST client/server security model: `Docs/RESTIC_REST_SECURITY_MODEL.md`

## Documentation expectations

- Human docs explain behavior and usage.
- Agent docs explain how to work on the repo.
- Avoid copying long sections between the two.
