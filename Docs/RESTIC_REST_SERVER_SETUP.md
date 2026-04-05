# Restic REST Server Onboarding

This guide covers the client side of onboarding a macOS machine to a REST
server deployed from the companion `restic-rest-server` repo.

The server repo handles container deployment, reverse proxy integration, and
host storage layout. This client repo handles local macOS automation,
Keychain-backed REST credentials, Keychain-backed repository passwords,
launchd scheduling, and local log rotation.

## Assumed Server Defaults

The examples here assume the companion server repo's default access model:

```text
--path /data/repos --append-only --private-repos
```

That means:

- repository URLs must begin with the username
- the client can back up and restore
- the client cannot run `forget --prune` through the REST API

## 1. Deploy or verify the server

From the server side, the matching repo is `restic-rest-server`. Use that
repo's human docs for deployment and day-two operations:

<https://github.com/Vantasin/restic-rest-server.git>

- `README.md`
- `Docs/DEPLOYMENT.md`
- `Docs/CONFIGURATION.md`
- `Docs/OPERATIONS.md`

At minimum, verify:

- the server stack is up
- public HTTPS is working
- the reverse proxy forwards to `rest-server:8000`

## 2. Create the server user

On the server:

```bash
docker compose exec rest-server create_user backup
```

That creates or updates the HTTP auth credentials for user `backup`.

## 3. Hand off the client-specific details

For the default `--private-repos` model, the client repository path must start
with the username. The server admin should give the client:

- the base per-user HTTPS repository URL without inline credentials, for
  example `https://restic.example.com/user`
- the REST username, for example `user`
- the REST password that was set during `create_user`

Concrete example:

```text
RESTIC_REPOSITORY_BASE_URL=https://restic.example.com/user
RESTIC_REST_USERNAME=user
```

Do not use only the server root such as
`https://restic.example.com` unless the server admin explicitly says
that is already the per-user base path.

The client then chooses a repository name under that base URL. For example, if
the client chooses `laptop`, the corresponding restic repository URL will be:

```text
rest:https://restic.example.com/user/laptop
```

The restic repository password is separate and should be generated or supplied
on the client side.

## 4. Configure the client repo

From this repo:

```bash
make bootstrap
make configure
```

If you want the client to handle missing Homebrew-managed dependencies, clone
the repo into the default location, and then start the bootstrap/configure
flow for you, you can instead run:

```bash
curl -fsSL https://raw.githubusercontent.com/Vantasin/restic-rest-client/main/setup.sh | zsh
```

That setup helper can install missing required dependencies such as `git`,
`make`, `openssl`, and `restic`, and can optionally install `msmtp`.
If the default clone path already contains a checkout, it asks whether to
reuse it and cancels cleanly if you decline, so you can rerun with a different
`--clone-dir`.

The configure step prompts for:

- `RESTIC_REPOSITORY_BASE_URL` using the admin-provided HTTPS base URL
- `RESTIC_REST_USERNAME`

The script shows a separate concrete example for each prompt, shows the
existing value when one is already set, and explicitly says when pressing
Enter will keep that current value. That lets users rerun configure without
guessing whether the shown value is an example or saved state.

Using the concrete example above, `make configure` should receive:

```text
RESTIC_REPOSITORY_BASE_URL=https://restic.example.com/user
RESTIC_REST_USERNAME=user
```

If the generated repo name is `my-macbook`, the derived repository URL will
be:

```text
rest:https://restic.example.com/user/my-macbook
```

It keeps the generated local defaults for:

- `RESTIC_REPOSITORY_NAME`
- `RESTIC_HOST`

Pass `./configure_env.sh --repo-name NAME --host LABEL` if the client wants to
override those defaults during setup.

After `make configure`, review `restic.env` if you want to change optional
settings such as prune mode, notifications, or power guards.

## 5. Store the passwords

Store the admin-provided REST server password:

```bash
make setup-rest-server-password
```

Generate the repository password:

```bash
make setup-repository-password
```

Those commands are safe to rerun during an idempotent setup pass. They skip
cleanly if the matching Keychain entry already exists. Use
`make setup-rest-server-password-replace` after the server admin changes the
REST password, and `make setup-repository-password-rotate` only when you
intend to rotate the repository encryption password.

## 6. Initialize the repository

From the client:

```bash
make init-repo
```

This is the step where the client creates the repository for the first time.
It uses the restic encryption password currently configured by
`RESTIC_PASSWORD_COMMAND` or `RESTIC_PASSWORD`, then verifies access with
`restic snapshots`. If the repository already exists, it skips `restic init`
and only verifies access.

## 7. Install the automation and watch the first automation-path run

```bash
make install-and-watch
```

This validates `newsyslog` first and then updates the managed launchd agents.
If install fails after changing managed state, `bootstrap.sh` rolls the managed
launchd/newsyslog state back. The backup agent also runs once immediately when
it is loaded successfully. `make install-and-watch` then follows only log
output written during or after that install-triggered run until the run
reaches a terminal outcome, so it does not replay stale daemon-log lines from
older runs and it returns that run's exit status.

If you prefer not to block the terminal, use `make install` and later
`make watch-backup-log`.

## 8. Rerun the backup on demand later

If you want to rerun the backup after that initial load-triggered run has
finished, use:

```bash
launchctl kickstart -k gui/$UID/com.restic-rest-client.backup
```

## 9. Decide whether the client should prune

With the companion server repo's default append-only mode:

- leave `RESTIC_PRUNE_ENABLED="false"`
- do not expect client `forget --prune` to succeed

If the server is intentionally switched to client-managed maintenance mode:

```text
--path /data/repos --private-repos
```

Then set on the client:

```bash
export RESTIC_PRUNE_ENABLED="true"
```

And reinstall the launchd assets:

```bash
make install
```

That reloads the installed launchd agents and adds the prune launch agent so
the installed automation matches the new prune mode without overwriting your
local generated config. Use `make install-force` only when you intentionally
want to regenerate local files from templates and overwrite the installed
`newsyslog` config.
