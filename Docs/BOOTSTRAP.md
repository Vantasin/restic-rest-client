# Bootstrap Script

`bootstrap.sh` generates host-specific local files from the tracked templates
and can install or uninstall the repo's launchd and `newsyslog` assets.

## Modes

- `--generate`: write local gitignored files only
- `--install`: write local files, install launchd agents, and install
  `newsyslog`
- `--uninstall`: unload/remove launchd and `newsyslog`, then remove generated
  local files

## What It Writes By Default

- `restic.env` from `restic.env.example`
- `restic-include-macos.txt` from `restic-include-macos.txt.example`
- `restic-exclude-macos.txt` from `restic-exclude-macos.txt.example`
- `launchd/com.restic-rest-client.backup.plist` from the matching template
- `launchd/com.restic-rest-client.prune.plist` from the matching template
- `launchd/com.restic-rest-client.logcleanup.plist` from the matching template

## Placeholders

Templates use these placeholders:

- `{{HOME}}` -> your home directory
- `{{USER}}` -> your username
- `{{SCRIPT_DIR}}` -> repo directory containing `bootstrap.sh`
- `{{HOSTNAME}}` -> system ComputerName or hostname fallback
- `{{HOSTNAME_SLUG}}` -> URL-safe hostname slug derived from `{{HOSTNAME}}`

## Output

The script prints a short action log:

- `WROTE:` for generated local files
- `SKIP:` when a target already exists
- `COPIED:` when launchd plists are copied to `~/Library/LaunchAgents`
- `LOADED:` when launchd agents are loaded
- `INSTALLED:` when `/etc/newsyslog.d/com.restic-rest-client.conf` is written
- `VERIFIED:` when launchd or `newsyslog` validation succeeds
- `REMOVED:` when uninstall deletes a file

Install and uninstall are fail-hard: if verification fails, the script exits
non-zero. `--install` validates `newsyslog` before loading the managed launchd
agents, and if a later install step fails it rolls the managed launchd and
`newsyslog` state back.

## Prune Install Behavior

Backup and log cleanup are always installed.

The prune launch agent is installed only when `RESTIC_PRUNE_ENABLED=true` in
`restic.env`. That matches the companion server repo's default append-only
access model.

If prune is disabled, install removes any previously installed prune launch
agent and verifies that it is not still loaded.

If you change `RESTIC_PRUNE_ENABLED` after the initial install, rerun:

```bash
make install
```

That reloads the installed launchd agents and adds or removes the prune launch
agent to match the new setting without overwriting your local generated config.
Use `make install-force` only when you intentionally want to regenerate local
files from templates and overwrite the installed `newsyslog` config.

## Recommended Order

1. Run `make bootstrap` or `./bootstrap.sh --generate`.
2. Run `make configure` or `./configure_env.sh`.
3. Review `restic.env` and adjust any optional settings you want. By default,
   configure keeps the generated repo-name and host defaults unless you pass
   `--repo-name` or `--host`.
4. Store the admin-provided REST server password with
   `make setup-rest-server-password`.
5. Generate the repository password with `make setup-repository-password`.
6. Run `make init-repo` for first-time repository creation and verification.
7. Run `make install` when you are ready to install launchd and `newsyslog`.

## Safety

- `restic.env` is created with placeholder REST settings and Keychain lookup
  commands, not live passwords
- existing generated files are not overwritten unless you pass `--force`
- uninstall removes the generated local files

## Usage

Generate local files only:

```bash
./bootstrap.sh --generate
```

Makefile equivalent:

```bash
make bootstrap
```

Populate the required REST settings in `restic.env`:

```bash
./configure_env.sh
```

By default, this prompts only for the REST base URL and username and keeps the
generated repo-name and host defaults.

Makefile equivalent:

```bash
make configure
```

Install:

```bash
./bootstrap.sh --install
```

This validates the `newsyslog` config first. If validation succeeds, install
updates the managed `newsyslog` and launchd state as one transaction and rolls
those managed assets back if a later install step fails. Because the backup
launchd template uses `RunAtLoad`, the backup job runs once immediately after a
successful install.

Install with overwrites:

```bash
./bootstrap.sh --install --force
```

This overwrites existing generated local files and the installed `newsyslog`
config. It is not required just to reconcile prune mode after changing
`RESTIC_PRUNE_ENABLED`.

Uninstall:

```bash
./bootstrap.sh --uninstall
```

Before relying on scheduled backups, grant Full Disk Access to the process that
runs restic. Manual runs usually need it for your terminal app. `launchd` runs
may also need it for the shell and `restic` executables used by
`run_backup.sh`.

## Manual Setup Outline

If you prefer not to use `bootstrap.sh`, the equivalent setup is:

1. Generate local files from the tracked templates.
2. Populate the required REST values in `restic.env` with `./configure_env.sh`
   or by editing the file directly.
3. Replace any remaining placeholder values in include/exclude files and local
   plists.
4. Store the REST server and repository passwords in Keychain or another local
   password source.
5. Initialize and verify the repository with `./init_repo.sh`.
6. Install the launchd agents you actually want.
7. Install the `newsyslog` config at
   `/etc/newsyslog.d/com.restic-rest-client.conf`.

If you install launchd manually and later change `RESTIC_PRUNE_ENABLED`,
remember to add or remove `com.restic-rest-client.prune.plist` yourself.
