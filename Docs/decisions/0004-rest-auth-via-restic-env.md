# 0004 REST Auth Via restic.env

## Status

Superseded by 0006

## Context

The companion `restic-rest-server` repo now prefers examples that keep REST
server credentials out of repository URLs. The client onboarding flow is also
explicitly split into:

- server admin provides the client-specific repository URL, username, and HTTP
  password
- client generates or rotates the restic repository password locally
- local gitignored files should be generated from tracked templates before the
  user edits them

The previous client default centered on `restic-repository.txt`, which no
longer matches that handoff model well.

## Decision

- make `restic.env` the default home for `RESTIC_REPOSITORY`,
  `RESTIC_REST_USERNAME`, `RESTIC_REST_PASSWORD`, and
  `RESTIC_PASSWORD_COMMAND`
- keep `RESTIC_REPOSITORY_FILE` and `restic-repository.txt` as an optional
  legacy compatibility path rather than the default
- split bootstrap generation from install so the local files can be created and
  edited before launchd or `newsyslog` are installed
- expand `setup_password.sh` so it manages both REST server password storage
  and repository password generation/rotation

## Consequences

- new client onboarding starts with `make bootstrap`, then `restic.env` edits,
  password setup, and finally `make install`
- default URL examples stay free of inline Basic Auth credentials
- bootstrap and install logic must avoid sourcing `restic.env` just to inspect
  simple settings such as prune mode
- the docs and agent context need to describe the env-first model consistently
