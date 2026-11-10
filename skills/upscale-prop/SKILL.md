---
name: "upscale-prop"
description: "Upscales and restores prop images (clothing, objects) for characters in a local ComfyUI with SeedVR2 7B Int8, staying faithful to the original. Takes only the image and, optionally, the output file name."
---

# Prop upscale (SeedVR2 7B Int8)

A 100% local pipeline in ComfyUI, driven through the comfy-mcp server. Everything needed is in this file (the `upscale_seedvr2.py` script is at the end). No gallery templates or custom nodes: only native nodes from ComfyUI ≥ 0.40.

Reply in the user's language.

The images become props for characters (references for character sheets and video generators). So the goal is **fidelity**: more resolution and sharpness without changing the item (logo, seams, colors, shape). SeedVR2 is a one-step, prompt-free restorer and preserved detail best in testing. Z-Image-Turbo reinvents details (it changed a logo and erased seams) and must not be used here.

## Inputs

- **Image (required).** A file the agent can read (png, jpg, webp) or one attached in the chat. If there is no image, ask for it and stop.
- **Output file name (optional).** If the user doesn't give one, use `<original_name>_upscale.png`. The extension is always `.png`. If the given name has another extension, switch it to `.png` and tell the user.

Nothing else: **no prompt, no questions** about scale, model, seed or color. Everything is fixed (see "Fixed parameters"). Don't add a prompt or description, and don't ask anything except for the image when it is missing.

## Fixed parameters

| Item | Value |
|---|---|
| Model | `seedvr2_7b_int8_convrot.safetensors` (the largest SeedVR2 that runs on an 8 GB RTX 4060; ComfyUI offloads part to system RAM) |
| VAE | `seedvr2_ema_vae_fp16.safetensors` |
| Sampler | 1 step, cfg 1, euler / simple, denoise 1, seed 42 |
| VAE encode/decode | tiled 512, overlap 128 |
| Color correction | `none` |
| Scale | the longer side goes to ~2400 px, at most 4x; an image already over 2400 px gets 1x (restoration only); the output never exceeds 6 MP (if the original is already larger, it is downscaled before restoring, and the user is told) |
| Transparency | preserved: the input PNG's alpha goes in through `JoinImageWithAlpha`; the output is always RGBA PNG (opaque when the input is opaque) |

The script computes the scale itself and reports the output resolution.

## Requirements (models)

| File | ComfyUI folder | URL |
|---|---|---|
| `seedvr2_7b_int8_convrot.safetensors` (8.3 GB) | `models/diffusion_models` | https://huggingface.co/Comfy-Org/SeedVR2/resolve/main/diffusion_models/seedvr2_7b_int8_convrot.safetensors |
| `seedvr2_ema_vae_fp16.safetensors` (0.5 GB) | `models/vae` | https://huggingface.co/Comfy-Org/SeedVR2/resolve/main/vae/seedvr2_ema_vae_fp16.safetensors |

If workflow validation reports a missing model, download it through comfy-mcp (`download_model(url, relative_path="models/<folder>", filename=..., wait=False)`) and poll the download status until it is `completed`.

ComfyUI ≥ 0.40 (nodes `SeedVR2Preprocess`, `SeedVR2Conditioning`, `SeedVR2PostProcessing`, `ResizeImageMaskNode`). Python with Pillow wherever the agent runs shell commands.

Time on an 8 GB RTX 4060: ~1–2 min per image, including model loading (tested 544→2176 px and 1200→2400 px).

If ComfyUI is not running, start it through comfy-mcp (`launch_comfyui`). If your models live in a shared folder (e.g. ComfyUI Desktop), pass `extra_args=["--listen","127.0.0.1","--extra-model-paths-config","<EXTRA_MODEL_PATHS_YAML>"]`. The call may time out even while ComfyUI is starting; check the server status or queue before retrying.

## Steps

Notation: `<folder>` = folder of the original image; `<name>` = file name without extension; `<output>` = final PNG name.

### 0. Prepare
- Confirm ComfyUI is up (server info through comfy-mcp; if it is not running, start it as above).
- Image attached in the chat: save it to a folder on the user's machine before continuing. If it's unclear which folder, ask the user.
- Create `<folder>/_upscale/` and write `upscale_seedvr2.py` (code at the end) there, if it isn't there yet.
- Set `<output>`: the user's name (with `.png`) or `<name>_upscale.png`. **If it already exists in `<folder>`, don't overwrite it**: use `<output without .png>_v2.png`, `_v3`… and tell the user.

