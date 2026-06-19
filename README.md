# minimax-image

Direct HTTP wrapper for the [MiniMax Image-01](https://platform.minimax.io/docs/api-reference/image-generation-t2i) API, packaged as an [OpenCode](https://opencode.ai) agent skill.

**No CLI wrapper, no npm install, no SDK.** Just `curl` + `jq`.

## What it does

- **Text-to-Image** generation via the MiniMax Image-01 model
- **Aspect ratios:** `1:1`, `16:9`, `4:3`, `3:2`, `2:3`, `3:4`, `9:16`, `21:9`
- **Custom width/height:** 512–2048 px, divisible by 8
- **Batch:** up to 9 images per request
- **Deterministic:** optional `--seed` for reproducible results
- **Auto-save:** `--out-dir` to download URLs (which expire after 24h)
- **Prompt optimization:** optional `--prompt-optimizer`

## Quick start

```bash
# 1. Clone
git clone https://github.com/webboty/minimax-image-skill.git ~/Projects/minimax-image

# 2. Symlink into OpenCode's global skills dir
mkdir -p ~/.config/opencode/skills
ln -s ~/Projects/minimax-image ~/.config/opencode/skills/minimax-image

# 3. Install jq
brew install jq   # macOS
# sudo apt install jq   # Linux

# 4. Set the API key (pick one)
#    a) shell env
export MINIMAX_API_KEY="eyJ..."
#    b) project-local .env
echo 'MINIMAX_API_KEY=eyJ...' > .env && chmod 600 .env
echo '.env' >> .gitignore
#    c) global helper
bash ~/.config/opencode/skills/minimax-image/scripts/init_env.sh --global

# 5. Verify
bash ~/.config/opencode/skills/minimax-image/scripts/check_env.sh

# 6. Generate!
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "A corgi astronaut floating in space, photorealistic, 8k" \
  --out-dir ./gen
```

See [SKILL.md](./SKILL.md) for the full agent-facing reference.

## Files

```
.
├── SKILL.md               # OpenCode agent contract
├── scripts/
│   ├── lib_env.sh         # .env loader (sourced by other scripts)
│   ├── check_env.sh       # Validate jq + API key + .env safety
│   ├── generate.sh        # Main API wrapper
│   └── init_env.sh        # Create .env template (chmod 600)
├── examples/
│   └── basic.md           # Usage examples
├── LICENSE
└── README.md
```

## Why a custom skill (not the official `minimax-multimodal-toolkit`)?

The official skill ships 13 sub-skills, requires `npm install -g mmx-cli`, and depends on `ffmpeg` for video. We only need one HTTP endpoint. This skill is ~150 lines of bash, no supply chain, no beta dependencies, and trivially auditable.

## API key resolution

The skill looks for the key in this order (highest first):

1. `$MINIMAX_API_KEY` (shell env var)
2. `./.env` (current working directory)
3. `~/.config/minimax-image/.env` (global)
4. `~/.config/minimax-image/key` (legacy single-value file)

The same `.env` file is consumable by Python via `python-dotenv`:

```python
from dotenv import load_dotenv
load_dotenv()
import os
key = os.environ["MINIMAX_API_KEY"]
```

## Security

- API key is **never** accepted as a CLI argument (visible in `ps`/history). Always via env, `.env`, or key file with `chmod 600`.
- `check_env.sh` warns if a project-local `.env` is not in `.gitignore`.
- `init_env.sh` writes files with `chmod 600` and supports piping the key from stdin (no shell history).
- The script logs only the URL, never the key.
- Generated image URLs from the API expire after 24 hours — use `--out-dir` for persistent storage.

## API key

Get yours at: <https://platform.minimax.io/user-center/basic-information/interface-key>

## License

MIT
