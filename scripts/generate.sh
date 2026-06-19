#!/usr/bin/env bash
# minimax-image generate.sh
# Direct HTTP wrapper for the MiniMax Image-01 API.
# No CLI deps. Uses curl + jq only.

set -euo pipefail

API_ENDPOINT="${MINIMAX_API_ENDPOINT:-https://api.minimax.io/v1/image_generation}"
API_MODEL="${MINIMAX_IMAGE_MODEL:-image-01}"
KEY_FILE="${MINIMAX_KEY_FILE:-$HOME/.config/minimax-image/key}"

# ---------- helpers ----------
die() { echo "error: $*" >&2; exit 1; }
log() { [[ "${QUIET:-0}" == "1" ]] || echo "$*" >&2; }

usage() {
  cat >&2 <<'EOF'
usage: generate.sh --prompt <text> [flags]

required:
  --prompt <text>              image description (max 1500 chars)

optional:
  --aspect-ratio <ratio>       1:1 (default), 16:9, 4:3, 3:2, 2:3, 3:4, 9:16, 21:9
  --width <px>                 512-2048, divisible by 8, paired with --height
  --height <px>                512-2048, divisible by 8, paired with --width
  --n <count>                  1-9, default 1
  --seed <int>                 deterministic seed
  --prompt-optimizer           enable automatic prompt enhancement
  --response-format <fmt>      url (default) | base64
  --out-dir <dir>              save images to directory
  --out-prefix <prefix>        filename prefix, default "image"
  --quiet                      suppress progress on stderr
  --dry-run                    print JSON body, do not call API
  -h, --help                   show this help
EOF
  exit 64
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1 (install: $2)"
}

resolve_api_key() {
  if [[ -n "${MINIMAX_API_KEY:-}" ]]; then
    return 0
  fi
  if [[ -f "$KEY_FILE" ]]; then
    MINIMAX_API_KEY="$(<"$KEY_FILE")"
    export MINIMAX_API_KEY
    return 0
  fi
  die "MINIMAX_API_KEY not set and no key file at $KEY_FILE
  → set: export MINIMAX_API_KEY=eyJ...
  → or:  echo 'eyJ...' > $KEY_FILE && chmod 600 $KEY_FILE"
}

# ---------- arg parsing ----------
PROMPT=""
ASPECT_RATIO=""
WIDTH=""
HEIGHT=""
N=""
SEED=""
PROMPT_OPTIMIZER="false"
RESPONSE_FORMAT="url"
OUT_DIR=""
OUT_PREFIX="image"
QUIET=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)               PROMPT="$2"; shift 2 ;;
    --aspect-ratio)         ASPECT_RATIO="$2"; shift 2 ;;
    --width)                WIDTH="$2"; shift 2 ;;
    --height)               HEIGHT="$2"; shift 2 ;;
    --n)                    N="$2"; shift 2 ;;
    --seed)                 SEED="$2"; shift 2 ;;
    --prompt-optimizer)     PROMPT_OPTIMIZER="true"; shift ;;
    --response-format)      RESPONSE_FORMAT="$2"; shift 2 ;;
    --out-dir)              OUT_DIR="$2"; shift 2 ;;
    --out-prefix)           OUT_PREFIX="$2"; shift 2 ;;
    --quiet)                QUIET=1; shift ;;
    --dry-run)              DRY_RUN=1; shift ;;
    -h|--help)              usage ;;
    *)                      die "unknown flag: $1 (use --help)" ;;
  esac
done

