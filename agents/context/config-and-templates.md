# Config And Template Context

Canonical human docs:

- `Docs/RESTIC_ENV.md`
- `Docs/INCLUDE_EXCLUDE.md`
- `Docs/BOOTSTRAP.md`

## Template-first model

Tracked files are templates and examples. Local operational files are generated
from them.

## High-sensitivity files

- `restic.env.example`: default env contract for the per-user base URL,
  repository name, derived `RESTIC_REPOSITORY`, REST username, and
  Keychain-backed password lookups
- `restic-include-macos.txt.example`: top-level backup roots
- `restic-exclude-macos.txt.example`: exclusions and backup-scope trimming
- `launchd/*.plist.example`: schedule/path defaults for generated agents

## Agent concerns

- Do not commit populated secrets.
- Scope changes in include/exclude templates can create large snapshot diffs.
- Example defaults should match the current intended operator policy.
- `{{HOSTNAME}}` and `{{HOSTNAME_SLUG}}` placeholder behavior must stay aligned
  between `bootstrap.sh` and the tracked templates.
- If a task changes only a local generated file, say that explicitly.

## Common drift risk

- Updating local generated files without updating the tracked template
- Updating templates without updating the human docs that explain them
