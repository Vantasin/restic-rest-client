#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGFILE="${HOME}/Library/Logs/restic-rest-client/daemon_backup.log"
initial_size=0
start_byte=1

usage() {
  cat <<'EOF'
Usage: ./install_and_watch.sh

Run ./bootstrap.sh --install, then follow only daemon-log output written
during or after that install-triggered backup run.
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

if [[ -e "$LOGFILE" ]]; then
  if [[ ! -f "$LOGFILE" ]]; then
    echo "ERROR: daemon log path exists and is not a file: $LOGFILE"
    exit 1
  fi
  initial_size="$(wc -c < "$LOGFILE" | tr -d '[:space:]')"
fi

"$SCRIPT_DIR/bootstrap.sh" --install

if [[ ! -e "$LOGFILE" ]]; then
  echo "Waiting for backup daemon log to be created: $LOGFILE"
  while [[ ! -e "$LOGFILE" ]]; do
    sleep 1
  done
fi

if [[ ! -f "$LOGFILE" ]]; then
  echo "ERROR: daemon log path exists and is not a file: $LOGFILE"
  exit 1
fi

if [[ "$initial_size" == <-> ]]; then
  start_byte=$((initial_size + 1))
fi

current_size="$(wc -c < "$LOGFILE" | tr -d '[:space:]')"
if [[ "$current_size" == <-> && "$current_size" -lt "$initial_size" ]]; then
  start_byte=1
fi

echo "Following install-triggered backup output from: $LOGFILE"
exec tail -c +"$start_byte" -F "$LOGFILE"
