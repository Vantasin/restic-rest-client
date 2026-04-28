# Include/Exclude Rules

This repo uses two configuration files to define what gets backed up:

- `restic-include-macos.txt` (what to include)
- `restic-exclude-macos.txt` (what to exclude)

Both files are generated from `.example` templates by `bootstrap.sh`, which
replaces `{{HOME}}` with your actual home directory.

## How Restic applies them

- `restic-include-macos.txt` is passed to `restic backup --files-from`.
- `restic-exclude-macos.txt` is passed to `restic backup --exclude-file`.

The include file defines the **top-level roots** to back up. The exclude file
trims out caches, logs, and other rebuildable or noisy paths.

## Edit guidelines

Best practices:

- Keep includes broad (e.g., your home directory), then exclude noise.
- Avoid excluding critical data unless you are certain it is redundant.
- If you change includes/excludes, expect the next snapshot to show large diffs.

Common adjustments:

- Exclude `Downloads` if you treat it as scratch.
- Exclude `node_modules`, `dist`, or build output if you can easily rebuild.
- Exclude other backup folders to avoid “backing up backups.”
- The default macOS exclude template skips
  `~/Library/Application Support/MobileSync` because Finder iPhone/iPad backups
  are often large, noisy, and redundant with the devices or another backup
  layer. Remove that exclusion only if this Mac holds the only copy and you
  want restic to preserve it too.
- The default macOS exclude template also skips some known
  TCC-protected `~/Library` paths, including
  `~/Library/Containers/com.apple.archiveutility`, to avoid repeated
  `operation not permitted` warnings from data macOS commonly blocks in
  unattended backups.
- Exclude `~/Library/Mobile Documents` only if you intentionally treat iCloud
  data as cloud-managed and redundant elsewhere.

## Safe workflow for changes

1) Edit the include/exclude files.
2) Run a manual backup and review the output.
3) Verify the latest snapshot with `restic snapshots`.

## Notes

- These files are **not** tracked in git; only the `.example` templates are.
- Always review the templates after updates before you generate new files.
- `operation not permitted` errors on `~/Library` usually mean macOS blocked the
  backup process and Full Disk Access is missing.
- `resource deadlock avoided` errors under `~/Library/Mobile Documents` often
  mean restic hit iCloud or File Provider placeholders instead of local files.