[[ -z "$PROMPT" ]] && die "missing --prompt (use --help)"
[[ ${#PROMPT} -gt 1500 ]] && die "prompt exceeds 1500 characters (got ${#PROMPT})"

case "$RESPONSE_FORMAT" in
  url|base64) ;;
  *) die "--response-format must be 'url' or 'base64'" ;;
esac

if [[ -n "$WIDTH" || -n "$HEIGHT" ]]; then
  [[ -z "$WIDTH" || -z "$HEIGHT" ]] && die "--width and --height must be set together"
  [[ "$WIDTH"  -lt 512 || "$WIDTH"  -gt 2048 ]] && die "--width out of range 512-2048"
  [[ "$HEIGHT" -lt 512 || "$HEIGHT" -gt 2048 ]] && die "--height out of range 512-2048"
  (( WIDTH  % 8 == 0 )) || die "--width must be divisible by 8"
  (( HEIGHT % 8 == 0 )) || die "--height must be divisible by 8"
fi

# ---------- preflight ----------
require_cmd curl "brew install curl"
require_cmd jq "brew install jq"
resolve_api_key

# ---------- build payload ----------
PAYLOAD=$(jq -n \
  --arg model "$API_MODEL" \
  --arg prompt "$PROMPT" \
  --arg aspect_ratio "$ASPECT_RATIO" \
  --argjson width "${WIDTH:-null}" \
  --argjson height "${HEIGHT:-null}" \
  --argjson n "${N:-null}" \
  --argjson seed "${SEED:-null}" \
  --argjson prompt_optimizer "$PROMPT_OPTIMIZER" \
  --arg response_format "$RESPONSE_FORMAT" \
  '
  {
    model: $model,
    prompt: $prompt,
    response_format: $response_format,
    prompt_optimizer: $prompt_optimizer
  }
  + (if $aspect_ratio != "" then {aspect_ratio: $aspect_ratio} else {} end)
  + (if $width  != null then {width:  $width}  else {} end)
  + (if $height != null then {height: $height} else {} end)
  + (if $n      != null then {n:      $n}      else {} end)
  + (if $seed   != null then {seed:   $seed}   else {} end)
  ')

if [[ "$DRY_RUN" == "1" ]]; then
  echo "$PAYLOAD"
  exit 0
fi

# ---------- call API ----------
log "POST $API_ENDPOINT"
HTTP_CODE=$(curl -sS -o /tmp/_minimax_resp.$$ -w "%{http_code}" \
  -X POST "$API_ENDPOINT" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  -H "Content-Type: application/json" \
  --max-time 120 \
  -d "$PAYLOAD") || die "curl failed"
RESP=$(cat /tmp/_minimax_resp.$$); rm -f /tmp/_minimax_resp.$$

if [[ "$HTTP_CODE" -ne 200 ]]; then
  echo "$RESP" >&2
  die "API returned HTTP $HTTP_CODE"
fi

STATUS_CODE=$(echo "$RESP" | jq -r '.base_resp.status_code // 0')
STATUS_MSG=$(echo "$RESP" | jq -r '.base_resp.status_msg // ""')
TRACE_ID=$(echo "$RESP" | jq -r '.id // ""')
SUCCESS=$(echo "$RESP" | jq -r '.metadata.success_count // 0')
FAILED=$(echo "$RESP" | jq -r '.metadata.failed_count // 0')

if [[ "$STATUS_CODE" != "0" ]]; then
  echo "$RESP" >&2
  die "API error $STATUS_CODE: $STATUS_MSG"
fi

# ---------- extract images ----------
case "$RESPONSE_FORMAT" in
  url)
    URLS=()
    while IFS= read -r url; do URLS+=("$url"); done < <(echo "$RESP" | jq -r '.data.image_urls[]?')
    [[ ${#URLS[@]} -eq 0 ]] && die "no image URLs in response (may be content-filtered)"
    ;;
  base64)
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    i=0
    while IFS= read -r b64; do
      echo "$b64" | base64 -d > "$TMP_DIR/$OUT_PREFIX-$i.jpeg"
      i=$((i+1))
    done < <(echo "$RESP" | jq -r '.data.image_base64[]?')
    URLS=()
    while IFS= read -r f; do URLS+=("$f"); done < <(ls "$TMP_DIR" | sort)
    for i in "${!URLS[@]}"; do URLS[$i]="$TMP_DIR/${URLS[$i]}"; done
    trap - EXIT
    ;;
esac

# ---------- save to out-dir (for url mode) ----------
if [[ -n "$OUT_DIR" && "$RESPONSE_FORMAT" == "url" ]]; then
  mkdir -p "$OUT_DIR"
  i=0
  for url in "${URLS[@]}"; do
    out="$OUT_DIR/$OUT_PREFIX-$i.jpeg"
    log "downloading → $out"
    curl -sSL --max-time 120 "$url" -o "$out" || die "download failed: $url"
    i=$((i+1))
  done
fi

# ---------- emit result ----------
RESULT=$(jq -n \
  --arg id "$TRACE_ID" \
  --argjson status_code "$STATUS_CODE" \
  --arg status_msg "$STATUS_MSG" \
  --argjson success "$SUCCESS" \
  --argjson failed "$FAILED" \
  --argjson urls "$(printf '%s\n' "${URLS[@]}" | jq -R . | jq -s .)" \
  --arg out_dir "$OUT_DIR" \
  '
  {
    id: $id,
    status_code: $status_code,
    status_msg: $status_msg,
    success_count: $success,
    failed_count: $failed
  }
  + (if $out_dir != "" then {saved_paths: $urls} else {image_urls: $urls} end)
  ')

echo "$RESULT"
exit 0
