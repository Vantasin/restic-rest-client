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

force=false
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
Usage: ./bootstrap.sh --install [--force]
       ./bootstrap.sh --uninstall

Generate host-specific config from the *.example templates:
- restic.env
- restic-repository.txt
- restic-include-macos.txt
- restic-exclude-macos.txt
- launchd/*.plist

Placeholders replaced:
- {{HOME}}       -> your home directory
- {{USER}}       -> your username
- {{SCRIPT_DIR}} -> repo directory containing this script
- {{HOSTNAME}}   -> system hostname (ComputerName)

Optional:
- --install    Generate local files and install launchd/newsyslog
- --uninstall  Unload/remove launchd and newsyslog, and remove local files
- --force      Overwrite local files and /etc/newsyslog.d/com.restic-rest-client.conf
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ "$do_install" == "true" && "$do_uninstall" == "true" ]]; then
  echo "ERROR: choose only one of --install or --uninstall."
  exit 1
fi

if [[ "$do_install" != "true" && "$do_uninstall" != "true" ]]; then
  echo "ERROR: must specify --install or --uninstall."
  usage
  exit 1
fi

escape_sed() {
  printf "%s" "$1" | sed -e 's/[&|\\/]/\\&/g'
}

write_from_template() {
  local src="$1"
  local dest="$2"
  local home_escaped user_escaped script_escaped host_escaped tmp

  if [[ ! -f "$src" ]]; then
    echo "ERROR: template not found: $src"
    return 1
  fi

  if [[ -e "$dest" && "$force" != "true" ]]; then
    echo "SKIP: $dest already exists"
    return 0
  fi

  home_escaped="$(escape_sed "$HOME_DIR")"
  user_escaped="$(escape_sed "$USER_NAME")"
  script_escaped="$(escape_sed "$SCRIPT_DIR")"
  host_escaped="$(escape_sed "$HOST_NAME")"
  tmp="${dest}.tmp"

  sed \
    -e "s|{{HOME}}|${home_escaped}|g" \
    -e "s|{{USER}}|${user_escaped}|g" \
    -e "s|{{SCRIPT_DIR}}|${script_escaped}|g" \
    -e "s|{{HOSTNAME}}|${host_escaped}|g" \
    "$src" > "$tmp"

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

  cp "$SCRIPT_DIR/launchd/$plist_name" "$agents_dir/"
  echo "COPIED: $agents_dir/$plist_name"

  if [[ ! -f "$agents_dir/$plist_name" ]]; then
    echo "ERROR: missing $agents_dir/$plist_name after copy."
    exit 1
  fi
}

verify_launchd_loaded() {
  local label="$1"

  if ! launchctl print "gui/$UID/$label" >/dev/null 2>&1; then
    echo "ERROR: $label failed to load."
    exit 1
  fi

  echo "VERIFIED: $label loaded"
}

verify_launchd_unloaded() {
  local label="$1"

  if launchctl print "gui/$UID/$label" >/dev/null 2>&1; then
    echo "ERROR: $label still loaded"
    exit 1
  fi

  echo "VERIFIED: $label unloaded"
}

load_prune_preference() {
  if [[ ! -f "$SCRIPT_DIR/restic.env" ]]; then
    printf 'false'
    return 0
  fi

  unset RESTIC_PRUNE_ENABLED
  source "$SCRIPT_DIR/restic.env"
  printf '%s' "${RESTIC_PRUNE_ENABLED:-false}"
}

if [[ "$do_install" == "true" ]]; then
  write_from_template "$SCRIPT_DIR/restic.env.example" "$SCRIPT_DIR/restic.env"
  [[ -f "$SCRIPT_DIR/restic.env" ]] && chmod 600 "$SCRIPT_DIR/restic.env"

  write_from_template "$SCRIPT_DIR/restic-repository.txt.example" "$SCRIPT_DIR/restic-repository.txt"
  [[ -f "$SCRIPT_DIR/restic-repository.txt" ]] && chmod 600 "$SCRIPT_DIR/restic-repository.txt"

  write_from_template "$SCRIPT_DIR/restic-include-macos.txt.example" "$SCRIPT_DIR/restic-include-macos.txt"
  write_from_template "$SCRIPT_DIR/restic-exclude-macos.txt.example" "$SCRIPT_DIR/restic-exclude-macos.txt"

  write_from_template "$SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME.example" "$SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME"
  write_from_template "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME.example" "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME"
  write_from_template "$SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME.example" "$SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME"
fi

if [[ "$do_install" == "true" ]]; then
  prune_enabled="$(load_prune_preference)"

  echo "Installing launchd agents..."
  if [[ "${EUID:-0}" -eq 0 ]]; then
    echo "ERROR: --install must be run as your user, not root."
    exit 1
  fi

  if ! command -v launchctl >/dev/null 2>&1; then
    echo "ERROR: launchctl not found. Are you running on macOS?"
    exit 1
  fi

  agents_dir="$HOME_DIR/Library/LaunchAgents"
  mkdir -p "$agents_dir"

  [[ -f "$SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME" ]] || { echo "ERROR: missing $SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME"; exit 1; }
  [[ -f "$SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME" ]] || { echo "ERROR: missing $SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME"; exit 1; }

  copy_launchd_agent "$BACKUP_PLIST_NAME"
  copy_launchd_agent "$LOGCLEANUP_PLIST_NAME"

  launchctl unload "$agents_dir/$BACKUP_PLIST_NAME" >/dev/null 2>&1 || true
  launchctl unload "$agents_dir/$LOGCLEANUP_PLIST_NAME" >/dev/null 2>&1 || true

  launchctl load "$agents_dir/$BACKUP_PLIST_NAME"
  launchctl load "$agents_dir/$LOGCLEANUP_PLIST_NAME"
  echo "LOADED: $BACKUP_LABEL"
  echo "LOADED: $LOGCLEANUP_LABEL"

  verify_launchd_loaded "$BACKUP_LABEL"
  verify_launchd_loaded "$LOGCLEANUP_LABEL"

  if is_true "$prune_enabled"; then
    [[ -f "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME" ]] || { echo "ERROR: missing $SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME"; exit 1; }
    copy_launchd_agent "$PRUNE_PLIST_NAME"
    launchctl unload "$agents_dir/$PRUNE_PLIST_NAME" >/dev/null 2>&1 || true
    launchctl load "$agents_dir/$PRUNE_PLIST_NAME"
    echo "LOADED: $PRUNE_LABEL"
    verify_launchd_loaded "$PRUNE_LABEL"
  else
    launchctl bootout "gui/$UID/$PRUNE_LABEL" >/dev/null 2>&1 || true
    remove_file "$agents_dir/$PRUNE_PLIST_NAME"
    verify_launchd_unloaded "$PRUNE_LABEL"
    echo "SKIP: prune launch agent not installed because RESTIC_PRUNE_ENABLED is not true."
  fi
fi

if [[ "$do_install" == "true" ]]; then
  local_conf="$SCRIPT_DIR/newsyslog/$NEWSYSLOG_TEMPLATE_NAME"
  tmp_conf="$SCRIPT_DIR/newsyslog/com.restic-rest-client.conf.tmp"
  dst_conf="$NEWSYSLOG_DEST"

  echo "Installing newsyslog config..."
  if [[ ! -f "$local_conf" ]]; then
    echo "ERROR: template not found: $local_conf"
    exit 1
  fi

  if [[ -e "$dst_conf" && "$force" != "true" ]]; then
    echo "SKIP: $dst_conf already exists (use --force to overwrite)."
  else
    home_escaped="$(escape_sed "$HOME_DIR")"
    user_escaped="$(escape_sed "$USER_NAME")"
    script_escaped="$(escape_sed "$SCRIPT_DIR")"
    host_escaped="$(escape_sed "$HOST_NAME")"

    sed \
      -e "s|{{HOME}}|${home_escaped}|g" \
      -e "s|{{USER}}|${user_escaped}|g" \
      -e "s|{{SCRIPT_DIR}}|${script_escaped}|g" \
      -e "s|{{HOSTNAME}}|${host_escaped}|g" \
      "$local_conf" > "$tmp_conf"

    if ! command -v sudo >/dev/null 2>&1; then
      echo "ERROR: sudo not found."
      exit 1
    fi

    sudo install -m 0640 "$tmp_conf" "$dst_conf"
    rm -f "$tmp_conf"
    echo "INSTALLED: $dst_conf"
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo not found."
    exit 1
  fi

  if ! sudo test -f "$dst_conf"; then
    echo "ERROR: $dst_conf not found after install."
    exit 1
  fi

  if ! command -v newsyslog >/dev/null 2>&1; then
    echo "ERROR: newsyslog not found; cannot validate."
    exit 1
  fi

  if ! sudo newsyslog -n -f "$dst_conf"; then
    echo "ERROR: newsyslog validation failed for $dst_conf."
    exit 1
  fi

  echo "VERIFIED: $dst_conf"
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
  remove_file "$SCRIPT_DIR/restic-repository.txt"
  remove_file "$SCRIPT_DIR/restic-include-macos.txt"
  remove_file "$SCRIPT_DIR/restic-exclude-macos.txt"
  remove_file "$SCRIPT_DIR/launchd/$BACKUP_PLIST_NAME"
  remove_file "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME"
  remove_file "$SCRIPT_DIR/launchd/$LOGCLEANUP_PLIST_NAME"
  echo "VERIFIED: local generated files removed"
fi
