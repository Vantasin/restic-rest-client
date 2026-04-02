# Bootstrap Script

`bootstrap.sh` generates host-specific local files from the tracked templates
and can install or uninstall the repo's launchd and `newsyslog` assets.

## What It Writes

- `restic.env` from `restic.env.example`
- `restic-repository.txt` from `restic-repository.txt.example`
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
non-zero.

## Prune Install Behavior

Backup and log cleanup are always installed.

The prune launch agent is installed only when `RESTIC_PRUNE_ENABLED=true` in
`restic.env`. That matches the companion server repo's default append-only
access model.

If prune is disabled, install removes any previously installed prune launch
agent and verifies that it is not still loaded.

## Safety

- `restic.env` is created but not populated with live secrets
- `restic-repository.txt` is created with a placeholder URL, not a real server
  password
- existing generated files are not overwritten unless you pass `--force`
- uninstall removes the generated local files, including `restic.env` and
  `restic-repository.txt`

## Usage

Install:

```bash
./bootstrap.sh --install
```

This prompts for `sudo` to install the `newsyslog` config.

Install with overwrites:

```bash
./bootstrap.sh --install --force
```

Uninstall:

```bash
./bootstrap.sh --uninstall
```

After install, set up the restic repository password:

```bash
./setup_password.sh
```

Before relying on scheduled backups, grant Full Disk Access to the process that
runs restic. Manual runs usually need it for your terminal app. `launchd` runs
may also need it for the shell and `restic` executables used by
`run_backup.sh`.

## Manual Setup Outline

If you prefer not to use `bootstrap.sh`, the equivalent setup is:

1. Generate local files from the tracked templates.
2. Replace the placeholder values in the generated files.
3. Set `RESTIC_HOST` and repository settings.
4. Set up the repository password with Keychain or another local password
   source.
5. Install the launchd agents you actually want.
6. Install the `newsyslog` config at
   `/etc/newsyslog.d/com.restic-rest-client.conf`.

If you install launchd manually and later change `RESTIC_PRUNE_ENABLED`,
remember to add or remove `com.restic-rest-client.prune.plist` yourself.
