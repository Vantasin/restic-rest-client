# Notification helpers for run_backup.sh.
#
# Expected from the caller:
# - log()
# - is_true()
# - SCRIPT_DIR, TASK, TIMESTAMP, LOGFILE
# - RESTIC_* env/config vars and INCLUDE_FILE / EXCLUDE_FILE

msmtp_available() {
  command -v "$MSMTP_BIN" >/dev/null 2>&1
}

html_escape() {
  local value="$1"
  value=${value//&/&amp;}
  value=${value//</&lt;}
  value=${value//>/&gt;}
  printf '%s' "$value"
}

status_color() {
  case "$1" in
    OK) echo "#16a34a" ;;
    WARN) echo "#d97706" ;;
    FAIL) echo "#dc2626" ;;
    INFO) echo "#2563eb" ;;
    *) echo "#2563eb" ;;
  esac
}

build_html_row() {
  local label_html value_html
  label_html=$(html_escape "$1")
  value_html=$(html_escape "$2")
  printf '<tr><td style="padding:4px 0;color:#6b7280;width:140px;">%s</td><td style="padding:4px 0;">%s</td></tr>\n' \
    "$label_html" "$value_html"
}

build_notification_html() {
  local status_label="$1"
  local heading="$2"
  local task_label="$3"
  local repo_value="${4:-}"
  local extra_rows="${5:-}"
  local note_text="${6:-}"
  local status_html heading_html
  local note_html rows badge_color

  badge_color=$(status_color "$status_label")
  status_html=$(html_escape "$status_label")
  heading_html=$(html_escape "$heading")

  rows="$(build_html_row "Host" "${RESTIC_HOST:-unknown}")"
  rows+=$(build_html_row "Task" "$task_label")
  if [[ -n "$repo_value" ]]; then
    rows+=$(build_html_row "Repo" "$repo_value")
  fi
  rows+=$(build_html_row "Timestamp" "$TIMESTAMP")
  rows+=$(build_html_row "Log" "$LOGFILE")
  rows+="$extra_rows"

  note_html=""
  if [[ -n "$note_text" ]]; then
    note_html=$(cat <<EOF_NOTE
    <div style="margin-top:12px;padding:12px;border-radius:10px;background:#f9fafb;border:1px solid #e5e7eb;font-size:13px;color:#374151;white-space:pre-wrap;">$(html_escape "$note_text")</div>
EOF_NOTE
)
  fi

  cat <<EOF_HTML
<html>
<body style="margin:0;padding:16px;background:#f3f4f6;">
  <div style="max-width:720px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:12px;padding:16px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#111827;">
    <div style="display:flex;align-items:center;gap:10px;">
      <span style="display:inline-block;padding:4px 10px;border-radius:999px;background:${badge_color};color:#fff;font-size:12px;font-weight:600;letter-spacing:0.3px;">${status_html}</span>
      <span style="font-size:16px;font-weight:600;">${heading_html}</span>
    </div>
    <table style="width:100%;border-collapse:collapse;margin-top:12px;font-size:14px;">
${rows}
    </table>
${note_html}
  </div>
</body>
</html>
EOF_HTML
}

