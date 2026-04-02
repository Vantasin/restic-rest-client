# Docs Directory

This directory contains the human-readable documentation for the repository.
Use the root [`README.md`](../README.md) as the quick-start entry point, then
follow the docs here for configuration, operation, REST-server onboarding, and
deeper reference material.

## What Lives Here

- [`BOOTSTRAP.md`](./BOOTSTRAP.md): local file generation, install, uninstall,
  and manual setup flow
- [`RESTIC_ENV.md`](./RESTIC_ENV.md): `restic.env` and
  `restic-repository.txt` configuration
- [`RUN_BACKUP_SCRIPT.md`](./RUN_BACKUP_SCRIPT.md): backup, prune, log-cleanup,
  and notification-test behavior
- [`INCLUDE_EXCLUDE.md`](./INCLUDE_EXCLUDE.md): backup scope and include/exclude
  guidance
- [`RESTIC_REST_SERVER_SETUP.md`](./RESTIC_REST_SERVER_SETUP.md): onboarding
  this client against the companion REST-server deployment
- [`RESTIC_REST_SECURITY_MODEL.md`](./RESTIC_REST_SECURITY_MODEL.md): client and
  server security boundaries for the REST model
- [`RESTIC_RESTORE_README.md`](./RESTIC_RESTORE_README.md): restore workflows
  and safety guidance
- [`SETUP_PASSWORD.md`](./SETUP_PASSWORD.md): Keychain-backed repository
  password setup and rotation
- [`MAKEFILE.md`](./MAKEFILE.md): Makefile shortcuts and convenience targets
- [`GIT_HOOKS.md`](./GIT_HOOKS.md): repo-managed Git hook installation and
  checks
- [`decisions/README.md`](./decisions/README.md): lightweight decision log for
  durable repo choices

## Suggested Reading Order

1. [`../README.md`](../README.md)
2. [`BOOTSTRAP.md`](./BOOTSTRAP.md)
3. [`RESTIC_ENV.md`](./RESTIC_ENV.md)
4. [`RESTIC_REST_SERVER_SETUP.md`](./RESTIC_REST_SERVER_SETUP.md)
5. [`RUN_BACKUP_SCRIPT.md`](./RUN_BACKUP_SCRIPT.md)

Then branch into restore, security, password, or backup-scope topics as
needed.
