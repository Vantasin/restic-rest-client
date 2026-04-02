# Restic Environment Configuration

`restic.env` is the main local config file for this client. It is generated
from `restic.env.example` and should never be committed.

This repo also generates `restic-repository.txt` from
`restic-repository.txt.example`. That file holds the REST repository URL so the
REST server password does not need to live in `restic.env`.

## Setup

```bash
cp restic.env.example restic.env
cp restic-repository.txt.example restic-repository.txt
chmod 600 restic.env restic-repository.txt
```

Only set one restic password method and one repository-location method.

## Host label

`RESTIC_HOST` is the machine label shown in `restic snapshots`.

```bash
export RESTIC_HOST="my-macbook"
```

Changing the host label does not corrupt the repo, but prune policies apply per
host, so old labels will no longer be pruned automatically.

## Repository password options

Preferred: Keychain-backed password retrieval.

```bash
security add-generic-password -a restic-rest-client-macbook -s restic-rest-client-macbook -w "YOUR_LONG_PASSWORD" -U
export RESTIC_PASSWORD_COMMAND='security find-generic-password -a restic-rest-client-macbook -s restic-rest-client-macbook -w'
```

The repo root also provides:

```bash
./setup_password.sh
./setup_password.sh --rotate
```

Fallback, if you intentionally keep the password in local env state:

```bash
export RESTIC_PASSWORD="YOUR_LONG_RANDOM_PASSWORD"
```

## Repository location options

Recommended default: `RESTIC_REPOSITORY_FILE`

Keep the REST URL in `restic-repository.txt`:

```bash
export RESTIC_REPOSITORY_FILE="{{SCRIPT_DIR}}/restic-repository.txt"
```

The file should contain only the repository URL, for example:

```text
rest:https://backup:<SERVER_PASSWORD>@backup.example.com/backup/my-macbook
```

This matches the companion `restic-rest-server` repo's default
`--private-repos` layout, where user `backup` is limited to paths under
`backup/...`.

Optional inline alternative:

```bash
export RESTIC_REPOSITORY="rest:https://backup:<SERVER_PASSWORD>@backup.example.com/backup/my-macbook"
```

Do not set both `RESTIC_REPOSITORY` and `RESTIC_REPOSITORY_FILE`.

If the REST server password contains URL-reserved characters, URL-encode the
password before storing it in the URL.

## Prune mode

The companion `restic-rest-server` repo defaults to append-only mode, so this
client repo defaults to disabled client-side prune:

```bash
export RESTIC_PRUNE_ENABLED="false"
```

Leave that default in place when the server runs:

```text
--path /data/repos --append-only --private-repos
```

Only set prune enabled when the server has intentionally been switched to
client-managed maintenance mode without `--append-only`:

```bash
export RESTIC_PRUNE_ENABLED="true"
```

After changing it, rerun:

```bash
./bootstrap.sh --install --force
```

That installs or removes the prune launch agent to match the new mode.

## Email notifications

If `RESTIC_NOTIFY_EMAIL` is set, `run_backup.sh` can send failure and success
notifications as multipart text+HTML emails with the per-run log attached:

```bash
export RESTIC_NOTIFY_EMAIL="you@example.com"
export RESTIC_NOTIFY_SUBJECT_PREFIX="[restic]"
export RESTIC_NOTIFY_ON_FAILURE="true"
export RESTIC_NOTIFY_ON_SUCCESS="false"
```

If your `msmtp` binary is not in the default path:

```bash
export MSMTP_BIN="/opt/homebrew/bin/msmtp"
```

Test commands:

```bash
./run_backup.sh test-email
./run_backup.sh test-success-email
./run_backup.sh test-failure-email
./run_backup.sh test-warning-email
./run_backup.sh test-lock-failure-email
```

Those exercise the notification path without contacting the repository.

## Lock retry

Wait for an active restic lock instead of failing immediately:

```bash
export RESTIC_RETRY_LOCK="10m"
```

## Log retention

Per-run logs older than this many days are deleted by `run_backup.sh
logcleanup`:

```bash
export RESTIC_LOG_RETENTION_DAYS="14"
```

## Laptop power guards

On MacBooks, battery or sleep transitions can interrupt backups and leave stale
restic locks. You can tell `run_backup.sh` to skip backup or prune runs in
those states:

```bash
export RESTIC_BACKUP_REQUIRE_AC_POWER="true"
export RESTIC_BACKUP_SKIP_WHEN_CLAMSHELL_CLOSED="false"
export RESTIC_PRUNE_REQUIRE_AC_POWER="true"
export RESTIC_PRUNE_SKIP_WHEN_CLAMSHELL_CLOSED="false"
```

Backup guards apply only to `backup`. Prune guards apply only to `prune`.
Clamshell guards default to `false` because closed-lid use on AC power can be
normal for docked MacBooks.

## Prune policy overrides

`run_backup.sh` uses these defaults when prune is enabled:

```bash
export RESTIC_KEEP_DAILY="7"
export RESTIC_KEEP_WEEKLY="4"
export RESTIC_KEEP_MONTHLY="6"
```

## Safety notes

- Never commit a populated `restic.env`.
- Never commit a populated `restic-repository.txt`.
- Keep both files at mode `600`.
- The REST server password and the restic repository password are separate.
