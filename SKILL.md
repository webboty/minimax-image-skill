---
name: minimax-image
description: Generate images via the MiniMax Image-01 API. Use when the user asks to create, render, or generate an image, picture, illustration, artwork, photo, or visual asset. Supports text-to-image, custom aspect ratios, batch generation, deterministic seeding, and reference-image-based character generation.
---

# MiniMax Image — Agent Skill Guide

Generate images via the MiniMax Image-01 API.
Direct HTTP call to `https://api.minimax.io/v1/image_generation` — no CLI wrapper, no SDK, no extra dependencies beyond `curl` and `jq`.

## Prerequisites

```bash
# 1. Install jq (macOS)
brew install jq

# Linux (Debian/Ubuntu)
sudo apt install jq
```

## API Key — three ways to provide it

Get your key at <https://platform.minimax.io/user-center/basic-information/interface-key>.

The skill searches in this order (highest priority first):

1. **Shell env var** (wins always)
   ```bash
   export MINIMAX_API_KEY="eyJ..."
   ```
2. **Project-local `.env`** (in CWD — recommended for apps that already use dotenv)
   ```bash
   # .env  (add to your project's .gitignore!)
   MINIMAX_API_KEY=eyJ...
   ```
3. **Global `~/.config/minimax-image/.env`** or legacy `key` file
   ```bash
   bash ~/.config/opencode/skills/minimax-image/scripts/init_env.sh --global
   ```

**The helper:**
```bash
bash ~/.config/opencode/skills/minimax-image/scripts/init_env.sh             # writes ./.env (chmod 600)
bash ~/.config/opencode/skills/minimax-image/scripts/init_env.sh --global     # writes ~/.config/minimax-image/.env
echo "$KEY" | bash .../init_env.sh --from-stdin                                # pipe from password manager, no shell history
```

**Python usage** (the same `.env` works for any tool that uses `python-dotenv`):
```python
from dotenv import load_dotenv
load_dotenv()  # reads ./.env by default
import os
key = os.environ["MINIMAX_API_KEY"]
```

## Verify

```bash
bash ~/.config/opencode/skills/minimax-image/scripts/check_env.sh
```

Reports:
- `jq` / `curl` presence
- which source the API key was resolved from (and warns if `.env` is not git-ignored)
- whether the API endpoint is reachable

## Quick Start

```bash
# Single image, default 1:1
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "A corgi astronaut floating in space, photorealistic, 8k"

# Custom aspect ratio, 3 variations
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "Minimalist logo for a coffee shop, black on white" \
  --aspect-ratio 1:1 \
  --n 3 \
  --out-dir ./gen

# Deterministic (same seed = same image)
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "Sunset over mountains" \
  --seed 42 \
  --out-dir ./gen
```

## Flags

| Flag | Type | Required | Description |
|---|---|---|---|
| `--prompt <text>` | string | yes | Image description, max 1500 chars |
| `--aspect-ratio <ratio>` | string | no | One of `1:1` (default), `16:9`, `4:3`, `3:2`, `2:3`, `3:4`, `9:16`, `21:9` |
| `--width <px>` | int | no | 512–2048, must be divisible by 8, paired with `--height`. Overridden by `--aspect-ratio` if both set |
| `--height <px>` | int | no | Same as `--width` |
| `--n <count>` | int | no | Number of images, 1–9, default 1 |
| `--seed <int>` | int | no | Deterministic seed for reproducible results |
| `--prompt-optimizer` | flag | no | Enable automatic prompt enhancement (default: off) |
| `--response-format <fmt>` | string | no | `url` (default, expires 24h) or `base64` |
| `--out-dir <dir>` | path | no | Save images to directory. Filename pattern: `<prefix>-<index>.<ext>` |
| `--out-prefix <prefix>` | string | no | Filename prefix, default `image` |
| `--quiet` | flag | no | Suppress progress on stderr, stdout = clean data |
| `--dry-run` | flag | no | Print the JSON request body without calling the API |

## Output

The script writes clean JSON to stdout (one URL/path per line in `--quiet` mode).

**Without `--out-dir`:**
```json
{
  "id": "03ff3cd0820949eb8a410056b5f21d38",
  "status_code": 0,
  "status_msg": "success",
  "image_urls": ["https://..."],
  "success_count": 1,
  "failed_count": 0
}
```

**With `--out-dir`:**
```json
{
  "id": "...",
  "status_code": 0,
  "image_urls": ["./gen/image-0.jpeg", "./gen/image-1.jpeg"],
  "success_count": 2,
  "failed_count": 0
}
```

Exit code is `0` on success, non-zero on failure.

## API Reference (summary)

- **Endpoint:** `POST https://api.minimax.io/v1/image_generation`
- **Auth:** `Authorization: Bearer $MINIMAX_API_KEY`
- **Model:** `image-01` (only)
- **Prompt length:** max 1500 characters
- **URL expiration:** 24 hours (use `--out-dir` to save locally)

### Error Codes

| status_code | Meaning | Action |
|---|---|---|
| 0 | Success | — |
| 1002 | Rate limit hit | Wait and retry |
| 1004 | Auth failed | Check API key |
| 1008 | Insufficient balance | Top up account |
| 1026 | Sensitive content in prompt | Rephrase prompt |
| 2013 | Invalid parameters | Check prompt/aspect_ratio/n |
| 2049 | Invalid API key | Regenerate key |

## Agent Patterns

```bash
# Generate, then read the URL and pass to vision tool
URL=$(bash scripts/generate.sh --prompt "..." --quiet | jq -r '.image_urls[0]')

# Batch with different prompts (loop)
for prompt in "cat" "dog" "bird"; do
  bash scripts/generate.sh --prompt "$prompt" --out-dir ./animals --quiet
done

# Inspect what the request would look like (debug)
bash scripts/generate.sh --prompt "test" --dry-run
```

## Security Notes

- The API key is **never** passed as a CLI argument (visible in `ps`/history). It's injected by the script as a header from the resolved source.
- `.env` files written by `init_env.sh` are created with `chmod 600` and must be added to your project's `.gitignore` — `check_env.sh` warns if a project-local `.env` is not git-ignored.
- The key is never echoed or written to logs. Use `--from-stdin` mode if piping from a password manager.
- Generated image URLs from `response_format=url` expire after 24 hours. Always pass `--out-dir` for persistent assets.

## Installation (Global)

This skill lives at `~/.config/opencode/skills/minimax-image/` as a symlink to the repository checkout:

```bash
git clone https://github.com/webboty/minimax-image-skill.git ~/Projects/minimax-image
mkdir -p ~/.config/opencode/skills
ln -s ~/Projects/minimax-image ~/.config/opencode/skills/minimax-image
```

Restart OpenCode to discover the skill.
