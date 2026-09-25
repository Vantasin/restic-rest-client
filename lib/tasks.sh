# Task helpers for run_backup.sh.
#
# Expected from the caller:
# - log()
# - RESTIC_* env/config vars and INCLUDE_FILE / EXCLUDE_FILE
# - helpers from lib/platform.sh

TASK_WAS_SKIPPED=false
TASK_SHOULD_NOTIFY_FAILURE=true
CHECK_MODE_SELECTED=""
CHECK_SCHEDULE_ANCHOR_DATE=""

mark_task_skipped() {
  TASK_WAS_SKIPPED=true
  TASK_SHOULD_NOTIFY_FAILURE=false
}

mark_task_preflight_failure() {
  TASK_SHOULD_NOTIFY_FAILURE=false
}

reset_task_state() {
  TASK_WAS_SKIPPED=false
  TASK_SHOULD_NOTIFY_FAILURE=true
  CHECK_MODE_SELECTED=""
  CHECK_SCHEDULE_ANCHOR_DATE=""
}

resolve_check_anchor_date() {
  local weekday_index

  weekday_index="$(date +"%w")"
  if [[ "$weekday_index" == "0" ]]; then
    date +"%Y-%m-%d"
  else
    date -v-"${weekday_index}"d +"%Y-%m-%d"
  fi
}

anchor_is_last_sunday_of_month() {
  local anchor_date="$1"
  local anchor_month next_sunday_month

  anchor_month=$(date -j -f "%Y-%m-%d" "$anchor_date" +"%m")
  next_sunday_month=$(date -j -v+7d -f "%Y-%m-%d" "$anchor_date" +"%m")
  [[ "$anchor_month" != "$next_sunday_month" ]]
}

resolve_check_mode() {
  local requested_mode="${1:-auto}"

  case "$requested_mode" in
    auto)
      CHECK_SCHEDULE_ANCHOR_DATE="$(resolve_check_anchor_date)" || return 1
      if anchor_is_last_sunday_of_month "$CHECK_SCHEDULE_ANCHOR_DATE"; then
        CHECK_MODE_SELECTED="full"
      else
        CHECK_MODE_SELECTED="lite"
      fi
      ;;
    lite|full)
      CHECK_MODE_SELECTED="$requested_mode"
      ;;
    *)
      log "ERROR: Unsupported check mode: $requested_mode"
      return 1
      ;;
  esac

  return 0
}

apply_task_guards() {
  local task_label="$1"
  local require_ac_power="$2"
  local skip_when_clamshell_closed="$3"

  log "[INFO] Require AC power: $require_ac_power"
  log "[INFO] Skip when lid closed: $skip_when_clamshell_closed"

  if is_true "$require_ac_power"; then
    if is_on_ac_power; then
      log "[INFO] AC power detected."
    else
      log "[INFO] Skipping ${task_label} because the Mac is not on AC power."
      mark_task_skipped
      return 10
    fi
  fi

  if is_true "$skip_when_clamshell_closed"; then
    if is_clamshell_closed; then
      log "[INFO] Skipping ${task_label} because the MacBook lid is closed."
      mark_task_skipped
      return 10
    fi
    log "[INFO] Clamshell state is open."
  fi

  return 0
}

