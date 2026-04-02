# Agent Rules Directory

This directory contains the repo's agent-facing rules and guardrails.

## Files

- [`core.md`](./core.md): repo-wide boundaries, safety expectations, and scope
  split between `Docs/` and `agents/`
- [`verification.md`](./verification.md): validation expectations for code,
  templates, and operational changes
- [`documentation.md`](./documentation.md): rules for when and where to update
  human docs versus agent docs
- [`template-integrity.md`](./template-integrity.md): source-of-truth rules for
  tracked templates versus generated local files
- [`scheduling-and-log-rotation.md`](./scheduling-and-log-rotation.md): rules
  for launchd timing, power guards, daemon logs, and newsyslog boundaries
- [`client-server-boundaries.md`](./client-server-boundaries.md): rules for the
  macOS client versus external REST-server deployment boundary
- [`deprecation-and-migration.md`](./deprecation-and-migration.md): rules for
  renames, removals, compatibility breaks, and router/doc cleanup

## Purpose

Use these files to keep agent work consistent across reviews, code changes,
documentation updates, and future repo expansion.
