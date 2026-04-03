# Core Rules

## Scope split

- `Docs/` is for human-readable component documentation.
- `agents/` is for agent-only rules, workflows, and working context.
- `AGENTS.md` must stay thin and route agents into `agents/`.

## Repository safety

- Never commit `restic.env` or other populated secrets.
- Treat generated host-specific files as local state unless the tracked
  `.example` template is the intentional change target.
- Do not silently change backup scope, retention, launchd timing, or power
  guards without updating the relevant docs.
- Do not silently change the client/server access model defaults without
  updating the REST-server onboarding and security docs.

## Change hygiene

- Prefer updating the canonical human docs in `Docs/` when behavior,
  configuration, setup, or operational expectations change.
- Update `agents/` only when agent workflows, component context, or repo rules
  need to change.
- Avoid duplicating long operational explanations in `agents/`; link to `Docs/`
  instead.
- After core agent-layer changes, run the agent review workflow.
- After core repository-function changes, run the repo review workflow.
- If a review produces follow-up changes, record those changes with the change
  logging workflow.

## Repo boundary

- This repo is for macOS client automation that talks to an external REST
  server.
- Do not fold Docker Compose deployment, reverse proxy stack details, or host
  storage provisioning into the client implementation layer.
- When a change depends on the server's access mode, keep `README.md`,
  `Docs/RESTIC_ENV.md`, `Docs/RESTIC_REST_SERVER_SETUP.md`, and
  `agents/context/rest-server-integration.md` aligned.
