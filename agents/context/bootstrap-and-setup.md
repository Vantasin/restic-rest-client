# Bootstrap And Setup Context

Canonical human docs:

- `Docs/BOOTSTRAP.md`
- `Docs/SETUP_PASSWORD.md`
- `Docs/MAKEFILE.md`

## Responsibilities

- `bootstrap.sh` generates local files and can install/uninstall launchd and
  newsyslog assets.
- `bootstrap.sh` also manages whether the prune launch agent is present based
  on `RESTIC_PRUNE_ENABLED`.
- `setup_password.sh` manages the Keychain-backed password flow.
- `Makefile` wraps common install/setup tasks for convenience.

## Agent concerns

- Bootstrap changes often affect both tracked templates and installed local
  state.
- The repository URL template and prune install mode are part of bootstrap
  behavior, not just docs.
- Password setup changes are security-sensitive; avoid exposing secrets in
  logs, docs, or examples.
- Makefile shortcuts should stay aligned with the underlying scripts.

## Typical follow-through

- If bootstrap behavior changes, update `Docs/BOOTSTRAP.md`.
- If password setup changes, update `Docs/SETUP_PASSWORD.md`.
- If the user-facing command surface changes, update `README.md` and
  `Docs/MAKEFILE.md` where relevant.
