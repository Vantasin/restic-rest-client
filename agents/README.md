# Agents Directory

This directory contains the agent-facing working material for the repository.
Unlike [`Docs/`](../Docs/README.md), which is written for humans operating or
understanding the repo, `agents/` is written to keep agent behavior consistent.

## Structure

- [`rules/`](./rules/README.md): non-negotiable repo rules, verification
  expectations, and documentation/update requirements
- [`workflows/`](./workflows/README.md): repeatable execution patterns for
  review, change logging, and documentation updates
- [`context/`](./context/README.md): component-level context, repo boundaries,
  and pointers to the canonical human docs

## Suggested Read Order

1. [`rules/core.md`](./rules/core.md)
2. [`context/repo-map.md`](./context/repo-map.md)
3. The relevant file in [`context/`](./context/README.md)
4. The relevant file in [`workflows/`](./workflows/README.md)

## Boundary

Do not move human-readable component documentation into `agents/`. Keep the
canonical operational and reference material in [`Docs/`](../Docs/README.md)
and use this directory to explain how agents should work with that material.
