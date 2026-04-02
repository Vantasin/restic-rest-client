# Agent Context Directory

This directory contains agent-facing context for the major parts of the
repository. These files explain boundaries, responsibilities, common drift
risks, and where the canonical human docs live.

## Files

- [`repo-map.md`](./repo-map.md): high-level repository map and component layout
- [`source-of-truth-matrix.md`](./source-of-truth-matrix.md): area-by-area map
  of implementation, docs, agent guidance, and verification
- [`run-backup.md`](./run-backup.md): `run_backup.sh` responsibilities and
  change impact
- [`config-and-templates.md`](./config-and-templates.md): env/templates/generate
  flow context
- [`launchd-and-logging.md`](./launchd-and-logging.md): scheduling, log files,
  and installed-vs-tracked distinctions
- [`newsyslog-and-log-files.md`](./newsyslog-and-log-files.md): daemon log
  rotation model and log ownership boundaries
- [`bootstrap-and-setup.md`](./bootstrap-and-setup.md): bootstrap, password
  setup, and Makefile relationship
- [`rest-server-integration.md`](./rest-server-integration.md): external
  REST-server assumptions and client/server boundary context

## How To Use It

Read the relevant context file before changing that part of the repo, then use
the linked human docs in `Docs/` for the detailed operator-facing behavior.
