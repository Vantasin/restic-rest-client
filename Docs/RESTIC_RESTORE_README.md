# 🧰 Restic Restore Guide

This document explains **how to safely restore data from a restic repository**, including:

- Full repository restores
- Restoring specific directories (e.g. Desktop)
- Restoring earlier snapshots
- Restoring individual files
- Best practices and common pitfalls

> **Golden rule:**  
> **Always restore into a temporary directory first.**  
> Never restore directly over live data.

---

## 📋 Prerequisites & Environment Setup

This repository uses a **`restic.env` file** to define all required restic environment variables (repository location, password command, etc.).

### Load the restic environment

From the root of this repo:

```bash
source restic.env
```

This exports variables such as:

- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD` or `RESTIC_PASSWORD_COMMAND`
- Any backend-specific credentials

### Verify access

```bash
restic snapshots
```

If this works without prompting for a password, your environment is correctly loaded.

> 💡 Tip:  
> You must re-run `source restic.env` in **every new shell** before using restic.

---

## 🧠 Mental Model (Important)

- Snapshots are **immutable**
- Restic restores files **exactly as they existed**
- Restic **always preserves original paths**
- Restores never modify the repository
- Path flattening is done **after restore** (using `rsync`)

---

## 🗂️ Snapshot Overview

List available snapshots:

```bash
restic snapshots
```

You can restore:
- `latest`
- A snapshot ID (e.g. `dcb734f1`)
- A snapshot selected by time

---

## 🗃️ Browse Snapshots with `restic mount` (Quick Look)

`restic mount` exposes the repository as a **read-only** filesystem so you can
browse in Finder with Quick Look and thumbnails.

> ⚠️ Requires macFUSE (or another FUSE driver) on macOS.  
> Avoid running this while a backup/prune job is active to prevent lock contention.

```bash
source restic.env
mkdir -p ~/ResticMount
restic mount ~/ResticMount
```

Open `~/ResticMount` in Finder. When finished, unmount:

```bash
# from the terminal running restic mount:
Ctrl+C

# or:
diskutil unmount ~/ResticMount
```

> 💡 Tip:
> If the Mac sleeps, the mount can become stale. Clear it with:
>
> ```bash
> pkill -f "restic mount"
> diskutil unmount force ~/ResticMount
> ```

---

## 🔁 Restore the Entire Repository (Disaster Recovery)

> ⚠️ Only do this to an **empty target directory**

```bash
mkdir -p ~/restic-full-restore
restic restore latest --target ~/restic-full-restore
```

---

## 📁 Restore a Specific Directory (Recommended Workflow)

### Example: Restore Desktop

```bash
rm -rf ~/Desktop/restic-restore
mkdir -p ~/Desktop/restic-restore

restic restore latest \
  --target "$HOME/Desktop/restic-restore" \
  --include "$HOME/Desktop/**"
```

---

## 🔽 Flatten the Restored Directory (Optional)

```bash
rsync -a \
  "$HOME/Desktop/restic-restore/Users/$USER/Desktop/" \
  "$HOME/Desktop/restic-restore/"

rm -rf "$HOME/Desktop/restic-restore/Users"
```

---

## ⏪ Restore from an Earlier Snapshot

```bash
restic restore dcb734f1 \
  --target "$HOME/Desktop/restic-restore" \
  --include "$HOME/Desktop/**"
```

---

## 🕒 Restore by Time

```bash
restic restore \
  --time "2026-01-13 20:30" \
  --target "$HOME/Desktop/restic-restore" \
  --include "$HOME/Desktop/**"
```

---

## 📄 Restore a Single File

```bash
restic restore latest \
  --target "$HOME/Desktop/restic-restore" \
  --include "$HOME/Desktop/README.md"
```

---

## 🔍 Inspect Snapshot Contents

```bash
restic ls latest "$HOME/Desktop" | head
```

---

## 🧪 Best Practices

### ✅ DO
- Run `source restic.env` before restores
- Restore into a temporary directory
- Inspect before merging back
- Use `rsync` for controlled merges

### ❌ DON’T
- Restore over live data
- Restore directly into `~/`
- Assume restic can strip paths

---

## 📌 Recommended Pattern

```text
source restic.env
restore → inspect → flatten → selectively merge
```
