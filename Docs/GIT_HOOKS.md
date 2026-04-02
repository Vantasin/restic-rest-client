# Git Hooks

This repo uses an optional repo-managed `pre-commit` hook to catch fast,
mechanical consistency problems before a commit is created.

## Install

Enable the hook for the current clone:

```bash
make install-hooks
```

This runs:

```bash
git config core.hooksPath githooks
```

You can also configure it directly:

```bash
git config core.hooksPath githooks
```

## What the pre-commit hook checks

- blocks generated or local-only files from being committed:
  - `restic.env`
  - `restic.env.*` except `restic.env.example`
  - `restic-repository.txt`
  - `restic-repository.txt.*` except `restic-repository.txt.example`
  - `restic-include-macos.txt`
  - `restic-exclude-macos.txt`
  - local `launchd/*.plist` files that are not `.example` templates
  - `.DS_Store`
- runs `git diff --cached --check`
- runs repo-wide `zsh -n` checks on the managed shell scripts and hooks
- runs repo-wide `plutil -lint` on tracked `launchd/*.plist.example`
- ensures each visible repo directory has a `README.md`

## Relationship To `make verify`

Use:

- `pre-commit` for commit-path enforcement:
  staged-file blocking and staged diff checks, plus repo-wide structural checks
- `make verify` for fast repo-wide checks across the working tree

`make verify` is the better baseline when you want to validate the repo outside
the commit path or when hooks are not yet installed for a clone.

## What the hook does not replace

The hook is intentionally lightweight. It does not replace:

- repo review workflows in `agents/workflows/repo-review.md`
- agent review workflows in `agents/workflows/agent-review.md`
- manual or real restic validation when behavior changes

## Notes

- Hooks are local to each clone until installed.
- The hook mixes staged checks and repo-wide checks:
  blocked-file and diff checks are staged, while shell/plist/README checks are
  repo-wide.
- If you intentionally need to bypass it for an exceptional case, Git still
  supports `--no-verify`, but that should be rare.
