#!/usr/bin/env bash
# minimax-image check_env.sh
# Verify the environment is ready to call the MiniMax Image API.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_env.sh
source "$SCRIPT_DIR/lib_env.sh"

ENV_SEARCH_PATHS=(
  "./.env"
  "$HOME/.config/minimax-image/.env"
)
KEY_FILE="${MINIMAX_KEY_FILE:-$HOME/.config/minimax-image/key}"
API_ENDPOINT="${MINIMAX_API_ENDPOINT:-https://api.minimax.io/v1/image_generation}"

ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
fail() { echo "  ✗ $*"; FAIL=1; }

FAIL=0

echo "MiniMax Image — environment check"
echo

# 1. jq
if command -v jq >/dev/null 2>&1; then
  ok "jq found: $(command -v jq) ($(jq --version))"
else
  fail "jq missing — install via: brew install jq (macOS) | apt install jq (Debian/Ubuntu)"
fi

# 2. curl
if command -v curl >/dev/null 2>&1; then
  ok "curl found: $(command -v curl)"
else
  fail "curl missing — install via: brew install curl"
fi

# 3. API key — try to resolve via lib_env
SOURCE=""
if [[ -n "${MINIMAX_API_KEY:-}" ]]; then
  SOURCE="shell env var MINIMAX_API_KEY (length: ${#MINIMAX_API_KEY})"
else
  for p in "${ENV_SEARCH_PATHS[@]}"; do
    if [[ -f "$p" ]] && grep -qE '^[[:space:]]*MINIMAX_API_KEY[[:space:]]*=' "$p"; then
      SOURCE="$p (.env file)"
      break
    fi
  done
  if [[ -z "$SOURCE" && -f "$KEY_FILE" ]]; then
    SOURCE="$KEY_FILE (key file)"
  fi
fi

if [[ -n "$SOURCE" ]]; then
  ok "API key resolved from: $SOURCE"
elif ensure_api_key 2>/dev/null; then
  ok "API key resolved from: $(api_key_source)"
else
  fail "API key not found
    → env:    export MINIMAX_API_KEY=eyJ...
    → .env:   create ./.env with: MINIMAX_API_KEY=eyJ...
    → file:   echo 'eyJ...' > $KEY_FILE && chmod 600 $KEY_FILE"
fi

# 4. .env file presence (informational)
for p in "${ENV_SEARCH_PATHS[@]}"; do
  if [[ -f "$p" ]]; then
    ok ".env found at: $p"
    if [[ "$p" == "./.env" ]]; then
      if [[ -f "./.gitignore" ]] && grep -qx '.env' ./.gitignore; then
        ok "./.env is git-ignored"
      else
        warn "./.gitignore does NOT list '.env' — add it to keep your key safe"
      fi
    fi
  fi
done

# 5. API reachability (best-effort)
if command -v curl >/dev/null 2>&1; then
  HTTP=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$API_ENDPOINT" -X OPTIONS 2>/dev/null || echo "000")
  case "$HTTP" in
    000) warn "could not reach $API_ENDPOINT (network/DNS issue?)" ;;
    405|400|401|200|204) ok "API endpoint reachable: $API_ENDPOINT" ;;
    *)                   warn "API endpoint returned unexpected HTTP $HTTP" ;;
  esac
fi

echo
if [[ $FAIL -eq 0 ]]; then
  echo "All required checks passed. Run a dry-run to confirm:"
  echo "  bash $SCRIPT_DIR/generate.sh --prompt \"test\" --dry-run"
  exit 0
else
  echo "One or more required checks failed. Fix the issues above."
  exit 1
fi
