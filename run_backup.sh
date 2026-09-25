#!/bin/zsh
# ==========================================
# Restic Backup Script for macOS
# Host: set via RESTIC_HOST in restic.env
# ==========================================

set -euo pipefail  # fail fast on unset vars and errors

# Ensure restic is found when launched via launchd (no user PATH).
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
RESTIC_BIN=${RESTIC_BIN:-restic}
MSMTP_BIN=${MSMTP_BIN:-msmtp}
TASK="${1:-backup}"
CHECK_MODE_REQUESTED="${2:-auto}"
TERMINAL_MARKER_PREFIX="[STATE] run_backup.sh finished:"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESTIC_REPO_DISPLAY_VALUE=""
RESTIC_REPO_SOURCE="unset"

emit_terminal_marker() {
  local exit_code="${1:-1}"
  local marker="${TERMINAL_MARKER_PREFIX} task=${TASK:-unknown} exit_code=${exit_code}"

  set +e
  if typeset -f log >/dev/null 2>&1 && [[ -n "${LOGFILE:-}" ]]; then
    log "$marker"
  else
    printf '%s\n' "$marker"
  fi
}

trap 'emit_terminal_marker "$?"' EXIT

# Load env vars (repo, password, host, etc.).
if [ ! -f "$SCRIPT_DIR/restic.env" ]; then
  echo "ERROR: $SCRIPT_DIR/restic.env not found. Run ./bootstrap.sh --generate or ./bootstrap.sh --install first."
  exit 1
fi

source "$SCRIPT_DIR/restic.env"

usage() {
  cat <<'EOF'
Usage: ./run_backup.sh [backup|prune|check [auto|lite|full]|logcleanup|test-email|test-success-email|test-failure-email|test-warning-email|test-lock-failure-email]
EOF
}

# Execution flow:
# 1) Load config and validate task.
# 2) Dispatch to backup, check, prune, logcleanup, or notification test tasks.

# Single entrypoint with explicit subcommands for launchd jobs.
case "$TASK" in
  backup|prune|check|logcleanup|test-email|test-success-email|test-failure-email|test-warning-email|test-lock-failure-email) ;;
  *)
    usage
    exit 1
    ;;
esac

if [[ "$TASK" == "check" ]]; then
  if [[ $# -gt 2 ]]; then
    usage
    exit 1
  fi
  case "$CHECK_MODE_REQUESTED" in
    auto|lite|full) ;;
    *)
      usage
      exit 1
      ;;
  esac
