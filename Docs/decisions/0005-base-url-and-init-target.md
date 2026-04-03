# 0005 Base URL And Init Target

## Status

Accepted

## Context

The companion `restic-rest-server` repo now documents the server-side handoff
as a base per-user repository URL pattern, the REST username, and the REST
password. The client, not the server admin, creates the actual repository.

The previous client flow expected a fully assembled repository URL in
`RESTIC_REPOSITORY` and documented manual `restic init` commands.

## Decision

- make the default tracked env template store `RESTIC_REPOSITORY_BASE_URL` and
  `RESTIC_REPOSITORY_NAME`, then derive `RESTIC_REPOSITORY`
- add a first-class `init_repo.sh` script and `make init-repo` target for
  client-side repository creation and verification

## Consequences

- the server admin hands off the per-user base URL, username, and password
- the client chooses the repository name beneath that base URL
- repo initialization becomes an explicit scripted workflow instead of a manual
  `restic init` step buried in docs
