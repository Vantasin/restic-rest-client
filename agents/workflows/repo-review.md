# Repo Review Workflow

Run this review after core repository-function changes, including:

- `run_backup.sh`
- `bootstrap.sh`
- `configure_env.sh`
- `init_repo.sh`
- `setup_password.sh`
- `Makefile`
- `launchd/*.plist.example`
- `newsyslog/*.example`
- `restic.env.example`
- `restic-include-macos.txt.example`
- `restic-exclude-macos.txt.example`
- human docs in `Docs/` or `README.md` when they describe changed behavior

## Goals

- Find behavioral regressions first.
- Keep backup integrity, restore safety, lock handling, and scheduling behavior
  coherent.
- Keep templates, docs, and real repo behavior aligned.
- Avoid operator-facing drift.

## Review sequence

1. Read `agents/context/repo-map.md` and the touched component context files.
2. Read the relevant human docs in `Docs/` and `README.md`.
3. Inspect the changed implementation, templates, and related docs together.
4. Check whether examples, schedules, defaults, and documented behavior still
   match.
5. Run the minimum relevant verification commands from
   `agents/rules/verification.md`.

## What to look for

- accidental backup-scope changes
- secrets or host-specific state being committed
- launchd schedule or path drift
- log rotation drift
- lock-handling regressions
- power-guard regressions for backup or prune
- restore or bootstrap guidance no longer matching behavior
- docs/examples that no longer reflect the implemented repo state

## Output expectations

- Lead with findings, ordered by severity.
- Include file references and concrete evidence such as commands, logs, exit
  codes, snapshot IDs, or launchd labels where relevant.
- If the review causes edits, log the follow-up changes with
  `agents/workflows/change-logging.md` and note that they were review-driven.
