#!/bin/zsh
set -euo pipefail

REPO_URL="${RESTIC_REST_CLIENT_REPO_URL:-https://github.com/Vantasin/restic-rest-client.git}"
CLONE_DIR="${RESTIC_REST_CLIENT_CLONE_DIR:-$HOME/Git/restic-rest-client}"

typeset -ga MISSING_REQUIRED_FORMULAE=()
typeset -ga MISSING_OPTIONAL_FORMULAE=()

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--clone-dir DIR] [--repo-url URL]

Bootstrap the macOS client setup flow by:

- checking for Homebrew
- prompting to install missing required and optional dependencies
- creating the clone directory
- cloning or reusing the repo checkout
- starting ./bootstrap.sh --generate and ./configure_env.sh

Environment overrides:
- RESTIC_REST_CLIENT_CLONE_DIR
- RESTIC_REST_CLIENT_REPO_URL
EOF
}

say() {
  print -- "$*"
}

warn() {
  print -u2 -- "WARN: $*"
}

die() {
  print -u2 -- "ERROR: $*"
  exit 1
}

prompt_yes_no() {
  local prompt="$1"
  local default_answer="$2"
  local reply=""

  if [[ ! -r /dev/tty ]]; then
    [[ "$default_answer" == "yes" ]]
    return
  fi

  while true; do
    if [[ "$default_answer" == "yes" ]]; then
      print -n -- "$prompt [Y/n]: " > /dev/tty
      read -r reply < /dev/tty
      reply="${reply:-y}"
    else
      print -n -- "$prompt [y/N]: " > /dev/tty
      read -r reply < /dev/tty
      reply="${reply:-n}"
    fi

    case "${reply:l}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) print -- "Please answer yes or no." > /dev/tty ;;
    esac
  done
}

detect_homebrew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    print -r -- /opt/homebrew/bin/brew
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    print -r -- /usr/local/bin/brew
    return 0
  fi

  return 1
}

load_homebrew() {
  local brew_bin

  if ! brew_bin="$(detect_homebrew_bin)"; then
    return 1
  fi

  eval "$("$brew_bin" shellenv)"
  command -v brew >/dev/null 2>&1
}

git_available() {
  command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1
}

make_available() {
  command -v make >/dev/null 2>&1
}

openssl_available() {
  command -v openssl >/dev/null 2>&1 && openssl version >/dev/null 2>&1
}

restic_available() {
  command -v restic >/dev/null 2>&1 && restic version >/dev/null 2>&1
}

msmtp_available() {
  command -v msmtp >/dev/null 2>&1
}

collect_missing_dependencies() {
  MISSING_REQUIRED_FORMULAE=()
  MISSING_OPTIONAL_FORMULAE=()

  if ! git_available; then
    MISSING_REQUIRED_FORMULAE+=("git")
  fi

  if ! make_available; then
    MISSING_REQUIRED_FORMULAE+=("make")
  fi

  if ! openssl_available; then
    MISSING_REQUIRED_FORMULAE+=("openssl@3")
  fi

  if ! restic_available; then
    MISSING_REQUIRED_FORMULAE+=("restic")
  fi

  if ! msmtp_available; then
    MISSING_OPTIONAL_FORMULAE+=("msmtp")
  fi
}

install_homebrew() {
  say "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || \
    die "Homebrew installation failed."
  load_homebrew || die "Homebrew installation completed, but brew is still unavailable."
}

