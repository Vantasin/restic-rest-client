# Makefile Convenience Targets

The Makefile is a thin wrapper around the repo's setup scripts and local Git
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
This prompts for `sudo` to install the `newsyslog` config.
Backup and log cleanup are always installed. Prune is installed only when
`RESTIC_PRUNE_ENABLED=true`. Rerun `make install` after changing
`RESTIC_PRUNE_ENABLED` so the installed launchd assets match the new prune
mode without overwriting local generated config.

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
make setup-rest-server-password
```

Prompt for the admin-provided REST server password, store it in Keychain, and
update `RESTIC_REST_PASSWORD` in `restic.env`.

```bash
make setup-repository-password
```

Generate and store the restic repository password in Keychain and update
`RESTIC_PASSWORD_COMMAND` in `restic.env`.

```bash
make setup-repository-password-rotate
```

Rotate an existing restic repository password entry.

Backward-compatible aliases:

- `make setup-password` -> `make setup-repository-password`
- `make setup-password-rotate` -> `make setup-repository-password-rotate`
