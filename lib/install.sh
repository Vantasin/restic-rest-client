# Managed-asset reconciliation for bootstrap.sh. No personal config is stored here.

# Select an update without overwriting a customization. Unknown legacy files
# are preserved; exact historical template matches can be safely upgraded.
reconcile_plist() {
  local current="$1" template="$2" baseline="$3" output="$4" relative="$5"
  local revision historical
  if [[ "$force" == true || ! -f "$current" ]] || cmp -s "$current" "$template"; then
    cp "$template" "$output"
    return
  fi
  if [[ -f "$baseline" ]]; then
    if cmp -s "$current" "$baseline"; then
      cp "$template" "$output"
    elif cmp -s "$baseline" "$template"; then
      echo "PRESERVED: customized $current"
      cp "$current" "$output"
    else
      echo "CONFLICT: customized $current also has template changes."
      echo "Review this diff and reconcile both local and installed plists with the new template."
      echo "See Docs/BOOTSTRAP.md for conflict recovery; then rerun install:"
      diff -u "$current" "$template" || true
      return 1
    fi
    return
  fi
  historical="${output}.historical"
  if command -v git >/dev/null 2>&1; then
    for revision in ${(f)"$(git -C "$SCRIPT_DIR" log --format=%H -- "$relative" 2>/dev/null)"}; do
      [[ -n "$revision" ]] || continue
      git -C "$SCRIPT_DIR" show "$revision:$relative" > "${historical}.template" 2>/dev/null || continue
      render_template_file "${historical}.template" "$historical" || return 1
      if cmp -s "$current" "$historical"; then
        echo "UPGRADED: recognized legacy template $current"
        cp "$template" "$output"
        return
      fi
    done
  fi
  echo "PRESERVED: untracked customization in $current (no matching baseline)"
  cp "$current" "$output"
}