send_email_message() {
  local subject="$1"
  local text_body="$2"
  local html_body="${3:-}"
  local attachment="${4:-}"
  local boundary alt_boundary attachment_name

  if [[ -n "$attachment" && -f "$attachment" ]]; then
    attachment_name=$(basename "$attachment")
    boundary="====restic_mixed_$(date +%s%N)===="
    if [[ -n "$html_body" ]]; then
      alt_boundary="====restic_alt_$(date +%s%N)===="
      {
        printf "To: %s\n" "$RESTIC_NOTIFY_EMAIL"
        printf "Subject: %s\n" "$subject"
        printf "MIME-Version: 1.0\n"
        printf "Content-Type: multipart/mixed; boundary=\"%s\"\n\n" "$boundary"
        printf '%s\n' "--${boundary}"
        printf "Content-Type: multipart/alternative; boundary=\"%s\"\n\n" "$alt_boundary"
        printf '%s\n' "--${alt_boundary}"
        printf "Content-Type: text/plain; charset=UTF-8\n"
        printf "Content-Transfer-Encoding: 8bit\n\n"
        printf '%s\n\n' "$text_body"
        printf '%s\n' "--${alt_boundary}"
        printf "Content-Type: text/html; charset=UTF-8\n"
        printf "Content-Transfer-Encoding: 8bit\n\n"
        printf '%s\n\n' "$html_body"
        printf '%s\n' "--${alt_boundary}--"
        printf '%s\n' "--${boundary}"
        printf "Content-Type: text/plain; charset=UTF-8; name=\"%s\"\n" "$attachment_name"
        printf "Content-Disposition: attachment; filename=\"%s\"\n" "$attachment_name"
        printf "Content-Transfer-Encoding: 8bit\n\n"
        cat "$attachment"
        printf '\n\n%s\n' "--${boundary}--"
      } | "$MSMTP_BIN" "$RESTIC_NOTIFY_EMAIL"
      return
    fi

    {
      printf "To: %s\n" "$RESTIC_NOTIFY_EMAIL"
      printf "Subject: %s\n" "$subject"
      printf "MIME-Version: 1.0\n"
      printf "Content-Type: multipart/mixed; boundary=\"%s\"\n\n" "$boundary"
      printf '%s\n' "--${boundary}"
      printf "Content-Type: text/plain; charset=UTF-8\n"
      printf "Content-Transfer-Encoding: 8bit\n\n"
      printf '%s\n\n' "$text_body"
      printf '%s\n' "--${boundary}"
      printf "Content-Type: text/plain; charset=UTF-8; name=\"%s\"\n" "$attachment_name"
      printf "Content-Disposition: attachment; filename=\"%s\"\n" "$attachment_name"
      printf "Content-Transfer-Encoding: 8bit\n\n"
      cat "$attachment"
      printf '%s\n' "--${boundary}--"
    } | "$MSMTP_BIN" "$RESTIC_NOTIFY_EMAIL"
    return
  fi

  if [[ -n "$html_body" ]]; then
    boundary="====restic_alt_$(date +%s%N)===="
    {
      printf "To: %s\n" "$RESTIC_NOTIFY_EMAIL"
      printf "Subject: %s\n" "$subject"
      printf "MIME-Version: 1.0\n"
      printf "Content-Type: multipart/alternative; boundary=\"%s\"\n\n" "$boundary"
      printf '%s\n' "--${boundary}"
      printf "Content-Type: text/plain; charset=UTF-8\n"
      printf "Content-Transfer-Encoding: 8bit\n\n"
      printf '%s\n\n' "$text_body"
      printf '%s\n' "--${boundary}"
      printf "Content-Type: text/html; charset=UTF-8\n"
      printf "Content-Transfer-Encoding: 8bit\n\n"
      printf '%s\n\n' "$html_body"
      printf '%s\n' "--${boundary}--"
    } | "$MSMTP_BIN" "$RESTIC_NOTIFY_EMAIL"
    return
  fi

  printf "To: %s\nSubject: %s\n\n%s\n" \
    "$RESTIC_NOTIFY_EMAIL" "$subject" "$text_body" \
    | "$MSMTP_BIN" "$RESTIC_NOTIFY_EMAIL"
}

build_lock_failure_note() {
  local task_label="$1"

  cat <<EOF
Restic ${task_label} could not acquire the repository lock after waiting ${RESTIC_RETRY_LOCK}.
Only run stale lock cleanup when no restic process is active.

From the repo root:
  make unlock-stale-locks

Direct script:
  ./unlock_stale_locks.sh

The helper refuses to run if a run_backup.sh or restic process is active.
EOF
}

merge_note_text() {
  local existing_note="${1:-}"
  local generated_note="${2:-}"

  if [[ -z "$existing_note" ]]; then
    printf '%s' "$generated_note"
  elif [[ -z "$generated_note" ]]; then
    printf '%s' "$existing_note"
  else
    printf '%s\n\n%s' "$existing_note" "$generated_note"
  fi
}

