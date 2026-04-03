#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/restic.env"
mode="repository"
rotate=false

source "$SCRIPT_DIR/lib/platform.sh"

keychain_account=""
keychain_service=""
password_length=32

usage() {
  cat <<'EOF'
Usage: ./setup_password.sh --rest-server [--account NAME] [--service NAME]
       ./setup_password.sh --repository [--account NAME] [--service NAME] [--length N] [--rotate]

Store the REST server password in macOS Keychain or generate/store the restic
repository password and update restic.env to use the matching Keychain entry.

Defaults:
- --rest-server account/service: restic-rest-client-rest-server
- --repository account/service:  restic-rest-client-repository
- --repository length:           32 bytes (hex output)
EOF
}

ensure_value_option() {
  local option_name="$1"

  if [[ $# -lt 2 || -z "${2:-}" ]]; then
    echo "ERROR: $option_name requires a value."
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rest-server)
      mode="rest-server"
      ;;
    --repository)
      mode="repository"
      ;;
    --account)
      ensure_value_option "$1" "${2:-}"
      keychain_account="$2"
      shift 2
      continue
      ;;
    --service)
      ensure_value_option "$1" "${2:-}"
      keychain_service="$2"
      shift 2
      continue
      ;;
    --length)
      ensure_value_option "$1" "${2:-}"
      password_length="$2"
      shift 2
      continue
      ;;
    --rotate)
      rotate=true
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

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Run ./bootstrap.sh --generate or ./bootstrap.sh --install first."
  exit 1
fi

if ! command -v security >/dev/null 2>&1; then
  echo "ERROR: 'security' not found. This script requires macOS Keychain."
  exit 1
fi

case "$mode" in
  rest-server)
    keychain_account="${keychain_account:-restic-rest-client-rest-server}"
    keychain_service="${keychain_service:-restic-rest-client-rest-server}"
    if [[ "${rotate:-false}" == "true" ]]; then
      echo "ERROR: --rotate applies only to --repository."
      exit 1
    fi
    ;;
  repository)
    keychain_account="${keychain_account:-restic-rest-client-repository}"
    keychain_service="${keychain_service:-restic-rest-client-repository}"
    if ! command -v openssl >/dev/null 2>&1; then
      echo "ERROR: 'openssl' not found. Install it (Homebrew) or set a password manually."
      exit 1
    fi
    ;;
  *)
    echo "ERROR: unsupported mode: $mode"
    exit 1
    ;;
esac

build_keychain_fetch_command() {
  local account_escaped service_escaped

  account_escaped="$(printf '%q' "$1")"
  service_escaped="$(printf '%q' "$2")"
  printf 'security find-generic-password -a %s -s %s -w' "$account_escaped" "$service_escaped"
}

