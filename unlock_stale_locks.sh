#!/bin/zsh
set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
RESTIC_BIN="${RESTIC_BIN:-restic}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/restic.env"

usage() {
  cat <<'EOF'
Usage: ./unlock_stale_locks.sh

List repository locks, refuse to proceed if a restic-related process is
active, run `restic unlock`, and then show the remaining locks.
EOF
}

if (( $# > 0 )); then
  case "$1" in
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1"
      usage
      exit 1
      ;;
  esac
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Run ./bootstrap.sh --generate or ./bootstrap.sh --install first."
  exit 1
fi

if ! command -v "$RESTIC_BIN" >/dev/null 2>&1; then
  echo "ERROR: '$RESTIC_BIN' not found. Install restic first."
  exit 1
fi

if ! command -v pgrep >/dev/null 2>&1; then
  echo "ERROR: 'pgrep' not found; cannot verify running restic jobs."
  exit 1
fi

source "$SCRIPT_DIR/lib/platform.sh"

if ! source "$ENV_FILE"; then
  echo "ERROR: failed to source $ENV_FILE."
  echo "Verify the repository settings and run the password setup commands first."
  exit 1
fi

if ! repo_value="$(resolve_repository_value 2>&1)"; then
  echo "ERROR: $repo_value"
  exit 1
fi

if [[ -z "${RESTIC_PASSWORD_COMMAND:-}" && -z "${RESTIC_PASSWORD:-}" ]]; then
  echo "ERROR: set RESTIC_PASSWORD_COMMAND or RESTIC_PASSWORD in $ENV_FILE before unlocking."
  exit 1
fi

masked_repo="$(mask_repository_credentials "$repo_value")"

set +e
active_processes="$(pgrep -fl "run_backup.sh|restic" 2>/dev/null)"
pgrep_status=$?
set -e

if [[ $pgrep_status -eq 0 && -n "$active_processes" ]]; then
  echo "ERROR: active restic-related process found; not unlocking."
  printf '%s\n' "$active_processes"
  exit 1
fi

if [[ $pgrep_status -gt 1 ]]; then
  echo "ERROR: failed to inspect running restic-related processes."
  exit 1
fi

echo "Repository: $masked_repo"
echo "Current locks:"
"$RESTIC_BIN" list locks
echo "Running restic unlock..."
"$RESTIC_BIN" unlock
echo "Remaining locks:"
"$RESTIC_BIN" list locks
