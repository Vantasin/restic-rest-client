# New Area Workflow

Use this workflow when adding a new major repo area or component, such as a new
deployment mode, server-side subsystem, or documentation domain.

Examples:

- another client mode or backend-specific workflow
- a second automation surface beyond the current macOS client flow
- a monitoring or reporting layer that materially changes repo scope

## Goals

- Add the new area without breaking the current source-of-truth structure.
- Keep human docs, agent docs, verification, and review coverage aligned from
  the start.
- Avoid leaving the new area as an undocumented one-off.

## Workflow

1. Define the boundary.
   Decide whether the new area belongs in the current macOS client scope or
   should be modeled as a separate component area.
2. Add or update human docs in `Docs/`.
   Create the canonical operator-facing documentation first.
3. Add directory README coverage.
   If the new area introduces a visible directory, add a `README.md` there.
4. Add agent context.
   Create or extend an area-level file in `agents/context/`.
5. Add agent rules only if needed.
   Add a new rules file only when the area has real non-negotiable invariants
   or migration hazards.
6. Update the routers.
   Update `AGENTS.md`, the relevant `agents/*/README.md`, and `Docs/README.md`
   if the new area changes the available documentation map.
7. Update verification if needed.
   If the new area introduces structural checks that should always run, extend
   `verify_repo.sh`, `Makefile`, and `githooks/pre-commit` where appropriate.
8. Add a decision entry when needed.
   If the new area establishes a durable architectural or operational choice,
   record it in `Docs/decisions/`.
9. Run the correct review.
   Use `agent-review.md` for agent-layer changes and `repo-review.md` for
   repository-function changes.
10. Log review-driven follow-up changes.
   If the review causes additional edits, log them with
   `change-logging.md`.

## Decision points

- Add a new area-level context file before adding per-file notes.
- Add a new area-level rule only when existing repo-wide rules are not enough.
- Prefer extending the source-of-truth matrix when the new area crosses several
  files or docs.
