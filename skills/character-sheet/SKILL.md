---
name: "character-sheet"
description: "Creates a 9:16 character reference sheet (17 panels) in a local ComfyUI: Gemma 4 (E4B on a 16 GB GPU, otherwise E2B) describes the character from an image and/or brief, and FLUX.2 klein (9B on a 16 GB GPU, otherwise 4B) generates the base and the panels. Works for humans, aliens, dragons, anime, etc."
---

# Character sheet (Gemma 4 + FLUX.2 klein)

A 100% local pipeline in ComfyUI, driven through the comfy-mcp server. Everything needed to rebuild the workflows is in this file: it does not depend on any external workflow .json.

Reply in the user's language.

## Rules

- **Never write character traits into the prompts yourself.** The description comes only from Gemma 4, based on the user's image and/or brief. The fixed texts below are generic and must not receive any character features. If the description comes out bad, rerun Gemma with another seed or ask the user for a better brief; never edit the description by hand.
- Photos of real people only with permission to use their likeness. Don't recreate public figures, actors or existing characters from films, series or games.
- Every character must have 2 or 3 distinctive features (call-outs). If the user doesn't give them, suggest some in the brief (the user approves; the text goes into the brief, not into the fixed prompts).
- **Humans always come out in minimal clothing**, even if the reference image or brief shows clothes: man = tight shorts, bare torso and bare feet; woman = tight shorts and fitted top, bare feet. The sheet is a body-and-identity mannequin; clothing comes later from the `costume-sheet` skill, and clothes on the sheet leak into the video. The rule lives in item 7 of `GEMMA_INSTRUCTIONS` (fixed, generic text, not a character trait). If the brief or image has clothes, ignore them and tell the user the costume is made separately. Does not apply to non-humans.
- Voice is not part of this skill.
- **The delivery includes a `README_<name>.md`** (step 5) explaining each file and which are the best references for video generation. Whoever uses the character in video (the `video-h3` skill) should read that file before choosing images.

## Requirements (models)

| File | ComfyUI folder | Source |
|---|---|---|
| `gemma4_e4b_it_fp8_scaled.safetensors` (9.1 GB) — used with a 16 GB GPU or larger | `models/text_encoders` | huggingface.co/Comfy-Org/gemma-4 (text_encoders) |
| `gemma4_e2b_it_int8_convrot.safetensors` (5.2 GB) — GPU under 16 GB | `models/text_encoders` | huggingface.co/Comfy-Org/gemma-4 (text_encoders) |
| `flux-2-klein-9b-fp8.safetensors` (9.4 GB) — GPU of 16 GB or larger | `models/diffusion_models` | huggingface.co/black-forest-labs/FLUX.2-klein-9b-fp8 (gated repo: accept the terms with a Hugging Face account and download manually) |
| `qwen_3_8b_fp8mixed.safetensors` (8.7 GB) — text encoder for the 9B | `models/text_encoders` | huggingface.co/Comfy-Org/flux2-klein-9B (split_files/text_encoders) |
| `flux-2-klein-4b-fp8.safetensors` (4.1 GB) — GPU under 16 GB | `models/diffusion_models` | huggingface.co/black-forest-labs/FLUX.2-klein-4b-fp8 |
| `qwen_3_4b.safetensors` (8 GB) — text encoder for the 4B | `models/text_encoders` | huggingface.co/Comfy-Org/z_image_turbo (split_files/text_encoders) |
| `flux2-vae.safetensors` | `models/vae` | huggingface.co/Comfy-Org/flux2-dev (split_files/vae) |

Only native ComfyUI nodes (≥ 0.40): CLIPLoader, TextGenerate, PrimitiveStringMultiline, StringConcatenate, SaveText, LoadImage, UNETLoader, VAELoader, CLIPTextEncode, ConditioningZeroOut, ReferenceLatent, VAEEncode, ImageScaleToTotalPixels, EmptyFlux2LatentImage, KSampler, VAEDecode, SaveImage. Python with Pillow for the assembly.

Tested: RTX 4060 8 GB with Gemma E2B + klein 4B (Gemma ~20 s; base ~5 s per image; panel ~12 s; full sheet < 10 min). RTX 5070 Ti 16 GB with Gemma E4B + klein 9B (Gemma ~30 s; base ~3.5 s per image, ~9 s for the first one including loading; 17 panels ~1.5 min; full sheet ~3 min).

