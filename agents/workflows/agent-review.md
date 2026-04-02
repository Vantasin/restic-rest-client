# Agent Review Workflow

Run this review after core changes to the repo's agent layer:

- `AGENTS.md`
- `agents/rules/`
- `agents/workflows/`
- `agents/context/`
- agent guidance structure or routing

## Goals

- Keep agent guidance internally consistent.
- Keep `AGENTS.md` thin and aligned with the `agents/` structure.
- Avoid drift between agent rules, workflows, and component context.
- Preserve the boundary between human docs in `Docs/` and agent docs in
  `agents/`.

## Review sequence

1. Read `agents/rules/core.md`, `agents/rules/documentation.md`, and
   `agents/context/repo-map.md`.
2. Check that `AGENTS.md` points to the current agent files and no stale paths
   remain.
3. Check that `agents/rules/`, `agents/workflows/`, and `agents/context/`
   describe distinct responsibilities without duplication.
4. Confirm agent docs still point back to the canonical human docs where
   required.
5. Run the relevant checks from `agents/rules/verification.md`.

## What to look for

- stale paths or renamed files not reflected in `AGENTS.md`
- conflicting guidance between rules, workflows, and context
- agent docs duplicating human operational docs instead of linking to them
- missing review, documentation, or verification requirements after structure
  changes
- future-architecture guidance drifting away from the current repo layout

## Output expectations

- Lead with findings, ordered by severity.
- Call out drift, ambiguity, duplication, or missing routing explicitly.
- If the review causes edits, log the follow-up changes with
  `agents/workflows/change-logging.md` and note that they were review-driven.
