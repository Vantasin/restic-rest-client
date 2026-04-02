# 0001 Template-First Config

## Status

Accepted

## Context

The repo needs to be safe to publish and easy to clone while still producing
host-specific local files for a real macOS backup setup.

## Decision

Tracked `.example` files are the Git source of truth for configuration and
automation templates. Local operational files are generated from them by
`bootstrap.sh` or manual setup steps.

## Consequences

- secrets and host-specific values stay out of tracked files
- generated local files must not be treated as the canonical implementation
  target by accident
- changes to defaults or placeholders require updates to both templates and the
  human docs that describe them