# Compare each rule with its old default, preserving comments and overrides.
# Unknown legacy rules are kept; missing managed paths are added exactly once.
reconcile_rotation() {
  local current="$1" template="$2" baseline="$3" output="$4"
  if [[ "$force" == true || ! -f "$current" ]]; then
    cp "$template" "$output"
    return
  fi
  [[ -f "$baseline" ]] || baseline=/dev/null
  awk '
    FILENAME == ARGV[1] { if ($0 !~ /^[[:space:]]*(#|$)/) old[$1]=$0; next }
    FILENAME == ARGV[2] {
      if ($0 !~ /^[[:space:]]*(#|$)/) { fresh[$1]=$0; order[++n]=$1 }
      next
    }
    /^[[:space:]]*(#|$)/ { print; next }
    {
      key=$1
      if (key in fresh) {
        if (seen[key]++) {
          print "CONFLICT: duplicate managed rotation rule: " key > "/dev/stderr"
          failed=1
        }
        if (key in old && $0 == old[key]) print fresh[key]
        else {
          print
          if ($0 != fresh[key]) print "PRESERVED: custom/legacy rotation rule: " key > "/dev/stderr"
        }
      } else if (!(key in old) || $0 != old[key]) print
    }
    END {
      for (i=1;i<=n;i++) if (!(order[i] in seen)) print fresh[order[i]]
      if (failed) exit 1
    }
  ' "$baseline" "$template" "$current" > "$output"
}

prepare_managed_assets() {
  local work="$1" agents_dir="$2" name local_file installed_file
  mkdir -p "$work/candidates" "$work/defaults" "$work/previous-local" "$work/previous-baselines" || return 1
  for name in "$BACKUP_PLIST_NAME" "$CHECK_PLIST_NAME" "$PRUNE_PLIST_NAME" "$LOGCLEANUP_PLIST_NAME"; do
    local_file="$SCRIPT_DIR/launchd/$name"
    installed_file="$agents_dir/$name"
    render_template_file "$local_file.example" "$work/defaults/$name" || return 1
    reconcile_plist "$local_file" "$work/defaults/$name" "$MANAGED_BASELINES/$name" "$work/local-$name" "launchd/$name.example" || return 1
    reconcile_plist "$installed_file" "$work/defaults/$name" "$MANAGED_BASELINES/$name" "$work/installed-$name" "launchd/$name.example" || return 1
    # An override in either location is retained. Different overrides need an
    # explicit local resolution instead of silently overwriting installed edits.
    if ! cmp -s "$work/local-$name" "$work/defaults/$name" && \
       ! cmp -s "$work/installed-$name" "$work/defaults/$name" && \
       ! cmp -s "$work/local-$name" "$work/installed-$name"; then
      echo "CONFLICT: local and installed $name contain different customizations."
      diff -u "$local_file" "$installed_file" || true
      return 1
    fi
    if ! cmp -s "$work/local-$name" "$work/defaults/$name"; then
      cp "$work/local-$name" "$work/candidates/$name" || return 1
    else
      cp "$work/installed-$name" "$work/candidates/$name" || return 1
    fi
    plutil -lint "$work/candidates/$name" || return 1
    backup_existing_install_file "$local_file" "$work/previous-local" "$name" || return 1
    backup_existing_install_file "$installed_file" "$work" "$name" || return 1
  done
  if [[ -d "$MANAGED_BASELINES" ]]; then
    cp -R "$MANAGED_BASELINES/." "$work/previous-baselines/" || return 1
  fi
  render_template_file "$SCRIPT_DIR/newsyslog/$NEWSYSLOG_TEMPLATE_NAME" "$work/defaults/newsyslog.conf" || return 1
  if sudo test -f "$NEWSYSLOG_DEST"; then
    sudo cat "$NEWSYSLOG_DEST" > "$work/newsyslog.conf" || return 1
  fi
  reconcile_rotation "$work/newsyslog.conf" "$work/defaults/newsyslog.conf" "$MANAGED_BASELINES/newsyslog.conf" "$work/candidates/newsyslog.conf" || return 1
  sudo newsyslog -n -f "$work/candidates/newsyslog.conf" || return 1
}

apply_managed_assets() {
  local work="$1" agents_dir="$2" prune_enabled="$3" name label
  for label in "$BACKUP_LABEL" "$CHECK_LABEL" "$PRUNE_LABEL" "$LOGCLEANUP_LABEL"; do
    launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
  done
  for name in "$BACKUP_PLIST_NAME" "$CHECK_PLIST_NAME" "$PRUNE_PLIST_NAME" "$LOGCLEANUP_PLIST_NAME"; do
    cp "$work/candidates/$name" "$SCRIPT_DIR/launchd/$name" || return 1
    if [[ "$name" == "$PRUNE_PLIST_NAME" ]] && ! is_true "$prune_enabled"; then
      rm -f "$agents_dir/$name" || return 1
    else
      cp "$work/candidates/$name" "$agents_dir/$name" || return 1
      echo "INSTALLED: $agents_dir/$name"
    fi
  done
  sudo install -m 0640 "$work/candidates/newsyslog.conf" "$NEWSYSLOG_DEST" || return 1
  echo "INSTALLED: $NEWSYSLOG_DEST"
  for label in "$LOGCLEANUP_LABEL" "$CHECK_LABEL" "$PRUNE_LABEL" "$BACKUP_LABEL"; do
    if [[ "$label" == "$PRUNE_LABEL" ]] && ! is_true "$prune_enabled"; then
      verify_launchd_unloaded "$label" || return 1
    else
      launchctl load "$agents_dir/$label.plist" || return 1
      verify_launchd_loaded "$label" || return 1
    fi
  done
  mkdir -p "$MANAGED_BASELINES" || return 1
  cp "$work/defaults/"* "$MANAGED_BASELINES/" || return 1
}

run_install_transaction() {
  local agents_dir="$HOME_DIR/Library/LaunchAgents" work prune_enabled name
  local backup_was_loaded=false check_was_loaded=false prune_was_loaded=false logcleanup_was_loaded=false
  local rollback_status=0
  [[ "${EUID:-0}" -ne 0 ]] || { echo 'ERROR: install must run as your user, not root.'; return 1; }
  for name in launchctl sudo newsyslog plutil; do
    command -v "$name" >/dev/null || { echo "ERROR: missing $name"; return 1; }
  done
  # Authenticate before treating a failed privileged existence check as absence.
  sudo -v || return 1
  prune_enabled="$(load_prune_preference)" || return 1
  mkdir -p "$agents_dir" || return 1
  work="$(mktemp -d)" || return 1
  if ! prepare_managed_assets "$work" "$agents_dir"; then
    echo 'ERROR: managed-asset preflight failed; installed assets were not changed.'
    rm -rf "$work"
    return 1
  fi
  launchd_label_is_loaded "$BACKUP_LABEL" && backup_was_loaded=true
  launchd_label_is_loaded "$CHECK_LABEL" && check_was_loaded=true
  launchd_label_is_loaded "$PRUNE_LABEL" && prune_was_loaded=true
  launchd_label_is_loaded "$LOGCLEANUP_LABEL" && logcleanup_was_loaded=true
  if ! apply_managed_assets "$work" "$agents_dir" "$prune_enabled"; then
    # Restore local files and baseline tracking before reloading old agents.
    for name in "$BACKUP_PLIST_NAME" "$CHECK_PLIST_NAME" "$PRUNE_PLIST_NAME" "$LOGCLEANUP_PLIST_NAME"; do
      restore_user_install_file "$work/previous-local" "$name" "$SCRIPT_DIR/launchd/$name" || rollback_status=1
    done
    rm -rf "$MANAGED_BASELINES" || rollback_status=1
    mkdir -p "$MANAGED_BASELINES" || rollback_status=1
    cp -R "$work/previous-baselines/." "$MANAGED_BASELINES/" || rollback_status=1
    rollback_install_state "$work" "$agents_dir" "$NEWSYSLOG_DEST" "$backup_was_loaded" "$check_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || rollback_status=1
    if [[ $rollback_status -eq 0 ]]; then
      rm -rf "$work"
    else
      echo "ERROR: rollback incomplete; recovery files retained at $work"
    fi
    return 1
  fi
  rm -rf "$work"
  echo 'VERIFIED: managed assets reconciled; personal configuration preserved unless --force was requested.'
}
