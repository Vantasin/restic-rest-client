# Verification Rules

Choose validation based on what changed and report what was or was not run.

## Always

- Prefer `make verify` as the baseline local verification pass.
- Run `git diff --check` before finishing.

## Review triggers

- Run `agents/workflows/agent-review.md` after core changes to `AGENTS.md`,
  `agents/`, or the repo's agent guidance structure.
- Run `agents/workflows/repo-review.md` after core changes to scripts,
  templates, scheduling, backup scope, or other repository behavior.
- If either review leads to follow-up edits, log them with
  `agents/workflows/change-logging.md`.

## When shell logic changes

- Run `zsh -n` on edited shell scripts such as `run_backup.sh`,
  `bootstrap.sh`, `setup_password.sh`, `verify_repo.sh`, and
  `githooks/pre-commit`.

## When launchd plist templates change

- Run `plutil -lint` on the touched plist files.
- If the task includes installing or reloading the local agent, state that
  clearly as a local operational change.

## When docs or templates affect operational behavior

- Verify that the referenced docs and examples still match the implemented
  behavior.
- If a change needs a real restic run, snapshot check, or unlock step and it
  was not executed, say so explicitly.

## When review findings are reported

- Prefer concrete evidence: file references, commands run, log paths, snapshot
  IDs, and exit codes where available.
