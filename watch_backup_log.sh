#!/bin/zsh
set -euo pipefail

LOGFILE="${HOME}/Library/Logs/restic-rest-client/daemon_backup.log"

usage() {
  cat <<'EOF'
Usage: ./watch_backup_log.sh

Follow only new output from the launchd backup daemon log. If the daemon log
does not exist yet, wait for it to be created.
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

if ! command -v tail >/dev/null 2>&1; then
  echo "ERROR: 'tail' not found."
  exit 1
fi

if [[ ! -e "$LOGFILE" ]]; then
  echo "Waiting for backup daemon log to be created: $LOGFILE"
  while [[ ! -e "$LOGFILE" ]]; do
    sleep 1
  done
fi

echo "Following new output from: $LOGFILE"
exec tail -n 0 -F "$LOGFILE"
