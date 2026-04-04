# Launchd Directory

This directory contains the tracked `launchd` templates for the local macOS
automation jobs.

## Purpose

These plist templates define how the repo schedules and runs:

- backups
- prune jobs when enabled
- log cleanup

The tracked `.example` files are the source of truth in git. Local generated
files are produced from them by [`bootstrap.sh`](../bootstrap.sh) and can then
be installed into `~/Library/LaunchAgents/`.

## Files

- [`com.restic-rest-client.backup.plist.example`](./com.restic-rest-client.backup.plist.example):
  backup schedule and command
- [`com.restic-rest-client.prune.plist.example`](./com.restic-rest-client.prune.plist.example):
  prune schedule and command
- [`com.restic-rest-client.logcleanup.plist.example`](./com.restic-rest-client.logcleanup.plist.example):
  local log-retention job

## Related Docs

- [`../Docs/BOOTSTRAP.md`](../Docs/BOOTSTRAP.md)
- [`../Docs/RUN_BACKUP_SCRIPT.md`](../Docs/RUN_BACKUP_SCRIPT.md)

## Notes

- Changes here affect generated local plists, not installed launch agents,
  until you regenerate and reload them locally.
- Backup and logcleanup are always installed. The prune plist is installed only
  when `RESTIC_PRUNE_ENABLED=true`.
- The backup plist uses `RunAtLoad`, so loading the installed agent starts one
  immediate backup run before the regular interval schedule takes over.
- Schedule changes are operationally significant and should be reflected in the
  human docs.
