# Restic REST Server Onboarding

This guide covers the client side of onboarding a macOS machine to a REST
server deployed from the companion `restic-rest-server` repo.

The server repo handles container deployment, reverse proxy integration, and
host storage layout. This client repo handles local macOS automation,
Keychain-backed repository passwords, launchd scheduling, and local log
rotation.

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

## 3. Build the repository URL

For the default `--private-repos` model, the client repository path must start
with the username:

```text
rest:https://backup:<SERVER_PASSWORD>@backup.example.com/backup/my-macbook
```

Store that URL in the client's local `restic-repository.txt`.

The repository URL contains the rest-server HTTP password. The restic
repository password is separate and should be stored through
`setup_password.sh`.

## 4. Configure the client repo

From this repo:

```bash
./bootstrap.sh --install
./setup_password.sh
```

Then edit:

- `restic.env`
- `restic-repository.txt`

At minimum:

- set `RESTIC_HOST`
- set the repository URL in `restic-repository.txt`

## 5. Initialize the repository

From the client:

```bash
source restic.env
restic init
restic snapshots
```

The first `init` chooses the restic encryption password currently configured by
`RESTIC_PASSWORD_COMMAND` or `RESTIC_PASSWORD`.

## 6. Test the automation path

```bash
launchctl kickstart -k gui/$UID/com.restic-rest-client.backup
tail -n 40 -f ~/Library/Logs/restic-rest-client/daemon_backup.log
```

## 7. Decide whether the client should prune

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
./bootstrap.sh --install --force
```