**License:** klein 4B is Apache 2.0 (free commercial use). klein 9B is under the FLUX Non-Commercial License: non-commercial use only (e.g. unmonetized memes). For a commercial project, use the 4B even on a 16 GB GPU, or get a commercial license from BFL.

## Inputs

Ask the user for whatever is missing:
1. Character name (becomes the folder name and the file prefix).
2. Project folder to save into (`<folder>/<name>/`). If the given folder already has the character's name, use it directly, without creating a subfolder with the same name.
3. Reference image (optional) and/or text brief (optional). At least one of the two.

## Steps

### 0. Prepare
- Confirm ComfyUI is up (server info through comfy-mcp).
- **Choose the models by VRAM** (server info → `hardware.gpu.vram_bytes`):
  - **≥ 15 GiB (16 GB card) → Gemma `e4b` + klein `9b`**;
  - less than that, or no GPU detected → Gemma `e2b` + klein `4b`.
  - If any file of the chosen model is missing (search the models through comfy-mcp), use the other group and tell the user. klein 9B requires its own encoder `qwen_3_8b_fp8mixed`; the 4B requires `qwen_3_4b` (don't mix them).
- Create the character folder and write the `character_sheet.py` script (code at the end of this skill) into it. If there is a brief, save it to `brief.txt` in the same folder.
- Upload the reference image to ComfyUI's `input` through comfy-mcp (`upload_file`). **A missing input image makes the job fail when queued** (the run tool may only return a generic "Error executing tool").
- Run the script in a shell with `python3 -I character_sheet.py ...` from the character folder; `-I` prevents importing modules from that folder, which makes no difference for this script.

### 1. Description with Gemma 4
- `python character_sheet.py gemma <folder> <name> <image_in_input|-> <brief.txt|-> <seed> <e4b|e2b>` (default seed 0; model chosen by VRAM, step 0)
- Run `workflows/wf_01_gemma_description.json` through comfy-mcp and wait for it, fetch the .txt into `<folder>/_gemma/` (not into a temporary folder that you might not be allowed to delete) and copy it to `<folder>/description.txt`.
- Check it (without editing): it's in English and covers style, species/age/ethnicity (if human), body, face, surface, clothing, call-outs. Rerun Gemma with another seed (1, 2, 3...) if it:
  - mentions something the character does NOT have (e.g. "no horns", "no tail"): klein draws it;
  - contradicts the brief;
  - contradicts itself or gets anatomy wrong (e.g. "ten digits on each foot" instead of five per foot; "heavily muscled legs" on a skinny character);
  - changes the length or type of a garment from the brief (see Lessons), for non-humans;
  - (human) dresses the character in more than the minimal clothing rule (shirt, long trousers, shoes, watch) or makes the shorts long: the shorts end at the upper thigh, above the knee.
- Show the description to the user (a summary in their language) before continuing.

### 2. Base (4 candidates)
- `python character_sheet.py base <folder> <name> <9b|4b>` writes 4 workflows (seeds 101, 202, 303, 404), 832×1216.
- Run all 4 and fetch the outputs with inline images so you can see them.
- Pick the best one (full body including feet, correct anatomy, faithful to the description); if the user is present, show them and let them choose. Save the chosen one as `<folder>/<name>_base.png` and upload it to ComfyUI's `input`.
- If you redo the description and generate the base again, the old candidates stay in `candidates/` (fetching into `candidates/` avoids mixing versions).

### 3. Panels (17, one per workflow)
- `python character_sheet.py panels <folder> <name> <name>_base.png <seed> <9b|4b>` (default seed 4242; use the same klein as the base)
- Queue all 17 without blocking and wait for the last one. If your MCP client times out on long calls, keep each wait under ~50 s and repeat, or poll the job status.
- Fetch each panel into `<folder>/panels/<id>/` and copy it to `<folder>/panels/<id>.png`.
- Check each panel: identity matches the base, anatomy, framing and direction. Redo the bad ones with another seed (`panels ... <seed> <9b|4b>` and run only that id).
- Known klein issues (4B and 9B): the right profile sometimes faces left and the left profile sometimes comes out frontal with the head turned (mirror only if the character is symmetrical, otherwise redo); 3/4 front sometimes comes out almost frontal; "walking" sometimes comes out frontal or 3/4 instead of side-on. **In testing, redoing these 4 panels (profiles, 3/4 front, walking) with 2 more seeds did not improve the body direction.** If one retry round doesn't fix it, accept the panel and mark it "don't use as an angle reference" in the README (step 5) instead of spending more seeds.

### 4. Assembly
- `python character_sheet.py assemble <folder> <name>` → `sheet_<name>_9x16.png` (2160×3840) + `preview_sheet_<name>.jpg`.
- Look at the preview yourself before delivering.

### 5. Reference guide (README)
Write `<folder>/README_<name>.md`, in the user's language, filled in with what actually came out (real file names, panels actually approved). Follow the template below. The goal is that someone else (or an agent in a new session) knows which images to pass to the video generator without guessing.

Filling rules:
- **Face (required for video):** `panels/hero.png` (or the face crop that `video_h3.py face` makes from the sheet). It is the identity reference.
- **Body (optional):** `<name>_base.png` or `panels/front_neutral.png`, only when the character's silhouette matters (e.g. very thin or very broad). For humans the body comes out in minimal clothing (tight shorts; women also with a top), so it serves as a mannequin: the video's clothing comes from the costume sheet (`costume-sheet`), and the prompt must say the body comes from the mannequin image and the clothing from the costume image. For non-humans the clothing in these panels **leaks** into the video; the prompt must say only the proportions are used.
- **Face angles:** `head_34` and `head_side`, only if the shot is 3/4 or profile.
- **Don't use:** the full 9:16 sheet (it becomes a collage on screen), the body pose panels (they carry the sheet's clothing and some come out facing the wrong way), the `candidates/` folder.
- Mark as "wrong direction" the panels that failed the step 3 check.
- List the character's exaggerated features (e.g. nose, moustache) and note that video tends to soften them: the video prompt must reinforce them in text.
- If the character will wear a costume, note that it needs its own body reference when its silhouette differs from the costume mannequin's.
- State the license of the klein used (9B non-commercial only; 4B free).

