#!/usr/bin/env bash
# minimax-image init_env.sh
# Create a .env file template in the current directory or at a given path.
# Default: ./.env  (project-local)
# Global:  --global  → ~/.config/minimax-image/.env

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: init_env.sh [--global] [--path <file>] [--from-stdin]

Creates a .env file template. With no flag, writes to ./.env.

Options:
  --global         write to ~/.config/minimax-image/.env
  --path <file>    write to a custom path
  --from-stdin     read MINIMAX_API_KEY value from stdin (do not echo it
                   in your shell history)

Example:
  # interactive (key will be visible in terminal — use only in trusted envs)
  bash init_env.sh

  # secure: pipe the key from a password manager
  pbcopy < ~/.secrets/minimax && pbpaste | bash init_env.sh --from-stdin
EOF
  exit 64
}

TARGET=""
GLOBAL=0
FROM_STDIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)     GLOBAL=1; shift ;;
    --path)       TARGET="$2"; shift 2 ;;
    --from-stdin) FROM_STDIN=1; shift ;;
    -h|--help)    usage ;;
    *)            echo "unknown flag: $1" >&2; usage ;;
  esac
done

if [[ $GLOBAL -eq 1 ]]; then
  TARGET="${TARGET:-$HOME/.config/minimax-image/.env}"
  mkdir -p "$(dirname "$TARGET")"
else
  TARGET="${TARGET:-./.env}"
fi

if [[ -f "$TARGET" ]]; then
  echo "error: $TARGET already exists. Remove it first or use --path." >&2
  exit 1
fi

if [[ $FROM_STDIN -eq 1 ]]; then
  KEY="$(cat)"
  [[ -z "$KEY" ]] && { echo "error: empty key on stdin" >&2; exit 1; }
  KEY="$KEY" umask 077
  printf 'MINIMAX_API_KEY=%s\n' "$KEY" > "$TARGET"
  echo "wrote: $TARGET  (perms: $(stat -f '%Lp' "$TARGET" 2>/dev/null || stat -c '%a' "$TARGET" 2>/dev/null))"
  exit 0
fi

# Interactive / template
KEY="${MINIMAX_API_KEY:-}"
if [[ -z "$KEY" ]]; then
  echo "Enter your MiniMax API key (input is visible):"
  read -r KEY
  [[ -z "$KEY" ]] && { echo "error: empty key" >&2; exit 1; }
fi

umask 077
cat > "$TARGET" <<EOF
# MiniMax API key — generated at https://platform.minimax.io/user-center/basic-information/interface-key
MINIMAX_API_KEY=$KEY

# Optional overrides (uncomment to use):
# MINIMAX_API_ENDPOINT=https://api.minimax.io/v1/image_generation
# MINIMAX_IMAGE_MODEL=image-01
EOF

PERMS=$(stat -f '%Lp' "$TARGET" 2>/dev/null || stat -c '%a' "$TARGET" 2>/dev/null)
echo "wrote: $TARGET  (perms: $PERMS)"
echo
echo "Next steps:"
echo "  1. Add '.env' to your .gitignore (if not already)"
echo "  2. Verify:  bash $(dirname "$0")/check_env.sh"
echo "  3. Try it:  bash $(dirname "$0")/generate.sh --prompt \"a sunset\" --out-dir ./gen"
