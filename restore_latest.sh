#!/bin/zsh
set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
RESTIC_BIN="${RESTIC_BIN:-restic}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/restic.env"
TARGET_DIR="${HOME}/restic-restore"

usage() {
  cat <<'EOF'
Usage: ./restore_latest.sh [--target DIR]

Restore the latest snapshot into an empty target directory.

Defaults:
- target directory: ~/restic-restore
EOF
}

ensure_value_option() {
  local option_name="$1"

  if [[ $# -lt 2 || -z "${2:-}" ]]; then
    echo "ERROR: $option_name requires a value."
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      ensure_value_option "$1" "${2:-}"
      TARGET_DIR="$2"
      shift 2
      continue
      ;;
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
done

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Run ./bootstrap.sh --generate or ./bootstrap.sh --install first."
  exit 1
fi

if ! command -v "$RESTIC_BIN" >/dev/null 2>&1; then
  echo "ERROR: '$RESTIC_BIN' not found. Install restic first."
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
  echo "ERROR: set RESTIC_PASSWORD_COMMAND or RESTIC_PASSWORD in $ENV_FILE before restoring."
  exit 1
fi

if [[ -e "$TARGET_DIR" && ! -d "$TARGET_DIR" ]]; then
  echo "ERROR: restore target exists and is not a directory: $TARGET_DIR"
  exit 1
fi

if [[ -d "$TARGET_DIR" ]]; then
  if [[ -n "$(find "$TARGET_DIR" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "ERROR: restore target is not empty: $TARGET_DIR"
    echo "Use an empty directory or pass --target to choose a different restore location."
    exit 1
  fi
else
  mkdir -p "$TARGET_DIR"
fi

masked_repo="$(mask_repository_credentials "$repo_value")"

echo "Repository: $masked_repo"
echo "Restore target: $TARGET_DIR"
echo "Restoring latest snapshot..."
"$RESTIC_BIN" restore latest --target "$TARGET_DIR"
echo "Restore completed: $TARGET_DIR"