ensure_dependency_prerequisites() {
  local brew_ready=false

  if load_homebrew; then
    brew_ready=true
  fi

  collect_missing_dependencies

  if (( ${#MISSING_REQUIRED_FORMULAE[@]} == 0 && ${#MISSING_OPTIONAL_FORMULAE[@]} == 0 )); then
    say "Required and optional Homebrew-managed dependencies are already available."
    return 0
  fi

  if [[ "$brew_ready" == "false" ]]; then
    say "Homebrew is not installed."

    if (( ${#MISSING_REQUIRED_FORMULAE[@]} > 0 )); then
      say "Missing required dependencies: ${(j:, :)MISSING_REQUIRED_FORMULAE}"
      prompt_yes_no "Install Homebrew so the setup script can install the missing required dependencies?" "yes" || \
        die "Missing required dependencies remain: ${(j:, :)MISSING_REQUIRED_FORMULAE}"
      install_homebrew
      brew_ready=true
    elif (( ${#MISSING_OPTIONAL_FORMULAE[@]} > 0 )); then
      say "Missing optional dependencies: ${(j:, :)MISSING_OPTIONAL_FORMULAE}"
      if prompt_yes_no "Install Homebrew so the setup script can offer optional dependency installation?" "no"; then
        install_homebrew
        brew_ready=true
      else
        warn "Continuing without Homebrew. Optional dependencies will not be installed automatically."
      fi
    fi
  fi

  collect_missing_dependencies

  if (( ${#MISSING_REQUIRED_FORMULAE[@]} > 0 )); then
    say "Missing required dependencies: ${(j:, :)MISSING_REQUIRED_FORMULAE}"
    prompt_yes_no "Install the missing required dependencies via Homebrew?" "yes" || \
      die "Required dependencies remain missing: ${(j:, :)MISSING_REQUIRED_FORMULAE}"
    brew install "${MISSING_REQUIRED_FORMULAE[@]}" || die "Failed to install required dependencies."
    collect_missing_dependencies
    (( ${#MISSING_REQUIRED_FORMULAE[@]} == 0 )) || \
      die "Required dependencies remain missing after installation: ${(j:, :)MISSING_REQUIRED_FORMULAE}"
  fi

  if [[ "$brew_ready" == "false" ]]; then
    return 0
  fi

  if (( ${#MISSING_OPTIONAL_FORMULAE[@]} > 0 )); then
    say "Missing optional dependencies: ${(j:, :)MISSING_OPTIONAL_FORMULAE}"
    if prompt_yes_no "Install the missing optional dependencies via Homebrew?" "no"; then
      brew install "${MISSING_OPTIONAL_FORMULAE[@]}" || die "Failed to install optional dependencies."
      collect_missing_dependencies
    else
      say "Skipping optional dependency installation."
    fi
  fi
}

ensure_repo_checkout() {
  local clone_parent
  clone_parent="$(dirname "$CLONE_DIR")"

  mkdir -p "$clone_parent"

  if [[ -d "$CLONE_DIR/.git" ]]; then
    say "Found an existing repo checkout at $CLONE_DIR."
    prompt_yes_no "Reuse the existing checkout and continue with bootstrap/configure?" "yes" || \
      die "Aborted because the existing checkout was not approved for reuse."
    return 0
  fi

  if [[ -e "$CLONE_DIR" ]]; then
    die "$CLONE_DIR already exists and is not a git checkout."
  fi

  say "Cloning $REPO_URL into $CLONE_DIR..."
  git clone "$REPO_URL" "$CLONE_DIR" || die "git clone failed."
}

run_repo_setup() {
  [[ -x "$CLONE_DIR/bootstrap.sh" ]] || die "Missing executable bootstrap.sh in $CLONE_DIR."
  [[ -x "$CLONE_DIR/configure_env.sh" ]] || die "Missing executable configure_env.sh in $CLONE_DIR."

  say "Running ./bootstrap.sh --generate..."
  (
    cd "$CLONE_DIR"
    ./bootstrap.sh --generate
  ) || die "bootstrap.sh --generate failed."

  say "Starting ./configure_env.sh..."
  (
    cd "$CLONE_DIR"
    if [[ -r /dev/tty ]]; then
      ./configure_env.sh < /dev/tty
    else
      ./configure_env.sh
    fi
  ) || die "configure_env.sh failed."

  say ""
  say "Initial setup completed in $CLONE_DIR."
  say "Next recommended steps:"
  say "  cd $CLONE_DIR"
  say "  ./setup_password.sh --rest-server"
  say "  ./setup_password.sh --repository"
  say "  ./init_repo.sh"
  say "  ./bootstrap.sh --install"
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "This setup script is intended for macOS."
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clone-dir)
      [[ $# -ge 2 && -n "${2:-}" ]] || die "$1 requires a value."
      CLONE_DIR="$2"
      shift 2
      continue
      ;;
    --repo-url)
      [[ $# -ge 2 && -n "${2:-}" ]] || die "$1 requires a value."
      REPO_URL="$2"
      shift 2
      continue
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

ensure_dependency_prerequisites
ensure_repo_checkout
run_repo_setup