elif [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOGDIR="$HOME/Library/Logs/restic-rest-client"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/${TASK}_$TIMESTAMP.log"

# Config paths and defaults.
INCLUDE_FILE="$SCRIPT_DIR/restic-include-macos.txt"
EXCLUDE_FILE="$SCRIPT_DIR/restic-exclude-macos.txt"
RESTIC_RETRY_LOCK="${RESTIC_RETRY_LOCK:-10m}"
RESTIC_KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
RESTIC_KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
RESTIC_KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"
RESTIC_BACKUP_REQUIRE_AC_POWER="${RESTIC_BACKUP_REQUIRE_AC_POWER:-false}"
RESTIC_BACKUP_SKIP_WHEN_CLAMSHELL_CLOSED="${RESTIC_BACKUP_SKIP_WHEN_CLAMSHELL_CLOSED:-false}"
RESTIC_PRUNE_REQUIRE_AC_POWER="${RESTIC_PRUNE_REQUIRE_AC_POWER:-false}"
RESTIC_PRUNE_SKIP_WHEN_CLAMSHELL_CLOSED="${RESTIC_PRUNE_SKIP_WHEN_CLAMSHELL_CLOSED:-false}"
RESTIC_CHECK_RETRY_LOCK="${RESTIC_CHECK_RETRY_LOCK:-60m}"
RESTIC_CHECK_LITE_READ_DATA_SUBSET="${RESTIC_CHECK_LITE_READ_DATA_SUBSET:-10%}"
RESTIC_CHECK_REQUIRE_AC_POWER="${RESTIC_CHECK_REQUIRE_AC_POWER:-false}"
RESTIC_CHECK_SKIP_WHEN_CLAMSHELL_CLOSED="${RESTIC_CHECK_SKIP_WHEN_CLAMSHELL_CLOSED:-false}"

log() {
  local now
  now=$(date +"%Y-%m-%d_%H-%M-%S")
  printf "[%s] %s\n" "$now" "$*" | tee -a "$LOGFILE"
}

source_required_library() {
  local library_path="$1"

  if [ ! -f "$library_path" ]; then
    echo "ERROR: $library_path not found." >&2
    exit 1
  fi

  source "$library_path"
}

source_required_library "$SCRIPT_DIR/lib/platform.sh"
source_required_library "$SCRIPT_DIR/lib/notifications.sh"
source_required_library "$SCRIPT_DIR/lib/tasks.sh"

load_repository_context() {
  local repo_value_or_error

  if ! repo_value_or_error="$(resolve_repository_value 2>&1)"; then
    REPO_CONTEXT_ERROR="$repo_value_or_error"
    return 1
  fi

  RESTIC_REPO_DISPLAY_VALUE="$(mask_repository_credentials "$repo_value_or_error")"
  RESTIC_REPO_SOURCE="env: RESTIC_REPOSITORY"
  REPO_CONTEXT_ERROR=""

  return 0
}

require_repository_context_or_exit() {
  if ! load_repository_context; then
    echo "ERROR: ${REPO_CONTEXT_ERROR:-Set RESTIC_REPOSITORY in restic.env.}" >&2
    exit 1
  fi
}

log_task_start() {
  local task_label="$1"
  local retry_lock_value="${2:-$RESTIC_RETRY_LOCK}"

  log "Starting Restic ${task_label}..."
  log "[INFO] Repository source: $RESTIC_REPO_SOURCE"
  log "[INFO] Using repository: $RESTIC_REPO_DISPLAY_VALUE"
  log "[INFO] Host: $RESTIC_HOST"
  log "[INFO] Retry lock: $retry_lock_value"
}

run_notification_test_task_or_exit() {
  local mode="$1"
  local task_label="$2"

  if ! load_repository_context >/dev/null 2>&1; then
    RESTIC_REPO_DISPLAY_VALUE="unset"
    RESTIC_REPO_SOURCE="unset"
  fi

  log "Starting Restic ${task_label}..."
  log "[INFO] Host: ${RESTIC_HOST:-unknown}"
  log "[INFO] Repository source: $RESTIC_REPO_SOURCE"
  log "[INFO] Using repository: ${RESTIC_REPO_DISPLAY_VALUE:-unset}"
  log "[INFO] Recipient: ${RESTIC_NOTIFY_EMAIL:-unset}"
  log "[INFO] msmtp binary: $MSMTP_BIN"

  if run_test_email "$mode"; then
    exit 0
  fi

  exit 1
}

run_logcleanup_or_exit() {
  log "Starting Restic log cleanup..."
  if run_logcleanup_task; then
    notify_success "logcleanup"
    exit 0
  fi

  notify_failure 1
  exit 1
}

run_backup_or_exit() {
  local backup_status=0

  require_repository_context_or_exit
  log_task_start "backup"
  if run_backup_task; then
    backup_status=0
  else
    backup_status=$?
  fi

  if [[ "$TASK_WAS_SKIPPED" == true ]]; then
    exit 0
  fi

  if [[ $backup_status -eq 0 ]]; then
    notify_success "backup" "${RESTIC_REPO_DISPLAY_VALUE:-unset}"
  elif [[ "$TASK_SHOULD_NOTIFY_FAILURE" == true ]]; then
    notify_failure "$backup_status"
  fi

  exit $backup_status
}

run_prune_or_exit() {
  local prune_status=0

  require_repository_context_or_exit
  log_task_start "prune"
  log "[INFO] Client-side prune enabled: ${RESTIC_PRUNE_ENABLED:-false}"
  log "[INFO] Prune policy: keep-daily $RESTIC_KEEP_DAILY, keep-weekly $RESTIC_KEEP_WEEKLY, keep-monthly $RESTIC_KEEP_MONTHLY"
  if run_prune_task; then
    prune_status=0
  else
    prune_status=$?
  fi

  if [[ "$TASK_WAS_SKIPPED" == true ]]; then
    exit 0
  fi

  if [[ $prune_status -eq 0 ]]; then
    notify_success "prune" "${RESTIC_REPO_DISPLAY_VALUE:-unset}"
  elif [[ "$TASK_SHOULD_NOTIFY_FAILURE" == true ]]; then
    notify_failure "$prune_status"
  fi

  exit $prune_status
}

build_check_notification_note() {
  local note_text

  note_text="Check mode: ${CHECK_MODE_SELECTED:-unknown}"
  if [[ "${CHECK_MODE_SELECTED:-}" == "lite" ]]; then
    note_text="${note_text}
Read-data subset: ${RESTIC_CHECK_LITE_READ_DATA_SUBSET}"
  elif [[ "${CHECK_MODE_SELECTED:-}" == "full" ]]; then
    note_text="${note_text}
Read-data scope: all repository data"
  fi

  if [[ "${CHECK_MODE_REQUESTED:-auto}" == "auto" && -n "${CHECK_SCHEDULE_ANCHOR_DATE:-}" ]]; then
    note_text="${note_text}
Scheduled Sunday anchor: ${CHECK_SCHEDULE_ANCHOR_DATE}"
  fi

  printf '%s' "$note_text"
}

run_check_or_exit() {
  local check_status=0
  local note_text subject_suffix

  require_repository_context_or_exit
  log_task_start "check" "$RESTIC_CHECK_RETRY_LOCK"
  if run_check_task; then
    check_status=0
  else
    check_status=$?
  fi

  if [[ "$TASK_WAS_SKIPPED" == true ]]; then
    exit 0
  fi

  note_text="$(build_check_notification_note)"
  subject_suffix=" [${CHECK_MODE_SELECTED:-unknown}]"

  if [[ $check_status -eq 0 ]]; then
    notify_success "check" "${RESTIC_REPO_DISPLAY_VALUE:-unset}" "false" "$note_text" "$subject_suffix"
  elif [[ "$TASK_SHOULD_NOTIFY_FAILURE" == true ]]; then
    notify_failure "$check_status" "check" "false" "$note_text" "$subject_suffix"
  fi

  exit $check_status
}

case "$TASK" in
  logcleanup) run_logcleanup_or_exit ;;
  test-email) run_notification_test_task_or_exit "generic" "test email" ;;
  test-success-email) run_notification_test_task_or_exit "success" "test success email" ;;
  test-failure-email) run_notification_test_task_or_exit "failure" "test failure email" ;;
  test-warning-email) run_notification_test_task_or_exit "warning" "test warning email" ;;
  test-lock-failure-email) run_notification_test_task_or_exit "lock-failure" "test lock failure email" ;;
  backup) run_backup_or_exit ;;
  prune) run_prune_or_exit ;;
  check) run_check_or_exit ;;
esac
