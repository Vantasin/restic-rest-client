#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$HOME"
USER_NAME="${USER:-$(id -un)}"
HOST_NAME="${HOSTNAME:-}"
BACKUP_LABEL="com.restic-rest-client.backup"
PRUNE_LABEL="com.restic-rest-client.prune"
LOGCLEANUP_LABEL="com.restic-rest-client.logcleanup"
BACKUP_PLIST_NAME="${BACKUP_LABEL}.plist"
PRUNE_PLIST_NAME="${PRUNE_LABEL}.plist"
LOGCLEANUP_PLIST_NAME="${LOGCLEANUP_LABEL}.plist"
NEWSYSLOG_TEMPLATE_NAME="com.restic-rest-client.conf.example"
NEWSYSLOG_DEST="/etc/newsyslog.d/com.restic-rest-client.conf"

if [[ -z "$HOST_NAME" ]]; then
  if command -v scutil >/dev/null 2>&1; then
    HOST_NAME="$(scutil --get ComputerName 2>/dev/null || true)"
  fi
fi
HOST_NAME="${HOST_NAME:-$(hostname -s 2>/dev/null || echo "your-mac")}"
HOST_NAME_SLUG="$(
  printf '%s' "$HOST_NAME" |
    tr '[:upper:]' '[:lower:]' |
    sed -E \
      -e 's/[^a-z0-9._-]+/-/g' \
      -e 's/^-+//; s/-+$//' \
      -e 's/-+/-/g'
)"
HOST_NAME_SLUG="${HOST_NAME_SLUG:-restic-client}"

force=false
do_generate=false
do_install=false
do_uninstall=false

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh --generate [--force]
       ./bootstrap.sh --install [--force]
       ./bootstrap.sh --uninstall

