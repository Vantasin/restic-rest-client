#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/restic.env"
HOST_NAME="${HOSTNAME:-}"

if [[ -z "$HOST_NAME" ]] && command -v scutil >/dev/null 2>&1; then
  HOST_NAME="$(scutil --get ComputerName 2>/dev/null || true)"
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

restic_host=""
repository_base_url=""
repository_name=""
rest_username=""
requested_restic_host=""
requested_repository_base_url=""
requested_repository_name=""
requested_rest_username=""

usage() {
  cat <<'EOF'
Usage: ./configure_env.sh [--base-url URL] [--repo-name NAME] [--username NAME] [--host LABEL]

Populate the required REST-server settings in restic.env. By default, the
script prompts only for the REST base URL and username. Use --repo-name or
--host to override the local defaults.
EOF
}

ensure_value_option() {
  local option_name="$1"

  if [[ $# -lt 2 || -z "${2:-}" ]]; then
    echo "ERROR: $option_name requires a value."
    exit 1
  fi
}

escape_double_quoted() {
  printf '%s' "$1" | sed -e 's/[\\$`"]/\\&/g'
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

prompt_value() {
  local prompt_text="$1"
  local default_value="${2:-}"
  local answer=""

  if [[ ! -t 0 ]]; then
    if [[ -n "$default_value" ]]; then
      printf '%s' "$default_value"
      return 0
    fi
    echo "ERROR: missing required value for $prompt_text." >&2
    exit 1
  fi

  if [[ -n "$default_value" ]]; then
    read -r "answer?$prompt_text [$default_value]: "
    printf '%s' "${answer:-$default_value}"
  else
    read -r "answer?$prompt_text: "
    printf '%s' "$answer"
  fi
}

normalize_base_url() {
  local value="$1"

  [[ -n "$value" ]] || {
    echo "ERROR: base URL cannot be empty." >&2
    exit 1
  }

  value="${value#rest:}"
  value="${value%/}"

  if [[ "$value" != https://* && "$value" != http://* ]]; then
    echo "ERROR: base URL must start with http:// or https:// and must not include the rest: prefix." >&2
    exit 1
  fi

  if [[ "$value" == *"@"* ]]; then
    echo "ERROR: base URL must not include inline credentials." >&2
    exit 1
  fi

  if [[ "$value" == *[\?\#]* ]]; then
    echo "ERROR: base URL must not include a query string or fragment." >&2
    exit 1
  fi

  printf '%s' "$value"
}

normalize_repo_name() {
  local value="$1"

  [[ -n "$value" ]] || {
    echo "ERROR: repository name cannot be empty." >&2
    exit 1
  }

  if [[ "$value" == /* || "$value" == */ || "$value" == *"//"* ]]; then
    echo "ERROR: repository name must be a relative path without leading or trailing '/'." >&2
    exit 1
  fi

  if [[ "$value" == *[[:space:]]* || "$value" == *[\?\#:\@]* ]]; then
    echo "ERROR: repository name must not contain whitespace or URL control characters." >&2
    exit 1
  fi

  if [[ "$value" == "." || "$value" == ".." || "$value" == */./* || "$value" == */../* || "$value" == ./* || "$value" == ../* || "$value" == */. || "$value" == */.. ]]; then
    echo "ERROR: repository name must not contain '.' or '..' path segments." >&2
    exit 1
  fi

  printf '%s' "$value"
}

normalize_required_text() {
  local label="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    echo "ERROR: $label cannot be empty." >&2
    exit 1
  fi

  printf '%s' "$value"
}

load_current_values() {
  local raw_values
  local -a loaded_values

  if ! raw_values="$(
    zsh -c '
      security() {
        printf "%s\n" "stub"
      }

      source "$1" >/dev/null 2>&1 || exit 1
      printf "%s\n%s\n%s\n%s\n" \
        "${RESTIC_HOST:-}" \
        "${RESTIC_REPOSITORY_BASE_URL:-}" \
        "${RESTIC_REPOSITORY_NAME:-}" \
        "${RESTIC_REST_USERNAME:-}"
    ' zsh "$ENV_FILE"
  )"; then
    echo "ERROR: failed to source $ENV_FILE." >&2
    echo "Verify the file syntax before running configure." >&2
    exit 1
  fi

  loaded_values=("${(@f)raw_values}")
  restic_host="${loaded_values[1]:-}"
  repository_base_url="${loaded_values[2]:-}"
  repository_name="${loaded_values[3]:-}"
  rest_username="${loaded_values[4]:-}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      ensure_value_option "$1" "${2:-}"
      requested_repository_base_url="$2"
      shift 2
      continue
      ;;
    --repo-name)
      ensure_value_option "$1" "${2:-}"
      requested_repository_name="$2"
      shift 2
      continue
      ;;
    --username)
      ensure_value_option "$1" "${2:-}"
      requested_rest_username="$2"
      shift 2
      continue
      ;;
    --host)
      ensure_value_option "$1" "${2:-}"
      requested_restic_host="$2"
      shift 2
      continue
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

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Run ./bootstrap.sh --generate or make bootstrap first."
  exit 1
fi

load_current_values

if [[ "$repository_base_url" == *"REPLACE_WITH_SERVER_HOST"* ]]; then
  repository_base_url=""
fi

if [[ "$rest_username" == "REPLACE_WITH_SERVER_USERNAME" ]]; then
  rest_username=""
fi

if [[ -z "$restic_host" || "$restic_host" == *"{{HOSTNAME}}"* ]]; then
  restic_host="$HOST_NAME"
fi

if [[ -z "$repository_name" || "$repository_name" == *"{{HOSTNAME_SLUG}}"* ]]; then
  repository_name="$HOST_NAME_SLUG"
fi

if ! normalize_repo_name "$repository_name" >/dev/null 2>&1; then
  repository_name="$HOST_NAME_SLUG"
fi

[[ -n "$requested_repository_base_url" ]] && repository_base_url="$requested_repository_base_url"
[[ -n "$requested_rest_username" ]] && rest_username="$requested_rest_username"
[[ -n "$requested_repository_name" ]] && repository_name="$requested_repository_name"
[[ -n "$requested_restic_host" ]] && restic_host="$requested_restic_host"

repository_base_url="$(prompt_value "RESTIC_REPOSITORY_BASE_URL (example: https://restic.example.com/user)" "$repository_base_url")"
rest_username="$(prompt_value "RESTIC_REST_USERNAME (example: user)" "$rest_username")"

repository_base_url="$(normalize_base_url "$repository_base_url")"
rest_username="$(normalize_required_text "RESTIC_REST_USERNAME" "$rest_username")"
repository_name="$(normalize_repo_name "$repository_name")"
restic_host="$(normalize_required_text "RESTIC_HOST" "$restic_host")"

set_export_line "RESTIC_HOST" "\"$(escape_double_quoted "$restic_host")\""
set_export_line "RESTIC_REPOSITORY_BASE_URL" "\"$(escape_double_quoted "$repository_base_url")\""
set_export_line "RESTIC_REPOSITORY_NAME" "\"$(escape_double_quoted "$repository_name")\""
set_export_line "RESTIC_REPOSITORY" '"rest:${RESTIC_REPOSITORY_BASE_URL%/}/${RESTIC_REPOSITORY_NAME}"'
set_export_line "RESTIC_REST_USERNAME" "\"$(escape_double_quoted "$rest_username")\""

echo "Configured: $ENV_FILE"
echo "  RESTIC_HOST=$restic_host"
echo "  RESTIC_REPOSITORY_BASE_URL=$repository_base_url"
echo "  RESTIC_REPOSITORY_NAME=$repository_name"
echo "  RESTIC_REPOSITORY=rest:${repository_base_url%/}/${repository_name}"
echo "  RESTIC_REST_USERNAME=$rest_username"
echo
echo "Next steps:"
echo "  make setup-rest-server-password"
echo "  make setup-repository-password"
echo "  make init-repo"