### 1. Workflow
- In a shell:
  `python3 _upscale/upscale_seedvr2.py workflow "<image>" "<input_name>" "_upscale/wf_upscale_<name>.json" "props_upscale/<output without .png>"`
  The script prints `input`, `multiplier` and `approx_output`. Keep these values for the report.
- `<input_name>` = the original file name (with extension), which is the name it gets in ComfyUI's `input` folder.

### 2. Run
- Upload the image to ComfyUI's `input` through comfy-mcp (`upload_file([image path], overwrite=True)`). **A missing input image makes the job fail when queued.** Check that the returned name equals `<input_name>`; if it doesn't, redo step 1 with the returned name.
- Validate the workflow JSON through comfy-mcp. If it is invalid because of a missing model, download it (see Requirements) and validate again.
- Run the workflow through comfy-mcp without blocking (`run_workflow(wait=False)`) → `prompt_id`. Many MCP clients time out on long calls, so don't wait inside a single call: poll the job status every ~60–110 s until it is `completed`.
- Out-of-memory error (`server_died`, OOM): free ComfyUI's memory, check system stats and run again once. If it fails again, tell the user (another program may be using the GPU).

### 3. Fetch and rename
- Fetch the outputs through comfy-mcp into `<folder>` (`fetch_outputs(prompt_id, out_dir=<folder>)`) → a single file `<first 8 chars of prompt_id>_000.png`.
- Rename it without overwriting: `mv -n "<id>_000.png" "<output>"`. Check size and mode (`RGBA`) with Pillow.

