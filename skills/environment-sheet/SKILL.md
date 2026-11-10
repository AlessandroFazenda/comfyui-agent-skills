---
name: "environment-sheet"
description: "Creates an environment (location) sheet in a local ComfyUI to reuse in video generators such as MiniMax H3. Requires a detailed brief of the place; if the brief is short, Gemma 4 suggests details for the user to approve. Gemma (E4B on a 16 GB GPU, otherwise E2B) writes the description, the user confirms it, and FLUX.2 klein (9B on a 16 GB GPU, otherwise 4B) plus Qwen-Image-Edit generate the base and the plates."
---

# Environment sheet (Gemma 4 + FLUX.2 klein + Qwen-Image-Edit)

A 100% local pipeline in ComfyUI, driven through the comfy-mcp server. Everything needed to rebuild the workflows is in this file (the `environment_sheet.py` script is at the end); it does not depend on any external .json.

Reply in the user's language.

The sheet is not a grid image: it is a **plate pack** (separate images of the same place, empty, each with a purpose) + the canonical description. Video generators copy the reference's layout; a grid with panels leaks into the video. The final assembly (`sheet_<name>.png`) is for human reference only. Every new environment also ships with `sheet/README.md`, a markdown guide on how to use the plates in MiniMax H3 (step 7).

## Rules

