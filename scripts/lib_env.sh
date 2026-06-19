#!/usr/bin/env bash
# minimax-image lib_env.sh
# Load MINIMAX_API_KEY from a .env file (project-local or global).
# Precedence (highest to lowest):
#   1. $MINIMAX_API_KEY (already in environment)
#   2. ./.env            (current working directory)
#   3. ~/.config/minimax-image/.env
#   4. ~/.config/minimax-image/key  (legacy single-value file)

set -euo pipefail

ENV_SEARCH_PATHS=(
  "./.env"
  "$HOME/.config/minimax-image/.env"
)

KEY_FILE="${MINIMAX_KEY_FILE:-$HOME/.config/minimax-image/key}"

# Parse a simple KEY=VALUE .env file (no expansion, no quotes required)
# Supports: KEY=value, KEY="value", KEY='value', comments with #, blank lines
load_env_file() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    # strip leading whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    # skip blanks and comments
    [[ -z "$line" || "$line" == \#* ]] && continue
    # must contain =
    [[ "$line" == *=* ]] || continue
    local key="${line%%=*}"
    local val="${line#*=}"
    # trim
    key="${key// /}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    # strip surrounding quotes
    if [[ ${#val} -ge 2 ]]; then
      case "$val" in
        \"*) val="${val:1:-1}" ;;
        \'*) val="${val:1:-1}" ;;
      esac
    fi
    # only export if not already set in env (env wins)
    if [[ -z "${!key:-}" ]]; then
      export "$key"="$val"
    fi
  done < "$f"
  return 0
}

# Returns 0 if MINIMAX_API_KEY is now set, 1 otherwise
ensure_api_key() {
  if [[ -n "${MINIMAX_API_KEY:-}" ]]; then
    return 0
  fi
  local p
  for p in "${ENV_SEARCH_PATHS[@]}"; do
    if load_env_file "$p" 2>/dev/null && [[ -n "${MINIMAX_API_KEY:-}" ]]; then
      export MINIMAX_ENV_SOURCE="$p"
      return 0
    fi
    [[ -n "${MINIMAX_API_KEY:-}" ]] && { export MINIMAX_ENV_SOURCE="$p"; return 0; }
  done
  if [[ -f "$KEY_FILE" ]]; then
    MINIMAX_API_KEY="$(<"$KEY_FILE")"
    export MINIMAX_API_KEY
    export MINIMAX_ENV_SOURCE="$KEY_FILE (key file)"
    return 0
  fi
  return 1
}

# Print where the key was resolved from (for check_env.sh)
api_key_source() {
  if [[ -n "${MINIMAX_API_KEY:-}" ]]; then
    if [[ -n "${MINIMAX_ENV_SOURCE:-}" ]]; then
      echo "$MINIMAX_ENV_SOURCE"
    else
      echo "shell env var MINIMAX_API_KEY"
    fi
  fi
}
