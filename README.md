# restic-rest-client

Opinionated macOS restic client automation for backing up to an external
`restic/rest-server` deployment, with template-based local config,
Keychain-backed secrets, and launchd/newsyslog automation. The defaults are
aligned to the companion `restic-rest-server` deployment model: HTTPS,
`--private-repos`, and append-only by default.

Companion server repo:
<https://github.com/Vantasin/restic-rest-server.git>

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/Vantasin/restic-rest-client/main/setup.sh | zsh
```

By default this clones or reuses `~/Git/restic-rest-client`. If you want a
different location, rerun it with `--clone-dir /your/path`.

> Note: The onboarding script checks for Homebrew and the required client
> tools, offers optional installs such as `msmtp`, clones or reuses the repo,
> runs `bootstrap.sh --generate`, and launches `configure_env.sh` for the
> required REST settings. It then prints the remaining `make` commands for
> Keychain password setup, repository initialization, and `make install-and-watch`. For the full setup flow, see
> - [Docs/BOOTSTRAP.md](./Docs/BOOTSTRAP.md)
> - [Docs/SETUP_PASSWORD.md](./Docs/SETUP_PASSWORD.md)
> - [Docs/RESTIC_REST_SERVER_SETUP.md](./Docs/RESTIC_REST_SERVER_SETUP.md)
> - [Docs/MAKEFILE.md](./Docs/MAKEFILE.md)

## restic.env

`restic.env` is the local client config file. The onboarding flow populates the
required repository URL and REST username, and the same file also controls
optional behavior such as prune, retention, email alerts, AC-power
requirements, and clamshell rules.

You can edit `restic.env` manually later and apply those changes with:

```bash
cd "$HOME/Git/restic-rest-client"
make install
```

For the full variable reference, example values, and the settings behind
prune, notifications, power guards, and lid-closed behavior, see
[Docs/RESTIC_ENV.md](./Docs/RESTIC_ENV.md).

## Access Model

- Rest-server username/password:
  HTTP auth credentials exposed to restic through `RESTIC_REST_USERNAME` and
  `RESTIC_REST_PASSWORD`
- Restic repository password:
  encryption password stored in Keychain through `RESTIC_PASSWORD_COMMAND`

These are separate secrets.

The companion `restic-rest-server` repo defaults to
`--append-only --private-repos`, so this client repo defaults to
`RESTIC_PRUNE_ENABLED=false`. Backups and restores work in that mode; client
`forget --prune` does not.

If the server is intentionally switched to client-managed maintenance mode
without `--append-only`, set:

```bash
export RESTIC_PRUNE_ENABLED="true"
```

Then rerun:

```bash
make install
```

That reloads the installed launchd agents and adds or removes the prune launch
agent to match `RESTIC_PRUNE_ENABLED` without overwriting your local generated
config. Use `make install-force` only when you intentionally want to
regenerate local files from templates and overwrite the installed
`newsyslog` config.

## Common Tasks

Run fast verification:

```bash
make verify
```

Run a backup:

```bash
make backup
```

Run prune, only when the server allows client-side maintenance:

```bash
make prune
```

Run log cleanup:

```bash
make logcleanup
```

Watch only new output from the launchd backup daemon log:

```bash
make watch-backup-log
```

> This starts from the end of `daemon_backup.log`, so it does not replay stale
> lines from older runs.

Send test emails:

```bash
make test-email
make test-success-email
make test-failure-email
make test-warning-email
make test-lock-failure-email
```

Unlock stale locks:

```bash
make unlock-stale-locks
```

> This helper refuses to run if a `run_backup.sh` or `restic` process is active.

Restore the latest snapshot into `~/restic-restore`:

```bash
make restore-latest
```

> Note: For restoring specific files, specific snapshots, or a different
> target directory, see [Docs/RESTIC_RESTORE_README.md](./Docs/RESTIC_RESTORE_README.md).

## macOS Notes

If a backup exits `3` with `operation not permitted`, restic usually saved a
partial snapshot because macOS blocked reads from protected paths under
`~/Library`.

Before relying on backups, grant Full Disk Access to the process that runs the
backup:

- manual runs usually need it for your terminal app
- `launchd` runs may also need it for the shell and `restic` executables used
  by `run_backup.sh`

If logs show `resource deadlock avoided` under `~/Library/Mobile Documents`,
the files are often iCloud or File Provider placeholders. Keep them downloaded
locally or exclude them intentionally.

## Repository Notes

- `restic.env` is local state and must not be committed.
- `make bootstrap` writes local files only.
- `make configure` populates the required REST settings in `restic.env`.
- `make install` and `./bootstrap.sh --install` prompt for `sudo` to install
  the `newsyslog` config.

## What This Repo Contains

- [`run_backup.sh`](./run_backup.sh): backup, prune, log-cleanup, and
  notification-test entry point
- [`setup.sh`](./setup.sh): curl-friendly dependency check, clone, bootstrap,
  and configure entry point
- [`bootstrap.sh`](./bootstrap.sh): generates local files and installs
  launchd/newsyslog assets
- [`configure_env.sh`](./configure_env.sh): populates the required REST
  settings in `restic.env`
- [`init_repo.sh`](./init_repo.sh): initializes the configured repository and
  verifies access
- [`install_and_watch.sh`](./install_and_watch.sh): install automation and
  follow only the install-triggered backup log output
- [`watch_backup_log.sh`](./watch_backup_log.sh): follow only new output from
  the launchd backup daemon log
- [`restore_latest.sh`](./restore_latest.sh): convenience restore helper for
  the latest snapshot into `~/restic-restore`
- [`unlock_stale_locks.sh`](./unlock_stale_locks.sh): safe stale-lock cleanup
  helper that refuses to run while restic is active
- [`setup_password.sh`](./setup_password.sh): Keychain-backed REST server
  password storage plus repository-password setup and rotation
- [`restic.env.example`](./restic.env.example): tracked env template
- [`Docs/README.md`](./Docs/README.md): human-readable reference docs
- [`AGENTS.md`](./AGENTS.md) and [`agents/`](./agents/README.md): agent-facing
  repo rules, context, and workflows

## Read Next

- [`Docs/BOOTSTRAP.md`](./Docs/BOOTSTRAP.md)
- [`Docs/RESTIC_ENV.md`](./Docs/RESTIC_ENV.md)
- [`Docs/RUN_BACKUP_SCRIPT.md`](./Docs/RUN_BACKUP_SCRIPT.md)
- [`Docs/INCLUDE_EXCLUDE.md`](./Docs/INCLUDE_EXCLUDE.md)
- [`Docs/RESTIC_REST_SERVER_SETUP.md`](./Docs/RESTIC_REST_SERVER_SETUP.md)
- [`Docs/RESTIC_REST_SECURITY_MODEL.md`](./Docs/RESTIC_REST_SECURITY_MODEL.md)
- [`Docs/RESTIC_RESTORE_README.md`](./Docs/RESTIC_RESTORE_README.md)
- [`Docs/SETUP_PASSWORD.md`](./Docs/SETUP_PASSWORD.md)
- [`Docs/MAKEFILE.md`](./Docs/MAKEFILE.md)
- [`Docs/GIT_HOOKS.md`](./Docs/GIT_HOOKS.md)
- [`Docs/decisions/README.md`](./Docs/decisions/README.md)