set_export_line() {
  local var_name="$1"
  local var_value="$2"
  local tmp_file found line

  tmp_file="${ENV_FILE}.tmp"
  found=0
  : > "$tmp_file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == export\ ${var_name}=* ]]; then
      printf 'export %s=%s\n' "$var_name" "$var_value" >> "$tmp_file"
      found=1
    else
      printf '%s\n' "$line" >> "$tmp_file"
    fi
  done < "$ENV_FILE"

  if [[ $found -eq 0 ]]; then
    printf 'export %s=%s\n' "$var_name" "$var_value" >> "$tmp_file"
  fi

  mv "$tmp_file" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

configure_rest_server_password() {
  local command_line provided_password

  command_line="$(build_keychain_fetch_command "$keychain_account" "$keychain_service")"

  read -r -s "provided_password?Enter the REST server password to store in Keychain: "
  echo

  if [[ -z "$provided_password" ]]; then
    echo "ERROR: password cannot be empty."
    exit 1
  fi

  security add-generic-password \
    -a "$keychain_account" \
    -s "$keychain_service" \
    -w "$provided_password" \
    -U >/dev/null

  set_export_line "RESTIC_REST_PASSWORD" "\"\$($command_line)\""

  if ! security find-generic-password -a "$keychain_account" -s "$keychain_service" -w >/dev/null 2>&1; then
    echo "ERROR: failed to verify Keychain entry."
    exit 1
  fi

  if ! grep -q "^export RESTIC_REST_PASSWORD=" "$ENV_FILE"; then
    echo "ERROR: failed to update $ENV_FILE."
    exit 1
  fi

  echo "Keychain entry stored for REST server password under account '$keychain_account' (service '$keychain_service')."
  echo "Updated: $ENV_FILE"
}

configure_repository_password() {
  local password command_line tmp_pass

  if [[ "${rotate:-false}" == "true" ]]; then
    if ! command -v restic >/dev/null 2>&1; then
      echo "ERROR: 'restic' not found. Install it before rotating."
      exit 1
    fi
    if ! command -v pgrep >/dev/null 2>&1; then
      echo "ERROR: 'pgrep' not found; cannot verify running restic jobs."
      exit 1
    fi
  fi

  case "$password_length" in
    ''|*[!0-9]*|0)
      echo "ERROR: --length must be a positive integer."
      exit 1
      ;;
  esac

  command_line="$(build_keychain_fetch_command "$keychain_account" "$keychain_service")"

  if [[ "${rotate:-false}" == "true" ]]; then
    if pgrep -fl "run_backup.sh|restic" >/dev/null 2>&1; then
      echo "ERROR: restic appears to be running. Stop backups before rotating."
      pgrep -fl "run_backup.sh|restic" || true
      exit 1
    fi
    if ! security find-generic-password -a "$keychain_account" -s "$keychain_service" -w >/dev/null 2>&1; then
      echo "ERROR: no existing Keychain entry for account '$keychain_account' and service '$keychain_service'."
      echo "Run without --rotate for initial setup."
      exit 1
    fi
  else
    if security find-generic-password -a "$keychain_account" -s "$keychain_service" -w >/dev/null 2>&1; then
      echo "ERROR: Keychain entry already exists for account '$keychain_account' and service '$keychain_service'."
      echo "Use --rotate to rotate it."
      exit 1
    fi
  fi

  password="$(openssl rand -hex "$password_length")"

  if [[ "${rotate:-false}" == "true" ]]; then
    if ! source "$ENV_FILE"; then
      echo "ERROR: failed to source $ENV_FILE. Verify its current password configuration."
      exit 1
    fi

    if ! resolve_repository_value >/dev/null 2>&1; then
      echo "ERROR: repository configuration is incomplete in $ENV_FILE."
      echo "Set RESTIC_REPOSITORY before rotating."
      exit 1
    fi
    if ! RESTIC_PASSWORD_COMMAND="$command_line" restic cat config >/dev/null 2>&1; then
      echo "ERROR: unable to access repository with current Keychain password."
      echo "Verify connectivity and credentials before rotating."
      exit 1
    fi

    tmp_pass="$(mktemp)"
    chmod 600 "$tmp_pass"
    printf "%s" "$password" > "$tmp_pass"

    if ! RESTIC_PASSWORD_COMMAND="$command_line" restic key passwd --new-password-file "$tmp_pass"; then
      rm -f "$tmp_pass"
      echo "ERROR: restic key passwd failed."
      exit 1
    fi

    rm -f "$tmp_pass"
  fi

  security add-generic-password \
    -a "$keychain_account" \
    -s "$keychain_service" \
    -w "$password" \
    -U >/dev/null

  set_export_line "RESTIC_PASSWORD_COMMAND" "\"$command_line\""

  if ! security find-generic-password -a "$keychain_account" -s "$keychain_service" -w >/dev/null 2>&1; then
    echo "ERROR: failed to verify Keychain entry."
    exit 1
  fi

  if ! grep -q "^export RESTIC_PASSWORD_COMMAND=" "$ENV_FILE"; then
    echo "ERROR: failed to update $ENV_FILE."
    exit 1
  fi

  if [[ "${rotate:-false}" == "true" ]]; then
    echo "Keychain entry rotated for repository password under account '$keychain_account' (service '$keychain_service')."
  else
    echo "Keychain entry created for repository password under account '$keychain_account' (service '$keychain_service')."
  fi
  echo "Updated: $ENV_FILE"
  echo "Store this password in your password manager."
  echo "To copy it to the clipboard:"
  echo "  security find-generic-password -a $keychain_account -s $keychain_service -w | pbcopy"
  echo "Then clear the clipboard:"
  echo "  printf \"\" | pbcopy"
}

case "$mode" in
  rest-server)
    configure_rest_server_password
    ;;
  repository)
    configure_repository_password
    ;;
esac
