# 0003 Rest Server Client Defaults

## Status

Superseded by 0004

## Context

This repo is a macOS client for a separate `restic/rest-server` deployment. In
the REST model, the server password usually appears inside the repository URL,
and the companion server repo defaults to `--append-only --private-repos`.

## Decision

- keep the repository URL in a separate generated local file,
  `restic-repository.txt`, and point `RESTIC_REPOSITORY_FILE` at it by default
- keep client-side prune disabled by default with `RESTIC_PRUNE_ENABLED=false`
- install the prune launch agent only when the client is explicitly configured
  for a non-append-only server

## Consequences

- the REST server password does not need to live in `restic.env`
- the repo-managed hook must block `restic-repository.txt`
- bootstrap and docs must treat prune as mode-dependent rather than always-on
- operators must intentionally opt in before allowing client-side prune
