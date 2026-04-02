# Platform and shell helpers shared by repo task scripts.
#
# Expected from the caller:
# - log()

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

is_on_ac_power() {
  command -v pmset >/dev/null 2>&1 || return 2
  local batt_status
  batt_status=$(pmset -g batt 2>/dev/null || true)
  [[ "$batt_status" == *"Now drawing from 'AC Power'"* ]]
}

is_clamshell_closed() {
  command -v ioreg >/dev/null 2>&1 || return 2
  local clamshell_state
  clamshell_state=$(ioreg -r -k AppleClamshellState -d 4 2>/dev/null | grep -m1 'AppleClamshellState' || true)
  [[ "$clamshell_state" == *"= Yes"* ]]
}

require_regular_file() {
  local label="$1"
  local path="$2"

  if [ ! -f "$path" ]; then
    log "ERROR: ${label} not found: $path"
    return 1
  fi

  return 0
}

mask_repository_credentials() {
  printf '%s' "${1:-}" | sed -E 's#(rest:https?://[^:/@]+:)[^@]+@#\1***@#'
}

resolve_repository_value() {
  local repo_file repo_value

  if [[ -n "${RESTIC_REPOSITORY:-}" && -n "${RESTIC_REPOSITORY_FILE:-}" ]]; then
    echo "Set only one of RESTIC_REPOSITORY or RESTIC_REPOSITORY_FILE." >&2
    return 1
  fi

  if [[ -n "${RESTIC_REPOSITORY:-}" ]]; then
    printf '%s' "$RESTIC_REPOSITORY"
    return 0
  fi

  repo_file="${RESTIC_REPOSITORY_FILE:-}"
  if [[ -z "$repo_file" ]]; then
    echo "Set RESTIC_REPOSITORY or RESTIC_REPOSITORY_FILE in restic.env." >&2
    return 1
  fi

  if [[ ! -f "$repo_file" ]]; then
    echo "Repository file not found: $repo_file" >&2
    return 1
  fi

  repo_value="$(<"$repo_file")"
  if [[ -z "$repo_value" ]]; then
    echo "Repository file is empty: $repo_file" >&2
    return 1
  fi

  printf '%s' "$repo_value"
}

run_command_logged() {
  local command_status

  set +e
  "$@" 2>&1 | while IFS= read -r line; do log "$line"; done
  command_status=${pipestatus[1]}
  set -e

  return $command_status
}
