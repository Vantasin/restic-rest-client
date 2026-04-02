#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/restic.env"
rotate=false

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Run ./bootstrap.sh --install first."
  exit 1
fi

if ! command -v security >/dev/null 2>&1; then
  echo "ERROR: 'security' not found. This script requires macOS Keychain."
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: 'openssl' not found. Install it (Homebrew) or set a password manually."
  exit 1
fi

source "$SCRIPT_DIR/lib/platform.sh"

keychain_account="restic-rest-client-macbook"
keychain_service="restic-rest-client-macbook"
password_length=32

usage() {
  cat <<'EOF'
Usage: ./setup_password.sh [--account NAME] [--service NAME] [--length N] [--rotate]

Generates a strong random password, stores it in macOS Keychain, and writes
RESTIC_PASSWORD_COMMAND to restic.env.

Defaults:
- account: restic-rest-client-macbook
- service: restic-rest-client-macbook
- length:  32 bytes (hex output)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account)
      keychain_account="$2"
      shift 2
      ;;
    --service)
      keychain_service="$2"
      shift 2
      ;;
    --length)
      password_length="$2"
      shift 2
      ;;
    --rotate)
      rotate=true
      shift
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
done

if [[ "${rotate:-false}" == "true" ]]; then
  if ! command -v restic >/dev/null 2>&1; then
    echo "ERROR: 'restic' not found. Install it before rotating."
    exit 1
  fi
  if ! command -v pgrep >/dev/null 2>&1; then
    echo "ERROR: 'pgrep' not found; cannot verify running restic jobs."
    exit 1
  fi
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

case "$password_length" in
  ''|*[!0-9]*)
    echo "ERROR: --length must be an integer."
    exit 1
    ;;
esac

password="$(openssl rand -hex "$password_length")"

command_line="security find-generic-password -a $keychain_account -s $keychain_service -w"

if [[ "${rotate:-false}" == "true" ]]; then
  source "$ENV_FILE"

  if ! resolve_repository_value >/dev/null 2>&1; then
    echo "ERROR: repository configuration is incomplete in $ENV_FILE."
    echo "Set RESTIC_REPOSITORY or RESTIC_REPOSITORY_FILE before rotating."
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

tmp_file="${ENV_FILE}.tmp"
found=0
while IFS= read -r line; do
  if [[ "$line" == export\ RESTIC_PASSWORD_COMMAND=* ]]; then
    echo "export RESTIC_PASSWORD_COMMAND='$command_line'" >> "$tmp_file"
    found=1
  else
    echo "$line" >> "$tmp_file"
  fi
done < "$ENV_FILE"

if [[ $found -eq 0 ]]; then
  echo "export RESTIC_PASSWORD_COMMAND='$command_line'" >> "$tmp_file"
fi

mv "$tmp_file" "$ENV_FILE"
chmod 600 "$ENV_FILE"

if ! security find-generic-password -a "$keychain_account" -s "$keychain_service" -w >/dev/null 2>&1; then
  echo "ERROR: failed to verify Keychain entry."
  exit 1
fi

if ! grep -q "^export RESTIC_PASSWORD_COMMAND=" "$ENV_FILE"; then
  echo "ERROR: failed to update $ENV_FILE."
  exit 1
fi

if [[ "${rotate:-false}" == "true" ]]; then
  echo "Keychain entry rotated for account '$keychain_account' (service '$keychain_service')."
else
  echo "Keychain entry created for account '$keychain_account' (service '$keychain_service')."
fi
echo "Updated: $ENV_FILE"
echo "Store this password in your password manager."
echo "To copy it to the clipboard:"
echo "  security find-generic-password -a $keychain_account -s $keychain_service -w | pbcopy"
echo "Then clear the clipboard:"
echo "  printf \"\" | pbcopy"
