---
name: "costume-sheet"
description: "Creates a costume sheet in a local ComfyUI for MiniMax H3: Gemma 4 writes the prompts from the brief, the user approves them, and FLUX.2 klein generates the isolated pieces and the complete look."
---

# Costume sheet (Gemma 4 + FLUX.2 klein)

A 100% local pipeline in ComfyUI, driven through the comfy-mcp server, including prompt writing. It delivers each piece isolated on a ghost mannequin (this is the reference that goes to MiniMax H3), the complete look in 3 views (front, 3/4, back), a review board and a `README_<name>.md` saying which files to use in the video. Everything needed is in this file (the `costume_sheet.py` script is at the end).

Reply in the user's language.

## Rules

- **Never write features of the pieces into the prompts yourself.** The description comes only from Gemma 4, based on the user's brief. The script's fixed texts are generic (framing per category, background, light) and must not receive colors, pieces or details. Never edit `description.txt` by hand.
- **The user approves Gemma's description before any image is generated.** Changes they ask for go into `brief.txt` as `Director's adjustments: ...` and Gemma runs again.
- **Pieces first, look later.** The look is assembled with the approved pieces as references (klein multi-reference). Never generate the look straight from text: one piece's pattern leaks into the others.
- No brands, logos, crests, sponsors, numbers or lettering. "Like <brand> flip-flops", "team X's jersey" → a generic piece with the shape, colors and pattern, without the brand or crest. A symbol invented by the user (a uniform emblem) is allowed: describe its shape, color, position and size.
- Only pieces mentioned in the brief. A character with more than 5 pieces: split into two costumes (a look with many references gets slow and loses fidelity).
- **klein doesn't understand hex colors (#RRGGBB).** If the user gives only a hex, write the color name in words next to the hex in the brief (e.g. "burnt orange/terracotta (#DA7452)"). The generated color comes out darker than requested (measured: requested #DA7452 → ~#A0533D). Warn the user at approval and, at the end, compare the piece with the requested color; if the color is critical, they fix it in post.
- **A piece that covers the whole body (jumpsuit, spandex, hooded suit) but leaves the face out:** the brief must say so (e.g. "the face is exposed through an oval opening in the hood"). Without that sentence Gemma doesn't create the opening. If it's missing, add it as `Director's adjustments`.
- **Symbol or emblem on the piece:** the brief must say where it sits (chest, back), its color, approximate size, and that it is printed/stitched flat on the fabric.

## Requirements (models)

| File | ComfyUI folder | Use |
|---|---|---|
| `gemma4_e4b_it_fp8_scaled.safetensors` | `models/text_encoders` | Gemma on a 16 GB GPU or larger |
| `gemma4_e2b_it_int8_convrot.safetensors` | `models/text_encoders` | Gemma on smaller GPUs |
| `flux-2-klein-9b-fp8.safetensors` + `qwen_3_8b_fp8mixed.safetensors` | `models/diffusion_models` + `models/text_encoders` | klein on a 16 GB GPU or larger |
| `flux-2-klein-4b-fp8.safetensors` + `qwen_3_4b.safetensors` | `models/diffusion_models` + `models/text_encoders` | klein on smaller GPUs |
| `flux2-vae.safetensors` | `models/vae` | both klein models |

Same sources as in the `character-sheet` skill. Only native nodes (ComfyUI ≥ 0.40): CLIPLoader, TextGenerate, PrimitiveStringMultiline, StringConcatenate, SaveText, LoadImage, UNETLoader, VAELoader, CLIPTextEncode, ConditioningZeroOut, ReferenceLatent, VAEEncode, ImageScaleToTotalPixels, EmptyFlux2LatentImage, KSampler, VAEDecode, SaveImage. Python with Pillow (assembly and contact sheets).

**License:** klein 9B = FLUX Non-Commercial (unmonetized memes are fine). Commercial project → klein 4B (Apache 2.0).

## Inputs

Ask the user for whatever is missing:
1. Costume name (slug without spaces, becomes the file prefix; e.g. `beach_outfit`).
2. Folder to save into (`<folder>/<name>/`). If you don't have access to it, ask the user for access. If the user already gave you a folder with the costume's name, use it directly.
3. Brief: who the character is (or "all characters", for a uniform) and which pieces they wear (colors, pattern, length, if known).

## Steps