- **The brief rules.** The more detailed, the better the sheet. Ask the user for a complete brief (see "Brief" below). If it is short or vague, **don't invent details**: run Gemma in `suggest` mode, show the suggestions and continue only with what the user approves or corrects.
- **Never write the description yourself.** The description (image prompt) comes only from Gemma 4. You may organize the user's text and the approved suggestions into `brief.txt`, but don't add features of the place on your own. If the description comes out bad, rerun Gemma with another seed or improve the brief; never edit the description by hand.
- **Confirmation required:** after Gemma writes the description and before generating any candidate image, show the description to the user and ask for approval. Without approval, don't generate the base.
- The environment has **no people**. No readable text, logos or brands in the images.
- Don't write negations in texts that go to klein ("no crest", "no horns"): the model draws whatever is mentioned. Describe only what exists ("green and white striped flag").
- Real brands, clubs and companies: only if the user asks. Even then, warn that klein doesn't know crests/logos and invents a different one in each image; the alternative is to describe only colors and shapes.
- **README.md required:** every new environment sheet ends with `sheet/README.md` (markdown, in the user's language) with usage instructions for MiniMax H3, following the template in step 7. Don't deliver the sheet without it.
- Default format **9:16 vertical (864×1536)**; 16:9 (1536×864) if the user asks. All plates in the same format as the video.

## Requirements (models)

| File | ComfyUI folder | Use |
|---|---|---|
| `gemma4_e4b_it_fp8_scaled.safetensors` (9.1 GB) — GPU of 16 GB or larger | `models/text_encoders` | suggestions and description (huggingface.co/Comfy-Org/gemma-4) |
| `gemma4_e2b_it_int8_convrot.safetensors` (5.2 GB) — GPU under 16 GB | `models/text_encoders` | suggestions and description (huggingface.co/Comfy-Org/gemma-4) |
| `flux-2-klein-9b-fp8.safetensors` (9.4 GB) — GPU of 16 GB or larger | `models/diffusion_models` | base and refinement (huggingface.co/black-forest-labs/FLUX.2-klein-9b-fp8, gated repo: accept the terms and download manually) |
| `qwen_3_8b_fp8mixed.safetensors` (8.7 GB) — text encoder for klein 9B | `models/text_encoders` | huggingface.co/Comfy-Org/flux2-klein-9B (split_files/text_encoders) |
| `flux-2-klein-4b-fp8.safetensors` (4.1 GB) — GPU under 16 GB | `models/diffusion_models` | base and refinement (huggingface.co/black-forest-labs/FLUX.2-klein-4b-fp8) |
| `qwen_3_4b.safetensors` — text encoder for klein 4B | `models/text_encoders` | Comfy-Org/z_image_turbo (split_files/text_encoders) |
| `flux2-vae.safetensors` | `models/vae` | klein VAE, 4B and 9B (Comfy-Org/flux2-dev) |
| `qwen-image-edit-2511-Q4_K_M.gguf` | `models/unet` | camera angles (UnetLoaderGGUF node, ComfyUI-GGUF pack) |
| `Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors` | `models/loras` | 4 steps, strength 1.0 |
| `qwen-image-edit-2511-multiple-angles-lora.safetensors` | `models/loras` | camera turns, strength 0.9 |
| `qwen_2.5_vl_7b_fp8_scaled.safetensors` | `models/text_encoders` | Qwen-Image-Edit text encoder |
| `qwen_image_vae.safetensors` | `models/vae` | Qwen-Image-Edit VAE |

ComfyUI ≥ 0.40 and ComfyUI-GGUF. Python with Pillow (assembly, crops, previews).

The angles (Qwen-Image-Edit GGUF Q4 + LoRAs) are the same on both hardware profiles.

Timings:
- RTX 4060 8 GB (Gemma E2B + klein 4B): Gemma ~20–30 s; base ~10 s; refinement ~10 s; Qwen angle ~1 min 30 s.
- RTX 5070 Ti 16 GB (Gemma E4B + klein 9B): Gemma ~39 s; base ~11 s for the first one (loading) and ~4.5 s afterwards.

**License:** klein 4B is Apache 2.0 (free commercial use). klein 9B is under the FLUX Non-Commercial License: non-commercial use only (e.g. unmonetized memes). For a commercial project, use the 4B even on a 16 GB GPU, or get a commercial license from BFL.

If ComfyUI is not running, start it through comfy-mcp (`launch_comfyui`). If your models live in a shared folder (e.g. ComfyUI Desktop), pass `extra_args=["--listen","127.0.0.1","--extra-model-paths-config","<EXTRA_MODEL_PATHS_YAML>"]`. The call may time out even while ComfyUI is starting; check the queue before retrying.

## Brief

Ask the user for whatever is missing:
1. Environment name (becomes the folder name and the file prefix).
2. Project folder to save into (`<folder>/<name>/`).
3. Format: 9:16 (default) or 16:9.
4. Reference image (optional) and text brief.

A good brief covers:
- type of place, city, neighborhood, era and social context;
- approximate size and architecture (walls, floor, window, door);
- colors and materials; state of upkeep (default: modest but cared-for);
- required furniture **with position** (left/right/back wall) and open space between pieces;
- how many and which personal objects (6 works well; more than that becomes clutter);
- view through the window or background, with details that identify the city;
- light: time of day and direction;
- 2 or 3 signature elements of the place.

If the user gives only one or two sentences, run `suggest` (step 1) instead of filling in the gaps yourself.

## Steps

### 0. Prepare
- Confirm ComfyUI is up (server info through comfy-mcp; if it isn't running, start it as above).
- **Choose the models by VRAM** (server info → `hardware.gpu.vram_bytes`):
  - **≥ 15 GiB (16 GB card) → Gemma `e4b` + klein `9b`**;
  - less than that, or no GPU detected → Gemma `e2b` + klein `4b`.
  - If any file of the chosen model is missing (search the models through comfy-mcp), use the other group and tell the user. klein 9B requires the `qwen_3_8b_fp8mixed` encoder; the 4B requires `qwen_3_4b` (don't mix them; the script already pairs them).
  - Commercial project: klein `4b` even with 16 GB (license).
- Create `<folder>/<name>/`, write `environment_sheet.py` (code at the end) into it and run `python environment_sheet.py init . <name> <9:16|16:9> <e4b|e2b> <9b|4b>` (writes `config.json`; all later steps read the models from it). Tell the user which profile was used.
- If there is a reference image, upload it to ComfyUI's `input` through comfy-mcp (`upload_file`). **A missing input image makes the job fail when queued.**

### 1. Complete brief (Gemma suggestions, if needed)
- Detailed brief: save it as `brief.txt` and go to step 2.
- Short brief: save the user's text to `short_brief.txt` and run `python environment_sheet.py suggest . short_brief.txt [seed]` → `workflows/wf_00_gemma_suggest_s<seed>.json`. Run it through comfy-mcp, wait, and read the text from the job's text outputs.
- Show the list of suggestions to the user and point out what looks problematic (e.g. people mentioned in the street, furniture in the middle of the room, heavy wear, an unrequested brand). Ask: approve / approve with changes / generate other suggestions (another seed).
- Save the approved result, with the user's changes, to `brief.txt`.

### 2. Description with Gemma 4 (3 seeds)
- `python environment_sheet.py gemma . <image_in_input|-> brief.txt 0 1 2` → 3 workflows. Run all 3 without blocking, wait for them, read the text outputs and save each one into `descriptions/` (rename to `description_s<seed>.txt` with `mv -n`).
- Check each description (without editing):
  - every item of the brief appears (furniture, objects, colors, view, light);
  - coherent layout: two large elements don't occupy the same spot (e.g. TV and window on the same wall become a TV floating in front of the window);
  - no typography, posters with lettering, unrequested brands, people;
  - light wear only (cracks, mold and dirt make the place look abandoned).
- Pick the best one and copy it to `description.txt`.
- **User confirmation (required):** show a summary of the chosen description in the user's language (layout per wall, furniture, objects, view, light, palette) and the issues you found. Ask: approve and generate candidates / use another of the 3 descriptions / redo with other seeds / adjust the brief. Continue only with approval.

### 3. Base (4 candidates)
- `python environment_sheet.py base . description.txt 101 202 303 404` → 4 workflows. Run, wait, fetch the outputs into `base/<seed>/` and rename to `base/base_<seed>.png`.
- Build the preview: `python environment_sheet.py review candidates_preview.jpg base/base_*.png`; show it to the user and comment on each one (items present, clutter, floating objects, window view, ceiling).
- The user chooses. If none works: new seeds (505 606 707 808) with the same description; if the problem is content (too many items, layout), go back to the brief.
- Copy the chosen one to `<name>_base.png`, upload it to ComfyUI's `input` (`upload_file`, overwrite) and copy it to `sheet/01_establishing.png`.

### 4. Camera angles (Qwen-Image-Edit + angles LoRA)
- `python environment_sheet.py angles . <name>_base.png 4242` → `side_left`, `side_right`, `three_quarter`. Queue them without blocking; each takes ~1 min 30 s.
- Fetch, rename into `plates/` and review. Common defects: blur/ghosting on the ceiling, duplicated furniture (two beds, two shirts), invented objects (air conditioner), rotated bed. Redo the bad one with another seed (`angles . <name>_base.png 777 side_right`).
- Keep only the good views. Each view shows a different wall of the room; name the plate after what it shows (e.g. `02_wardrobe_wall`, `03_bed_and_flag_wall`).
- **The reverse shot (turning 180° toward the door) doesn't work**: Qwen just mirrors the entrance view (both with a "back view" LoRA prompt and with a text instruction). Don't include it in the sheet; tell the user.

### 5. Details (base crop + klein refinement)
- `python environment_sheet.py grid . <name>_base.png` → `grid.jpg` with coordinates every 100 px. Look at it.
- Choose 3 or 4 crops in the format's aspect ratio (the script computes the height): the main action area (e.g. TV/video game + chair), work furniture (desk), a wall with signature objects, the window/view. Write `crops.json`:
  ```json
  {"tv_videogame": {"box": [360, 470, 450], "label": "Medium shot of the TV area of this room: wall-mounted TV, low rack with the video game console, gaming chair."}}
  ```
  `box` = [x, y, width] on the base; `label` = one English sentence naming only what is in the crop, using the names from the description (adding nothing).
- `python environment_sheet.py crops . <name>_base.png crops.json` → `crops/<name>_crop_<id>.png` (upscaled). Upload all of them to `input` (`upload_file`).
- `python environment_sheet.py refine . crops.json 4242` → one workflow per crop (img2img, denoise 0.5, 8 steps). Run, fetch, rename into `plates/`.
- Don't use klein with the base as ReferenceLatent to "generate" the detail at the same size: in 3 of 4 tests it copied the whole base and ignored the framing.

### 6. Review and assembly
- Review preview: `python environment_sheet.py review _rev.jpg plates/*.png`; redo whatever is bad.
- Copy the chosen ones into `sheet/` with numbered descriptive names (`01_establishing.png`, `02_...`), and copy `description.txt` into `sheet/`. The `README.md` comes later, in step 7.
- Write `card.txt` (reference only): line 1 = title; then the environment in 2–3 lines, "Fixed elements:" and one item per line (walls, floor, furniture, objects, view, light), all taken from the approved description.
- `python environment_sheet.py assemble . card.txt` → `sheet_<name>.png` + `preview_sheet_<name>.jpg` (4-column grid + card). Look at the preview before delivering and show it to the user.

### 7. README.md (required)
Write `sheet/README.md` (markdown, in the user's language) with usage instructions for MiniMax H3, after the step 6 assembly. Write it directly into the environment folder (e.g. a heredoc with a quoted delimiter). Don't deliver the sheet without it.

How to fill in the template below:
- Everything about the place (title, summary, fixed elements, purpose of each plate) comes from the approved `card.txt` and `description.txt` and the reviewed plates. Don't add features of the place.
- One table row per plate that exists in `sheet/`, with the real file name (without `.png`) and its purpose based on what the plate shows.
- Specific warnings only for defects seen during review (e.g. strong ripples on the water in the side angles, a duplicated object in one plate). Omit if there are none.
- License according to `config.json`: klein `9b` = non-commercial use only; klein `4b` = Apache 2.0, free use.
- The prompt example is in English and uses 2 or 3 fixed elements of this environment; replace the template's example with what makes sense for the place.

Template:

````markdown
# <title from card.txt>: how to use in MiniMax H3

<Summary of the environment in 1 or 2 sentences, from card.txt.>

## What to send to the generator

Send the **plates** in this folder (`01_` to `0N_`), never the `sheet_<name>.png` assembly. Video generators copy the reference's layout, and a grid with panels and text leaks into the video. The assembly is only for you to look at.

Per shot, use **1 or 2 plates** that match the framing, plus the character sheet. More than that and the generator starts mixing up the leftovers.

| Plate | Use for |
|---|---|
| `01_establishing` | frontal wide shot, scene opening, first frame |
| `<file>` | <shot the plate shows> |

There is no reverse shot (turning 180° to look behind the set): the angles model only mirrors the view. For the reverse, use the closest plate and let the character do the work.

<Specific warnings about the plates, if any.>

## How to write the prompt

Give each image a **purpose**, in English, and repeat 2 or 3 fixed elements of the environment in the text.

```
Image 1 is the location: keep <2 or 3 fixed elements> exactly as in the
reference, with the same lighting.
Image 2 is the character: keep face, hair and outfit exactly as in the
reference.
<Character action and line>. <Camera movement, height, depth of field>.
```

Fixed elements to repeat (pick 2 or 3): <short list taken from the "Fixed elements" section of card.txt>.

If the generator invents text, logos or elements that don't exist in the place, reinforce in the prompt what must stay out (e.g. "no readable text, no logos").

## Most stable method

1. Build the **first frame** in FLUX.2 klein: character sheet + environment plate, both as ReferenceLatent.
2. Use that frame for **image-to-video** in MiniMax H3, with the prompt above.

This is more faithful than asking H3 to combine character and set from scratch.

## Files in this folder

- `01_` to `0N_`: environment plates, <9:16 (864×1536) or 16:9 (1536×864)>.
- `description.txt`: canonical description of the place (in English), written by Gemma and approved by the user. Paste excerpts into the video prompt when you need more detail.
- `README.md`: this file.

## License

<klein 9B: plates for **non-commercial** use only; for a commercial project, redo them with klein 4B. klein 4B: Apache 2.0, free commercial use.>
````

### 8. Output
`<folder>/<name>/`: `sheet/` (final plates + `description.txt` + `README.md`), `sheet_<name>.png`, `preview_sheet_<name>.jpg`, `brief.txt`, `descriptions/`, `base/`, `plates/` (all versions), `crops/`, `crops.json`, `workflows/`, `config.json`, `environment_sheet.py`.

File notes:
- Never delete or overwrite the user's files: rename with `mv -n`; empty temporary folders may be left behind (tell the user).
- Paths: the script uses paths as seen by the shell where it runs (run it from the environment folder, `.`); comfy-mcp tools (`run_workflow`, `fetch_outputs`, `upload_file`) use paths as seen by the machine running the comfy-mcp server. On a single machine they are the same; if the agent runs in a VM or container, translate between them.

## Use in MiniMax H3

- Per shot, send 1 or 2 plates that match the framing + the character sheet, each image with a purpose in the prompt: "Image 1 is the location: keep architecture, furniture, colors and lighting exactly. Image 2 is the character…".
- Repeat 2–3 fixed elements from `card.txt` in the video prompt (wall colors, main furniture, view).
- Most stable method: build the first frame in klein (character base + environment plate, two ReferenceLatents) and use image-to-video.
- `sheet/README.md` (step 7) has all this adapted to the environment, with the purpose of each plate and a sample prompt.

## Lessons from testing

### Small bedroom in a working-class neighborhood of a big city
- Without limits, Gemma asks for heavy wear (cracked plaster, mold, bare cement) → "light wear" rule in the system prompt.
- Gemma sometimes puts the TV and the window on the same wall → klein draws the TV floating in front of the window. Check the layout in the description before approving.
- Asking for "at least 8 objects" cluttered the bed and chairs; 6 objects + "open space between the furniture" fixed it.
- A sports club's name → klein invents different crests, sometimes with letters. "Green and white striped flag" without mentioning a crest came out clean.
- "Camera tilted down" reduces the ceiling only a little: in 9:16 it still takes ~25% of the frame.
- Qwen + angles LoRA: good side views, but with occasional defects (redo with another seed); "back view" only mirrors.
- Details: crop + refinement keeps everything identical to the base; generation with ReferenceLatent copies the base.
- 16 GB profile (same brief): Gemma E4B covered every item with a coherent layout (TV above the bed, away from the window). klein 9B gave cleaner, more detailed images and a roomier space, but sometimes duplicates an object (two plastic chairs) and puts the console on the desk instead of the rack. Check the items when choosing the base, as with the 4B.

### Abstract set (a desk floating in a black void, RTX 5070 Ti)
- Abstract environment (a void, no room): list in the brief only the furniture that exists and leave the exclusions ("no walls, no sky, no stars, no other furniture") for the final sentence. A stray "no furniture" fights with the desk and the chair.
- Gemma may cut the description mid-way through the final sentence (length limit). Discard the truncated seed instead of editing.
- Qwen + angles LoRA in a scene with water: the side views come out with exaggerated circular ripples. Warn in the README and prefer the frontal plate when the water must stay still.
- Monitor screens: klein draws micro-scribbles that look like text; check at zoom (native-size crop) that nothing is readable.
- The run tool may return an MCP error (e.g. 403) without queuing the job. Check the queue and resend once.
- If the agent reaches the user's files through a mounted folder, the mount point may point straight at a subfolder and change between sessions. List the folder before writing the README.

## Script `environment_sheet.py`

```python
#!/usr/bin/env python3
"""Environment sheet: workflows (ComfyUI API format) and assembly.
Usage (always from the environment folder):
  python environment_sheet.py init     <folder> <name> <9:16|16:9> <e4b|e2b> <9b|4b>
  python environment_sheet.py suggest  <folder> <short_brief.txt> [seed]
  python environment_sheet.py gemma    <folder> <ref_image_in_input|-> <brief.txt> <seed> [seed ...]
  python environment_sheet.py base     <folder> <description.txt> <seed> [seed ...]
  python environment_sheet.py grid     <folder> <image.png>
  python environment_sheet.py angles   <folder> <base_in_input> <seed> [id ...]
  python environment_sheet.py crops    <folder> <base.png> <crops.json>
  python environment_sheet.py refine   <folder> <crops.json> <seed> [id ...]
  python environment_sheet.py review   <out.jpg> <img> [img ...]
  python environment_sheet.py assemble <folder> <card.txt>
"""
import json, os, sys

# =====================================================================
# Gemma 4
# =====================================================================
# Gemma 4 by VRAM: e4b for a 16 GB GPU or larger, e2b for smaller GPUs
GEMMA_MODELS = {
    "e4b": "gemma4_e4b_it_fp8_scaled.safetensors",
    "e2b": "gemma4_e2b_it_int8_convrot.safetensors",
}

SUGGEST_SYSTEM = """You are an experienced production designer helping a filmmaker plan a film location. The filmmaker gives you a short brief. You expand it into a complete, concrete brief that another AI will later turn into an image prompt.

Rules:
- Keep everything the filmmaker wrote. Never contradict or remove it.
- Fill only the gaps, with details that are plausible for that exact place, city, social context and era.
- Never name brands, logos, real companies or sports clubs unless the filmmaker named them.
- Never describe people. The location is unoccupied.
- Write in the same language as the brief."""

SUGGEST_INSTRUCTIONS = """Expand the brief below into a detailed location brief, as a numbered list with one short paragraph per item, in this order:
1. Type of place, city, neighborhood and era.
2. Approximate size and architecture (walls, floor, ceiling, windows, doors).
3. Colors and materials of the surfaces; state of upkeep.
4. Required furniture, each with its position (left wall, right wall, back wall, foreground).
5. Six personal or set-dressing objects, each with its position.
6. What is seen through the window or in the background, with details that identify the city.
7. Light: time of day, light direction, lamps on or off.
8. Palette of 4 to 6 colors.
9. Two or three signature elements that make the place recognizable in any shot.

Output only the list."""

DESC_SYSTEM = """You are an expert production designer and location scout who writes prompts for text-to-image models. You receive a reference image and/or a text brief describing a place. Your job is to describe this location in purely visual, concrete terms so an image model can recreate the same place consistently across many shots of a film.

Rules:
- Describe only the place: architecture, surfaces, furniture, objects, view, light. The location is unoccupied; never describe people or body parts.
- Describe what is in the image or stated in the brief, and fill the gaps with details that are plausible for that exact place, city, social context and era.
- If the brief and the image disagree, the brief wins.
- Never name brands, logos, real companies, sports clubs or copyrighted characters, unless the brief explicitly asks for them; then name them and describe their items by colors, shapes and materials. Posters, stickers and screens show images or abstract graphics only, without readable words.
- Every object, color and requirement stated in the brief must appear in your text, stated clearly and early.
- The place is lived-in and cared-for: describe only light everyday wear (small scuffs, slightly faded paint), never heavy cracks, damp stains, dirt or decay, unless the brief asks for them.
- Use precise visual vocabulary (materials, colors, textures, wear, dimensions). Avoid vague words like "beautiful", "cozy" or "interesting".
- Give the position of every important element (left wall, right wall, back wall, foreground, under the window...) so the layout stays the same from any camera angle. Never place two large elements on the same spot (for example a TV in front of a window).
- Never mention things that are not there (no sentences like "there is no rug"): image models read every named object as present. The only negations allowed are in the final sentence."""

DESC_INSTRUCTIONS = """Write a long (450 to 550 words) and very detailed text in English to be used as a text-to-image prompt for a {aspect} establishing shot of this location, seen from the entrance at eye level with a wide lens, showing the whole space. The entrance door is behind the camera, out of frame.

Cover with details everything in this list, in this order:
1. Rendering style: match the reference (photo, anime, 3D render). If there is no reference, use a photorealistic cinematic film still.
2. Type of place, city, neighborhood and era.
3. Size and architecture: room dimensions, walls, floor, window (frame, bars, glass), electrical outlets. The ceiling only briefly.
4. Surfaces: materials, colors, finish, light everyday wear only.
5. Furniture, each with its position in the room (left wall, right wall, back wall, foreground).
6. The personal objects named in the brief, each with its position; if the brief names none, choose six that fit. Keep open floor space between pieces of furniture.
7. The view through the window, with concrete details that make the city recognizable.
8. Lighting: one fixed setup (time of day, sun direction, color temperature, practical lamps on or off).
9. Color palette in 4 to 6 colors.
10. Two or three signature elements that make this location instantly recognizable in any shot.
11. End with one sentence: the room is unoccupied, no people, no readable text, logos or watermarks, straight vertical lines and correct perspective.

Output only the text, no headings, no lists, no quotes."""

NO_BRIEF = "No written brief. Describe the location from the reference image only."


def wf_text(name, gemma, system, prompt_a, prompt_b, delim, prefix, seed, ref=None):
    tg = {"clip": ["1", 0], "prompt": ["6", 0], "max_length": 2048,
          "sampling_mode": "on", "sampling_mode.temperature": 1.0, "sampling_mode.top_k": 64,
          "sampling_mode.top_p": 0.95, "sampling_mode.min_p": 0.05,
          "sampling_mode.repetition_penalty": 1.05, "sampling_mode.seed": seed,
          "sampling_mode.presence_penalty": 0.0,
          "thinking": True, "use_default_template": True, "mtp": "auto",
          "system_prompt": ["3", 0]}
    wf = {
        "1": {"class_type": "CLIPLoader", "inputs": {"clip_name": GEMMA_MODELS[gemma], "type": "stable_diffusion", "device": "default"}},
        "3": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": system}},
        "4": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": prompt_a}},
        "5": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": prompt_b}},
        "6": {"class_type": "StringConcatenate", "inputs": {"string_a": ["4", 0], "string_b": ["5", 0], "delimiter": delim}},
        "7": {"class_type": "TextGenerate", "inputs": tg},
        "8": {"class_type": "SaveText", "inputs": {"text": ["7", 0], "filename_prefix": f"environments/{name}/{prefix}_s{seed}", "format": "txt"}},
    }
    if ref:
        wf["2"] = {"class_type": "LoadImage", "inputs": {"image": ref}}
        tg["image"] = ["2", 0]
    return wf

# =====================================================================
# FLUX.2 klein
# =====================================================================
SIZES = {"9:16": (864, 1536), "16:9": (1536, 864)}
ASPECT = {"9:16": "vertical 9:16", "16:9": "horizontal 16:9"}

# Fixed, generic texts: nothing specific to the place here (klein draws whatever is mentioned).
def framing(fmt):
    return (f"{ASPECT[fmt].capitalize()} establishing shot of an interior, photographed from the doorway at eye level "
            "with a wide 24mm lens, camera tilted slightly downward so the ceiling is barely visible at the top edge, "
            "the floor and furniture fill the frame, the whole room visible, straight vertical lines.")

def finish(fmt):
    return f"{ASPECT[fmt].capitalize()} photorealistic cinematic film still, natural colors, fine detail. No people, no text, no watermark."

# klein by VRAM: 9b for a 16 GB GPU or larger, 4b for smaller GPUs. Each one requires its own text encoder (don't mix).
KLEIN_MODELS = {
    "9b": ("flux-2-klein-9b-fp8.safetensors", "qwen_3_8b_fp8mixed.safetensors"),
    "4b": ("flux-2-klein-4b-fp8.safetensors", "qwen_3_4b.safetensors"),
}

def loaders(klein):
    unet, te = KLEIN_MODELS[klein]
    return {
        "105": {"class_type": "UNETLoader", "inputs": {"unet_name": unet, "weight_dtype": "default"}},
        "106": {"class_type": "CLIPLoader", "inputs": {"clip_name": te, "type": "flux2", "device": "default"}},
        "108": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae.safetensors"}},
    }

def ksampler(seed, pos, neg, latent, steps=4, denoise=1):
    return {"class_type": "KSampler", "inputs": {"seed": seed, "steps": steps, "cfg": 1, "sampler_name": "euler",
            "scheduler": "simple", "denoise": denoise, "model": ["105", 0], "positive": pos, "negative": neg, "latent_image": latent}}

def wf_base(name, fmt, klein, desc, seed):
    w, h = SIZES[fmt]
    wf = loaders(klein)
    wf.update({
        "107": {"class_type": "CLIPTextEncode", "inputs": {"text": f"{framing(fmt)} {desc} Photorealistic cinematic film still, natural colors, fine detail. No text, no watermark.", "clip": ["106", 0]}},
        "113": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["107", 0]}},
        "114": {"class_type": "EmptyFlux2LatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "116": ksampler(seed, ["107", 0], ["113", 0], ["114", 0]),
        "103": {"class_type": "VAEDecode", "inputs": {"samples": ["116", 0], "vae": ["108", 0]}},
        "94": {"class_type": "SaveImage", "inputs": {"filename_prefix": f"environments/{name}/base_{seed}", "images": ["103", 0]}},
    })
    return wf

# Details: upscaled crop of the base + refinement (img2img, denoise 0.5) with the image itself as ReferenceLatent.
def wf_refine(name, fmt, klein, k, crop_img, label, seed, denoise=0.5):
    wf = loaders(klein)
    wf.update({
        "76": {"class_type": "LoadImage", "inputs": {"image": crop_img}},
        "78": {"class_type": "VAEEncode", "inputs": {"pixels": ["76", 0], "vae": ["108", 0]}},
        "107": {"class_type": "CLIPTextEncode", "inputs": {"text": f"{label} Sharp, detailed, clean edges. {finish(fmt)}", "clip": ["106", 0]}},
        "113": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["107", 0]}},
        "201": {"class_type": "ReferenceLatent", "inputs": {"conditioning": ["107", 0], "latent": ["78", 0]}},
        "202": {"class_type": "ReferenceLatent", "inputs": {"conditioning": ["113", 0], "latent": ["78", 0]}},
        "116": ksampler(seed, ["201", 0], ["202", 0], ["78", 0], steps=8, denoise=denoise),
        "103": {"class_type": "VAEDecode", "inputs": {"samples": ["116", 0], "vae": ["108", 0]}},
        "94": {"class_type": "SaveImage", "inputs": {"filename_prefix": f"environments/{name}/plates/{k}", "images": ["103", 0]}},
    })
    return wf

# =====================================================================
# Qwen-Image-Edit-2511 (GGUF) + Lightning + Multiple Angles: camera turns
# =====================================================================
ANGLES = {
    "side_left":     "<sks> left side view eye-level shot wide shot",
    "side_right":    "<sks> right side view eye-level shot wide shot",
    "three_quarter": "<sks> front-right quarter view eye-level shot wide shot",
}

def wf_angle(name, fmt, k, ref, seed):
    w, h = SIZES[fmt]
    return {
        "1": {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": "qwen-image-edit-2511-Q4_K_M.gguf"}},
        "2": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0], "lora_name": "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors", "strength_model": 1.0}},
        "3": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["2", 0], "lora_name": "qwen-image-edit-2511-multiple-angles-lora.safetensors", "strength_model": 0.9}},
        "4": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["3", 0], "shift": 3.1}},
        "5": {"class_type": "CFGNorm", "inputs": {"model": ["4", 0], "strength": 1.0}},
        "6": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors", "type": "qwen_image", "device": "default"}},
        "7": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "8": {"class_type": "LoadImage", "inputs": {"image": ref}},
        "9": {"class_type": "ImageScaleToTotalPixels", "inputs": {"upscale_method": "lanczos", "megapixels": 1, "resolution_steps": 1, "image": ["8", 0]}},
        "10": {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {"clip": ["6", 0], "prompt": ANGLES[k], "vae": ["7", 0], "image1": ["9", 0]}},
        "11": {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {"clip": ["6", 0], "prompt": "", "vae": ["7", 0], "image1": ["9", 0]}},
        "12": {"class_type": "FluxKontextMultiReferenceLatentMethod", "inputs": {"conditioning": ["10", 0], "reference_latents_method": "index_timestep_zero"}},
        "13": {"class_type": "FluxKontextMultiReferenceLatentMethod", "inputs": {"conditioning": ["11", 0], "reference_latents_method": "index_timestep_zero"}},
        "14": {"class_type": "EmptySD3LatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "15": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 4, "cfg": 1, "sampler_name": "euler", "scheduler": "simple",
                "denoise": 1, "model": ["5", 0], "positive": ["12", 0], "negative": ["13", 0], "latent_image": ["14", 0]}},
        "16": {"class_type": "VAEDecode", "inputs": {"samples": ["15", 0], "vae": ["7", 0]}},
        "17": {"class_type": "SaveImage", "inputs": {"filename_prefix": f"environments/{name}/plates/{k}_s{seed}", "images": ["16", 0]}},
    }

# =====================================================================
# Image utilities (PIL)
# =====================================================================
def grid(folder, img):
    from PIL import Image, ImageDraw
    im = Image.open(img).convert("RGB"); d = ImageDraw.Draw(im)
    for x in range(0, im.width, 100):
        d.line([(x, 0), (x, im.height)], fill=(255, 0, 0)); d.text((x + 2, 2), str(x), fill=(255, 0, 0))
    for y in range(0, im.height, 100):
        d.line([(0, y), (im.width, y)], fill=(0, 0, 255)); d.text((2, y + 2), str(y), fill=(0, 0, 255))
    out = os.path.join(folder, "grid.jpg"); im.save(out, quality=85); print(out, im.size)

def crops(folder, name, fmt, base, cjson):
    from PIL import Image
    W, H = SIZES[fmt]; ratio = H / W
    im = Image.open(base).convert("RGB"); spec = json.load(open(cjson, encoding="utf-8"))
    os.makedirs(os.path.join(folder, "crops"), exist_ok=True)
    for k, v in spec.items():
        x, y, w = v["box"]; h = round(w * ratio)
        if x < 0 or y < 0 or x + w > im.width or y + h > im.height:
            sys.exit(f"crop {k} falls outside the image: {(x, y, x + w, y + h)} in {im.size}")
        out = os.path.join(folder, "crops", f"{name}_crop_{k}.png")
        im.crop((x, y, x + w, y + h)).resize((W, H), Image.LANCZOS).save(out)
        print(k, (x, y, x + w, y + h), out)

def review(out, imgs):
    from PIL import Image, ImageDraw
    th = 768; g = 12
    ims = [Image.open(f).convert("RGB") for f in imgs]
    ims = [im.resize((round(im.width * th / im.height), th)) for im in ims]
    c = Image.new("RGB", (sum(i.width for i in ims) + g * (len(ims) + 1), th + 50), "white"); d = ImageDraw.Draw(c)
    x = g
    for f, im in zip(imgs, ims):
        c.paste(im, (x, g)); d.text((x + 6, g + th + 12), os.path.basename(f), fill="black"); x += im.width + g
    c.save(out, quality=85); print(out)

def font(sz, bold=False):
    from PIL import ImageFont
    names = ["DejaVuSans-Bold.ttf", "arialbd.ttf", "Arial Bold.ttf"] if bold else ["DejaVuSans.ttf", "arial.ttf", "Arial.ttf"]
    for n in names:
        try: return ImageFont.truetype(n, sz)
        except Exception: pass
    try: return ImageFont.load_default(sz)
    except TypeError: return ImageFont.load_default()

def assemble(folder, name, fmt, card):
    """Reference sheet: plates from sheet/ in a 4-column grid + text card. Not for the video generator."""
    from PIL import Image, ImageOps, ImageDraw
    import glob
    fs = sorted(glob.glob(os.path.join(folder, "sheet", "[0-9]*.png")))
    W, H = SIZES[fmt]; s = 540 / min(W, H); w, h = round(W * s), round(H * s); g = 16; cols = 4
    n = len(fs) + 1; rows = -(-n // cols)
    C = Image.new("RGB", (cols * w + (cols + 1) * g, rows * h + (rows + 1) * g), "white"); d = ImageDraw.Draw(C)
    pos = lambda i: (g + (i % cols) * (w + g), g + (i // cols) * (h + g))
    for i, f in enumerate(fs):
        C.paste(ImageOps.fit(Image.open(f).convert("RGB"), (w, h), Image.LANCZOS), pos(i))
    x0, y0 = pos(len(fs)); d.rectangle([x0, y0, x0 + w, y0 + h], fill=(238, 240, 234))
    y = y0 + 28
    for i, t in enumerate(open(card, encoding="utf-8").read().splitlines() + [""] + ["Plates:"] + ["  " + os.path.splitext(os.path.basename(f))[0] for f in fs]):
        bold = i == 0 or t.endswith(":")
        d.text((x0 + 24, y), t, font=font(28 if i == 0 else 19, bold), fill=(35, 45, 35)); y += 46 if i == 0 else 29
    out = os.path.join(folder, f"sheet_{name}.png"); C.save(out)
    C.resize((C.width // 2, C.height // 2), Image.LANCZOS).save(os.path.join(folder, f"preview_sheet_{name}.jpg"), quality=88)
    print(out, C.size)

# =====================================================================
def dump(wf, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(wf, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(path)

def cfg(folder):
    return json.load(open(os.path.join(folder, "config.json"), encoding="utf-8"))

def read(p):
    return open(p, encoding="utf-8").read().strip()

if __name__ == "__main__":
    a = sys.argv; mode = a[1]
    if mode == "review":
        review(a[2], a[3:]); sys.exit()
    folder = a[2]; wfdir = os.path.join(folder, "workflows")
    if mode == "init":
        os.makedirs(folder, exist_ok=True)
        if a[4] not in SIZES or a[5] not in GEMMA_MODELS or a[6] not in KLEIN_MODELS:
            sys.exit("usage: init <folder> <name> <9:16|16:9> <e4b|e2b> <9b|4b>")
        json.dump({"name": a[3], "format": a[4], "gemma": a[5], "klein": a[6]}, open(os.path.join(folder, "config.json"), "w", encoding="utf-8"))
        print(os.path.join(folder, "config.json")); sys.exit()
    c = cfg(folder); name, fmt = c["name"], c["format"]
    gemma, klein = c.get("gemma", "e2b"), c.get("klein", "4b")
    if mode == "suggest":
        seed = int(a[4]) if len(a) > 4 else 0
        dump(wf_text(name, gemma, SUGGEST_SYSTEM, SUGGEST_INSTRUCTIONS, read(a[3]), "\n\nBrief: ", "suggestion", seed),
             os.path.join(wfdir, f"wf_00_gemma_suggest_s{seed}.json"))
    elif mode == "gemma":
        ref = None if a[3] == "-" else a[3]; brief = read(a[4]) if a[4] != "-" else NO_BRIEF
        for s in map(int, a[5:]):
            dump(wf_text(name, gemma, DESC_SYSTEM, DESC_INSTRUCTIONS.format(aspect=ASPECT[fmt]), brief, "\n\nLocation brief: ", "description", s, ref),
                 os.path.join(wfdir, f"wf_01_gemma_description_s{s}.json"))
    elif mode == "base":
        desc = read(a[3])
        for s in map(int, a[4:]):
            dump(wf_base(name, fmt, klein, desc, s), os.path.join(wfdir, f"wf_02_base_{s}.json"))
    elif mode == "grid":
        grid(folder, a[3])
    elif mode == "angles":
        ref, seed = a[3], int(a[4]); ids = a[5:] or list(ANGLES)
        for k in ids:
            dump(wf_angle(name, fmt, k, ref, seed), os.path.join(wfdir, f"wf_03_angle_{k}_s{seed}.json"))
    elif mode == "crops":
        crops(folder, name, fmt, a[3], a[4])
    elif mode == "refine":
        spec = json.load(open(a[3], encoding="utf-8")); seed = int(a[4]); ids = a[5:] or list(spec)
        for k in ids:
            dump(wf_refine(name, fmt, klein, k, f"{name}_crop_{k}.png", spec[k]["label"], seed),
                 os.path.join(wfdir, f"wf_04_refine_{k}_s{seed}.json"))
    elif mode == "assemble":
        assemble(folder, name, fmt, a[3])
```
