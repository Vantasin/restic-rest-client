# 0002 Separate Human And Agent Docs

## Status

Accepted

## Context

The repo needs both human-friendly operational documentation and agent-facing
rules, workflows, and context. Combining them in one place would increase drift
and make GitHub browsing less clear.

## Decision

`Docs/` is the human-readable documentation tree. `agents/` is the agent-facing
tree for rules, workflows, and context. `AGENTS.md` stays thin and routes into
`agents/`.

## Consequences

- human docs remain focused on setup, behavior, and operations
- agent docs remain focused on how to work on the repo
- router files and README coverage must be kept current when new areas are
  added or renamed
