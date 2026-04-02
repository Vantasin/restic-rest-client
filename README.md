# restic-rest-client

Opinionated macOS restic client automation for backing up to an external
`restic/rest-server` deployment. This repo keeps the same local automation
shape as the original `Restic` repo, but the defaults are aligned to the
companion `restic-rest-server` deployment model: HTTPS, `--private-repos`, and
append-only by default.

## Quick Start

### 1. Clone and install

```bash
git clone <REPO_URL> "$HOME/Git/restic-rest-client"
cd "$HOME/Git/restic-rest-client"
./bootstrap.sh --install
```

Optional:

```bash
make install
```

By default, install writes local config, installs backup and log-cleanup
launchd agents, and installs the `newsyslog` config. The prune agent is only
installed when `RESTIC_PRUNE_ENABLED=true`.

### 2. Enable repo-managed Git hooks

```bash
make install-hooks
```

### 3. Set up the restic repository password

```bash
./setup_password.sh
```

Optional:

```bash
make setup-password
```

This stores the restic encryption password in Keychain. It does not set the
REST server password used in the repository URL.

### 4. Configure the client

Edit these local files:

- `restic.env`
- `restic-repository.txt`

Set at minimum:

- `RESTIC_HOST` in `restic.env`
- the repository URL in `restic-repository.txt`

Default repository URL pattern for the companion server repo:

```text
rest:https://backup:<SERVER_PASSWORD>@backup.example.com/backup/<HOSTNAME>
```

This matches the server repo's default `--private-repos` model, where user
`backup` can access paths under `backup/...`.

### 5. Initialize and test

```bash
source restic.env
restic init
restic snapshots
launchctl kickstart -k gui/$UID/com.restic-rest-client.backup
tail -n 40 -f ~/Library/Logs/restic-rest-client/daemon_backup.log
```

## Access Model

- Rest-server username/password:
  HTTP auth credentials used in `restic-repository.txt`
- Restic repository password:
  encryption password stored in Keychain or otherwise provided to restic

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
./bootstrap.sh --install --force
```

That installs the prune launch agent in addition to backup and log cleanup.

## What This Repo Contains

- [`run_backup.sh`](./run_backup.sh): backup, prune, log-cleanup, and
  notification-test entry point
- [`bootstrap.sh`](./bootstrap.sh): generates local files and installs
  launchd/newsyslog assets
- [`setup_password.sh`](./setup_password.sh): Keychain-backed repository
  password setup and rotation
- [`restic.env.example`](./restic.env.example): tracked env template
- [`restic-repository.txt.example`](./restic-repository.txt.example): tracked
  repository-URL template
- [`Docs/README.md`](./Docs/README.md): human-readable reference docs
- [`AGENTS.md`](./AGENTS.md) and [`agents/`](./agents/README.md): agent-facing
  repo rules, context, and workflows

## Common Tasks

Run fast verification:

```bash
make verify
```

Run a backup:

```bash
./run_backup.sh
```

Run prune, only when the server allows client-side maintenance:

```bash
./run_backup.sh prune
```

Run log cleanup:

```bash
./run_backup.sh logcleanup
```

Send test emails:

```bash
./run_backup.sh test-email
./run_backup.sh test-success-email
./run_backup.sh test-failure-email
./run_backup.sh test-warning-email
./run_backup.sh test-lock-failure-email
```

Unlock stale locks:

```bash
source restic.env
if pgrep -fl "run_backup.sh|restic" >/dev/null; then
  echo "Active restic-related process found; not unlocking."
  pgrep -fl "run_backup.sh|restic"
else
  restic list locks
  restic unlock
fi
```

Restore into a temporary directory:

```bash
source restic.env
restic restore latest --target /tmp/restic-restore
```

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

## Repository Notes

- `restic.env` and `restic-repository.txt` are local state and must not be
  committed.
- `./bootstrap.sh --install` prompts for `sudo` to install the `newsyslog`
  config.