Generate host-specific config from the *.example templates:
- restic.env
- restic-include-macos.txt
- restic-exclude-macos.txt
- launchd/*.plist

Placeholders replaced:
- {{HOME}}       -> your home directory
- {{USER}}       -> your username
- {{SCRIPT_DIR}} -> repo directory containing this script
- {{HOSTNAME}}   -> system hostname (ComputerName)
- {{HOSTNAME_SLUG}} -> URL-safe hostname slug derived from ComputerName

Optional:
- --generate   Generate local files only
- --install    Generate local files and install launchd/newsyslog
- --uninstall  Unload/remove launchd and newsyslog, and remove local files
- --force      Overwrite local files and /etc/newsyslog.d/com.restic-rest-client.conf
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --generate)
      do_generate=true
      ;;
    --force)
      force=true
      ;;
    --install)
      do_install=true
      ;;
    --uninstall)
      do_uninstall=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

selected_actions=0
[[ "$do_generate" == "true" ]] && ((selected_actions+=1))
[[ "$do_install" == "true" ]] && ((selected_actions+=1))
[[ "$do_uninstall" == "true" ]] && ((selected_actions+=1))

if (( selected_actions > 1 )); then
  echo "ERROR: choose only one of --generate, --install, or --uninstall."
  exit 1
fi

if (( selected_actions == 0 )); then
  echo "ERROR: must specify --generate, --install, or --uninstall."
  usage
  exit 1
fi

escape_sed() {
  printf "%s" "$1" | sed -e 's/[&|\\/]/\\&/g'
}

render_template_file() {
  local src="$1"
  local dest="$2"
  local home_escaped user_escaped script_escaped host_escaped host_slug_escaped

  if [[ ! -f "$src" ]]; then
    echo "ERROR: template not found: $src"
    return 1
  fi

  home_escaped="$(escape_sed "$HOME_DIR")"
  user_escaped="$(escape_sed "$USER_NAME")"
  script_escaped="$(escape_sed "$SCRIPT_DIR")"
  host_escaped="$(escape_sed "$HOST_NAME")"
  host_slug_escaped="$(escape_sed "$HOST_NAME_SLUG")"

  sed \
    -e "s|{{HOME}}|${home_escaped}|g" \
    -e "s|{{USER}}|${user_escaped}|g" \
    -e "s|{{SCRIPT_DIR}}|${script_escaped}|g" \
    -e "s|{{HOSTNAME}}|${host_escaped}|g" \
    -e "s|{{HOSTNAME_SLUG}}|${host_slug_escaped}|g" \
    "$src" > "$dest"
}

write_from_template() {
  local src="$1"
  local dest="$2"
  local tmp

  if [[ ! -f "$src" ]]; then
    echo "ERROR: template not found: $src"
    return 1
  fi

  if [[ -e "$dest" && "$force" != "true" ]]; then
    echo "SKIP: $dest already exists"
    return 0
  fi

  tmp="${dest}.tmp"

  render_template_file "$src" "$tmp" || return 1

  mv "$tmp" "$dest"
  echo "WROTE: $dest"
}

remove_file() {
  local target="$1"

  if [[ -e "$target" ]]; then
    rm -f "$target"
    echo "REMOVED: $target"
    if [[ -e "$target" ]]; then
      echo "ERROR: failed to remove $target"
      exit 1
    fi
  else
    echo "SKIP: $target not found"
  fi
}

copy_launchd_agent() {
  local plist_name="$1"
  local target_dir="$2"

  cp "$SCRIPT_DIR/launchd/$plist_name" "$target_dir/"
  echo "COPIED: $target_dir/$plist_name"

  if [[ ! -f "$target_dir/$plist_name" ]]; then
    echo "ERROR: missing $target_dir/$plist_name after copy."
    return 1
  fi
}

verify_launchd_loaded() {
  local label="$1"

  if ! launchctl print "gui/$UID/$label" >/dev/null 2>&1; then
    echo "ERROR: $label failed to load."
    return 1
  fi

  echo "VERIFIED: $label loaded"
}

verify_launchd_unloaded() {
  local label="$1"

  if launchctl print "gui/$UID/$label" >/dev/null 2>&1; then
    echo "ERROR: $label still loaded"
    return 1
  fi

  echo "VERIFIED: $label unloaded"
}

launchd_label_is_loaded() {
  local label="$1"
  launchctl print "gui/$UID/$label" >/dev/null 2>&1
}

backup_existing_install_file() {
  local src="$1"
  local state_dir="$2"
  local backup_name="$3"
  local use_sudo="${4:-false}"

  if is_true "$use_sudo"; then
    if sudo test -f "$src"; then
      sudo cp "$src" "$state_dir/$backup_name" || return 1
    fi
  elif [[ -f "$src" ]]; then
    cp "$src" "$state_dir/$backup_name" || return 1
  fi
}

restore_user_install_file() {
  local state_dir="$1"
  local backup_name="$2"
  local dest="$3"

  if [[ -f "$state_dir/$backup_name" ]]; then
    cp "$state_dir/$backup_name" "$dest" || return 1
    echo "RESTORED: $dest"
  else
    rm -f "$dest" || return 1
    echo "ROLLED BACK: removed $dest"
  fi
}

restore_sudo_install_file() {
  local state_dir="$1"
  local backup_name="$2"
  local dest="$3"

  if [[ -f "$state_dir/$backup_name" ]]; then
    sudo install -m 0640 "$state_dir/$backup_name" "$dest" || return 1
    echo "RESTORED: $dest"
  else
    sudo rm -f "$dest" || return 1
    echo "ROLLED BACK: removed $dest"
  fi
}

rollback_install_state() {
  local state_dir="$1"
  local agents_dir="$2"
  local dst_conf="$3"
  local backup_was_loaded="$4"
  local prune_was_loaded="$5"
  local logcleanup_was_loaded="$6"
  local rollback_status=0

  echo "ROLLBACK: restoring launchd/newsyslog install state..."

  set +e

  launchctl bootout "gui/$UID/$BACKUP_LABEL" >/dev/null 2>&1 || true
  launchctl bootout "gui/$UID/$PRUNE_LABEL" >/dev/null 2>&1 || true
  launchctl bootout "gui/$UID/$LOGCLEANUP_LABEL" >/dev/null 2>&1 || true

  restore_user_install_file "$state_dir" "$BACKUP_PLIST_NAME" "$agents_dir/$BACKUP_PLIST_NAME" || rollback_status=1
  restore_user_install_file "$state_dir" "$PRUNE_PLIST_NAME" "$agents_dir/$PRUNE_PLIST_NAME" || rollback_status=1
  restore_user_install_file "$state_dir" "$LOGCLEANUP_PLIST_NAME" "$agents_dir/$LOGCLEANUP_PLIST_NAME" || rollback_status=1
  restore_sudo_install_file "$state_dir" "newsyslog.conf" "$dst_conf" || rollback_status=1

  if [[ "$logcleanup_was_loaded" == "true" && -f "$agents_dir/$LOGCLEANUP_PLIST_NAME" ]]; then
    launchctl load "$agents_dir/$LOGCLEANUP_PLIST_NAME" >/dev/null 2>&1 || rollback_status=1
  fi
  if [[ "$prune_was_loaded" == "true" && -f "$agents_dir/$PRUNE_PLIST_NAME" ]]; then
    launchctl load "$agents_dir/$PRUNE_PLIST_NAME" >/dev/null 2>&1 || rollback_status=1
  fi
  if [[ "$backup_was_loaded" == "true" && -f "$agents_dir/$BACKUP_PLIST_NAME" ]]; then
    launchctl load "$agents_dir/$BACKUP_PLIST_NAME" >/dev/null 2>&1 || rollback_status=1
  fi

  set -e

  if [[ $rollback_status -ne 0 ]]; then
    echo "ERROR: rollback did not fully restore the previous install state."
    return 1
  fi

  echo "ROLLBACK: previous install state restored."
}

load_prune_preference() {
  local prune_enabled

  if [[ ! -f "$SCRIPT_DIR/restic.env" ]]; then
    printf 'false'
    return 0
  fi

  # Evaluate restic.env in a helper shell so quoted values and inline comments
  # behave the same way as normal runtime sourcing. Stub Keychain lookups so
  # install can still inspect prune mode before the user stores passwords.
  if ! prune_enabled="$(
    zsh -c '
      security() {
        printf "%s\n" "stub"
      }

      source "$1"
      printf "%s" "${RESTIC_PRUNE_ENABLED:-false}"
    ' zsh "$SCRIPT_DIR/restic.env"
  )"; then
    echo "ERROR: failed to evaluate RESTIC_PRUNE_ENABLED from $SCRIPT_DIR/restic.env"
    return 1
  fi

  printf '%s' "$prune_enabled"
}

run_install_transaction() {
  local prune_enabled
  local agents_dir local_conf tmp_conf dst_conf state_dir
  local backup_was_loaded=false
  local prune_was_loaded=false
  local logcleanup_was_loaded=false
  local install_newsyslog=false

  echo "Installing launchd agents..."
  if [[ "${EUID:-0}" -eq 0 ]]; then
    echo "ERROR: --install must be run as your user, not root."
    return 1
  fi

  if ! command -v launchctl >/dev/null 2>&1; then
    echo "ERROR: launchctl not found. Are you running on macOS?"
    return 1
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo not found."
    return 1
  fi

  if ! command -v newsyslog >/dev/null 2>&1; then
    echo "ERROR: newsyslog not found; cannot validate."
    return 1
  fi

  prune_enabled="$(load_prune_preference)" || return 1
  agents_dir="$HOME_DIR/Library/LaunchAgents"
  mkdir -p "$agents_dir"

  [[ -f "$SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME" ]] || { echo "ERROR: missing $SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME"; return 1; }
  [[ -f "$SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME" ]] || { echo "ERROR: missing $SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME"; return 1; }
  if is_true "$prune_enabled"; then
    [[ -f "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME" ]] || { echo "ERROR: missing $SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME"; return 1; }
  fi

  local_conf="$SCRIPT_DIR/newsyslog/$NEWSYSLOG_TEMPLATE_NAME"
  tmp_conf="$SCRIPT_DIR/newsyslog/com.restic-rest-client.conf.tmp"
  dst_conf="$NEWSYSLOG_DEST"

  if [[ ! -f "$local_conf" ]]; then
    echo "ERROR: template not found: $local_conf"
    return 1
  fi

  if ! render_template_file "$local_conf" "$tmp_conf"; then
    rm -f "$tmp_conf"
    return 1
  fi

  if [[ -e "$dst_conf" && "$force" != "true" ]]; then
    echo "SKIP: $dst_conf already exists (use --force to overwrite)."
    echo "Validating installed newsyslog config before loading launchd agents..."
    if ! sudo newsyslog -n -f "$dst_conf"; then
      rm -f "$tmp_conf"
      echo "ERROR: newsyslog validation failed for $dst_conf."
      return 1
    fi
  else
    install_newsyslog=true
    echo "Validating newsyslog config before loading launchd agents..."
    if ! sudo newsyslog -n -f "$tmp_conf"; then
      rm -f "$tmp_conf"
      echo "ERROR: newsyslog validation failed for $tmp_conf."
      return 1
    fi
  fi

  if launchd_label_is_loaded "$BACKUP_LABEL"; then
    backup_was_loaded=true
  fi
  if launchd_label_is_loaded "$PRUNE_LABEL"; then
    prune_was_loaded=true
  fi
  if launchd_label_is_loaded "$LOGCLEANUP_LABEL"; then
    logcleanup_was_loaded=true
  fi

  if ! state_dir="$(mktemp -d)"; then
    rm -f "$tmp_conf"
    echo "ERROR: failed to create a temporary install-state directory."
    return 1
  fi
  backup_existing_install_file "$agents_dir/$BACKUP_PLIST_NAME" "$state_dir" "$BACKUP_PLIST_NAME" || { rm -f "$tmp_conf"; rm -rf "$state_dir"; return 1; }
  backup_existing_install_file "$agents_dir/$PRUNE_PLIST_NAME" "$state_dir" "$PRUNE_PLIST_NAME" || { rm -f "$tmp_conf"; rm -rf "$state_dir"; return 1; }
  backup_existing_install_file "$agents_dir/$LOGCLEANUP_PLIST_NAME" "$state_dir" "$LOGCLEANUP_PLIST_NAME" || { rm -f "$tmp_conf"; rm -rf "$state_dir"; return 1; }
  backup_existing_install_file "$dst_conf" "$state_dir" "newsyslog.conf" "true" || { rm -f "$tmp_conf"; rm -rf "$state_dir"; return 1; }

  if is_true "$install_newsyslog"; then
    echo "Installing newsyslog config..."
    if ! sudo install -m 0640 "$tmp_conf" "$dst_conf"; then
      rm -f "$tmp_conf"
      rm -rf "$state_dir"
      return 1
    fi
    echo "INSTALLED: $dst_conf"
  fi

  if ! sudo test -f "$dst_conf"; then
    echo "ERROR: $dst_conf not found after install."
    rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
    rm -f "$tmp_conf"
    rm -rf "$state_dir"
    return 1
  fi

  if ! copy_launchd_agent "$BACKUP_PLIST_NAME" "$agents_dir"; then
    rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
    rm -f "$tmp_conf"
    rm -rf "$state_dir"
    return 1
  fi

  if ! copy_launchd_agent "$LOGCLEANUP_PLIST_NAME" "$agents_dir"; then
    rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
    rm -f "$tmp_conf"
    rm -rf "$state_dir"
    return 1
  fi

  if is_true "$prune_enabled"; then
    if ! copy_launchd_agent "$PRUNE_PLIST_NAME" "$agents_dir"; then
      rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
      rm -f "$tmp_conf"
      rm -rf "$state_dir"
      return 1
    fi
  fi

  launchctl bootout "gui/$UID/$BACKUP_LABEL" >/dev/null 2>&1 || true
  launchctl bootout "gui/$UID/$PRUNE_LABEL" >/dev/null 2>&1 || true
  launchctl bootout "gui/$UID/$LOGCLEANUP_LABEL" >/dev/null 2>&1 || true

  if ! launchctl load "$agents_dir/$LOGCLEANUP_PLIST_NAME"; then
    rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
    rm -f "$tmp_conf"
    rm -rf "$state_dir"
    return 1
  fi

  if is_true "$prune_enabled"; then
    if ! launchctl load "$agents_dir/$PRUNE_PLIST_NAME"; then
      rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
      rm -f "$tmp_conf"
      rm -rf "$state_dir"
      return 1
    fi
  else
    if [[ -e "$agents_dir/$PRUNE_PLIST_NAME" ]]; then
      rm -f "$agents_dir/$PRUNE_PLIST_NAME"
      if [[ -e "$agents_dir/$PRUNE_PLIST_NAME" ]]; then
        echo "ERROR: failed to remove $agents_dir/$PRUNE_PLIST_NAME"
        rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
        rm -f "$tmp_conf"
        rm -rf "$state_dir"
        return 1
      fi
      echo "REMOVED: $agents_dir/$PRUNE_PLIST_NAME"
    else
      echo "SKIP: $agents_dir/$PRUNE_PLIST_NAME not found"
    fi
  fi

  if ! launchctl load "$agents_dir/$BACKUP_PLIST_NAME"; then
    rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
    rm -f "$tmp_conf"
    rm -rf "$state_dir"
    return 1
  fi

  if ! verify_launchd_loaded "$LOGCLEANUP_LABEL"; then
    rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
    rm -f "$tmp_conf"
    rm -rf "$state_dir"
    return 1
  fi

  if is_true "$prune_enabled"; then
    if ! verify_launchd_loaded "$PRUNE_LABEL"; then
      rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
      rm -f "$tmp_conf"
      rm -rf "$state_dir"
      return 1
    fi
  else
    if ! verify_launchd_unloaded "$PRUNE_LABEL"; then
      rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
      rm -f "$tmp_conf"
      rm -rf "$state_dir"
      return 1
    fi
    echo "SKIP: prune launch agent not installed because RESTIC_PRUNE_ENABLED is not true."
  fi

  if ! verify_launchd_loaded "$BACKUP_LABEL"; then
    rollback_install_state "$state_dir" "$agents_dir" "$dst_conf" "$backup_was_loaded" "$prune_was_loaded" "$logcleanup_was_loaded" || true
    rm -f "$tmp_conf"
    rm -rf "$state_dir"
    return 1
  fi

  echo "VERIFIED: $dst_conf"
  rm -f "$tmp_conf"
  rm -rf "$state_dir"
}

if [[ "$do_generate" == "true" || "$do_install" == "true" ]]; then
  write_from_template "$SCRIPT_DIR/restic.env.example" "$SCRIPT_DIR/restic.env"
  [[ -f "$SCRIPT_DIR/restic.env" ]] && chmod 600 "$SCRIPT_DIR/restic.env"

  write_from_template "$SCRIPT_DIR/restic-include-macos.txt.example" "$SCRIPT_DIR/restic-include-macos.txt"
  write_from_template "$SCRIPT_DIR/restic-exclude-macos.txt.example" "$SCRIPT_DIR/restic-exclude-macos.txt"

  write_from_template "$SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME.example" "$SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME"
  write_from_template "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME.example" "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME"
  write_from_template "$SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME.example" "$SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME"
fi

if [[ "$do_install" == "true" ]]; then
  run_install_transaction || exit 1
fi

if [[ "$do_uninstall" == "true" ]]; then
  echo "Uninstalling launchd agents..."
  if [[ "${EUID:-0}" -eq 0 ]]; then
    echo "ERROR: --uninstall must be run as your user, not root."
    exit 1
  fi

  if ! command -v launchctl >/dev/null 2>&1; then
    echo "ERROR: launchctl not found. Are you running on macOS?"
    exit 1
  fi

  agents_dir="$HOME_DIR/Library/LaunchAgents"
  launchctl bootout "gui/$UID/$BACKUP_LABEL" >/dev/null 2>&1 || true
  launchctl bootout "gui/$UID/$PRUNE_LABEL" >/dev/null 2>&1 || true
  launchctl bootout "gui/$UID/$LOGCLEANUP_LABEL" >/dev/null 2>&1 || true

  remove_file "$agents_dir/$BACKUP_PLIST_NAME"
  remove_file "$agents_dir/$PRUNE_PLIST_NAME"
  remove_file "$agents_dir/$LOGCLEANUP_PLIST_NAME"

  verify_launchd_unloaded "$BACKUP_LABEL"
  verify_launchd_unloaded "$PRUNE_LABEL"
  verify_launchd_unloaded "$LOGCLEANUP_LABEL"
fi

if [[ "$do_uninstall" == "true" ]]; then
  dst_conf="$NEWSYSLOG_DEST"

  echo "Uninstalling newsyslog config..."
  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo not found."
    exit 1
  fi

  if sudo test -f "$dst_conf"; then
    sudo rm -f "$dst_conf"
    echo "REMOVED: $dst_conf"
    if sudo test -f "$dst_conf"; then
      echo "ERROR: failed to remove $dst_conf"
      exit 1
    fi
    echo "VERIFIED: $dst_conf removed"
  else
    echo "SKIP: $dst_conf not found"
  fi
fi

if [[ "$do_uninstall" == "true" ]]; then
  echo "Removing local generated files..."
  remove_file "$SCRIPT_DIR/restic.env"
  remove_file "$SCRIPT_DIR/restic-include-macos.txt"
  remove_file "$SCRIPT_DIR/restic-exclude-macos.txt"
  remove_file "$SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME"
  remove_file "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME"
  remove_file "$SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME"
  echo "VERIFIED: local generated files removed"
fi
