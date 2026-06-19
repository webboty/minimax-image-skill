# Examples

## Basic: single image

```bash
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "A serene Japanese garden in autumn, soft golden light"
```

→ returns JSON with one `image_urls[]` entry (URL expires in 24h).

## Save to disk

```bash
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "Minimalist logo, black on white, vector" \
  --aspect-ratio 1:1 \
  --out-dir ./gen \
  --out-prefix logo
```

→ downloads `gen/logo-0.jpeg`.

## Batch of 4 with deterministic seed

```bash
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "Vintage travel poster for Mars, 1950s style" \
  --n 4 \
  --seed 42 \
  --aspect-ratio 4:3 \
  --out-dir ./gen
```

→ 4 files: `gen/image-0.jpeg` … `gen/image-3.jpeg`, all reproducible from seed 42.

## Wide cinematic

```bash
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "Cinematic wide shot of a desert highway at sunset" \
  --aspect-ratio 21:9 \
  --out-dir ./gen
```

## Custom dimensions (e.g. 1024x576)

```bash
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "Mountain landscape" \
  --width 1024 --height 576 \
  --out-dir ./gen
```

## With prompt optimizer (MiniMax enhances the prompt automatically)

```bash
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "dog" \
  --prompt-optimizer \
  --out-dir ./gen
```

## Dry-run (debug what would be sent)

```bash
bash ~/.config/opencode/skills/minimax-image/scripts/generate.sh \
  --prompt "test" \
  --aspect-ratio 16:9 \
  --n 3 \
  --dry-run
```

→ prints the JSON body without making the API call.

## Pipe to jq for a clean URL

```bash
URL=$(bash scripts/generate.sh --prompt "A cat" --quiet | jq -r '.image_urls[0]')
echo "Generated: $URL"
```

## Chaining with vision tools

```bash
URL=$(bash scripts/generate.sh --prompt "Abstract painting" --quiet | jq -r '.image_urls[0]')
# then feed $URL to a vision analysis tool
```
