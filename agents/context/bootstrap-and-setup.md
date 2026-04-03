# Bootstrap And Setup Context

Canonical human docs:

- `README.md`
- `Docs/BOOTSTRAP.md`
- `Docs/RESTIC_ENV.md`
- `Docs/SETUP_PASSWORD.md`
- `Docs/MAKEFILE.md`
- `Docs/RESTIC_REST_SERVER_SETUP.md`

## Responsibilities

- `bootstrap.sh` generates local files and can install/uninstall launchd and
  newsyslog assets.
- `bootstrap.sh` also manages whether the prune launch agent is present based
  on `RESTIC_PRUNE_ENABLED`.
- `configure_env.sh` prompts for REST base URL and username and keeps local
  repo-name/host defaults unless explicitly overridden.
- `init_repo.sh` initializes the configured repository and verifies access.
- `setup_password.sh` manages REST server password storage plus repository
  password generation/rotation.
- `Makefile` wraps common install/setup tasks for convenience.

## Agent concerns

- Bootstrap changes often affect both tracked templates and installed local
  state.
- The env template and prune install mode are part of bootstrap behavior, not
  just docs.
- `make install` should reconcile prune-agent state without overwriting local
  generated config; `--force` is the template-overwrite path.
- Password setup changes are security-sensitive; avoid exposing secrets in
  logs, docs, or examples.
- Makefile shortcuts should stay aligned with the underlying scripts.

## Typical follow-through

- If bootstrap behavior changes, update `Docs/BOOTSTRAP.md`.
- If the configure step or env contract changes, update `Docs/RESTIC_ENV.md`,
  `README.md`, and `Docs/RESTIC_REST_SERVER_SETUP.md`.
- If password setup changes, update `Docs/SETUP_PASSWORD.md`.
- If the user-facing command surface changes, update `README.md` and
  `Docs/MAKEFILE.md` where relevant.
