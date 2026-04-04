# restic-rest-client

Opinionated macOS restic client automation for backing up to an external
`restic/rest-server` deployment, with template-based local config,
Keychain-backed secrets, and launchd/newsyslog automation. The defaults are
aligned to the companion `restic-rest-server` deployment model: HTTPS,
`--private-repos`, and append-only by default.

Companion server repo:
<https://github.com/Vantasin/restic-rest-server.git>

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/Vantasin/restic-rest-client.git "$HOME/Git/restic-rest-client"
cd "$HOME/Git/restic-rest-client"
```

### 2. Generate local config and set server details

Run:

```bash
make bootstrap
make configure
```

The server admin should provide:

- the base per-user HTTPS repository URL
- the REST username
- the REST password

Example:

```text
RESTIC_REPOSITORY_BASE_URL=https://restic.example.com/user
RESTIC_REST_USERNAME=user
```

Do not enter only the server root such as
`https://restic.example.com` unless the server admin explicitly tells
you that the per-user base path is the root.

`make configure` prompts only for the base URL and username. It keeps the
local defaults for `RESTIC_REPOSITORY_NAME` and `RESTIC_HOST`, and
`restic.env` derives the final `RESTIC_REPOSITORY` from those values. Edit
`restic.env` afterward only if you want to change optional settings such as
repo name, host label, prune mode, retention, notifications, or power guards.

With the example above and the default repo name, the derived repository URL
would look like:

```text
rest:https://restic.example.com/user/my-macbook
```

### 3. Store passwords in Keychain

```bash
make setup-rest-server-password
```

```bash
make setup-repository-password
```

The first command stores the admin-provided REST server password and updates
`RESTIC_REST_PASSWORD` in `restic.env`. The second generates the restic repository password, stores it in Keychain, and updates `RESTIC_PASSWORD_COMMAND`.

### 4. Initialize the repository and verify access

```bash
make init-repo
```

This is the step where the client creates the repository for the first time.
If the repository already exists, it skips `restic init` and just verifies
access.

### 5. Install automation

```bash
make install
```

This installs the backup and log-cleanup launchd agents plus the `newsyslog`
config. The prune agent is installed only when `RESTIC_PRUNE_ENABLED=true`.
The backup agent also runs once immediately when it is loaded.

### 6. Watch the first scheduled-path run

```bash
tail -n 40 -f ~/Library/Logs/restic-rest-client/daemon_backup.log
```

If you want to rerun the backup after that initial load-triggered run has
finished, use:

```bash
launchctl kickstart -k gui/$UID/com.restic-rest-client.backup
```

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

## What This Repo Contains

- [`run_backup.sh`](./run_backup.sh): backup, prune, log-cleanup, and
  notification-test entry point
- [`bootstrap.sh`](./bootstrap.sh): generates local files and installs
  launchd/newsyslog assets
- [`configure_env.sh`](./configure_env.sh): populates the required REST
  settings in `restic.env`
- [`init_repo.sh`](./init_repo.sh): initializes the configured repository and
  verifies access
- [`setup_password.sh`](./setup_password.sh): Keychain-backed REST server
  password storage plus repository-password setup and rotation
- [`restic.env.example`](./restic.env.example): tracked env template
- [`Docs/README.md`](./Docs/README.md): human-readable reference docs
- [`AGENTS.md`](./AGENTS.md) and [`agents/`](./agents/README.md): agent-facing
  repo rules, context, and workflows

## Common Tasks

Run fast verification:

```bash
make verify
```

Install the optional repo-managed Git hook:

```bash
make install-hooks
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

- `restic.env` is local state and must not be committed.
- `make bootstrap` writes local files only.
- `make configure` populates the required REST settings in `restic.env`.
- `make install` and `./bootstrap.sh --install` prompt for `sudo` to install
  the `newsyslog` config.
