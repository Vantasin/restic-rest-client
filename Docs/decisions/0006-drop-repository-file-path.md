# 0006 Drop Repository File Path

## Status

Accepted

## Context

The public client repo never shipped a live onboarding flow that depended on
`RESTIC_REPOSITORY_FILE` or `restic-repository.txt`. The default and documented
client contract had already converged on:

- repository URL in `restic.env`
- REST auth in `RESTIC_REST_USERNAME` and `RESTIC_REST_PASSWORD`
- repository password via `RESTIC_PASSWORD_COMMAND`

Keeping the repository-file path as an undocumented compatibility branch adds
runtime branching, docs surface area, and agent-context drift without serving a
real public migration need.

## Decision

- remove `RESTIC_REPOSITORY_FILE` support from the runtime scripts
- delete `restic-repository.txt.example`
- describe `RESTIC_REPOSITORY` in `restic.env` as the only supported repository
  location contract

## Consequences

- repository resolution becomes simpler and env-only
- setup, restore, security, and hook docs no longer need to explain a second
  repository-location path
- older historical decision entries still document the previous approach, but
  the current accepted contract is env-only
