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

# 4. Set API key
export MINIMAX_API_KEY="eyJ..."

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
│   ├── check_env.sh       # Validate jq + API key
│   └── generate.sh        # Main API wrapper
├── examples/
│   └── basic.md           # Usage examples
├── LICENSE
└── README.md
```

## Why a custom skill (not the official `minimax-multimodal-toolkit`)?

The official skill ships 13 sub-skills, requires `npm install -g mmx-cli`, and depends on `ffmpeg` for video. We only need one HTTP endpoint. This skill is ~150 lines of bash, no supply chain, no beta dependencies, and trivially auditable.

## Security

- API key is read from `MINIMAX_API_KEY` env var (recommended) or `~/.config/minimax-image/key` with `chmod 600`. **Never** as a CLI argument.
- The script logs only the URL, never the key.
- Generated image URLs from the API expire after 24 hours — use `--out-dir` for persistent storage.

## API key

Get yours at: <https://platform.minimax.io/user-center/basic-information/interface-key>

## License

MIT