Template:

````markdown
# <Name>: character usage guide

<2 lines: who it is, taken from description.txt>. Made with the `character-sheet` skill (Gemma 4 + FLUX.2 klein, local ComfyUI). Paths are relative to this folder.

> License: <notice for the klein used>.

## What each file is
<table: sheet, preview, base, description.txt, brief.txt, panels/ (list of the 17 with sizes), character_sheet.py, workflows/, candidates/>

## Best files for video reference (MiniMax H3)
<1. face, 2. body (optional), 3. angles, following the rules above>

### What NOT to use
<list, including the rejected panels>

## Caveats
<exaggerated features, leaking clothing, hair, etc., from what showed up in testing>

## Prompt definition template (ref2va)
<Subject 1> defined with the visible features and "whose face comes from <Picture 1>"; "retention_analysis" with "only the face is used, none of the hair, bare shoulders or background of the reference".

## How to redo or adjust
<character_sheet.py commands to redo a panel and reassemble>
````

### 6. Output
`<folder>/<name>/`: `sheet_<name>_9x16.png`, `preview_sheet_<name>.jpg`, `README_<name>.md`, `description.txt`, `brief.txt` (if any), `<name>_base.png`, `panels/`, `workflows/`, `_gemma/`, `character_sheet.py`.

## Sheet layout (target spec)

```
9:16 Character reference sheet — enlarged hero face close-up, face rotation grid, T-pose front, T-pose back, Front neutral, Side — left, Side — right, 3/4 front, 3/4 back, Full back, Walking pose.
Layout: vertical 9:16 portrait canvas, designed like a premium film/game studio character turnaround board.
Top section (identity focus): one very large hero face close-up spanning ~50–60% of the width, positioned prominently as the main visual anchor. Beside it: a compact face rotation sheet/grid showing multiple head angles (front, 3/4, side, back, looking down/up) plus one supporting portrait crop. This top row should immediately establish facial identity.
Middle section: T-pose front, T-pose back, Front neutral (3 evenly spaced panels).
Lower section: Side — left, Side — right, 3/4 front, Full back, 3/4 back, Walking pose arranged in clean stacked rows with balanced spacing.
Full-body panels remain large enough to preserve proportions and outfit detail while prioritizing the face sheet at the top.
Composition must fully utilize the tall 9:16 frame, with a strong hierarchy: face identity first, body turnaround second.
Match the visual style, face, outfit, skin texture, hair, and proportions from the reference images exactly. No redesign, no stylization, no reinterpretation. Photorealistic appearance preserved 100% consistently across every panel.
Neutral grey studio backdrop. Soft studio three-point lighting, flat even illumination, no harsh shadows. Thin white gutters separating panels. No text, no labels, no watermarks.
```

