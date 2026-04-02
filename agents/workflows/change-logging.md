# Change Logging Workflow

Use this workflow when summarizing work, writing commit context, or recording
operational changes.

## Record

- What changed
- Why it changed
- What user-visible or operator-visible behavior changed
- What verification was run
- What was not verified
- Whether the change came from the main implementation pass or from a later
  review follow-up

## Include when relevant

- Snapshot IDs
- Restic exit codes
- Launchd labels
- Log file paths
- Whether a change affected local generated files only, tracked templates only,
  or both
- Which review workflow triggered the follow-up change (`agent-review` or
  `repo-review`)

## Do not include

- Secrets
- Raw credentials
- Unnecessary path dumps from logs when a shorter explanation is enough

## Special cases

- If a change only affects tracked templates and not installed local launchd
  agents, say that explicitly.
- If a local operational step was performed outside the repo, record it
  separately from committed file changes.
- If review findings cause additional edits, log the findings-driven changes as
  a distinct follow-up rather than folding them into the original summary.
