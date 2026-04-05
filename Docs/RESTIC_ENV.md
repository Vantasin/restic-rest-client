# Restic Environment Configuration

`restic.env` is the main local config file for this client. It is generated
from `restic.env.example`, should never be committed, and is now the default
home for:

- the repository URL
- the REST server username
- the Keychain-backed REST server password lookup
- the Keychain-backed repository password lookup

## Setup

```bash
make bootstrap
make configure
```

That generates `restic.env` plus the other local config files, applies
`chmod 600` to `restic.env`, then prompts for the required REST base URL and
username.

After that, edit `restic.env` only for optional settings or manual overrides.
The tracked example still carries the common default runtime settings used by
this repo.

Only set one repository-password method.

## Host Label

`RESTIC_HOST` is the machine label shown in `restic snapshots`.

```bash
export RESTIC_HOST="my-macbook"
```

Changing the host label does not corrupt the repo, but prune policies apply per
host, so old labels will no longer be pruned automatically.

## REST Server Access

Recommended default:

```bash
export RESTIC_REPOSITORY_BASE_URL="https://restic.example.com/user"
export RESTIC_REPOSITORY_NAME="my-macbook"
export RESTIC_REPOSITORY="rest:${RESTIC_REPOSITORY_BASE_URL%/}/${RESTIC_REPOSITORY_NAME}"
export RESTIC_REST_USERNAME="user"
export RESTIC_REST_PASSWORD="$(security find-generic-password -a restic-rest-client-rest-server -s restic-rest-client-rest-server -w)"
```

Notes:

- the server admin should provide the base per-user HTTPS repository URL plus
  the REST username/password
- example: if the server user is `user`, use
  `RESTIC_REPOSITORY_BASE_URL="https://restic.example.com/user"` rather than
  only `https://restic.example.com`
- `make configure` prompts for `RESTIC_REPOSITORY_BASE_URL` and
  `RESTIC_REST_USERNAME`, shows a separate example for each variable, shows
  the current saved value when one exists, and explicitly says when pressing
  Enter will keep that value. It then keeps or writes local defaults for
  `RESTIC_REPOSITORY_NAME` and `RESTIC_HOST`, and ends by printing the
  recommended `cd`, password setup, `make init-repo`, and
  `make install-and-watch` commands
- `RESTIC_REPOSITORY_NAME` is the client-side repo path segment created under
  that base URL
- `RESTIC_REPOSITORY` should include the `rest:` backend prefix and is derived
  from the base URL plus repository name by default
- `RESTIC_REPOSITORY_NAME` defaults to a URL-safe slug derived from the local
  machine name when bootstrap generates `restic.env`
- restic's REST backend consumes `RESTIC_REST_USERNAME` and
  `RESTIC_REST_PASSWORD`, so the default template loads the server password
  from Keychain when `restic.env` is sourced
- rerunning `./setup_password.sh --rest-server` or
  `make setup-rest-server-password` is safe; if the Keychain entry already
  exists, the command leaves the stored secret unchanged and only repairs the
  `RESTIC_REST_PASSWORD` line in `restic.env` if needed
- after the server admin changes the password with `create_user` again, rerun
  `./setup_password.sh --rest-server --replace` or
  `make setup-rest-server-password-replace`

Manual fallback, if you intentionally keep the server password in local env
state:

```bash
export RESTIC_REST_PASSWORD="SERVER_PASSWORD"
```

## Repository Password

Preferred: Keychain-backed password retrieval.

Use the provided script:

```bash
./setup_password.sh --repository
./setup_password.sh --repository --rotate
```

Makefile alternatives:

```bash
make setup-repository-password
make setup-repository-password-rotate
```

Those commands manage a Keychain entry and write:

```bash
export RESTIC_PASSWORD_COMMAND="security find-generic-password -a restic-rest-client-repository -s restic-rest-client-repository -w"
```

Running `./setup_password.sh --repository` or
`make setup-repository-password` again is safe: if the Keychain entry already
exists, the command leaves the stored secret unchanged and only repairs the
`RESTIC_PASSWORD_COMMAND` line in `restic.env` if needed.

After the server password is stored and the repository password is generated,
run:

```bash
make init-repo
```

That is the client-side repository creation and verification step.

Fallback, if you intentionally keep the repository password in local env state:

```bash
export RESTIC_PASSWORD="YOUR_LONG_RANDOM_PASSWORD"
```

## Prune Mode

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
make install
```

That reloads the installed launchd agents and installs or removes the prune
launch agent to match the new mode without overwriting your local generated
config. Use `make install-force` only when you intentionally want to
regenerate local files from templates and overwrite the installed
`newsyslog` config.

## Email Notifications

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

## Lock Retry

Wait for an active restic lock instead of failing immediately:

```bash
export RESTIC_RETRY_LOCK="10m"
```

## Log Retention

Per-run logs older than this many days are deleted by `run_backup.sh
logcleanup`:

```bash
export RESTIC_LOG_RETENTION_DAYS="14"
```

## Laptop Power Guards

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

## Prune Policy Overrides

`run_backup.sh` uses these defaults when prune is enabled:

```bash
export RESTIC_KEEP_DAILY="7"
export RESTIC_KEEP_WEEKLY="4"
export RESTIC_KEEP_MONTHLY="6"
```

## Safety Notes

- Never commit a populated `restic.env`.
- Keep `restic.env` at mode `600`.
- The REST server password and the restic repository password are separate.
- If the Keychain entries do not exist yet, `source restic.env` will fail until
  you run the matching password setup command.
