#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGFILE="${HOME}/Library/Logs/restic-rest-client/daemon_backup.log"
initial_size=0
start_byte=1
tail_state_dir=""
tail_fifo=""
tail_pid=""

usage() {
  cat <<'EOF'
Usage: ./install_and_watch.sh

Run ./bootstrap.sh --install, then follow only daemon-log output written
during or after that install-triggered backup run until the run finishes.
EOF
}

cleanup_tail() {
  if [[ -n "$tail_pid" ]]; then
    kill "$tail_pid" >/dev/null 2>&1 || true
    wait "$tail_pid" >/dev/null 2>&1 || true
    tail_pid=""
  fi

  if [[ -n "$tail_state_dir" && -d "$tail_state_dir" ]]; then
    rm -rf "$tail_state_dir"
    tail_state_dir=""
    tail_fifo=""
  fi
}

follow_install_log() {
  if ! tail_state_dir="$(mktemp -d)"; then
    echo "ERROR: failed to create temporary watcher state."
    exit 1
  fi
  tail_fifo="$tail_state_dir/install_and_watch.pipe"
  mkfifo "$tail_fifo"

  tail -c +"$start_byte" -F "$LOGFILE" > "$tail_fifo" &
  tail_pid=$!

  while IFS= read -r line; do
    printf '%s\n' "$line"
    if [[ "$line" == *"Backup task finished."* ]]; then
      echo "Install-triggered backup run finished."
      exit 0
    fi
  done < "$tail_fifo"

  echo "ERROR: stopped following $LOGFILE before the install-triggered backup run finished."
  exit 1
}

trap cleanup_tail EXIT

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
follow_install_log