run_logcleanup_task() {
  # Per-run logs only; daemon logs are rotated by newsyslog.
  local retention_days logdir
  retention_days="${RESTIC_LOG_RETENTION_DAYS:-14}"
  case "$retention_days" in
    ''|*[!0-9]*)
      log "ERROR: RESTIC_LOG_RETENTION_DAYS must be an integer."
      return 1
      ;;
  esac

  logdir="$HOME/Library/Logs/restic-rest-client"
  if [ ! -d "$logdir" ]; then
    log "INFO: Log directory not found: $logdir"
    return 0
  fi

  log "Pruning restic logs older than ${retention_days} days in $logdir"
  local cleanup_status=0
  if ! find "$logdir" -type f -name 'backup_*.log' -mtime +"$retention_days" -delete; then
    cleanup_status=1
  fi
  if ! find "$logdir" -type f -name 'prune_*.log' -mtime +"$retention_days" -delete; then
    cleanup_status=1
  fi
  if ! find "$logdir" -type f -name 'check_*.log' -mtime +"$retention_days" -delete; then
    cleanup_status=1
  fi
  if ! find "$logdir" -type f -name 'logcleanup_*.log' -mtime +"$retention_days" -delete; then
    cleanup_status=1
  fi
  if ! find "$logdir" -type f -name 'test-email_*.log' -mtime +"$retention_days" -delete; then
    cleanup_status=1
  fi
  if ! find "$logdir" -type f -name 'test-success-email_*.log' -mtime +"$retention_days" -delete; then
    cleanup_status=1
  fi
  if ! find "$logdir" -type f -name 'test-failure-email_*.log' -mtime +"$retention_days" -delete; then
    cleanup_status=1
  fi
  if ! find "$logdir" -type f -name 'test-warning-email_*.log' -mtime +"$retention_days" -delete; then
    cleanup_status=1
  fi
  if ! find "$logdir" -type f -name 'test-lock-failure-email_*.log' -mtime +"$retention_days" -delete; then
    cleanup_status=1
  fi

  if [[ $cleanup_status -ne 0 ]]; then
    log "ERROR: Log cleanup encountered errors."
    return 1
  fi

  log "Log cleanup complete."
  return 0
}

run_backup_task() {
  local backup_status=0
  local guard_status=0

  reset_task_state

  log "[INFO] Include file: $INCLUDE_FILE"
  log "[INFO] Exclude file: $EXCLUDE_FILE"

  if ! require_regular_file "Include file" "$INCLUDE_FILE"; then
    mark_task_preflight_failure
    log "Backup task finished."
    return 1
  fi

  if ! require_regular_file "Exclude file" "$EXCLUDE_FILE"; then
    mark_task_preflight_failure
    log "Backup task finished."
    return 1
  fi

  if apply_task_guards "backup" "$RESTIC_BACKUP_REQUIRE_AC_POWER" "$RESTIC_BACKUP_SKIP_WHEN_CLAMSHELL_CLOSED"; then
    guard_status=0
  else
    guard_status=$?
  fi
  if [[ $guard_status -eq 10 ]]; then
    log "Backup task finished."
    return 0
  elif [[ $guard_status -ne 0 ]]; then
    log "Backup task finished."
    return 1
  fi

  if run_command_logged \
    "$RESTIC_BIN" \
    --retry-lock "$RESTIC_RETRY_LOCK" \
    backup \
    --tag "macos" \
    --host "$RESTIC_HOST" \
    --files-from "$INCLUDE_FILE" \
    --exclude-file "$EXCLUDE_FILE"; then
    backup_status=0
  else
    backup_status=$?
  fi

  printf "\n" | tee -a "$LOGFILE"
  log "Backup exit code: $backup_status"

  if [[ $backup_status -eq 0 ]]; then
    log "Backup completed successfully."
  else
    if [[ $backup_status -eq 3 ]]; then
      log "ERROR: Restic backup completed with unreadable source files; the snapshot may be incomplete."
      log "[HINT] macOS 'operation not permitted' errors usually mean the process running restic lacks Full Disk Access."
      log "[HINT] Manual runs usually need Full Disk Access for your terminal app; launchd runs may also need it for the shell/restic executables."
      log "[HINT] 'resource deadlock avoided' often comes from iCloud or File Provider data under ~/Library/Mobile Documents; keep those files local or exclude those paths."
    else
      log "ERROR: Restic backup failed!"
    fi
  fi

  log "Backup task finished."
  return $backup_status
}

