# Makefile Convenience Targets

The Makefile is a thin wrapper around the repo's setup scripts, the common
`run_backup.sh` task modes, the stale-lock maintenance helper, and local Git
hook configuration. It exists to provide easy-to-remember shortcuts, while the
underlying scripts and Git config remain the source of truth.

## Targets

```bash
make bootstrap
```

Generate local gitignored config files from the tracked templates without
installing launchd or `newsyslog`.

```bash
make bootstrap-force
```

Generate local files and overwrite existing local config.

```bash
make configure
```

Prompt for the REST base URL and username and update `restic.env`. Repo name
and host keep their local defaults unless overridden explicitly.

```bash
make init-repo
```

Initialize the configured repository if it does not exist yet, then verify
access with `restic snapshots`.

```bash
make install
```

Generate local config files and install launchd + `newsyslog`.
This prompts for `sudo` to validate/install the `newsyslog` config before the
managed launchd agents are reloaded.
Backup and log cleanup are always installed. Prune is installed only when
`RESTIC_PRUNE_ENABLED=true`. Rerun `make install` after changing
`RESTIC_PRUNE_ENABLED` so the installed launchd assets match the new prune
mode without overwriting local generated config. If install fails after it has
started changing managed state, `bootstrap.sh` rolls the managed
launchd/newsyslog state back. The backup launch agent also runs once
immediately when it is loaded successfully.

```bash
make install-force
```

Install with overwrites for existing local files and the `newsyslog` config.
Use this only when you intentionally want to regenerate local files from
templates and overwrite the installed `newsyslog` config.

```bash
make uninstall
```

Unload/remove launchd, remove `newsyslog` config, and delete local generated
files.

```bash
make install-hooks
```

Configure the current clone to use the repo-managed Git hooks in `githooks/`.

```bash
make verify
```

Run fast repo-wide consistency checks. This is intended to be safe and local:
it checks syntax, executable bits for runnable repo entrypoints, plist
validity, whitespace issues, and directory README coverage across both the
working tree and staged index without requiring a live restic repository,
Keychain access, network access, or installed launchd state.

```bash
make backup
```

Run a backup immediately.

```bash
make prune
```

Run `forget --prune` when `RESTIC_PRUNE_ENABLED=true`.

```bash
make logcleanup
```

Delete old per-run logs according to `RESTIC_LOG_RETENTION_DAYS`.

```bash
make restore-latest
```

Restore the latest snapshot into `~/restic-restore`. The helper creates the
target directory when needed and refuses to use a non-empty target so it does
not restore over existing data. For specific snapshots, specific files, or a
different target directory, use [Docs/RESTIC_RESTORE_README.md](./RESTIC_RESTORE_README.md).

```bash
make unlock-stale-locks
```

List repository locks, refuse to proceed if a `run_backup.sh` or `restic`
process is active, run `restic unlock`, and then show the remaining locks.

```bash
make test-email
make test-success-email
make test-failure-email
make test-warning-email
make test-lock-failure-email
```

Run the matching notification test mode from `run_backup.sh`.

```bash
make setup-rest-server-password
```

Ensure the REST server password is configured in Keychain and update
`RESTIC_REST_PASSWORD` in `restic.env`. If the Keychain entry already exists,
the command skips cleanly and leaves the stored secret unchanged.

```bash
make setup-rest-server-password-replace
```

Prompt for the admin-provided REST server password and replace the existing
Keychain entry.

```bash
make setup-repository-password
```

Ensure the restic repository password is configured in Keychain and update
`RESTIC_PASSWORD_COMMAND` in `restic.env`. If the Keychain entry already
exists, the command skips cleanly and leaves the stored secret unchanged.

```bash
make setup-repository-password-rotate
```

Rotate an existing restic repository password entry.

Backward-compatible aliases:

- `make setup-password` -> `make setup-repository-password`
- `make setup-password-rotate` -> `make setup-repository-password-rotate`
