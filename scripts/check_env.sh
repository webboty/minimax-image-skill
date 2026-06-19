#!/usr/bin/env bash
# minimax-image check_env.sh
# Verify the environment is ready to call the MiniMax Image API.

set -euo pipefail

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

# 3. API key
if [[ -n "${MINIMAX_API_KEY:-}" ]]; then
  ok "API key resolved from env var MINIMAX_API_KEY (length: ${#MINIMAX_API_KEY})"
elif [[ -f "$KEY_FILE" ]]; then
  PERMS=$(stat -f "%Lp" "$KEY_FILE" 2>/dev/null || stat -c "%a" "$KEY_FILE" 2>/dev/null || echo "???")
  if [[ "$PERMS" == "600" || "$PERMS" == "400" ]]; then
    ok "API key resolved from $KEY_FILE (perms: $PERMS)"
  else
    warn "API key file exists at $KEY_FILE but perms are $PERMS (recommend chmod 600)"
  fi
else
  fail "API key not found
    → set env:   export MINIMAX_API_KEY=eyJ...
    → or file:   echo 'eyJ...' > $KEY_FILE && chmod 600 $KEY_FILE"
fi

# 4. API reachability (best-effort, no auth needed for this check)
if command -v curl >/dev/null 2>&1; then
  HTTP=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$API_ENDPOINT" -X OPTIONS 2>/dev/null || echo "000")
  case "$HTTP" in
    000) warn "could not reach $API_ENDPOINT (network/DNS issue?)" ;;
    405|400|401|200|204) ok "API endpoint reachable: $API_ENDPOINT" ;;
    *)                   warn "API endpoint returned unexpected HTTP $HTTP" ;;
  esac
fi

# 5. Out dir (optional, only warning)
if [[ -n "${MINIMAX_OUT_DIR:-}" && ! -d "$MINIMAX_OUT_DIR" ]]; then
  warn "MINIMAX_OUT_DIR=$MINIMAX_OUT_DIR does not exist yet (will be created on first run)"
fi

echo
if [[ $FAIL -eq 0 ]]; then
  echo "All required checks passed. Run a dry-run to confirm:"
  echo "  bash $(dirname "$0")/generate.sh --prompt \"test\" --dry-run"
  exit 0
else
  echo "One or more required checks failed. Fix the issues above."
  exit 1
fi
