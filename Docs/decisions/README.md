# Decision Log

This directory is the lightweight decision log for the repository.

Use it to record durable architectural or operational choices that are likely to
matter later, especially when the reasoning is easy to forget after the code
has changed.

## When To Add A Decision

Add a decision entry when a change:

- sets a long-term repo direction
- defines a source-of-truth boundary
- introduces an intentional tradeoff
- changes how multiple components are expected to fit together
- is likely to be questioned again in future reviews

## Suggested Format

Use numbered files such as:

```text
0001-short-title.md
0002-another-decision.md
```

Each entry should cover:

- status
- context
- decision
- consequences

## Current Entries

- [`0001-template-first-config.md`](./0001-template-first-config.md)
- [`0002-separate-human-and-agent-docs.md`](./0002-separate-human-and-agent-docs.md)
- [`0003-rest-server-client-defaults.md`](./0003-rest-server-client-defaults.md)
- [`0004-rest-auth-via-restic-env.md`](./0004-rest-auth-via-restic-env.md)
- [`0005-base-url-and-init-target.md`](./0005-base-url-and-init-target.md)
- [`0006-drop-repository-file-path.md`](./0006-drop-repository-file-path.md)