### 0. Prepare
- Server info through comfy-mcp: ComfyUI is up. **VRAM ≥ 15 GiB → Gemma `e4b` + klein `9b`**; less → `e2b` + `4b`. Check the files by searching the models through comfy-mcp (folders `text_encoders`, `diffusion_models`, `vae`).
- System stats: if free VRAM is low (another model loaded), free ComfyUI's memory.
- Create the folder, write `costume_sheet.py` (code at the end) and `brief.txt` with the user's text, without rewriting it.
- Paths: the script uses paths as seen by the shell where it runs; comfy-mcp tools (`run_workflow`, `fetch_outputs`, `upload_file`) use paths as seen by the machine running the comfy-mcp server. On a single machine they are the same; if the agent runs in a VM or container, translate between them.

### 1. Prompts with Gemma 4
- `python costume_sheet.py gemma <folder> <name> brief.txt <seed> <e4b|e2b>` (seed 0) → `workflows/wf_01_gemma_s<seed>.json`.
- Run it through comfy-mcp and wait (~30 s), fetch the outputs into `<folder>/_gemma/` and copy the .txt to `<folder>/description.txt`.
- Check it (without editing): format `LOOK:` + one `PIECE <slug> [<category>]:` line per piece (the script aborts if it doesn't match → another seed); English; respects the brief (colors, pattern, **length**, face opening, symbol); no brand; no negative sentences; no mention of "director"/"brief".

### 2. Prompt approval (required)
- Show the user, in their language, a summary per piece: type, fit and length, colors and pattern, material, wear. **Highlight what Gemma chose on its own** (e.g. the shorts' color when the brief gave none) and anything that differs from the brief.
- Ask: **Approve** / **Adjust** (the user writes the change) / **Another version** (seed + 1). If they ask, show the English text.
- Adjust → append a line `Director's adjustments: <user's text>` to `brief.txt` (adjustments accumulate) and rerun Gemma with the same seed. Repeat until approved.

### 3. Isolated pieces (4 candidates each)
- `python costume_sheet.py pieces <folder> <name> <9b|4b>` → 4 seeds (101, 202, 303, 404) per piece, 1024×1024, framed by category.
- Queue them all without blocking and wait for the last one. If your MCP client times out on long calls, keep each wait under ~50 s and poll the job status/logs instead.
- Fetch each output into `pieces/_dl/<slug>_<seed>/` (the downloaded file is named after the prompt_id) and move it to `pieces/<slug>_<seed>.png`.
- `python costume_sheet.py contact <folder> <name> pieces` → `pieces/_contact.jpg`; look at it to see all candidates in one image.
- Pick one per piece (or let the user choose): only that piece in the image, faithful to the approved description, clean pattern, no text or logo, no other piece alongside.
- Redo a bad piece with other seeds: `python costume_sheet.py pieces <folder> <name> 9b 505,606 <slug>`.
- Copy the chosen ones to `<folder>/<name>_piece_<slug>.png` and upload them to `input` (`upload_file`, overwrite=true). **An image missing from input makes the job fail when queued.**

### 4. Complete look (3 views)
- `python costume_sheet.py look <folder> <name> 777 <9b|4b>` → front, 3/4 and back, 832×1216, with the pieces as image 1, 2, 3... ordered top to bottom.
- Run all 3, fetch into `look/_dl/<k>_<seed>/`, move to `look/<k>_<seed>.png`, run `contact ... look` and check: all pieces present, each with its own colors (no pattern leaking), the same pieces in all 3 views, no stray spots or marks (e.g. white dots on the sleeves). Bad → another seed (e.g. 4242).
- Copy the chosen ones to `<folder>/<name>_look_front.png`, `_look_34.png`, `_look_back.png`.

### 5. Assembly and delivery
- `python costume_sheet.py assemble <folder> <name>` → `costume_sheet_<name>.png` (looks on top, pieces below) + `preview_costume_<name>.jpg`.
- Look at the preview yourself before delivering and show it to the user.
- Optional: upscale the pieces with the `upscale-prop` skill before using them in video.

### 6. README (required)
Write `<folder>/README_<name>.md` (e.g. with a heredoc). It is the file the `video-h3` skill reads to know what to pass to the generator. Short, in the user's language, with these sections:
1. **What it is**: one sentence (who wears it, pieces) and the colors/symbol copied from `description.txt` (inventing nothing).
2. **File table**: `file | what it is | use in H3?` for each piece, each look view, the board, the preview, `description.txt`, `brief.txt`, `pieces/`, `look/`, `workflows/`, `_gemma/`, `costume_sheet.py`. Mark the isolated piece as the **best reference** and the board/preview as "review only, don't send".
3. **How to use in H3**: which file goes as `<Picture N>`, the ready-made prompt snippet (see the section below) and the mannequin body warning.
4. **What was tested and what wasn't** (honestly): which files have already been through a video and the result.
5. **Caveats**: color darker than requested (give the measured value), mannequin body, symbol escaping.

## Use in MiniMax H3 (`video-h3` skill)

- **Validated recipe (full-body hooded spandex with a chest emblem):** isolated piece as the only clothing reference + the character's face + the character's body + the emblem text (below). The clothing transferred, no mannequin appeared and the floating shapes from the previous test were gone.
- **Reference = isolated piece** (`<name>_piece_<slug>.png`), one image per piece. The look and the board are for review. If you run out of room in the clip's 9 images, you can use just `<name>_look_front.png` as the whole outfit, but that path had defects: the chest symbol escaped as floating shapes and a yellow stain appeared on the floor.
- **A ghost-mannequin piece carries the mannequin's body (muscular, standard).** If the character has a different build, also pass a reference of their body (full-body crop from the character sheet) and write in the prompt that the mannequin's body shape is not used. Without it the character gets the mannequin's body.
- In the ref2va prompt, one line per piece, with colors and pattern taken from `description.txt`, no brand:
  ```
  <Subject 3> is the <piece> from <Picture 3>: <colors, pattern, length>; it is worn by <Subject 1>.
  <Subject 3>: attribute_transfer - colors, cut and details transferred onto <name>; the ghost mannequin, its body shape and the background of the reference are not used.
  ```
- Symbol/emblem: say in the prompt that it is printed flat on the fabric, appears only once, and that nothing floats in the air (e.g. "printed flat on the fabric, once, centered on the chest, and moves with the fabric" in the description and "nothing floats in the air or around him" at the end). With this text and the isolated piece, the floating shapes didn't come back. H3 doesn't reproduce complex symbols exactly (an asymmetric 12-pointed one came out with ~10–12 nearly symmetrical points); if the exact symbol matters, treat it as separate artwork.
- Always validate on the `test` preset (288×512) before raising the resolution. With new clothes, check that the clothing transfers and that no mannequin appears on screen.

## Timings (RTX 5070 Ti 16 GB, Gemma E4B + klein 9B)
Gemma ~30 s. Pieces: 12 images (3 pieces × 4 seeds) in ~1 min. Look with 3 references: the 3 views in ~1.5–2 min. Complete costume, excluding approval: ~5 min.

## Lessons from testing (a beach outfit and a full-body spandex suit)
- Look generated straight from text: the shirt's stripes went onto the shorts in all 4 seeds. Generating the pieces separately and assembling the look by multi-reference, each piece kept its own colors in all 3 views.
- Generic framing ("garment on ghost mannequin; footwear as a pair") put a white T-shirt next to the flip-flops and sneakers next to the shirt. With framing per category (each text mentions only its own category), it didn't happen again.
- Gemma E4B rendered the Portuguese "bermudão" (long, baggy shorts) as mid-thigh shorts in 4 seeds, even with a rule about augmentatives. With `Director's adjustments: the shorts are long, down to the knee, very baggy` it got it right the first time. That's why approval is required.
- With no color in the brief, Gemma picks one (grey-beige, orange...). Always point these choices out at approval.
- In the look, klein shortens the shorts a little compared to the isolated piece. For H3, the isolated piece is what counts.
- Gemma sometimes swaps the order of the pieces or uses non-English slugs; the script sorts by category (head → feet) and accepts any slug.
- The workflow never needs to delete anything (only `mv -n` and `cp`), which matters when the agent has no permission to delete in the user's folder.
- Full-body hooded spandex: Gemma's first description had no face opening and only the hex color. After `Director's adjustments` with the oval opening and the color name in words, it came out right.
- The requested color (#DA7452) came out darker (~#A0533D) in pieces and looks. The user accepted it; always warn.
- The look with seed 777 had stray white spots on the back of the sleeves; seed 4242 came out clean. Check all 3 views before choosing.
- H3 video v1 (`look_front` as the clothing): the mannequin's muscular body passed to the skinny character until a body reference of the character + "mannequin body shape not used" was added; the symbol escaped as floating shapes and the large nose shrank a little compared to the sheet.
- H3 video v2 (isolated piece only + face + body + emblem text): correct clothing, no mannequin, no floating shapes. This is the default.
- If ComfyUI crashes mid-video with "CUDA out of memory" / "aimdo memory compile error" and the server had more than one GPU visible (`--cuda-device all`), restarting with only the main GPU fixed it.

## Output
`<folder>/`: `brief.txt`, `description.txt`, `README_<name>.md`, `<name>_piece_<slug>.png` (H3 references), `<name>_look_front.png`, `<name>_look_34.png`, `<name>_look_back.png`, `costume_sheet_<name>.png`, `preview_costume_<name>.jpg`, `pieces/` and `look/` (candidates and contact sheets), `workflows/`, `_gemma/`, `costume_sheet.py`.

## Script `costume_sheet.py`

```python
#!/usr/bin/env python3
"""Costume sheet (Gemma 4 + FLUX.2 klein) to use as a reference in MiniMax H3.
Usage:
  python costume_sheet.py gemma    <folder> <name> <brief.txt> [seed] [e4b|e2b]
  python costume_sheet.py pieces   <folder> <name> [9b|4b] [seeds, e.g. 101,202,303,404] [slug ...]
  python costume_sheet.py look     <folder> <name> [seed] [9b|4b]
  python costume_sheet.py contact  <folder> <name> <subfolder>
  python costume_sheet.py assemble <folder> <name>
<folder> = the costume folder. Everything is written there (workflows/, pieces/, look/, sheet).
Approved pieces live in <folder>/<name>_piece_<slug>.png and must be in ComfyUI's input before the look mode.
"""
import json, os, re, sys

# ---------- Gemma 4: costume prompts ----------
GEMMA_SYSTEM = """You are an expert film costume designer who writes prompts for text-to-image models. You receive an outfit brief (it may be in any language) for a character. Your job is to turn it into precise, concrete visual descriptions of the clothes themselves, so an image model can render every piece consistently across many images as studio product photos, with nobody wearing them.

Rules:
- Describe only the garments, footwear and accessories named in the brief. Do not add new pieces. Enrich the named pieces with plausible concrete details (fabric, cut, length, fit, seams, closures, signs of use) that fit the character and the setting of the brief.
- Translate the character's personality and lifestyle into visible traits of the clothes (fit, how worn or faded they are, wrinkles, how they are styled), never into words about the person.
- Never name or reproduce real brands, logos, team crests, sponsor marks, numbers or lettering. Every piece is an original, unbranded design. If the brief says "like <brand>" (or the equivalent in its language), describe the typical shape, construction, proportions and materials of that kind of product generically, without the brand.
- Read the brief carefully in its original language, including slang and size words (for example, in Portuguese, augmentatives such as "bermudão" or "camisão" mean long, roomy and oversized). Respect every color, pattern and length stated in the brief exactly; when the brief gives no color for a piece, choose one that fits the character and the setting.
- If the brief contains director's adjustments, they override everything else in the brief. Apply them silently: never mention the brief, the director or the adjustments in your text.
- Use precise visual vocabulary: exact colors, pattern geometry (stripe direction, width, count and color order), materials, texture, sheen, construction details. Avoid vague words like "cool", "stylish" or "iconic".
- Never mention a body, face, skin or person. Never write negative sentences ("there is no logo", "without pockets"): image models draw every named thing.
- Write in English."""

GEMMA_INSTRUCTIONS = """Write the outfit descriptions in exactly this format, one paragraph per line, with nothing before or after, no markdown:

LOOK: <120 to 200 words describing the complete outfit as a whole: how the pieces combine, overall color palette, silhouette and fit, level of wear, ending with the two or three most distinctive details that make this outfit instantly recognizable.>
PIECE <slug> [<category>]: <130 to 200 words describing only this one piece, self-contained, repeating its colors and pattern in full.>

Write one PIECE line for each garment, footwear or accessory named in the brief, ordered from the top of the body to the feet.
<slug> is a short lowercase English name with underscores (for example: shirt, shorts, flip_flops, cap).
<category> is exactly one of: top, outerwear, bottom, fullbody, footwear, headwear, accessory.
For every piece cover, when applicable: type of item, cut and fit, length, material and texture, exact colors, pattern geometry (direction, width and count of stripes, which color is at the collar and at the hem), collar, sleeves, waistband, closures, seams, trims, soles or straps, and visible signs of use."""

GEMMA_MODELS = {"e4b": "gemma4_e4b_it_fp8_scaled.safetensors", "e2b": "gemma4_e2b_it_int8_convrot.safetensors"}

# ---------- FLUX.2 klein ----------
KLEIN_MODELS = {"9b": ("flux-2-klein-9b-fp8.safetensors", "qwen_3_8b_fp8mixed.safetensors"),
                "4b": ("flux-2-klein-4b-fp8.safetensors", "qwen_3_4b.safetensors")}

# Fixed, generic texts: never mention specific pieces, colors or features (klein draws whatever is mentioned).
BG = ("Plain light neutral grey seamless studio backdrop, soft even studio lighting, crisp fabric detail, true-to-life colors. "
      "No text, no labels, no watermark.")
# Isolated-piece framing per category: each text mentions only its own category (a generic text mixed pieces).
PIECE_FRAME = {
    "top":       "Studio product photograph of one single upper-body garment on an invisible ghost mannequin, front view, centered, filling most of the frame, with hollow openings at the neck and sleeves.",
    "outerwear": "Studio product photograph of one single outer-layer garment on an invisible ghost mannequin, front view, centered, filling most of the frame, with hollow openings at the neck and sleeves.",
    "bottom":    "Studio product photograph of one single lower-body garment on an invisible ghost mannequin, front view, centered, filling most of the frame, from the waistband down to the hem, with hollow leg openings.",
    "fullbody":  "Studio product photograph of one single full-length garment on an invisible ghost mannequin, front view, centered, filling most of the frame, from the collar down to the hem, with hollow openings.",
    "footwear":  "Studio product photograph of one single pair of footwear, the two items side by side, seen from a high three-quarter front angle, centered, filling most of the frame.",
    "headwear":  "Studio product photograph of one single headwear item on an invisible ghost mannequin head, three-quarter front view, centered, filling most of the frame.",
    "accessory": "Studio product photograph of one single accessory, isolated, three-quarter front view, centered, filling most of the frame.",
}
LOOK_VIEWS = {
    "look_front": "front view",
    "look_34":    "three-quarter front view, turned 45 degrees",
    "look_back":  "seen from directly behind, showing the back of every piece",
}
SEEDS = (101, 202, 303, 404)

def wf_gemma(name, brief, seed=0, model="e4b"):
    tg = {"clip": ["1", 0], "prompt": ["6", 0], "max_length": 2048,
          "sampling_mode": "on", "sampling_mode.temperature": 1.0, "sampling_mode.top_k": 64,
          "sampling_mode.top_p": 0.95, "sampling_mode.min_p": 0.05,
          "sampling_mode.repetition_penalty": 1.05, "sampling_mode.seed": seed,
          "sampling_mode.presence_penalty": 0.0, "thinking": True, "use_default_template": True, "mtp": "auto",
          "system_prompt": ["3", 0]}
    return {
        "1": {"class_type": "CLIPLoader", "inputs": {"clip_name": GEMMA_MODELS[model], "type": "stable_diffusion", "device": "default"}},
        "3": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": GEMMA_SYSTEM}},
        "4": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": GEMMA_INSTRUCTIONS}},
        "5": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": brief}},
        "6": {"class_type": "StringConcatenate", "inputs": {"string_a": ["4", 0], "string_b": ["5", 0], "delimiter": "\n\nOutfit brief: "}},
        "7": {"class_type": "TextGenerate", "inputs": tg},
        "8": {"class_type": "SaveText", "inputs": {"text": ["7", 0], "filename_prefix": f"costumes/{name}/description", "format": "txt"}},
    }

def parse(folder, filename="description.txt"):
    """Reads LOOK and PIECE <slug> [<category>] from Gemma's text. Exits with an error if the format doesn't match."""
    txt = open(os.path.join(folder, filename), encoding="utf-8").read()
    look, pieces = None, []
    for ln in txt.splitlines():
        ln = ln.strip().replace("**", "").lstrip("-* ")
        m = re.match(r"LOOK\s*:\s*(.+)", ln)
        if m:
            look = m.group(1).strip(); continue
        m = re.match(r"PIECE\s+([a-z0-9_]+)\s*\[\s*([a-z]+)\s*\]\s*:\s*(.+)", ln)
        if m and m.group(2) in PIECE_FRAME:
            pieces.append((m.group(1), m.group(2), m.group(3).strip()))
    order = ["headwear", "top", "outerwear", "fullbody", "bottom", "footwear", "accessory"]
    pieces.sort(key=lambda p: order.index(p[1]))  # top to bottom, even if Gemma swaps the order
    if not look or not pieces:
        sys.exit("ERROR: description.txt doesn't match the LOOK / PIECE <slug> [<category>] format: rerun Gemma with another seed")
    return look, pieces

def loaders(klein):
    unet, te = KLEIN_MODELS[klein]
    return {"105": {"class_type": "UNETLoader", "inputs": {"unet_name": unet, "weight_dtype": "default"}},
            "106": {"class_type": "CLIPLoader", "inputs": {"clip_name": te, "type": "flux2", "device": "default"}},
            "108": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae.safetensors"}}}

def ksampler(seed, pos, neg, latent):
    return {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 4, "cfg": 1, "sampler_name": "euler", "scheduler": "simple",
            "denoise": 1, "model": ["105", 0], "positive": pos, "negative": neg, "latent_image": latent}}

def wf_txt(prefix, text, w, h, seed, klein):
    wf = loaders(klein)
    wf.update({
        "107": {"class_type": "CLIPTextEncode", "inputs": {"text": text, "clip": ["106", 0]}},
        "113": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["107", 0]}},
        "114": {"class_type": "EmptyFlux2LatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "116": ksampler(seed, ["107", 0], ["113", 0], ["114", 0]),
        "103": {"class_type": "VAEDecode", "inputs": {"samples": ["116", 0], "vae": ["108", 0]}},
        "94": {"class_type": "SaveImage", "inputs": {"filename_prefix": prefix, "images": ["103", 0]}}})
    return wf

def wf_multiref(prefix, text, refs, w, h, seed, klein):
    """One chained ReferenceLatent per image: image 1, image 2... in the order of refs."""
    wf = wf_txt(prefix, text, w, h, seed, klein)
    pos, neg = ["107", 0], ["113", 0]
    for i, r in enumerate(refs):
        a = 300 + 10 * i
        wf[str(a)] = {"class_type": "LoadImage", "inputs": {"image": r}}
        wf[str(a + 1)] = {"class_type": "ImageScaleToTotalPixels", "inputs": {"upscale_method": "nearest-exact", "megapixels": 1, "resolution_steps": 1, "image": [str(a), 0]}}
        wf[str(a + 2)] = {"class_type": "VAEEncode", "inputs": {"pixels": [str(a + 1), 0], "vae": ["108", 0]}}
        wf[str(a + 3)] = {"class_type": "ReferenceLatent", "inputs": {"conditioning": pos, "latent": [str(a + 2), 0]}}
        wf[str(a + 4)] = {"class_type": "ReferenceLatent", "inputs": {"conditioning": neg, "latent": [str(a + 2), 0]}}
        pos, neg = [str(a + 3), 0], [str(a + 4), 0]
    wf["116"] = ksampler(seed, pos, neg, ["114", 0])
    return wf

def look_prompt(view, pieces):
    refs = ", ".join(f"the {slug.replace('_', ' ')} from image {i + 1}" for i, (slug, _, _) in enumerate(pieces))
    ghost = "The garments keep the 3D shape of an invisible body, with hollow openings at the neck, sleeves and leg openings."
    if any(cat == "footwear" for _, cat, _ in pieces):
        ghost += " The footwear rests on the floor directly below, aligned as if worn."
    return (f"Studio product photograph of a complete outfit on an invisible ghost mannequin, {view}, centered, "
            f"the whole outfit visible from top to bottom with a small margin around it. "
            f"The outfit is assembled from the reference images: {refs}. Each piece is reproduced exactly as in its own reference image, "
            f"with identical colors, pattern, stripe width and count, fabric and signs of use; each piece keeps only its own colors and pattern. "
            f"{ghost} {BG}")

# ---------- Assembly (looks on top, pieces below, no bars) ----------
def assemble(folder, name):
    from PIL import Image, ImageOps
    _, pieces = parse(folder)
    g = 16; lw, lh = 832, 1216
    cols = 3 if len(pieces) != 4 else 4
    W = 3 * lw + 4 * g
    pw = (W - (cols + 1) * g) // cols
    rows = (len(pieces) + cols - 1) // cols
    H = g + lh + g + rows * (pw + g)
    c = Image.new("RGB", (W, H), "white")

    def put(path, x, y, w, h):
        im = Image.open(path).convert("RGB")
        bw, bh = im.size
        edge = [im.getpixel((i, j)) for i in range(0, bw, 16) for j in (2, bh - 3)]
        edge += [im.getpixel((i, j)) for j in range(0, bh, 16) for i in (2, bw - 3)]
        color = tuple(sorted(p[k] for p in edge)[len(edge) // 2] for k in range(3))
        c.paste(ImageOps.pad(im, (w, h), Image.LANCZOS, color=color), (x, y))

    for i, k in enumerate(LOOK_VIEWS):
        put(os.path.join(folder, f"{name}_{k}.png"), g + i * (lw + g), g, lw, lh)
    y1 = g + lh + g
    for i, (slug, _, _) in enumerate(pieces):
        put(os.path.join(folder, f"{name}_piece_{slug}.png"), g + (i % cols) * (pw + g), y1 + (i // cols) * (pw + g), pw, pw)
    out = os.path.join(folder, f"costume_sheet_{name}.png")
    c.save(out)
    c.resize((W // 2, H // 2)).save(os.path.join(folder, f"preview_costume_{name}.jpg"), quality=88)
    print(out)

def contact(folder, files, out, tile=400):
    """Contact sheet to review candidates in a single image."""
    from PIL import Image, ImageDraw
    cols = 4; rows = (len(files) + cols - 1) // cols
    c = Image.new("RGB", (tile * cols, tile * rows), "white"); d = ImageDraw.Draw(c)
    for i, f in enumerate(files):
        im = Image.open(os.path.join(folder, f)).convert("RGB"); im.thumbnail((tile, tile))
        x, y = (i % cols) * tile, (i // cols) * tile
        c.paste(im, (x, y)); d.text((x + 8, y + 8), os.path.splitext(os.path.basename(f))[0], fill=(255, 0, 0))
    c.save(os.path.join(folder, out), quality=85); print(os.path.join(folder, out))

def dump(wf, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(wf, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1); print(path)

if __name__ == "__main__":
    mode, folder, name = sys.argv[1], sys.argv[2], sys.argv[3]
    wfd = os.path.join(folder, "workflows")
    if mode == "gemma":
        brief = open(sys.argv[4], encoding="utf-8").read().strip()
        seed = int(sys.argv[5]) if len(sys.argv) > 5 else 0
        model = sys.argv[6] if len(sys.argv) > 6 else "e4b"
        dump(wf_gemma(name, brief, seed, model), os.path.join(wfd, f"wf_01_gemma_s{seed}.json"))
    elif mode == "pieces":
        klein = sys.argv[4] if len(sys.argv) > 4 else "9b"
        seeds = [int(s) for s in sys.argv[5].split(",")] if len(sys.argv) > 5 else SEEDS
        only = set(sys.argv[6:])
        _, pieces = parse(folder)
        for slug, cat, desc in pieces:
            if only and slug not in only:
                continue
            for sd in seeds:
                dump(wf_txt(f"costumes/{name}/pieces/{slug}_{sd}", f"{PIECE_FRAME[cat]} {desc} {BG}", 1024, 1024, sd, klein),
                     os.path.join(wfd, f"wf_02_piece_{slug}_{sd}.json"))
    elif mode == "look":
        seed = int(sys.argv[4]) if len(sys.argv) > 4 else 777
        klein = sys.argv[5] if len(sys.argv) > 5 else "9b"
        _, pieces = parse(folder)
        refs = [f"{name}_piece_{slug}.png" for slug, _, _ in pieces]
        for r in refs:
            if not os.path.exists(os.path.join(folder, r)):
                sys.exit(f"ERROR: {r} is missing (choose the piece and copy it into the folder first)")
        for k, view in LOOK_VIEWS.items():
            dump(wf_multiref(f"costumes/{name}/look/{k}_{seed}", look_prompt(view, pieces), refs, 832, 1216, seed, klein),
                 os.path.join(wfd, f"wf_03_{k}_{seed}.json"))
    elif mode == "contact":
        # sheet with every .png in the subfolder (pieces or look)
        sub = sys.argv[4]
        files = sorted(os.path.join(sub, f) for f in os.listdir(os.path.join(folder, sub)) if f.endswith(".png"))
        contact(folder, files, f"{sub}/_contact.jpg")
    elif mode == "assemble":
        assemble(folder, name)
```