How it is implemented: klein can't generate the whole sheet in a single image (it drops panels and changes the person). So each panel is generated separately, using the base as reference (ReferenceLatent), and the sheet is assembled by script:
- Top (640 px tall × 2): hero face (55% of the width) + 2×3 grid of heads (front, 3/4, profile, back of head, looking down, looking up) + a wide supporting portrait.
- Middle: T-pose front, T-pose back, front neutral.
- Bottom: left profile, right profile, 3/4 front / full back, 3/4 back, walking.
- Grey background, 16 px white gutters, no text.
- The style follows the reference/description (photo, anime, 3D). The "Photorealistic" sentence of the spec applies when the character is photorealistic.

## Workflow configuration (reference)

### Gemma 4 (description)
- CLIPLoader, type `stable_diffusion`, device `default`, with the model chosen by VRAM:
  - GPU ≥ 16 GB: `gemma4_e4b_it_fp8_scaled.safetensors` (E4B, larger model);
  - GPU < 16 GB: `gemma4_e2b_it_int8_convrot.safetensors` (E2B).
- All other nodes, texts and parameters are the same for both models.
- LoadImage (reference) → TextGenerate's `image` input. Without an image: leave it unconnected.
- PrimitiveStringMultiline (system prompt) → `system_prompt`.
- PrimitiveStringMultiline (instructions) + PrimitiveStringMultiline (brief) → StringConcatenate (delimiter `"\n\nCharacter brief: "`) → `prompt`.
- TextGenerate: max_length 2048; sampling_mode on; temperature 1.0; top_k 64; top_p 0.95; min_p 0.05; repetition_penalty 1.05; seed 0; presence_penalty 0; thinking on; use_default_template on; mtp auto.
- SaveText (txt format).
- Empty brief = `No written brief. Describe the character from the reference image only.`
- Full texts of the system prompt and the instructions: the `GEMMA_SYSTEM` and `GEMMA_INSTRUCTIONS` constants in the script.

### FLUX.2 klein (base and panels)
- Model chosen by VRAM (same node, same parameters, same VAE):
  - GPU ≥ 16 GB: UNETLoader `flux-2-klein-9b-fp8.safetensors` (default) + CLIPLoader `qwen_3_8b_fp8mixed.safetensors` type `flux2`;
  - GPU < 16 GB: UNETLoader `flux-2-klein-4b-fp8.safetensors` (default) + CLIPLoader `qwen_3_4b.safetensors` type `flux2`.
- VAELoader `flux2-vae.safetensors` (the same for both).
- KSampler: steps 4, cfg 1, euler, simple, denoise 1. Negative = ConditioningZeroOut of the positive (klein has no negative prompt).
- Base (text → image): EmptyFlux2LatentImage 832×1216; prompt = full-body framing + description + background.
- Panels: LoadImage(base) → ImageScaleToTotalPixels (nearest-exact, 1 MP, resolution_steps 1) → VAEEncode → ReferenceLatent on the positive and on the zeroed negative.
- Sizes: hero face 960×1024; heads 1024×1024; portrait 1216×832; full body 832×992.
- Close-ups (hero, heads, portrait) do NOT get the description: identity comes from the image only; the long full-body description makes klein widen the framing. Full-body panels get the description.

## Lessons from testing

