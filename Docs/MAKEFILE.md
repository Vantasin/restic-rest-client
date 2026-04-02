# Makefile Convenience Targets

The Makefile is a thin wrapper around the repo's setup scripts and local Git
hook configuration. It exists to provide easy-to-remember shortcuts, while the
underlying scripts and Git config remain the source of truth.

## Targets

```bash
make install
```

Generate local config files and install launchd + newsyslog.
This will prompt for `sudo` to install the newsyslog config.
Backup and log cleanup are always installed. Prune is installed only when
`RESTIC_PRUNE_ENABLED=true`.

```bash
make install-force
```

Install with overwrites for existing local files and the newsyslog config.

```bash
make uninstall
```

Unload/remove launchd, remove newsyslog config, and delete local generated
files (including `restic.env` and `restic-repository.txt`).

```bash
make install-hooks
```

Configure the current clone to use the repo-managed Git hooks in `githooks/`.

```bash
make verify
```

Run fast repo-wide consistency checks. This is intended to be safe and local:
it checks syntax, plist validity, whitespace issues, and directory README
coverage across both the working tree and staged index without requiring a live
restic repository, Keychain access, network access, or installed launchd
state.

```bash
make setup-password
```

Generate and store a Keychain password and update `restic.env`.

```bash
make setup-password-rotate
```

Rotate an existing Keychain password entry.