build_generic_restic_failure_note() {
  local task_label="$1"

  cat <<EOF
Restic ${task_label} failed for a non-lock reason.
See the attached log for the failure cause before taking action.
Only use restic unlock if the log explicitly mentions repository lock errors.
EOF
}

log_has_lock_failure() {
  [[ -f "$LOGFILE" ]] || return 1
  grep -Eiq 'repo already locked|repository is already locked|unable to create lock in backend|failed to lock repository|remove stale locks' "$LOGFILE"
}

notify_failure() {
  local exit_code="$1"
  local task_label="${2:-$TASK}"
  local force_send="${3:-false}"
  local note_text="${4:-}"
  local subject_suffix="${5:-}"
  local status_label="FAIL"
  local subject_summary="failed"
  local body_summary="failed"
  local heading_text
  local subject body
  local html_body extra_rows repo_value attachment_name

  if [[ -z "${RESTIC_NOTIFY_EMAIL:-}" ]]; then
    return 0
  fi

  if ! is_true "$force_send" && ! is_true "${RESTIC_NOTIFY_ON_FAILURE:-true}"; then
    return 0
  fi

  if ! msmtp_available; then
    log "[WARN] msmtp not found; skipping failure notification"
    return 0
  fi

  if [[ "$task_label" == "backup" && "$exit_code" -eq 3 ]]; then
    status_label="WARN"
    subject_summary="completed with warnings"
    body_summary="completed with warnings"
    note_text=$(merge_note_text "$note_text" "Backup completed with unreadable source files; the snapshot may be incomplete.")
  elif [[ ( "$task_label" == "backup" || "$task_label" == "prune" ) ]] && \
       { [[ "$exit_code" -eq 11 ]] || log_has_lock_failure; }; then
    note_text=$(merge_note_text "$note_text" "$(build_lock_failure_note "$task_label")")
  elif [[ "$exit_code" -eq 1 && ( "$task_label" == "backup" || "$task_label" == "prune" ) ]]; then
    note_text=$(merge_note_text "$note_text" "$(build_generic_restic_failure_note "$task_label")")
  fi

  heading_text="Restic ${task_label} ${subject_summary}"
  subject="${RESTIC_NOTIFY_SUBJECT_PREFIX:-[restic]} ${task_label} ${subject_summary} on ${RESTIC_HOST:-unknown}${subject_suffix}"
  attachment_name=$(basename "$LOGFILE")
  body="Restic ${task_label} ${body_summary} on ${RESTIC_HOST:-unknown} at ${TIMESTAMP} with exit code ${exit_code}.
Repo: ${RESTIC_REPO_DISPLAY_VALUE:-unset}
Log: ${LOGFILE}
Attached log: ${attachment_name}"
  extra_rows="$(build_html_row "Exit code" "$exit_code")"
  repo_value="${RESTIC_REPO_DISPLAY_VALUE:-unset}"
  extra_rows+=$(build_html_row "Attached log" "$attachment_name")

  if [[ "$task_label" == "backup" ]]; then
    body="${body}
Include: ${INCLUDE_FILE}
Exclude: ${EXCLUDE_FILE}"
    extra_rows+=$(build_html_row "Include" "$INCLUDE_FILE")
    extra_rows+=$(build_html_row "Exclude" "$EXCLUDE_FILE")
  fi

  if [[ -n "$note_text" ]]; then
    body="${body}
Note: ${note_text}"
  fi

  html_body=$(build_notification_html "$status_label" "$heading_text" "$task_label" "$repo_value" "$extra_rows" "$note_text")

  if ! send_email_message "$subject" "$body" "$html_body" "$LOGFILE"; then
    log "[WARN] Failed to send failure email via msmtp"
    return 1
  else
    log "[INFO] Failure email sent."
    return 0
  fi
}

