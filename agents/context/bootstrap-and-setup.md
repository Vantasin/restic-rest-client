# Bootstrap And Setup Context

Canonical human docs:

- `README.md`
- `Docs/BOOTSTRAP.md`
- `Docs/RESTIC_ENV.md`
- `Docs/SETUP_PASSWORD.md`
- `Docs/MAKEFILE.md`
- `Docs/RESTIC_REST_SERVER_SETUP.md`

## Responsibilities

- `setup.sh` is the curl-friendly onboarding entry point that can install
  missing Homebrew-managed dependencies, clone the repo, and start
  `bootstrap.sh --generate` plus `configure_env.sh`.
- `bootstrap.sh` generates local files and can install/uninstall launchd and
  newsyslog assets.
- `bootstrap.sh` also manages whether the prune launch agent is present based
  on `RESTIC_PRUNE_ENABLED`.
- `install_and_watch.sh` wraps `bootstrap.sh --install` and then follows only
  daemon-log output written during or after the install-triggered backup run.
- `configure_env.sh` prompts for REST base URL and username and keeps local
  repo-name/host defaults unless explicitly overridden. The prompt separates
  examples from current saved values and explicitly tells the user when Enter
  keeps the current value. It also writes the derived `RESTIC_REPOSITORY`
  value from the base URL plus repository name and owns the consolidated
  post-config next-step output.
- `init_repo.sh` initializes the configured repository and verifies access.
- `setup_password.sh` manages REST server password storage plus repository
  password generation/rotation. `--rest-server` and `--repository` are
  idempotent by default; `--rest-server --replace` and
  `--repository --rotate` are the explicit secret-changing paths.
- `Makefile` wraps common install/setup tasks, the direct
  `run_backup.sh` operational modes, and the install/restore/log-watch/
  stale-lock maintenance helpers for convenience.

## Agent concerns

- Bootstrap changes often affect both tracked templates and installed local
  state.
- `setup.sh` owns the dependency-check, Homebrew-install prompt, and clone-path
  handoff into the lower-level setup scripts.
- The env template and prune install mode are part of bootstrap behavior, not
  just docs.
- `--install` should validate `newsyslog` before loading the managed launchd
  agents and should keep managed launchd/newsyslog changes rollback-safe.
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
