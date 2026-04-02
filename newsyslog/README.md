# Newsyslog Directory

This directory contains the tracked `newsyslog` template used to rotate the
fixed daemon logs written by the repo's `launchd` jobs.

## Purpose

`run_backup.sh` writes per-run task logs and fixed daemon logs under
`~/Library/Logs/restic-rest-client`. The daemon logs are rotated by the `newsyslog`
configuration installed from this directory.

## Files

- [`com.restic-rest-client.conf.example`](./com.restic-rest-client.conf.example): template for the
  `newsyslog` configuration that is installed to `/etc/newsyslog.d/`

## Related Docs

- [`../Docs/BOOTSTRAP.md`](../Docs/BOOTSTRAP.md)
- [`../Docs/RUN_BACKUP_SCRIPT.md`](../Docs/RUN_BACKUP_SCRIPT.md)

## Notes

- The tracked `.example` file is the git source of truth.
- Installing or replacing the live config requires the bootstrap flow or a
  manual `sudo` copy into `/etc/newsyslog.d/`.
