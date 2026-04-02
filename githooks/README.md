# Git Hooks Directory

This directory contains the repo-managed Git hooks used to catch fast,
mechanical consistency issues before a commit is created.

## Purpose

The hooks here are intentionally lightweight. They complement the review
workflows in `agents/` by catching cheap problems early without trying to
replace human or agent review.

## Files

- [`pre-commit`](./pre-commit): blocks generated/local files from being
  committed, checks staged diff safety, and runs repo-wide structural
  validation

## Install

Enable the repo-managed hooks for this clone with:

```bash
make install-hooks
```

This sets:

```bash
git config core.hooksPath githooks
```

## Relationship To `make verify`

The hook is commit-path enforcement. It combines staged-file checks with
repo-wide shell, plist, and README validation. For a manual repo-wide
consistency pass, use:

```bash
make verify
```

## Related Docs

- [`../Docs/GIT_HOOKS.md`](../Docs/GIT_HOOKS.md)
- [`../Docs/MAKEFILE.md`](../Docs/MAKEFILE.md)