### General
- Never mention in the fixed texts features only some characters have (horns, scales, wings...): klein draws whatever is mentioned. A test with "including ears, horns or crest" put horns on a human.
- Negations in the description ("there are no horns") also turn into the feature in the image.
- Without "Full-body shot ... to the feet" at the start, the base gets cut at the thighs.
- Non-human/non-biped character (dragon, quadruped): adapt only the panel pose text (e.g. T-pose → wings/limbs spread; walking → the species' natural gait), without describing the appearance.

### Human with a moustache
- Without the minimal clothing rule, Gemma dressed the human (linen shirt, trousers, belt, watch) and the sheet's clothes would leak into the video. Hence the minimal clothing rule for humans (item 7 of `GEMMA_INSTRUCTIONS`).
- In Gemma's text, describe what is worn and what is exposed (bare torso, bare feet) instead of negating garments ("no shirt"): klein draws whatever is mentioned.
- "Fitted plain short shorts" came out as loose board shorts; "tight, form-fitting stretch (athletic compression style)" came out tight in all 4 bases.
- Moustache with a bare torso: klein turns it into a full beard when the description talks about hiding "the lower face" or "facial hair". Three Gemma rounds didn't fix it; what worked was adding a positive sentence to the brief (e.g. "handlebar moustache covering only the upper lip and mouth; chin, jaw and cheeks smooth and clean-shaven"). Do this as soon as the brief asks for a moustache, and tell the user about the added sentence.
- Gemma often miscounts fingers in the last sentence ("ten digits" per hand and foot); if the base comes out with five fingers, move on instead of spending more seeds.

### Caricatured character
- A garment described as "baggy" or "loose" in the brief became long trousers in all 4 bases (the description said "wide-legged"). Write the **length** in the brief (e.g. "short briefs ending at the upper thigh, well above the knee, leaving the legs exposed down to the bare feet"); with that, all 4 bases came out short. If the length comes out wrong, redo the brief and Gemma before generating the panels.
- Gemma's description may contradict the brief in details ("muscular" legs for a skinny character, "ten digits on each foot"). Check the bases before accepting; if the base came out right, the text contradiction doesn't show in the image.
- A caricatured character (huge nose, thick moustache, skeletal body) works with a raw brief in any language, without rewriting: Gemma translates and enriches it. The strongest feature (the nose) came out well in the base and the close-ups.
- Supporting portraits cut the head at the top if the vertical crop centering is 0.42; use 0.2 (already set in the script).
- Video use (MiniMax H3): the face crop holds the moustache and face, but the most exaggerated feature (the nose) came out smaller in the video than on the sheet. Using the sheet's body as a body reference brings part of the clothing along; reinforce in text that only the proportions are used. Hence the README (step 5).
- Fetching Gemma's output into a temporary folder may leave behind an empty folder you can't delete without permission; fetch straight into `_gemma/`.

## Script `character_sheet.py`

```python
#!/usr/bin/env python3
"""Writes the workflows (ComfyUI API format) and assembles the 9:16 sheet.
Usage:
  python character_sheet.py gemma    <folder> <name> [ref_image_in_input|-] [brief.txt|-] [seed] [e4b|e2b]
  python character_sheet.py base     <folder> <name> [9b|4b]
  python character_sheet.py panels   <folder> <name> <base_image_in_input> [seed] [9b|4b]
  python character_sheet.py assemble <folder> <name>
<folder> = the character folder. Everything is written there (workflows/, panels/, sheet).
"""
import json, os, sys

# ---------- Gemma 4 (E4B or E2B): character description ----------
GEMMA_SYSTEM = """You are an expert character designer who writes prompts for text-to-image models. You receive a reference image and/or a short text brief describing a character. The character can be anything: a human, an alien, a creature, a dragon, a robot, an anime or cartoon character, a hybrid. Your job is to describe it in purely visual, concrete terms so an image model can recreate the same character consistently across many images.

Rules:
- Describe only what is visible in the image or stated in the brief. Do not invent a backstory, personality or name.
- If the brief and the image disagree, the brief wins.
- Never identify or name real people, celebrities, brands or existing copyrighted characters, even if the image resembles one. Treat the character as an original design.
- Use precise visual vocabulary (shapes, proportions, colors, materials, textures). Avoid vague words like "beautiful", "cool" or "interesting".
- Use anatomy that fits the species (correct number of limbs, fingers, claws, wings, tails, eyes, horns for this design). Do not apply human anatomy to non-human characters. Humans have five fingers on each hand at most.
- Never mention features the character does not have (no sentences like "there are no horns" or "no tail"): image models read every named feature as present. The only negations allowed are in the final anatomy sentence."""

GEMMA_INSTRUCTIONS = """Write a long (500 to 600 words) and very detailed text in English to be used as a text-to-image prompt for a full-body studio image of this ORIGINAL character, standing in a neutral relaxed pose, facing the camera, on a plain neutral grey background with soft even lighting.

If human, describe age in numbers, human race, ethnicity and skin tone. This item is mandatory.

Cover with details everything in this list, in this order and only when applicable:
1. Rendering style: match the reference (photorealistic photo, anime, 3D render, illustration). If there is no reference, use photorealistic.
2. Character type: species or kind of being, apparent age or life stage, sex or gender presentation if any.
3. Body: height impression, build, proportions, posture.
4. Head and face: shape, eyes, nose or snout, mouth or beak, ears, horns, expression.
5. Surface: skin, fur, scales, feathers or metal, with colors, patterns and texture.
6. Hair, mane, crest or similar.
7. Clothing, armor and accessories. If the character is human, this item is mandatory and overrides the reference image and the brief: describe ONLY minimal clothing. For a man or male-presenting character: tight, form-fitting stretch short shorts (athletic compression style, hugging the hips and thighs) in a solid dark neutral color, ending at the upper thigh well above the knee, with a bare torso, bare arms, bare legs and bare feet. For a woman or female-presenting character: the same tight, form-fitting stretch short shorts plus a fitted plain sports crop top in a solid dark neutral color, with bare arms, bare legs and bare feet. Describe the material, color and fit of these garments and nothing else worn on the body. If the character is not human: materials, colors and fit of any clothing, armor and accessories.
8. Two or three distinctive features that make this character unique and instantly recognizable (marks, scars, unusual colors, signature accessory).
9. End with one sentence of anatomy guidance suited to this species: correct number of limbs and digits for the design, symmetrical features, no extra or fused body parts, no text or watermark.

Output only the text, no headings, no lists, no quotes."""

NO_BRIEF = "No written brief. Describe the character from the reference image only."

# Gemma 4 by VRAM: e4b for a 16 GB GPU or larger, e2b for smaller GPUs
GEMMA_MODELS = {
    "e4b": "gemma4_e4b_it_fp8_scaled.safetensors",
    "e2b": "gemma4_e2b_it_int8_convrot.safetensors",
}

def wf_gemma(name, ref=None, brief=None, seed=0, model="e2b"):
    tg = {"clip": ["1", 0], "prompt": ["6", 0], "max_length": 2048,
          "sampling_mode": "on", "sampling_mode.temperature": 1.0, "sampling_mode.top_k": 64,
          "sampling_mode.top_p": 0.95, "sampling_mode.min_p": 0.05,
          "sampling_mode.repetition_penalty": 1.05, "sampling_mode.seed": seed,
          "sampling_mode.presence_penalty": 0.0,
          "thinking": True, "use_default_template": True, "mtp": "auto",
          "system_prompt": ["3", 0]}
    wf = {
        "1": {"class_type": "CLIPLoader", "inputs": {"clip_name": GEMMA_MODELS[model], "type": "stable_diffusion", "device": "default"}},
        "3": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": GEMMA_SYSTEM}},
        "4": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": GEMMA_INSTRUCTIONS}},
        "5": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": brief or NO_BRIEF}},
        "6": {"class_type": "StringConcatenate", "inputs": {"string_a": ["4", 0], "string_b": ["5", 0], "delimiter": "\n\nCharacter brief: "}},
        "7": {"class_type": "TextGenerate", "inputs": tg},
        "8": {"class_type": "SaveText", "inputs": {"text": ["7", 0], "filename_prefix": f"{name}/description", "format": "txt"}},
    }
    if ref:
        wf["2"] = {"class_type": "LoadImage", "inputs": {"image": ref}}
        tg["image"] = ["2", 0]
    return wf

# ---------- FLUX.2 klein (9B or 4B) ----------
# klein by VRAM: 9b for a 16 GB GPU or larger, 4b for smaller GPUs. Each one requires its own text encoder.
KLEIN_MODELS = {
    "9b": ("flux-2-klein-9b-fp8.safetensors", "qwen_3_8b_fp8mixed.safetensors"),
    "4b": ("flux-2-klein-4b-fp8.safetensors", "qwen_3_4b.safetensors"),
}
# Fixed, generic texts: never mention specific features (horns, scales, wings...), klein draws whatever is mentioned.
LOCK = ("The exact same character from image 1: identical face, body proportions, surface details, hair, colors, outfit and accessories, "
        "in the identical rendering style. No redesign, no stylization change, no reinterpretation.")
PRIORITY = "The framing, pose and camera angle stated at the start of this prompt take priority over any pose mentioned in the character description."
BG = ("Plain neutral grey seamless studio backdrop, soft three-point studio lighting, flat even illumination, no harsh shadows. "
      "No text, no labels, no watermark.")
HEAD = "Head-and-shoulders shot, framed tightly from the top of the head to the shoulders, the head fills most of the frame."
FULL = "Full-body shot, the entire character visible from the top of the head to the feet, small margin around the body, centered."

def loaders(klein="4b"):
    unet, te = KLEIN_MODELS[klein]
    return {
        "105": {"class_type": "UNETLoader", "inputs": {"unet_name": unet, "weight_dtype": "default"}},
        "106": {"class_type": "CLIPLoader", "inputs": {"clip_name": te, "type": "flux2", "device": "default"}},
        "108": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae.safetensors"}},
    }

def ksampler(seed, pos, neg, latent):
    return {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 4, "cfg": 1, "sampler_name": "euler",
            "scheduler": "simple", "denoise": 1, "model": ["105", 0], "positive": pos, "negative": neg, "latent_image": latent}}

def wf_base(name, desc, seed, klein="4b"):
    wf = loaders(klein)
    wf.update({
        "107": {"class_type": "CLIPTextEncode", "inputs": {"text": f"{FULL} Standing in a neutral relaxed pose, facing the camera. {desc} {BG}", "clip": ["106", 0]}},
        "113": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["107", 0]}},
        "114": {"class_type": "EmptyFlux2LatentImage", "inputs": {"width": 832, "height": 1216, "batch_size": 1}},
        "116": ksampler(seed, ["107", 0], ["113", 0], ["114", 0]),
        "103": {"class_type": "VAEDecode", "inputs": {"samples": ["116", 0], "vae": ["108", 0]}},
        "94": {"class_type": "SaveImage", "inputs": {"filename_prefix": f"{name}/base_{seed}", "images": ["103", 0]}},
    })
    return wf

# id: (width, height, framing, pose/camera) — panels of the layout spec
PANELS = {
    "hero":           (960, 1024, "Extreme close-up of the face filling the frame.", "Looking straight into the camera, calm neutral expression, highly detailed eyes and textures."),
    "head_front":     (1024, 1024, HEAD, "Facing the camera straight on, neutral expression."),
    "head_34":        (1024, 1024, HEAD, "Head turned in a three-quarter view toward the left of the image, neutral expression."),
    "head_side":      (1024, 1024, HEAD, "Strict side profile, facing the left of the image, neutral expression."),
    "head_back":      (1024, 1024, HEAD, "Seen from directly behind, showing the back of the head and neck."),
    "head_down":      (1024, 1024, HEAD, "Facing the camera, head tilted down looking at the floor."),
    "head_up":        (1024, 1024, HEAD, "Facing the camera, chin raised looking up toward the ceiling."),
    "portrait":       (1216, 832, "Close-up portrait from the chest up.", "Slight head tilt, natural relaxed expression."),
    "tpose_front":    (832, 992, FULL, "Facing the camera, T-pose: arms stretched straight out horizontally to the sides, legs straight."),
    "tpose_back":     (832, 992, FULL, "Seen from directly behind, T-pose: arms stretched straight out horizontally to the sides."),
    "front_neutral":  (832, 992, FULL, "Facing the camera, standing relaxed, arms at the sides, neutral expression."),
    "side_left":      (832, 992, FULL, "Strict side profile, body facing the left of the image, standing relaxed."),
    "side_right":     (832, 992, FULL, "Strict side profile, body facing the right of the image, standing relaxed."),
    "34_front":       (832, 992, FULL, "Three-quarter front view, body turned 45 degrees, standing relaxed."),
    "full_back":      (832, 992, FULL, "Seen from directly behind, standing relaxed, arms at the sides."),
    "34_back":        (832, 992, FULL, "Three-quarter back view, seen from behind and turned 45 degrees, standing relaxed."),
    "walking":        (832, 992, FULL, "Side view, walking naturally mid-stride."),
}

CLOSE_UPS = {"hero", "head_front", "head_34", "head_side", "head_back", "head_down", "head_up", "portrait"}

def panel_prompt(k, desc):
    _, _, framing, pose = PANELS[k]
    if k in CLOSE_UPS:  # close-up: identity from image 1 only; the full-body description would widen the framing
        return f"{framing} {pose} {LOCK} {BG}"
    return f"{framing} {pose} {LOCK} {PRIORITY} Character description: {desc} {BG}"

def wf_panel(name, k, desc, ref, seed, klein="4b"):
    w, h, _, _ = PANELS[k]
    wf = loaders(klein)
    wf.update({
        "76": {"class_type": "LoadImage", "inputs": {"image": ref}},
        "109": {"class_type": "ImageScaleToTotalPixels", "inputs": {"upscale_method": "nearest-exact", "megapixels": 1, "resolution_steps": 1, "image": ["76", 0]}},
        "78": {"class_type": "VAEEncode", "inputs": {"pixels": ["109", 0], "vae": ["108", 0]}},
        "107": {"class_type": "CLIPTextEncode", "inputs": {"text": panel_prompt(k, desc), "clip": ["106", 0]}},
        "113": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["107", 0]}},
        "201": {"class_type": "ReferenceLatent", "inputs": {"conditioning": ["107", 0], "latent": ["78", 0]}},
        "202": {"class_type": "ReferenceLatent", "inputs": {"conditioning": ["113", 0], "latent": ["78", 0]}},
        "114": {"class_type": "EmptyFlux2LatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "116": ksampler(seed, ["201", 0], ["202", 0], ["114", 0]),
        "103": {"class_type": "VAEDecode", "inputs": {"samples": ["116", 0], "vae": ["108", 0]}},
        "94": {"class_type": "SaveImage", "inputs": {"filename_prefix": f"{name}/panels/{k}", "images": ["103", 0]}},
    })
    return wf

# ---------- 9:16 assembly (2160 x 3840) ----------
def assemble(folder, name):
    from PIL import Image, ImageOps
    P = os.path.join(folder, "panels")
    S = 2; W, H = 1080 * S, 1920 * S; g = 8 * S
    c = Image.new("RGB", (W, H), "white")  # thin white gutters
    def put(k, x, y, w, h, cen=(0.5, 0.5)):
        im = Image.open(os.path.join(P, k + ".png")).convert("RGB")
        c.paste(ImageOps.fit(im, (w, h), Image.LANCZOS, centering=cen), (x, y))
    Ht = 640 * S; hw = 592 * S                       # top: hero face ~55% of the width
    put("hero", g, g, hw, Ht, (0.5, 0.4))
    x0 = g + hw + g; rw = W - x0 - g; cw = (rw - g) // 2; ch = (Ht - 3 * g) // 4
    for i, k in enumerate(["head_front", "head_34", "head_side", "head_back", "head_down", "head_up"]):
        put(k, x0 + (i % 2) * (cw + g), g + (i // 2) * (ch + g), cw, ch, (0.5, 0.38))
    put("portrait", x0, g + 3 * (ch + g), rw, ch, (0.5, 0.2))
    y1 = g + Ht + g; bw = (W - 4 * g) // 3; bh = (H - y1 - 3 * g) // 3
    rows = [["tpose_front", "tpose_back", "front_neutral"],   # middle
            ["side_left", "side_right", "34_front"],          # bottom
            ["full_back", "34_back", "walking"]]
    for r, row in enumerate(rows):
        for j, k in enumerate(row):
            put(k, g + j * (bw + g), y1 + r * (bh + g), bw, bh)
    out = os.path.join(folder, f"sheet_{name}_9x16.png")
    c.save(out); c.resize((1080, 1920)).save(os.path.join(folder, f"preview_sheet_{name}.jpg"), quality=88)
    print(out)

def dump(wf, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(wf, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(path)

if __name__ == "__main__":
    mode, folder, name = sys.argv[1], sys.argv[2], sys.argv[3]
    wfdir = os.path.join(folder, "workflows")
    if mode == "gemma":
        ref = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != "-" else None
        brief = open(sys.argv[5], encoding="utf-8").read().strip() if len(sys.argv) > 5 and sys.argv[5] != "-" else None
        seed = int(sys.argv[6]) if len(sys.argv) > 6 else 0
        model = sys.argv[7] if len(sys.argv) > 7 else "e2b"
        dump(wf_gemma(name, ref, brief, seed, model), os.path.join(wfdir, "wf_01_gemma_description.json"))
    elif mode in ("base", "panels"):
        desc = open(os.path.join(folder, "description.txt"), encoding="utf-8").read().strip()
        if mode == "base":
            klein = sys.argv[4] if len(sys.argv) > 4 else "4b"
            for s in (101, 202, 303, 404):
                dump(wf_base(name, desc, s, klein), os.path.join(wfdir, f"wf_02_base_{s}.json"))
        else:
            ref = sys.argv[4]; seed = int(sys.argv[5]) if len(sys.argv) > 5 else 4242
            klein = sys.argv[6] if len(sys.argv) > 6 else "4b"
            for k in PANELS:
                dump(wf_panel(name, k, desc, ref, seed, klein), os.path.join(wfdir, f"wf_03_panel_{k}.json"))
    elif mode == "assemble":
        assemble(folder, name)
```

Path note: the script uses paths as seen by the shell where it runs; comfy-mcp tools (`upload_file`, `run_workflow`, `fetch_outputs`) use paths as seen by the machine running the comfy-mcp server. On a single machine they are the same; if the agent runs in a VM or container, translate between them.