notify_success() {
  local task_label="${1:-$TASK}"
  local repo_value="${2:-}"
  local force_send="${3:-false}"
  local note_text="${4:-}"
  local subject_suffix="${5:-}"
  local subject body
  local html_body attachment_name extra_rows

  if [[ -z "${RESTIC_NOTIFY_EMAIL:-}" ]]; then
    return 0
  fi

  if ! is_true "$force_send" && ! is_true "${RESTIC_NOTIFY_ON_SUCCESS:-false}"; then
    return 0
  fi

  if ! msmtp_available; then
    log "[WARN] msmtp not found; skipping success notification"
    return 0
  fi

  subject="${RESTIC_NOTIFY_SUBJECT_PREFIX:-[restic]} ${task_label} succeeded on ${RESTIC_HOST:-unknown}${subject_suffix}"
  attachment_name=$(basename "$LOGFILE")
  body="Restic ${task_label} succeeded on ${RESTIC_HOST:-unknown} at ${TIMESTAMP}."
  if [[ -n "$repo_value" ]]; then
    body="${body}
Repo: ${repo_value}"
  fi
  body="${body}
Log: ${LOGFILE}
Attached log: ${attachment_name}"
  if [[ -n "$note_text" ]]; then
    body="${body}
Note: ${note_text}"
  fi

  extra_rows=$(build_html_row "Attached log" "$attachment_name")
  html_body=$(build_notification_html "OK" "Restic ${task_label} succeeded" "$task_label" "$repo_value" "$extra_rows" "$note_text")

  if ! send_email_message "$subject" "$body" "$html_body" "$LOGFILE"; then
    log "[WARN] Failed to send success email via msmtp"
    return 1
  else
    log "[INFO] Success email sent."
    return 0
  fi
}

run_test_email() {
  local mode="$1"
  local subject body task_name notification_label note_text html_body status_label attachment_name extra_rows

  if [[ -z "${RESTIC_NOTIFY_EMAIL:-}" ]]; then
    log "ERROR: RESTIC_NOTIFY_EMAIL is not set."
    return 1
  fi

  if ! msmtp_available; then
    log "ERROR: msmtp not found at '$MSMTP_BIN'."
    return 1
  fi

  case "$mode" in
    generic)
      task_name="test-email"
      notification_label="generic notification path test"
      subject="${RESTIC_NOTIFY_SUBJECT_PREFIX:-[restic]} test email from ${RESTIC_HOST:-unknown}"
      status_label="INFO"
      note_text="This is a generic notification path test. It does not contact the restic repository."
      ;;
    success)
      notify_success "backup" "${RESTIC_REPO_DISPLAY_VALUE:-unset}" "true" \
        "This is a simulated backup success notification." " [test]"
      return $?
      ;;
    failure)
      notify_failure 1 "backup" "true" \
        "This is a simulated generic backup failure notification." " [test]"
      return $?
      ;;
    warning)
      notify_failure 3 "backup" "true" \
        "This is a simulated backup warning notification." " [test]"
      return $?
      ;;
    lock-failure)
      notify_failure 11 "backup" "true" \
        "This is a simulated backup lock-failure notification." " [test]"
      return $?
      ;;
    *)
      log "ERROR: Unsupported test email mode: $mode"
      return 1
      ;;
  esac

  body="This is a test email from run_backup.sh.
Task: ${task_name}
Notification: ${notification_label}
Host: ${RESTIC_HOST:-unknown}
Repo: ${RESTIC_REPO_DISPLAY_VALUE:-unset}
Log: ${LOGFILE}
Attached log: $(basename "$LOGFILE")
Timestamp: ${TIMESTAMP}"

  attachment_name=$(basename "$LOGFILE")
  extra_rows="$(build_html_row "Notification" "$notification_label")"
  extra_rows+=$(build_html_row "Attached log" "$attachment_name")
  html_body=$(build_notification_html "$status_label" "Restic notification test" "$task_name" "${RESTIC_REPO_DISPLAY_VALUE:-unset}" \
    "$extra_rows" "$note_text")

  if ! send_email_message "$subject" "$body" "$html_body" "$LOGFILE"; then
    log "ERROR: Failed to send test email via msmtp."
    return 1
  fi

  log "Test email sent successfully."
  return 0
}