run_check_task() {
  local check_status=0
  local guard_status=0
  local check_mode_requested="${CHECK_MODE_REQUESTED:-auto}"
  local -a check_command

  reset_task_state

  if ! resolve_check_mode "$check_mode_requested"; then
    mark_task_preflight_failure
    log "Check task finished."
    return 1
  fi

  log "[INFO] Check mode request: $check_mode_requested"
  log "[INFO] Check mode selected: $CHECK_MODE_SELECTED"
  if [[ "$check_mode_requested" == "auto" ]]; then
    log "[INFO] Scheduled Sunday anchor: $CHECK_SCHEDULE_ANCHOR_DATE"
    if [[ "$CHECK_MODE_SELECTED" == "full" ]]; then
      log "[INFO] Auto mode selected full because the scheduled Sunday anchor is the last Sunday of the month."
    else
      log "[INFO] Auto mode selected lite because the scheduled Sunday anchor is not the last Sunday of the month."
    fi
  else
    log "[INFO] Explicit check mode selected."
  fi

  log "[INFO] Check retry lock: $RESTIC_CHECK_RETRY_LOCK"
  if [[ "$CHECK_MODE_SELECTED" == "lite" ]]; then
    if [[ -z "${RESTIC_CHECK_LITE_READ_DATA_SUBSET:-}" ]]; then
      mark_task_preflight_failure
      log "ERROR: RESTIC_CHECK_LITE_READ_DATA_SUBSET must not be empty."
      log "Check task finished."
      return 1
    fi
    log "[INFO] Lite check read-data subset: $RESTIC_CHECK_LITE_READ_DATA_SUBSET"
    check_command=(
      "$RESTIC_BIN"
      --retry-lock "$RESTIC_CHECK_RETRY_LOCK"
      check
      --read-data-subset "$RESTIC_CHECK_LITE_READ_DATA_SUBSET"
    )
  else
    log "[INFO] Full check reads all repository data."
    check_command=(
      "$RESTIC_BIN"
      --retry-lock "$RESTIC_CHECK_RETRY_LOCK"
      check
      --read-data
    )
  fi

  if apply_task_guards "check" "$RESTIC_CHECK_REQUIRE_AC_POWER" "$RESTIC_CHECK_SKIP_WHEN_CLAMSHELL_CLOSED"; then
    guard_status=0
  else
    guard_status=$?
  fi
  if [[ $guard_status -eq 10 ]]; then
    log "Check task finished."
    return 0
  elif [[ $guard_status -ne 0 ]]; then
    log "Check task finished."
    return 1
  fi

  if run_command_logged "${check_command[@]}"; then
    check_status=0
  else
    check_status=$?
  fi

  printf "\n" | tee -a "$LOGFILE"
  log "Check exit code: $check_status"

  if [[ $check_status -ne 0 ]]; then
    log "ERROR: Restic check failed!"
  else
    log "Check completed successfully."
  fi

  log "Check task finished."
  return $check_status
}

run_prune_task() {
  local prune_status=0
  local guard_status=0

  reset_task_state

  if ! is_true "${RESTIC_PRUNE_ENABLED:-false}"; then
    log "[INFO] Skipping prune because RESTIC_PRUNE_ENABLED is not true."
    log "[HINT] This repo defaults to disabled client-side prune to match append-only rest-server deployments."
    mark_task_skipped
    log "Prune task finished."
    return 0
  fi

  log "Pruning old snapshots..."

  if apply_task_guards "prune" "$RESTIC_PRUNE_REQUIRE_AC_POWER" "$RESTIC_PRUNE_SKIP_WHEN_CLAMSHELL_CLOSED"; then
    guard_status=0
  else
    guard_status=$?
  fi
  if [[ $guard_status -eq 10 ]]; then
    log "Prune task finished."
    return 0
  elif [[ $guard_status -ne 0 ]]; then
    log "Prune task finished."
    return 1
  fi

  if run_command_logged \
    "$RESTIC_BIN" \
    --retry-lock "$RESTIC_RETRY_LOCK" \
    forget \
    --keep-daily "$RESTIC_KEEP_DAILY" \
    --keep-weekly "$RESTIC_KEEP_WEEKLY" \
    --keep-monthly "$RESTIC_KEEP_MONTHLY" \
    --prune; then
    prune_status=0
  else
    prune_status=$?
  fi

  printf "\n" | tee -a "$LOGFILE"
  log "Prune exit code: $prune_status"

  if [[ $prune_status -ne 0 ]]; then
    log "ERROR: Restic prune failed!"
  else
    log "Prune completed successfully."
  fi

  log "Prune task finished."
  return $prune_status
}
