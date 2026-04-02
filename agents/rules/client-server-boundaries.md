# Client And Server Boundaries Rules

This repo is for macOS client automation that talks to an external REST server.

## Non-Negotiables

- do not add Docker Compose deployment or reverse-proxy implementation here
- keep `Docs/` human-only and `agents/` agent-only
- keep local secret files ignored and blocked by the repo-managed hook
- keep prune behavior aligned with the documented server access mode

## Allowed Growth

- client onboarding guidance for the companion REST-server repo
- restore, verification, and notification improvements on the macOS client
- compatibility guidance around append-only versus client-managed maintenance

## Guardrails

- if a change depends on the server's default flags, update the README and the
  REST-server onboarding/security docs in the same work
- if you need server deployment changes, document the integration point here
  instead of vendoring the full server stack