### 4. Review (required before delivering)
- `python3 _upscale/upscale_seedvr2.py compare "<image>" "<output>" "_upscale/preview_<name>.jpg"` → an image with the full view side by side plus the two most detailed crops.
- Look at the preview yourself. Check:
  - item identical to the original: shape, colors, seams, pockets, zipper;
  - logos and text: SeedVR2 cannot recover letters that aren't sharp in the original; with small fonts it invents letter shapes. If that happens, say clearly that the logo/text is "similar, but illegible/altered";
  - wavy stripes and weaves (inherited from the original's compression);
  - transparency edges, when the input has alpha.
- Show the preview to the user together with the report.

### 5. Report
One or two sentences: where the file is (`<folder>/<output>`), input → output resolution and multiplier, and the issues seen in the preview. If the scale was 1x or below 1, explain why.

## Output

- `<folder>/<output>`: the upscaled prop, next to the original. The original is never modified.
- `<folder>/_upscale/`: `upscale_seedvr2.py`, `wf_upscale_<name>.json` (reusable) and `preview_<name>.jpg`.

File notes:
- Never delete or overwrite the user's files: rename with `mv -n`.
- Paths: the script uses paths as seen by the shell where it runs; comfy-mcp tools (`upload_file`, `validate_workflow`, `run_workflow`, `fetch_outputs`) use paths as seen by the machine running the comfy-mcp server. On a single machine they are the same; if the agent runs in a VM or container, translate between them.

## Lessons from testing

- Zip-up track jacket (1200×1200 webp): SeedVR2 7B Int8 at 2x kept seams, logo and collar; Z-Image-Turbo 2K changed the logo, erased the chest seam and altered the collar.
- 4x on 1200 px (4800 px, 23 MP) is too heavy for 8 GB; a target of ~2400 px on the longer side runs in ~1–2 min.
- Track jacket with a crest (544×544 webp, 4x → 2176 px): fabric, cuffs and zipper improved a lot, but the crest text, blurry in the original, turned into invented letters.
- `SaveImage` outputs RGBA even with an opaque input (alpha 255 everywhere).

## Script `upscale_seedvr2.py`

```python
#!/usr/bin/env python3
"""Prop upscale with SeedVR2 7B Int8 (native ComfyUI nodes, no custom nodes).
Usage:
  python upscale_seedvr2.py workflow <local_image> <input_name> <out.json> <output_prefix> [seed]
  python upscale_seedvr2.py compare <original> <upscale> <out.jpg>
"""
import json, os, sys
from PIL import Image, ImageFilter, ImageStat, ImageDraw

UNET = "seedvr2_7b_int8_convrot.safetensors"
VAE = "seedvr2_ema_vae_fp16.safetensors"
TARGET = 2400    # longer side of the output, in px
MAX_MULT = 4.0   # never upscale more than 4x
MAX_MP = 6.0     # output megapixel cap (RTX 4060 8 GB: 5.8 MP tested)


def multiplier(w, h):
    m = max(1.0, min(MAX_MULT, TARGET / max(w, h)))
    if w * h * m * m / 1e6 > MAX_MP:          # already large: cap by pixel count (may end up < 1)
        m = (MAX_MP * 1e6 / (w * h)) ** 0.5
    return round(m, 4)


def workflow(input_name, prefix, mult, seed):
    tiles = {"tile_size": 512, "overlap": 128, "temporal_size": 4096, "temporal_overlap": 8}
    return {
        "1": {"class_type": "LoadImage", "inputs": {"image": input_name}},
        "2": {"class_type": "JoinImageWithAlpha", "inputs": {"image": ["1", 0], "alpha": ["1", 1]}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "4": {"class_type": "UNETLoader", "inputs": {"unet_name": UNET, "weight_dtype": "default"}},
        "5": {"class_type": "ResizeImageMaskNode", "inputs": {"input": ["2", 0], "resize_type": "scale by multiplier",
              "resize_type.multiplier": mult, "scale_method": "lanczos"}},
        "6": {"class_type": "SeedVR2Preprocess", "inputs": {"resized_images": ["5", 0]}},
        "7": {"class_type": "VAEEncodeTiled", "inputs": {"pixels": ["6", 0], "vae": ["3", 0], **tiles}},
        "8": {"class_type": "SeedVR2Conditioning", "inputs": {"model": ["4", 0], "vae_conditioning": ["7", 0]}},
        "9": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 1, "cfg": 1, "sampler_name": "euler",
              "scheduler": "simple", "denoise": 1, "model": ["4", 0], "positive": ["8", 0], "negative": ["8", 1],
              "latent_image": ["7", 0]}},
        "10": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["9", 0], "vae": ["3", 0], **tiles}},
        "11": {"class_type": "SeedVR2PostProcessing", "inputs": {"images": ["10", 0], "original_resized_images": ["5", 0],
               "color_correction_method": "none"}},
        "12": {"class_type": "SaveImage", "inputs": {"images": ["11", 0], "filename_prefix": prefix}},
    }


def detail_tiles(im, n=2, grid=4):
    """The n blocks with the most edges (most detail) in a grid x grid layout, in relative coordinates."""
    g = im.convert("L").filter(ImageFilter.FIND_EDGES)
    w, h = im.size; tw, th = w / grid, h / grid; scores = []
    for i in range(grid):
        for j in range(grid):
            box = (int(i * tw), int(j * th), int((i + 1) * tw), int((j + 1) * th))
            scores.append((ImageStat.Stat(g.crop(box)).mean[0], (i / grid, j / grid, (i + 1) / grid, (j + 1) / grid)))
    return [b for _, b in sorted(scores, reverse=True)[:n]]


def compare(orig, up, out, side=700):
    o = Image.open(orig).convert("RGB"); u = Image.open(up).convert("RGB")
    def crop(im, b):
        w, h = im.size
        return im.crop((int(b[0] * w), int(b[1] * h), int(b[2] * w), int(b[3] * h))).resize((side, side), Image.LANCZOS)
    fit = lambda im: im.resize((side, round(side * im.height / im.width)), Image.LANCZOS)
    rows = [(fit(o), fit(u))] + [(crop(o, b), crop(u, b)) for b in detail_tiles(o)]
    H = sum(a.height for a, _ in rows) + 40
    c = Image.new("RGB", (2 * side + 12, H), "white"); d = ImageDraw.Draw(c)
    d.text((8, 12), f"original {o.size[0]}x{o.size[1]}", fill="black")
    d.text((side + 20, 12), f"SeedVR2 7B {u.size[0]}x{u.size[1]}", fill="black")
    y = 40
    for a, b in rows:
        c.paste(a, (0, y)); c.paste(b, (side + 12, y)); y += a.height
    c.save(out, quality=90); print(out)


if __name__ == "__main__":
    a = sys.argv
    if a[1] == "workflow":
        img, input_name, out, prefix = a[2], a[3], a[4], a[5]
        seed = int(a[6]) if len(a) > 6 else 42
        w, h = Image.open(img).size; m = multiplier(w, h)
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        json.dump(workflow(input_name, prefix, m, seed), open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(json.dumps({"input": [w, h], "multiplier": m, "approx_output": [round(w * m), round(h * m)], "json": out}))
    elif a[1] == "compare":
        compare(a[2], a[3], a[4])
```
