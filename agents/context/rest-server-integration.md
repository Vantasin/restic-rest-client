# REST Server Integration Context

This repo assumes an external REST server rather than embedding server
deployment logic locally.

## Current assumptions

- the companion server repo is responsible for Docker Compose deployment and
  day-two server operations
- the default access model is `--append-only --private-repos`
- the repository URL usually embeds the REST server password, so this repo
  keeps it in `restic-repository.txt`
- client-side prune is disabled by default and must be explicitly enabled when
  the server allows it

## Guardrails

- keep server deployment implementation out of this repo
- keep client onboarding docs high-level and aligned to the companion server
  repo's defaults
- when a change alters the client/server access model, update both human docs
  and agent context together

## Documentation owners

- onboarding and URL patterns: `Docs/RESTIC_REST_SERVER_SETUP.md`
- client/server security model: `Docs/RESTIC_REST_SECURITY_MODEL.md`
- local env and prune defaults: `Docs/RESTIC_ENV.md`
