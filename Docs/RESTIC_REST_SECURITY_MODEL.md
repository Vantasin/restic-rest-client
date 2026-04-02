# Restic REST Security Model

This document explains the security boundary for a macOS restic client that
backs up to an external REST server deployed from the companion
`restic-rest-server` repo.

## Goals

- backups live on the backup server, not the live machine
- a compromised server must not reveal backup contents without the restic
  repository password
- client credentials should be scoped to one REST-server username path prefix
- the client repo should not assume server-side delete rights by default

## Secret Separation

There are two different secrets in this model:

1. Rest-server username/password
   This is HTTP auth for the REST endpoint. In this repo it lives in the local
   `restic-repository.txt` file.
2. Restic repository password
   This is the encryption password for the repository data itself. In this repo
   it is intended to live in macOS Keychain via `RESTIC_PASSWORD_COMMAND`.

The server can authenticate the client with the HTTP password, but it still
cannot decrypt repository contents without the restic repository password.

## Default Server Access Model

The companion server repo defaults to:

```text
--path /data/repos --append-only --private-repos
```

Security consequences:

- `--private-repos` limits a user such as `backup` to paths under `backup/...`
- `--append-only` allows backup and restore but blocks delete and prune through
  the API
- HTTPS is expected to be terminated by the reverse proxy layer documented in
  the server repo

## Why This Client Stores The URL In A Separate File

The REST repository URL usually embeds the rest-server password. Keeping it in
`restic-repository.txt` instead of `restic.env` gives the repo a cleaner
boundary:

- `restic.env` stays focused on client behavior and local automation
- `restic-repository.txt` is the one local file that contains the REST auth URL
- both files are ignored by Git and blocked by the repo-managed hook

## Why Prune Is Disabled By Default

This client repo defaults to `RESTIC_PRUNE_ENABLED=false` because the companion
server repo defaults to append-only mode.

That prevents the local automation from repeatedly attempting a prune job that
the server is expected to reject.

If the server is intentionally switched to client-managed maintenance mode
without `--append-only`, the client can enable prune explicitly and reinstall
its launchd assets.

## Compromise Scenarios

Compromised client with both secrets:

- can back up and restore through the REST API
- cannot decrypt existing data without the restic password
- cannot delete or prune in append-only mode
- can delete or prune if the server was intentionally switched to
  client-managed maintenance mode

Compromised server:

- can see encrypted repository blobs and metadata stored on disk
- cannot decrypt backup contents without the restic repository password
- can still deny service or delete data if the operator controls the host

## Operational Guardrails

- do not commit `restic.env` or `restic-repository.txt`
- keep both files mode `600`
- rotate the restic repository password with `setup_password.sh --rotate`
- rotate the REST server password on the server side with `create_user` again
- update `restic-repository.txt` after a REST server password change
