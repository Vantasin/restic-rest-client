#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

usage() {
  cat <<'EOF'
Usage: ./verify_repo.sh [all|shell|plists|readmes|diff|diff-cached]

Default: all

Checks:
- diff:     git diff --check (working tree)
- diff-cached: git diff --cached --check (index)
- shell:    zsh syntax checks plus executable-bit checks for runnable repo shell entrypoints and hooks
- plists:   plutil validation for tracked launchd plist templates
- readmes:  ensure each visible repo directory has a README.md
EOF
}

check_diff() {
  echo "[verify] git diff --check (working tree)"
  git diff --check
}

check_diff_cached() {
  echo "[verify] git diff --cached --check (index)"
  git diff --cached --check
}

check_shell() {
  echo "[verify] zsh syntax"

  local file
  local -a shell_files=(
    "setup.sh"
    "run_backup.sh"
    "restore_latest.sh"
    "unlock_stale_locks.sh"
    "configure_env.sh"
    "init_repo.sh"
    "lib/platform.sh"
    "lib/notifications.sh"
    "lib/tasks.sh"
    "bootstrap.sh"
    "setup_password.sh"
    "verify_repo.sh"
    "githooks/pre-commit"
  )
  local -a executable_files=(
    "setup.sh"
    "run_backup.sh"
    "restore_latest.sh"
    "unlock_stale_locks.sh"
    "configure_env.sh"
    "init_repo.sh"
    "bootstrap.sh"
    "setup_password.sh"
    "verify_repo.sh"
    "githooks/pre-commit"
  )

  for file in $executable_files; do
    [[ -f "$file" ]] || continue
    if [[ ! -x "$file" ]]; then
      echo "ERROR: expected executable bit on $file" >&2
      return 1
    fi
  done

  for file in $shell_files; do
    [[ -f "$file" ]] || continue
    zsh -n "$file"
  done
}

check_plists() {
  echo "[verify] launchd plist templates"

  command -v plutil >/dev/null 2>&1 || {
    echo "ERROR: plutil is required to validate launchd plist templates." >&2
    return 1
  }

  local file
  for file in launchd/*.plist.example; do
    [[ -e "$file" ]] || continue
    plutil -lint "$file" >/dev/null
  done
}

check_readmes() {
  echo "[verify] directory README coverage"

  local dir segment
  local skip_dir
  local -a missing_readmes

  for dir in ${(f)"$(find . -type d | sort)"}; do
    [[ "$dir" == "." ]] && continue

    skip_dir=false
    for segment in ${(s:/:)dir}; do
      [[ -z "$segment" || "$segment" == "." ]] && continue
      if [[ "$segment" == .* ]]; then
        skip_dir=true
        break
      fi
    done

    [[ "$skip_dir" == true ]] && continue
    [[ -f "$dir/README.md" ]] || missing_readmes+=("$dir")
  done

  if (( ${#missing_readmes[@]} > 0 )); then
    echo "ERROR: missing README.md in visible directories:" >&2
    printf '%s\n' "${missing_readmes[@]}" | sed 's/^/  - /' >&2
    return 1
  fi
}

run_target() {
  case "$1" in
    diff) check_diff ;;
    diff-cached) check_diff_cached ;;
    shell) check_shell ;;
    plists) check_plists ;;
    readmes) check_readmes ;;
    all)
      check_diff
      check_diff_cached
      check_shell
      check_plists
      check_readmes
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "ERROR: unknown verify target: $1" >&2
      usage >&2
      return 1
      ;;
  esac
}

if (( $# == 0 )); then
  run_target all
else
  typeset target
  for target in "$@"; do
    run_target "$target"
  done
fi
