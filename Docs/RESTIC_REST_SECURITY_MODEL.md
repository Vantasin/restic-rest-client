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
   This is HTTP auth for the REST endpoint. In this repo the username lives in
   `restic.env` as `RESTIC_REST_USERNAME`, and the password is normally loaded
   from Keychain into `RESTIC_REST_PASSWORD` when `restic.env` is sourced.
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

## Why This Client Keeps REST Auth Separate From The URL

The companion server repo now prefers `RESTIC_REST_USERNAME` and
`RESTIC_REST_PASSWORD` over inline `user:password@` URLs.

That keeps the default examples cleaner:

- the repository URL in `restic.env` stays free of inline Basic Auth
  credentials
- the REST server password is stored in Keychain rather than pasted into a URL
- the repository password remains a separate Keychain-backed secret

Restic's REST backend consumes the server password through
`RESTIC_REST_PASSWORD`, so the password is present in the environment for the
duration of the restic process. The default model accepts that tradeoff to keep
credentials out of tracked templates and URL examples.

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

- do not commit `restic.env`
- keep it mode `600`
- rerun `setup_password.sh --rest-server` after a server password change
- rotate the restic repository password with
  `setup_password.sh --repository --rotate`
- rotate the REST server password on the server side with `create_user` again
