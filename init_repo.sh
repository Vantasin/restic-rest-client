#!/bin/zsh
set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
RESTIC_BIN="${RESTIC_BIN:-restic}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/restic.env"

usage() {
  cat <<'EOF'
Usage: ./init_repo.sh

Initialize the configured repository if it does not exist yet, then verify
access with `restic snapshots`.
EOF
}

is_missing_repository_probe() {
  local probe_text="$1"

  print -r -- "$probe_text" | grep -Eiq \
    'Is there a repository at the following location\?|404 Not Found|config file.*(not found|no such file or directory)|stat:.*404'
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

masked_repo="$(mask_repository_credentials "$repo_value")"

if [[ -z "${RESTIC_PASSWORD_COMMAND:-}" && -z "${RESTIC_PASSWORD:-}" ]]; then
  echo "ERROR: set RESTIC_PASSWORD_COMMAND or RESTIC_PASSWORD in $ENV_FILE before initializing."
  exit 1
fi

echo "Repository: $masked_repo"
echo "Checking whether the repository already exists..."

probe_output="$(mktemp)"
trap 'rm -f "$probe_output"' EXIT

set +e
"$RESTIC_BIN" cat config >"$probe_output" 2>&1
probe_status=$?
set -e

probe_text="$(<"$probe_output")"

if [[ $probe_status -eq 0 ]]; then
  echo "Repository already initialized."
elif is_missing_repository_probe "$probe_text"; then
  echo "Repository not initialized yet. Running restic init..."
  "$RESTIC_BIN" init
else
  echo "ERROR: repository probe failed before initialization."
  cat "$probe_output"
  exit "$probe_status"
fi

echo "Verifying access with restic snapshots..."
"$RESTIC_BIN" snapshots
