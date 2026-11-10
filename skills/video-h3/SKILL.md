---
name: "video-h3"
description: "Generates dialogue clips with a local MiniMax H3 (ref2va) from character/environment sheets, props and voices; continuous shot, a 1-frame anchor (upscaled with RTX VSR, color matched to clip 1) right after the last line, a very-low-resolution test first, RTX 5070 Ti and 4060 profiles, and Full HD through RTX VSR (default), SeedVR2 or short native shots."
---

# Video with MiniMax H3 (local ref2va)

A local pipeline in ComfyUI, driven through the comfy-mcp server. It takes character sheets, an environment sheet/plate, clothing and prop images, voice references and a script with dialogue. It delivers 15 s clips with native audio (voices, foley, ambience), chained by a 1-frame anchor taken right after each clip's last line (upscaled with RTX VSR and color matched to clip 1), and the assembled film with no dead time and no hard cut, in Full HD. Everything needed is in this file (the `video_h3.py` and `a1.py` scripts are at the end).

Reply in the user's language.

**3-stage flow** (the same for any scene, from 15 s to 1 min+; **every clip is 15 s**):

Default profile: **`local_16gb` (RTX 5070 Ti 16 GB + 32 GB RAM)**. `local_8gb` (RTX 4060) is kept for smaller cards.

| Stage | Purpose | `local_16gb` (5070 Ti), 15 s clip | `local_8gb` (4060), 15 s clip |
|---|---|---|---|
| 1. Live storyboard (`test`) | approve content: who appears, clothing, prop, actions, lines, timing, seams | 288×512, ~1.2 min (70–92 s; ~3 min on the first run with a cold model) | 288×512, ~4 min (225–240 s) |
| 2. Render (`draft`) | the real take: framing, faces, light | **768×1344, 19.4 min** | 544×960, ~20–23 min (estimated) |
| 3. Full HD | delivery | **RTX VSR Ultra → 1080×1920** (default; validated from 640×1152: 5 s in under 30 s). SeedVR2 is the alternative (~3 min per 3 s of video) | RTX VSR not tested yet on this card; SeedVR2 2× → 1088×1920, ~60 min |
| Native Full HD (`hd`) | short shots, look tests | **1088×1920 up to 5 s only, 12.5 min** | doesn't run (out of memory) |

The director approves each stage before the next one. Upscaling **always starts from the draft**, never from the test.

## Rules

- **The user is the director. Cut the camera only when they ask.** Every clip defaults to a single continuous shot: one framing, no cuts, no angle changes, no close-ups on your own initiative. Don't add shot/reverse shot, close-ups on the lines or a wide shot at the end unless the script asks for it. When the director asks for a cut ("cut to a close-up of X", "wide shot here"), the prompt gets a `[Shot N]` with "Cut to..." exactly at that point. You may warn about a risk (e.g. "in a continuous shot this line may slip in time"), but the decision is the director's.
- **Always start with the `test` preset** (288×512): ~1.2 min per 15 s clip on the 5070 Ti (~4 min on the 4060), versus ~20 min for `draft`. Move up a preset only after the director approves the test. The test validates the prompt: who appears, clothing, prop, actions, order and timing of lines. It does **not** lock the frame: the same seed at another resolution changes the framing and even the side of the screen. That's why framing and look are approved at `draft`.
- **Resolution limits per profile** (resolution ladder on the 5070 Ti; no step ran out of VRAM):
  - `local_16gb`: 15 s clips up to **768×1344** (19.4 min; 704×1248 took 15.5 min). **1088×1920 up to 5 s only** (12.5 min); the script refuses longer clips on the `hd` preset. 15 s Full HD = `draft` 768×1344 + **RTX VSR** (1080×1920), or SeedVR2 (~1.43×) if the director wants more texture, or a larger rented GPU (`vastai` skill).
  - `local_8gb`: don't generate above 544×960 (1088×1920 at 5 s ran over 1 h without finishing step 1; 768×1344 at 5 s took 13.5 min with a poor result). Full HD = `draft` + RTX VSR (to be tested on this card) or SeedVR2 2×.
  - Both: don't upscale the `test` (3.75×), because SeedVR2 makes the face look painted and bends glasses (RTX VSR wasn't tested from `test`).
- **On the 5070 Ti the bottleneck is system RAM, not VRAM**: the model (20 GB) and text encoder (15 GB) don't fit entirely in 16 GB and keep swapping through RAM; on the ladder only 2–4.5 GB of 32 GB were left. Close heavy programs (a browser with many tabs) before running `draft` or `hd`. With 64 GB of RAM it should be roomier and a bit faster.
- **Prompt in the official ref2va format** ("Prompt" section). People, clothes, props and set are `<Subject N>` defined from the images. `<Picture N>` only appears inside those definitions ("whose face comes from `<Picture 1>`"). Never describe an image as `<Picture N> = ...`: the model treats a loose Picture as a video frame and puts the references on screen as a collage (it happened in a first version).
- **You write the prompt** from the approved script and show the director a summary in their language (framing, requested cuts, who says what and when, actions) before generating. Without approval, don't run.
- **Dialogue format**: every line goes in double quotes inside the tag, with `.`, `!` or `?` **inside** the quotes: `<d>[English] "Line here."</d>` (the tag is the line's language, e.g. `[Portuguese]`). Two sentences of the same continuous line share **a single pair of quotes**: `<d>[English] "First sentence. And the second one."</d>`. Whoever doesn't speak (and the speaker, outside their line's window) gets the instruction "vocal cords remain silenced"; an extra who moves their lips without sound: "move their lips only; their vocal cords remain silenced, so there is no audible sound from them at all". Without this, MiniMax leaked invented lines in a scene with several extras. Write numbers as words ("five hundred"); write slang as it is spoken; avoid words the model may read as something else (rephrase them). Accent and intonation stay outside the tags.
- **Line timing in a continuous shot**: the seconds in the prompt are a suggestion (lines run 1–2.5 s late). In 15 s: up to 4 short lines, **the last line ends by 11 s** (10.5 s if there is a laugh or action afterwards) and the **last ~4 s stay still and silent**. That still ending is a **safety margin**, not part of the film: the next clip's anchor is taken right after the last line and the edit cuts there ("Anchor chaining" section). Reinforce the silence in two places, which is what worked:
  - in the final beat: "Complete silence: nobody speaks, no voice and no laugh, only quiet room tone. The camera holds still on the same two-shot.";
  - as the first sentence of `overall_soundscape`: "All dialogue ends by 11 seconds; the last four seconds have no speech at all."
  With only "Nobody speaks" in the final beat, the last line slipped to 13.25–15 s on 2 seeds in a row; with the reinforcement, the ending was silent on the first try. If the ending has speech, fix the prompt (move the lines ~0.5–1 s earlier + reinforcement) before changing seeds.
- **Duration: every clip is 15 s** (362 frames), H3's maximum, which fits both profiles at 288×512 without freezing the machine (on `local_16gb`, also at 768×1344). Don't go over 15 s: outside its training the model tends to repeat motion and lose identity, and the voice references add up to 15 s at most anyway. Longer scene → 15 s clips chained by anchor ("Anchor chaining" section): with the anchor right after the line, each clip contributes ~9–11 s to the film (7 clips = 71 s); with the old method, **15 + 14 × (clips − 1) s**. A clip may be shorter only if the director asks.
- **Pacing between clips**: directors rejected both the film with each clip's 4 still seconds ("school play") and the hard cut at the end of the line (a pose "jump", vlog style). The default is the anchor right after the line (continuous seam, ~1.2 s breath between lines), **with 1 frame** ("Anchor chaining" section). Long pauses only where the script asks for them (a drag on a cigarette, a reaction, an awkward silence).
- **At most 2 characters speak per clip** (H3 accepts up to 3 audios, but 3 voices adding up to 15 s are too short and swap mouths). A third character on screen stays quiet or laughs **without sound** ("laughs silently with his mouth closed, making no sound"). Split the script so each clip has 1 or 2 speakers.
- **Continuity**: in every clip, lock each character's side of the screen ("<Subject 1> is always on the LEFT side of the frame..."), plus clothing, prop and light. Without it the sides swap from one clip to the next.
- Branded clothing: describe the garment, colors and stripes; don't write the brand if the image doesn't show the logo (the model invents one).
- Stock images with a watermark: ask the user for another one (the watermark leaks into the video and there's a licensing issue). Don't remove watermarks.
- **API nodes (paid)**: the `MiniMax H3 ... (partner)` nodes spend Comfy Cloud credits. Only use them if the user asks and authorizes the spend. The default is the local model. For heavy renders, a rented GPU (`vastai` skill, destroying the instance afterwards) beats Comfy Cloud, which is expensive for H3 and has a 30 min/1 h limit per execution.

## Requirements (models)

| File | Folder | Use |
|---|---|---|
| `minimax_h3_fused_refdelta_r1024_turbo8_mystic07_int8_convrot.safetensors` | `models/diffusion_models` | H3 ref2va + fl2va fused, turbo (huggingface.co/MATLOWAI/minimax-h3-fused-turbo-int8-convrot) |
| `qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | `models/text_encoders` | text encoder (Comfy-Org/MiniMax-H3) |
| `minimax_h3_video_vae_fp16.safetensors` | `models/vae` | video VAE (local profiles; production uses int8_convrot) |
| `minimax_h3_audio_vae_fp32.safetensors` | `models/vae` | audio VAE |
| `nvvfx` runtime (NVIDIA VFX) in ComfyUI's Python + the `deno-custom-nodes` pack (node `DenoRTXVFXEasyUpscale`); the official `comfyui_nvidia_rtx_nodes` pack also works alongside | `custom_nodes` / ComfyUI venv | **default Full HD upscale (RTX VSR)**. Without the runtime, the node fails with `No module named 'nvvfx'`; installation is manual (deno-custom-nodes guide) and touches ComfyUI's Python, so ask the user |
| `seedvr2_7b_int8_convrot.safetensors` | `models/diffusion_models` | alternative upscale (Comfy-Org/SeedVR2; the same as in the `upscale-prop` skill) |
| `seedvr2_ema_vae_fp16.safetensors` | `models/vae` | SeedVR2 VAE |

Nodes (core, ComfyUI ≥ 0.40): `MiniMaxH3ReferenceToVideo`, `MiniMaxH3AddGuide`, `LoadVideo`, `GetVideoComponents`, `ResizeImageMaskNode`, and for SeedVR2 `SeedVR2Preprocess`, `SeedVR2Conditioning`, `SeedVR2PostProcessing`; plus `MiniMaxChunkFeedForward` (KJNodes) and `DenoRTXVFXEasyUpscale` (deno-custom-nodes, the only RTX VSR node the script uses and that was tested). In the shell: Python with Pillow and numpy, ffmpeg.

The official `video_minimax_h3_r2v` template didn't run with this setup (it asks for `minimax_h3_ref2va_pruned`, the int8 VAE and a turbo LoRA). The script builds the workflow from scratch. The warning `unet unexpected: ['adaln_basis', 'adaln_mean']` when loading the fused model is harmless.

If ComfyUI is not running, start it through comfy-mcp (`launch_comfyui`). If your models live in a shared folder (e.g. ComfyUI Desktop), pass `extra_args=["--listen","127.0.0.1","--extra-model-paths-config","<EXTRA_MODEL_PATHS_YAML>"]`. Files in `input` survive a restart.

## Presets and profiles

Each profile has its presets (9:16; 16:9 swaps them). `workflow` uses the presets of the profile in `config.json`.

**`local_16gb`: RTX 5070 Ti 16 GB + 32 GB RAM (default)**

| Preset | Size | Purpose | Measured time (6 images, 2 audios) |
|---|---|---|---|
| `test` | 288×512 | live storyboard | 15 s: **70–92 s** (8 images + 2 voices; ~3 min with a cold model); 70–86 s on a rented 5070 Ti |
| `draft` / `final` | 768×1344 | the real take (ceiling for 15 s) | 15 s: **19.4 min** (~4.3 min/step; step 1 4.4 min including model load) |
| `hd` | 1088×1920 | native Full HD, **up to 5 s** | 5 s: **12.5 min** (~2.6 min/step) |

Outside the presets: 704×1248 at 15 s = 15.5 min (~3.2 min/step). Free VRAM at peak: 1.2–1.9 GB. Free RAM at peak: 2–4.5 GB. 640×1152, 5 s, 1 image, 4 steps = 135 s total.

**`local_8gb`: RTX 4060 8 GB + 32 GB RAM**

| Preset | Size | Purpose | Measured time |
|---|---|---|---|
| `test` | 288×512 | live storyboard | 15 s: **225–240 s**; 13 s: 190–205 s; same with an anchor |
| `draft` | 544×960 | approvable take | 13 s: **998 s** (~213 s/step); with an anchor, 17–20 min (~234 s/step); 15 s: ~20–23 min (estimated) |
| `final` | 768×1344 | don't use | 5 s in 13.5 min (808 s), poor result |

Outside the presets, on the 4060: native 1088×1920 at 1.6 s took 13 min (and became a collage of the references: clip too short); at 5 s, over 1 h without finishing step 1. SeedVR2 7B upscale of 3 s (73 frames) to 1088×1920: 10–11 min (≈4 min generating, the rest loading and decoding).

Profiles (`config.json` → `profile`): `local_16gb` (default for `init`), `local_8gb` (fp16 VAE, ChunkFeedForward 4/4096, 4 steps on both) and `production` (int8 VAE, no chunking). **Moving to another machine means switching the profile and checking the file names in `PROFILES`**; prompts, `<clip>.json`, anchors and references don't change.

4060 measurements that serve as reference for the 5070 Ti:
- 4 steps is what the checkpoint author recommends. With 8 steps and no ChunkFeedForward, the draft took ~70 min per clip. (On the 5070 Ti, 8 steps at 640×1152/5 s cost little and didn't change sharpness: see the sharpness A/B lessons.)
- ChunkFeedForward 4/4096 took the draft step from ~500 s to ~213 s.
- Step 1 includes model initialization (~3.5 min in the draft, ~30 s in the test).

Every generation logs its time in `timings.csv` (`time` mode). That table is the basis for sizing a production machine.

## References

H3 limits: up to 9 images, 3 videos and 3 audios (12 files); reference audios of 2–15 s each and **15 s in total**; audio never on its own.

- **Face**: `python video_h3.py face <sheet_9x16.png> refs/<name>_face.png` crops the large face panel from the character sheet (`character-sheet` skill). Use the crop, not the whole sheet.
- **Clothing**: the garment image; in the prompt, `attribute_transfer` and "the man wearing it in the reference is not used". The `costume-sheet` skill's board is a 3×2 grid (looks on top, pieces below): prefer the isolated piece (`<name>_piece_<slug>.png`); to use the complete front look, crop the top-left panel (`python video_h3.py look <costume_sheet_<name>.png> refs/<name>_look.png`). The whole grid may turn into a collage on screen.
- **Face and the sheet's clothing**: a character sheet may show the body in other clothes (sweatpants, shorts, tank top) and those clothes **leak** into the video (a character came out in grey sweatpants instead of white shorts). In the face's `retention_analysis` write "only the head is used, none of the clothing or the studio background of the reference" (without naming the sheet's garment: naming "grey sweatpants" reinforces it) and, for the clothing, describe the visible skin ("white shorts that end above the knee, with his bare pale legs showing").
- **Prop**: a clean image of the object; "the hand and background of the reference are not used".
- **Environment**: 1 plate from the environment sheet (`environment-sheet` skill). The assembled grid doesn't work (its text panel leaks).
- **Voice**: `python video_h3.py pauses <audio>` lists the pauses; `python video_h3.py voice <audio> refs/<name>_voice.wav <start> <end>` cuts at a pause, with fades, mono 48 kHz. Keep the sum ≤ 15 s across all voices in the clip (e.g. 8.4 s + 5.2 s). A character who doesn't speak in the clip gets no audio.
- **The same references in every clip of the chain**, even with an anchor: the anchor gives continuity, the references hold identity.
- 6 images were enough for 2 characters + 2 outfits + prop + room; 8 images (3 faces + 3 looks + prop + room) worked for 3 characters in the same shot.
- Prefix the project's files (e.g. `<pfx>_<name>_face.png`) so you don't overwrite, in `input`, another project's references with the same name.
- Upload everything to ComfyUI's `input` through comfy-mcp (`upload_file`, overwrite). **A file missing from input makes the job fail when queued.**

## Anchor chaining (scenes longer than 15 s)

With an anchor, the room, light, positions and ambient sound carry across the seam; without one, the room changes angle and layout and the next clip starts with ~1 s of silence. **A 5-clip chain (64 s) was tested at `test` and `draft`** (anchor at the end of the clip) and **a 7-clip chain with 3 characters** with the anchor right after the line: identity, clothing, prop, room and screen sides were stable at every seam, none showing a cut.

**Default method: 1-frame anchor, upscaled and color matched to clip 1** (approved by the director; `a1.py` script at the end of this file). Instead of copying 25 frames from the end of clip N, the anchor is **a single frame** chosen right after the last line (or the last planned action), upscaled 2× with **RTX VSR Ultra**, scaled back to the clip size (lanczos), and with each color channel's mean and standard deviation matched to a frame of clip 1. That frame goes into frame 0 of clip N+1 through a `MiniMaxH3AddGuide` (`image` only), and 1 s of audio from the same point goes into a second `MiniMaxH3AddGuide` (`audio` only), so the ambient sound carries on and the ~1 s of silence of an unanchored clip doesn't come back. In the edit, clip N ends at the anchor frame and N+1 starts at frame 1 (1/24 s).

Why: with the 25-frame anchor, whatever gets worse at the end of a clip (light darkening, soft faces) becomes the next one's starting point; in one 7-clip draft the brightness fell from 105 to 85 between clip 1 and clip 7. With 1 frame + clip 1's color, brightness stayed at 98–103 from clip 4 to 7 and the director found the motion more natural. The upscale's extra detail does **not** survive (H3 redraws the image at its own level of detail: sharpness of the generated frame 0 ~285 vs ~410 for the upscaled anchor); the gain is stable color and a clean restart. **RTX VSR replaced SeedVR2 for this step** (natural skin, ~2 s per frame; SeedVR2, ~11 s, is the `seedvr2` alternative): the approved chain was made with SeedVR2, and RTX VSR on the anchor frame was validated (workflow, 2 s, sharpness 282 → 312) but **not yet tested in a generated chain**: on the first chain with it, check the seams more carefully.

1. **Color reference** (once per project, with clip 1 approved): `python3 a1.py ref videos/<clip1>.mp4 2` writes `refs/anchor1/color_ref_clip1.png`.
2. **Generate clip N** with the still, silent final beat (line-timing rule). It is only a margin.
3. **Find the frame**: `python video_h3.py speech videos/<clipN>.mp4` (end of the last line) + the contact sheet (`review`) to see the last planned action; `python3 a1.py cuts videos/<clipN>.mp4` to see whether H3 invented a cut; `python3 a1.py still videos/<clipN>.mp4 <t_a> <t_b>` lists motion frame by frame and names the stillest. Choose a **still** frame (motion ≤ ~3), **after the last line, before any cut** and, if possible, after the planned action. With 1 frame the model doesn't know where people were heading: an anchor mid-gesture jolts the seam.
4. **Prepare and upscale**: `python3 a1.py prepare videos/<clipN>.mp4 <frame> <clipN> [rtx|seedvr2]` writes the frame PNG, 1 s of audio and `workflows/a1_rtx_<clipN>.json`. Upload the PNG and the audio to `input` (`upload_file`, overwrite), run the workflow through comfy-mcp and wait (seconds), fetch the outputs into `refs/anchor1/`, rename with `mv -n` and run `python3 a1.py final <clipN> <upscaled_png>` (scales down and matches the color; shows brightness before/after). Upload `<pfx>_a1_<clipN>_final.png` to `input`.
5. **Next clip**: `python3 a1.py wf <clipN+1>.json <preset> <seed> <clipN>` writes `workflows/<id>a1_<preset>_s<seed>.json` with both guides at frame 0 (the `anchor` field of the clip JSON is ignored). Prompt as in the 25-frame method: the first second describes the state of the anchor frame, with "The video opens by continuing the previous moment seamlessly, with the same framing, light and positions, and the first line starts right at 1.0 seconds with no pause." If clip N's planned final action fell after the anchor (e.g. a character lowering their eyes), describe it in the first second of N+1.
6. **Check**: `python3 a1.py seam videos/<clipN>.mp4 <frame> videos/<clipN+1>.mp4`. Expected: anchor frame × new frame 0 ~5–8; over the first ~3 frames of the new clip the step rises to 6–12 (the model "pulls away" from the still frame) and falls back to 2–4 after that. Also run `cuts` on the new clip.
7. **Assemble**: `python video_h3.py assemble videos/film.mp4 videos/clip1.mp4:0:<(q1+1)/24> videos/clip2.mp4:0.0417:<(q2+1)/24> ... videos/clipN.mp4:0.0417:<end>`, where qK is the anchor frame taken from clip K and 0.0417 = 1/24 s. Expected: jumps of 8–13 at the joins (continuous).

Result (7-clip, 3-character scene, draft 768×1344, clips 2–7 with 1 frame + SeedVR2): 71.0 s, jumps of 8.2–13.2 at the 6 joins, no cuts, stable brightness, motion approved by the director; ~21 min per clip + ~1 min per anchor.

**Alternative: 25-frame anchor right after the last line** (still valid when motion must cross the seam with no jolt at all). `MiniMaxH3AddGuide` accepts any 25-frame segment. Taking the anchor from the second right after the last line (or the last planned action), the next clip continues from there; in the edit, clip N ends at the end of the anchor and N+1 starts at 25/24 s, which is the copy of that same segment. The result is a continuous seam, without the 4 dead seconds and without a hard cut. The 4 still seconds at the end remain in the prompt, as a margin for late lines, but don't go into the film.

1. **Generate clip N** with the still, silent final beat (line-timing rule). It is only a margin.
2. **Find the anchor point**: `python video_h3.py speech videos/<clipN>.mp4` lists the segments with sound above -32 dB. The instant `t0` is the end of the last line + ~0.1 s, **or** the end of the last planned action, if it comes later (a high five, a drag on a vape, two characters looking at each other, someone lowering their head). Use the contact sheet (`review`) to locate the action: it has 1.5 frames/s, frame k is at k/1.5 s. Check in the speech list that [t0, t0+1.04] has no sound; if it does (a laugh, a grunt), push t0 later or change seeds.
3. **Extract**: `python video_h3.py anchor_at videos/<clipN>.mp4 refs/<pfx>_anchor_<clipN>.mp4 <t0>` (25 frames + audio from t0, nearly lossless). Note t0 (the edit uses it). Upload to `input` (`upload_file`, overwrite) **only after** the command finishes.
4. **Next clip**: in the clip JSON, `"anchor": "<pfx>_anchor_<clipN>.mp4"`. The workflow gets `LoadVideo` → `GetVideoComponents` → `MiniMaxH3AddGuide` (frame 0, image + audio). In the prompt, the first second describes **the previous clip's state at t0** (the reaction, not the still ending) with the sentence "The video opens by continuing the previous moment seamlessly, with the same framing, light and positions, and the first line starts right at 1.0 seconds with no pause.", and the first line goes in `(1.0s-...)`. With that sentence the line started at 1.0–1.2 s in 9 of 12 tests. If the clip opens with an action (handing over a controller), have the character speak during the action, not before.
5. **Check**: `python video_h3.py seam_at videos/<clipN>.mp4 <t0> videos/<clipN+1>.mp4`. Expected: anchor repetition ~6–8 (recompression only) and steps of 1–5 at frames 20–28 (continuous motion). Also compare with `md5sum` the anchor against the copy that the output fetch brings back (it goes to `videos/_echo/`).
6. **Assemble**: `python video_h3.py assemble videos/film.mp4 videos/clip1.mp4:0:<t0_1+1.0417> videos/clip2.mp4:1.0417:<t0_2+1.0417> ... videos/clipN.mp4:1.0417:<end>`. Each segment is `video:start:end` in seconds; 1.0417 = 25/24 s (end of the anchor). The last clip ends where the action ends. `assemble` puts a 25 ms micro-fade on the audio at each join and measures the image jump: 6–13 = continuous; ~70 = a real cut.

Result (7 clips, test 288×512): 71.2 s versus 99.7 s with the anchor at the end; jumps of 6.4–13.1 at the 6 joins; ~1.2 s breath between lines; the planned pauses (a drag, a look, a lowered head) lasted 3–5 s.

**Old method (anchor at the end of the clip)**: `python video_h3.py anchor videos/<clipN>.mp4 refs/anchor_<clipN>.mp4` (last 25 frames) + `seam` + `concat --anchor`. Leaves ~4–5 s of still silence at each seam; use it only if the director wants that pause.

The chain is sequential: each clip waits for the previous one to finish. Do the whole chain at `test` first. Clip 1's anchor depends on nothing: when redoing the chain, the approved clip 1 can be reused.

Caveats:
- **Invented cuts in the silent beat**: with the 1-frame anchor, in two clips of one chain H3 cut on its own to a wide shot of the room exactly at 10.42 s (frame 250), right after the last line. No need to redo: run `cuts` and take the anchor before the cut; the action that would come after moves to the first second of the next clip.
- **Camera that widens or tightens on its own**: even with "never changes angle", H3 slowly pulled back during a drag on a vape and zoomed in on a character in another clip. Take the anchor before the camera move, so the next clip doesn't inherit the wider frame.
- **Stray sound at the start**: with the 1 s audio guide, a short sound (laugh, breath) sometimes appears in the first 0.2–0.6 s of the new clip. Ask the director to listen.
- **Anchor with motion** (a gesture, rising smoke) copies a little less faithfully than a still anchor (repetition 7–15 instead of 6). It doesn't break the seam; prefer a t0 where the action is already ending.
- **Defects travel through the anchor**: an artifact in the anchor segment (e.g. a smudge on the face) passes to N+1. Review that second before extracting; if it has a defect, change t0 or redo with another seed.
- **A line inside the anchor** travels too: the next clip starts with the end of that line. That's why t0 goes after the line, never in the middle.
- Chain work order: extract the anchor and queue the next clip right away; review the previous clip's contact sheet while the next one generates.

## Steps

### 0. Prepare
- Server info through comfy-mcp: ComfyUI is up. Account auth only matters if you will use paid nodes.
- System stats: if free VRAM is low, free ComfyUI's memory before running.
- In the project folder: write `video_h3.py` and `a1.py` and run `python video_h3.py init . <9:16|16:9> [local_16gb|local_8gb|production] [prefix]` (default: `local_16gb`; the prefix names the anchor files, default `h3`). Old project: change `profile` in `config.json`.
- Before `draft` or `hd` on the 5070 Ti: check system stats and ask the user to close heavy programs if free RAM is below ~15 GB.
- Before Full HD: confirm the `DenoRTXVFXEasyUpscale` node exists (look up the node through comfy-mcp). If the job fails with `No module named 'nvvfx'`, NVIDIA's runtime isn't installed: tell the user (installation is manual) and use SeedVR2 until then.

### 1. Script
- Adjust the dialogue (rules above) and split the scene into 15 s clips, each one (from the 2nd on) with its first second continuing the previous one, lines from ~1 to 11 s and the still, silent beat from 11 to 15 s.
- For each clip: a single framing (or the cuts the director asked for, with their times), who says what, actions, screen side. If the director doesn't state the framing, ask instead of choosing cuts.
- Show the director the adjusted dialogue and the clip split; continue with approval.

### 2. References
Prepare faces, voices and images as in the section above, in `refs/`, and upload them to `input`.

### 3. Prompt and clip JSON
- Write `prompts/<clip>.txt` in the format of the "Prompt" section.
- Write `<clip>.json`:
  ```json
  {"id": "clip2", "seconds": 15, "output": "<project>", "prompt": "prompts/clip2.txt",
   "images": ["anna_face.png", "ben_face.png", "jacket_a.png", "jacket_b.png", "prop_vape.png", "room_06_tv_videogame.png"],
   "audios": ["anna_voice_ref.wav"],
   "anchor": "anchor_clip1.mp4"}
  ```
  The order of `images` defines `<Picture 1..N>` and the order of `audios` defines `<Audio 1..N>`. **Audios go in the order the characters speak in the clip**: `<Audio 1>` is the voice of whoever speaks first (S1). In a clip where Ben speaks first, `"audios": ["ben_voice_ref.wav", "anna_voice_ref.wav"]`. Clip without lines: `"audios": []` and summary `[reference generation]`. `anchor` only from the second clip on (25-frame method).

### 4. Test (very low resolution)
- `python video_h3.py workflow . clip1.json test <seed> [seed ...]`. Generate 2 or 3 seeds per clip.
- Validate and run each one through comfy-mcp without blocking.
- Wait (e.g. `sleep 170` in a shell) and check the job status or the last log lines. If your MCP client times out on long calls, keep each wait under ~50 s.
- When done: fetch the outputs into `videos/` and run `python video_h3.py arrived <first 8 chars of the prompt_id> <name> workflows/<wf>.json <seconds> [refs/<anchor>.mp4]`: moves the video to `videos/<name>.mp4` and the anchor copy to `videos/_echo/` (the `_000`/`_001` order varies; the script picks by size), checks the anchor's md5, logs the time (from the log, "Prompt executed in") in `timings.csv`, makes the contact sheet and lists the lines.
- **Clip name when redoing**: change the `id` in the clip JSON (e.g. `clip2v3`) before generating workflows for a new version; with the same id, `workflow` overwrites the old JSON files and `SaveVideo` mixes versions.
- `python video_h3.py review videos/<v>.mp4 videos/<v>_contact.jpg`: contact sheet + volume every 0.25 s. Look at the contact sheet.
- Check: the right characters with the right clothing, prop in the right hand, no reference pasted on screen, framing and cuts as the director asked, lines in the right segments (`speech`), first line at ~1.0 s in anchored clips, silence in the second after the last line/action, no defect in the segment that becomes the anchor. Among seeds, prefer the one that starts speaking earlier and has no stray sound (laugh, grunt) after the last line; discard a seed where a character disappears and reappears. Without automatic transcription, ask the director to **listen** (see the subtitles lesson for an ASR option).
- With the clip chosen: find the anchor frame (`speech`, `cuts`, `still`), prepare the 1-frame anchor (`a1.py prepare` → RTX VSR → `a1.py final`) and move on to the next clip in the chain ("Anchor chaining" section). The 1-frame anchor hasn't been tested at `test` (288×512) yet; if the result looks odd, use the 25-frame one (`anchor_at`) for the test and the 1-frame one for the draft.
- At the end of the chain: `assemble` with the noted frames and show the film to the director.

### 5. Draft
- With the test chain approved: redo each clip at `draft` (and `final` only in production), **in order, extracting the anchor from the previous draft** (the test anchor doesn't work: different resolution). Each clip's anchor frame is chosen again in the draft (`speech` + `cuts` + `still` + contact sheet): line timing changes between resolutions. Same prompts and seeds as the approved test, but warn that the frame changes: in one scene the test came out as a two-shot from the knees up and the draft as a full-body shot with the window behind, with the same prompt. If the director wants the test's frame, describe the framing more precisely (camera distance, what stays out of frame) and test 1 clip at draft before the chain.
- `local_16gb` (768×1344): 19.4 min per 15 s clip; 5-clip chain ≈ 1h40. `local_8gb` (544×960): ~20–23 min per clip (estimated); 5 clips ≈ 1h45.
- On `local_16gb`, a short shot (up to 5 s) can go straight to native Full HD with the `hd` preset (12.5 min), without upscaling.
- Review as in the test. If it diverges from the test, generate another seed at draft; don't go back to test.
- Assemble the draft film (`assemble` with the draft's anchor frames) and send it to the director. **Upscaling only starts with the draft film approved** (RTX VSR takes seconds per block; SeedVR2 took ~60 min per 15 s clip on the 4060).

### 6. Full HD (RTX VSR; SeedVR2 as the alternative)
**Default: RTX Video Super Resolution, `VSR Ultra` mode** (node `DenoRTXVFXEasyUpscale`), taking the draft film to 1080×1920 (16:9: 1920×1080). The director compared it with SeedVR2 on the same clip and preferred RTX VSR, because SeedVR2 exaggerates freckles and pores and the skin looks retouched ("fake"), while RTX VSR keeps the skin natural and human-looking; it is also much faster. Sharpness measured on the face (variance of the Laplacian, same frame): plain resize 64, RTX VSR 136, SeedVR2 197. Higher measured sharpness is not the goal: the natural look is.
1. `python video_h3.py upscale . videos/<film>.mp4` (`rtx` engine is the default) → cuts into blocks of 120 frames (5 s; on the 5070 Ti blocks of 240 frames also ran, ~1–3 min each) with 8 frames of overlap in `upscale/`, writes one workflow per block in `workflows/` and the manifest `upscale/<film>_blocks.json`. A 15 s clip gives 3–4 blocks.
2. Upload the blocks to `input` (`upload_file`, overwrite).
3. For each block, in order: free ComfyUI's memory → run without blocking → wait (short `sleep` + job status) → fetch the outputs into `upscale/` → `mv -n <id>_001.mp4 upscale/<film>_bN_up.mp4` (`_000` is the input copy: move it to `videos/_echo/`) → `time` with the time from the log.
4. `python video_h3.py merge upscale/<film>_blocks.json videos/<film>_1080x1920.mp4` → joins the blocks with a linear blend over the overlap and adds the original audio. Checks that the output has the same number of frames as the original.
5. Review: a still frame side by side (plain resize × RTX VSR) with face crops, and ask the director to watch for flicker and the passage between blocks (every ~4.7 s).
- **Why blocks**: the node loads all of the block's frames as float32 into RAM (124 frames at 1080×1920 ≈ 3 GB); a 70 s film doesn't fit in 32 GB. 120 frames is the tested block size; 240 worked on the 5070 Ti (19 blocks for a 178 s film). In `merge`, the last block may have a huge overlap (154 frames in the 178 s film): kept frames must be stored as uint8 (float32 blew past ~3.9 GB of RAM in a small VM and the process was killed with "Killed").
- **Crop**: the mode is `Center Crop (Fill)`. From 768×1344 (ratio 0.571) to 1080×1920 (0.5625), ~1.5% is cropped at the sides; it's applied to the whole assembled film, so it doesn't show as a jump.
- **Validated**: a 5 s clip (124 frames) at 640×1152 → 1080×1920, in a single workflow, no errors, done in under 30 s. **Not measured yet**: from 768×1344, the join between blocks and the time for a 15 s clip.
- **Error `No module named 'nvvfx'`**: the NVIDIA VFX runtime isn't in ComfyUI's Python. Install it following the `deno-custom-nodes` guide (ZIP with `install_rtx_vfx.bat`, ComfyUI closed) or with the `comfyui_nvidia_rtx_nodes` pack; it's the user's decision, don't install it on your own. Then restart ComfyUI.

**Alternative: SeedVR2 7B** (more texture, but over-sharpens skin): `python video_h3.py upscale . videos/<film>.mp4 seedvr2 [multiplier]`. Upscales until the longer side reaches 1920 (544×960 → 1088×1920 on `local_8gb`; 768×1344 → ~1098×1920 on `local_16gb`; the multiplier is computed automatically). SeedVR2 restores without a prompt and only adds definition (hair, glasses, skin, beard). The video doesn't fit at once: the script cuts it into blocks of 73 frames (3 s) with 8 frames of overlap; the rest of the procedure (one workflow per block, free memory **always** between blocks, `merge`) is the same as for RTX VSR. Times: 4060 ~10–11 min per block (~60 min per 15 s clip); 5070 Ti **179 s for a 73-frame block** (640×1152 → 1066×1920, including model load; the sampling step took ~11 s). On the 5070 Ti, a whole 124-frame clip at once froze (free RAM ~3 GB) and was cancelled: always use blocks. There are also the native nodes `SeedVR2TemporalChunk`/`SeedVR2TemporalMerge` (to be tested).

### 7. Output
`<project>/`: `config.json`, `video_h3.py`, `a1.py`, `refs/` (faces, looks, voices, anchors; `refs/anchor1/` with the raw, upscaled and final frames, the 1 s audios and the color reference), `prompts/`, `<clip>.json`, `workflows/`, `videos/` (every version + contact sheets + films, including the `_1080x1920` one; the input copies that the output fetch brings along go to `videos/_echo/`), `upscale/` (blocks, upscaled blocks, manifest), `timings.csv`.

File notes:
- Never delete or overwrite the user's files: rename with `mv -n`; don't create temporary files in the project folder (use a temp folder; a reusable script goes into the project folder).
- Paths: the scripts use paths as seen by the shell where they run (run them from the project folder, `.`); comfy-mcp tools (`run_workflow`, `fetch_outputs`, `upload_file`) use paths as seen by the machine running the comfy-mcp server. On a single machine they are the same; if the agent runs in a VM or container, translate between them.

## Prompt (official ref2va format)

Sections in this order; `detailed_description` in English, 350–500 words. Default template (single continuous shot, anchored clip):

```text
subject_definitions:
<Subject 1> is <name>, <visible features>, whose face and hair come from <Picture 1>.
<Subject 2> is <name>, <features>, whose face and hair come from <Picture 2>.
<Subject 3> is the <clothing> from <Picture 3>: <garment, colors, details>; it is worn by <Subject 1>.
<Subject 4> is the <clothing> from <Picture 4>: ...; it is worn by <Subject 2>.
<Subject 5> is the <prop> from <Picture 5>; it is held by <Subject 2>.
<Subject 6> is <place> from <Picture 6>: <walls, floor, furniture with positions, window/view>.
<Audio 1> is the voice-timbre reference for <Subject 1> (S1).
<Audio 2> is the voice-timbre reference for <Subject 2> (S2).

summary:
[reference generation + audio reference] In one continuous shot in <Subject 6>, <one sentence with the scene, using only labels already defined>. <Audio 1> and <Audio 2> guide their voices.

retention_analysis:
<Subject 1> (appears in every shot of <name>): fully_preserved - face, hair, glasses retained; only the head is used, none of the clothing or the studio background of the reference.
<Subject 3>: attribute_transfer - colors, cut and details transferred onto <name>; the man wearing it in the reference is not used.
<Subject 5>: fully_preserved - shape and colors retained; the hand and background of the reference are not used.
<Subject 6>: partially_preserved - layout, colors, furniture and view retained; the camera position changes.
<Audio 1>: reference - voice timbre and accent only, no copied words or background.

detailed_description:
The target video is live-action and photoreal, <style>, vertical 9:16 framing, <light>. One continuous shot with no cuts for the whole video. The camera <position/height> and frames <who> in a <framing requested by the director>; it never cuts and never changes angle. Screen direction is fixed: <Subject 1> is always on the LEFT side of the frame and <Subject 2> is always on the RIGHT side. <where each one is, clothing, prop>.
[Shot 1] (0.0s-15.0s) A single continuous <framing> that holds the same framing. The video opens by continuing the previous moment seamlessly, with the same framing, light and positions, and the first line starts right at 1.0 seconds with no pause.   <- anchored clips only
(0.0s-1.0s) <the previous clip's state in the anchor segment (t0)>.
(1.0s-4.5s) <action>, <Subject 1> (S1) says, <d>[English] "Line here."</d>
(4.5s-8.0s) <action>, <Subject 2> (S2) says, <d>[English] "Another line."</d>
(8.0s-11.0s) <action>, <last line, ending by 11 s>
...
(11.0s-15.0s) <still beat: safety margin, not part of the film>. Both stay still. Complete silence: nobody speaks, no voice and no laugh, only quiet room tone. The camera holds still on the same framing.
Both keep <glasses/clothing/prop> the whole time; clothes, props, room and sides of the frame never change. There are no cuts, no subtitles, no on-screen text and no watermark.

overall_soundscape:
All dialogue ends by 11 seconds; the last four seconds have no speech at all. <ambience and physical sounds, no dialogue: TV, room tone, street>

non_diegetic_music:
N/A
```

When the director asks for a cut: replace "One continuous shot with no cuts..." with the shot list, each one with `[Shot N] (start-end) Cut to <framing>.` at the requested point, and remove "no cuts" from the end. In an anchored clip with a cut at 1.0 s, `[Shot 1] (0.0s-1.0s)` continues the end of the previous clip and `[Shot 2]` starts at the cut.

Format rules:
- `(Sx)` in the order each voice appears in the clip. Don't write `(Sx)` in `retention_analysis`.
- A character who doesn't speak in the clip: no `<Audio>` and "<name> never speaks; their vocal cords remain silenced" at the end of `detailed_description`. In scenes with extras, list each group: "the staff move their lips only; their vocal cords remain silenced, so there is no audible sound from them at all".
- Lines in double quotes, final punctuation inside the quotes, two sentences of one continuous line = a single pair of quotes. In `overall_soundscape`, describe the speech without words ("one speech of two sentences between 0.8 and 8.4 seconds") and say that all dialogue ends by X s.
- `summary` doesn't create new labels.
- Don't repeat lines in `overall_soundscape`.

## Lessons from testing

### Backstage b-roll with extras, a 178 s film, subtitles
- **Leaked lines**: in a backstage b-roll (one character in the foreground, staff in the background) v1 generated lines that don't exist. v2, with double quotes, punctuation inside the quotes, a single pair of quotes for the two sentences and "vocal cords remain silenced" for everyone who doesn't speak (and for the extras who only move their lips), came out with only the two requested sentences (checked by ASR). The director approved it. A line ending by ~8.6 s in a 12 s clip left the end free for the extras' gesture.
- **Gestures**: a finger pointed at a prosthetic nose ended up pointing at the lens; the staff's shrug was unclear and there was noise/laughter at 9.8–12 s. Only one seed was tested; to get a gesture right, test more seeds and describe the hand ("index finger touches the tip of the prosthetic nose").
- **Duration**: 12 s requested produced 294 frames at 768×1344 (a 12.25 s clip).
- **Upscaling a whole film** (4270 frames, 177.9 s): 19 blocks of 240 frames on RTX VSR, 1080×1920. If your shell has a time limit per call, make the block cutting skip blocks that already have a workflow (a timeout left the last block truncated). `merge` must keep the overlap as uint8 (already in the script).
- **Subtitles**: script text, ASR timings (faster-whisper: `pip install faster-whisper`; pass a mono 16 kHz float32 numpy array, because a file path gave `av.open() got an unexpected keyword argument 'metadata_errors'`) plus the energy segments from `video_h3.py speech`. Lines invented by MiniMax go into the SRT if the director wants. Burn them in with ffmpeg `subtitles` (libass) with `original_size=1080x1920` and `force_style='FontName=DejaVu Sans Bold,FontSize=11,Bold=1,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=1,Outline=1.2,Shadow=0,Alignment=2,MarginV=95,MarginL=40,MarginR=40'` (FontSize 15 was too large). With a per-call time limit, encode in 3 segments and join them with `-c copy`, adding the original film's audio at the end.

### 1-frame anchor + upscale (7-clip draft at 768×1344)
- Diagnosis of draft v1 (25-frame anchor): the director saw the characters losing definition from clip 1 to 7. The references go into every clip, but the anchor weighs in: sharpness falls from the start to the end of each clip (~470–600 → ~250–340) and the anchor comes from the final segment; the light darkened (brightness 105 → 85) and the camera widened from clip 4 on (smaller faces).
- A/B on clip 2 (same prompt and seed): 25-frame anchor × 1 frame + SeedVR2 + clip 1's color. Similar face sharpness (300–373 × 275–361): the upscale's detail doesn't carry into the video. At the seam, the step over the first frames rose to 10–12 (versus 2–3 at the end of the previous clip); the director found the motion **more natural** and approved the method.
- Chain 2–7 with 1 frame: brightness stable at 98–103; clip 3's framing tighter (larger faces); two invented cuts at 10.42 s (clips 5 and 6), solved by taking the anchor before them; ~21 min per clip at draft.
- `MiniMaxH3AddGuide` has no strength setting; it accepts chained guides at different frames, and image and audio can go in separate guides.
- Anchor frame upscale: SeedVR2 7B 2× in ~11 s (sharpness 332 → 412); RTX VSR Ultra 2× in ~2 s (282 → 312). RTX VSR stayed, because the director prefers its skin in Full HD.

### "Why is that other video sharper?": A/B on the 5070 Ti
A community workflow ("MiniMax H3 - Basic"): same model and VAEs as this skill; differences: `MiniMaxH3TurboSampler` instead of `res_multistep`, `MiniMaxH3SigmaShift` 12/3, `MiniMaxH3MotionCache`, `ModelAttentionBackend` "comfy kitchen attention", encoder offloading, an int8 "heretic" encoder instead of nvfp4, `ref_image_size` `max`, an HQ switch (4 steps without upscale, or 8 steps + RTX VSR Ultra up to 1080p).

Generator A/B (same seed and image, 640×1152, 5 s, cumulative chain; face sharpness = variance of the Laplacian): A base 234 · B turbo sampler + shift + attention 215 · C with 8 steps 206 · D with `ref_image_size` `max` 210 · E with int8 encoder 222. Visually the five were practically identical: **no generator setting made the video sharper**; the base didn't lose. Conclusion: the other workflow's sharpness doesn't come from steps, sampler, `ref_image_size` or encoder.

Upscale (same clip, up to ~1080×1920, face crop): plain resize 64 · RTX VSR Ultra 136 · SeedVR2 197. The director found SeedVR2 "fake" (excess freckles and pores) and RTX VSR more natural: **RTX VSR became the Full HD default** (step 6).

Environment: `nvvfx` wasn't installed at first (the Deno node failed with `No module named 'nvvfx'`); after the user installed it, the node ran without restarting ComfyUI. The `comfyui-minimax-h3-turbo` 1.2.3 pack was installed (registry). `MiniMaxH3MotionCache` and `MiniMaxH3Resolutions` don't show up in core v0.42.0: what MotionCache does wasn't confirmed. None of this is needed for this skill.

Untested tip: downscale reference images to ~768 px on the longer side, because the visual text encoder spends tokens per pixel (2062 tokens at 768 px vs 4622 at 1536 px, by the tip's numbers) and gets slower. It's a speed tip, not a sharpness one. Careful: downscaling too much may cost face identity.

### 3 characters in one bedroom, 7 clips (5070 Ti)
- A scene with 3 characters in a continuous three-shot, seen from the door, window behind: 8 images (3 faces + 3 looks + vape + room), 1 or 2 voices per clip. Screen sides, clothes and vape stable across the 7 clips; the third character laughed silently when asked.
- A script with regional slang works if the slang is written as spoken; regional variants matter (an expression from one city sounds wrong in a character from another). Loanwords may need replacing with the word the characters would actually use.
- The grey sweatpants from one character's sheet leaked into the video despite a look with white shorts. Solved with "only the head is used..." on the face + "bare legs" on the look, without naming the sheet's garment.
- Local `test` on the 5070 Ti: 70–92 s per 15 s clip with 8 images + 2 voices; ~181 s on the first generation after hours idle (cold model). Two seeds queued: ~2.5 min.
- v1 (anchor at the end): 99.7 s, ~5 s of still silence per seam; the director called it a "school play". v2 (hard cut at the end of the line, same clips): 69.7 s, a jump of 10–20 at each cut; the director didn't want hard cuts. v3 (anchor right after the line, chain redone from 2 to 7): 71.2 s, jumps of 6–13, approved as the method.
- With "first line starts right at 1.0 seconds with no pause" the first line started at 1.0–1.2 s (one seed at 2.3 s). Without the sentence, 1.0–2.0 s.
- An anchor with vape smoke in the air copied well (repetition ~6–7); one with a wide gesture (a high five ending) gave 8–15 and still a continuous seam.
- A character exiting by walking toward the camera: the screen is filled with their shirt for ~1 s; in one seed they left and reappeared (discarded). To leave the frame, ask for an exit to the side.
- A character's short laugh ("gives a short, awkward laugh") comes out weak or not at all at 288×512.

### 2 characters in a small bedroom (first tests)
- v1: free-form prompt with `<Picture N> = ...` and 8 steps → a collage of the references themselves, one character never appeared, 71 min. v2: official format + 4 steps + ChunkFeedForward → characters, clothes and vape right, 17 min.
- The face crop from the sheet holds identity well at 544×960 and at 288×512, even in a two-shot from the knees up.
- Shot/reverse shot with a close-up on each line (version with cuts): lines on time and in the right mouth, but the seam between clips shows. Single continuous shot: a more fluid scene and an invisible seam, but lines slipped (one fell into the silent beat, another came 2.5 s late) and the risk of a line in the wrong mouth is higher. Cuts are the director's decision.
- Locking each character's screen side in every clip solved the side swap between clips.
- H3 didn't respect "camera next to the TV" in the wide shot: it preferred the view from the door, with the window behind.
- 25-frame anchor: H3 reproduces the first second almost identically (difference ~6, recompression only) and continues from there. Control without an anchor (same prompt and seed): a different room and 1 s of silence at the start.
- A white smudge near the mouth at the end of clip 1 (288×512) passed to clip 2 through the anchor.
- 5-clip chain (64 s): at `test`, ~3.5 min per clip (~18 min total); at `draft`, 17–20 min per clip. Identity stable from 1 to 5 at both presets (at test, one face got a little more angular in clips 4–5, without losing the character). Lines landed more or less on time; a drag on the vape came late (it ended up at the end of clip 3). An action-only clip (going back to playing a game) worked without a reference audio.
- In the continuous shot, the last line of clips 1 and 2 slipped into the final beat at both resolutions. End the lines by ~9–10 s.
- At `draft`, a line at the end of clip 4 slipped to the last second; the anchor carried the rest of the line into clip 5, which had no dialogue and ended up with ~2 s of voice at the start. A line at the end of clip N **becomes a line at the start of N+1**.
- Set elements the prompt doesn't lock can migrate along the chain: at draft, the TV appeared behind the two characters from clip 4 on (it had been out of frame). If an object's position matters, describe it in every clip.
- The draft held identity better than the test (larger, more defined face at 544×960), even with a wider frame.

### Resolution ladder (RTX 5070 Ti)
- Same clip 1 (15 s, 4 lines, 6 images + 2 voices), profile with ChunkFeedForward: 704×1248 in 15.5 min, 768×1344 in 19.4 min, 1088×1920 at 5 s in 12.5 min. None ran out of VRAM or spilled into shared memory (free VRAM at peak 1.2–1.9 GB). RAM had 2–4.5 GB free: it is the machine's bottleneck.
- Quality: faces, clothes and the window view much more defined than at 288×512; at 768×1344 the hillside and water tank outside become readable. Framing changes between resolutions, as already known.
- Lines: at 704×1248 the last line ran to ~12.3 s; at 768×1344 it ended at 10.75 s with a silent ending (the silence reinforcement works at any resolution).
- The same 5070 Ti rented on Vast (125 GB of RAM) made the 5-clip chain at 288×512 in 6.4 min (70–86 s per clip), ~3× faster than the 4060.

### 15 s chain
- A full script in **5 clips of 15 s** (71.5 s), 288×512, continuous shot with anchors: identity, clothes, vape, room and screen sides stable from 1 to 5; none of the 4 seams shows a cut (steps of 2–4 at frames 20–28; an isolated 10–19 when there was smoke in the anchor). ~4 min per clip; whole chain ~35 min with one redo.
- Clip 1 (4 lines): with only "Nobody speaks" at the end, the last line fell at 13.25–15 s on two different seeds (spectrum identical to the lines, no correlation between seeds: it was speech, not an artifact). Moving the lines ~0.5–1 s earlier + "Complete silence…" in the final beat + "All dialogue ends by 11 seconds…" in the soundscape: silent ending from 11.75 s to 14.25 s on the first try. With the reinforcement, clips 2–4 had clean endings on the first try.
- The drag on the vape keeps coming ~2–4 s late (clip 3: smoke still rising in the last second). Solved in the next clip by describing the smoke ending in the first second.
- In a clip with two close actions (one character's line + another's drag), the line may come out together with the action, not after: leave ~1 s free between action and line.
- Clip without dialogue (going back to playing): a short laugh may come out at the start; there was a ~0.25 s hole of digital silence (-85 dB) at 1.3 s, right after the segment the edit cuts.

### High resolution on the 4060
- Native 1088×1920, 1.6 s, 6 images: 13 min, and the video became a collage of the references. A very short clip with many references doesn't work; the practical minimum for ref2va is ~5 s.
- Native 1088×1920, 5 s: over 1 h without finishing step 1 (VRAM full, the card started using system RAM). Cancelled.
- Native 1088×1920, 5 s, on a 96 GB GPU (RTX PRO 6000): under 6 min, and a look well above 544 + SeedVR2 (directional late-afternoon light, skin texture, blurred background; contrast a bit exaggerated). A 13 s clip at 1088×1920 took over ~10 min on that card. Path to test for the final: a rented GPU (`vastai` skill).
- Native 768×1344, 5 s: 13.5 min (~2.7 min per step), but the director rejected the result.
- SeedVR2 7B upscale, same 3 s segment of clip 1: from `draft` (2×), a clean, natural image, sharp glasses, defined curls, beard and mole preserved; from `test` (3.75×), a painted-looking face, bent glasses frame and a blurred face. Upscaling doesn't recover what 288×512 doesn't have. (Later the director came to prefer RTX VSR, for more natural skin.)
- `lab` color correction in video SeedVR2 kept the original's colors.

## Ideas to test

- 1-frame anchor with RTX VSR over a whole chain (only the frame workflow was validated) and at `test` 288×512.
- 1-frame anchor + a second guide with a sharp frame from clip 1 (e.g. at frame_idx 24) to hold identity.
- RTX VSR from `draft` 768×1344: time for a 15 s clip, blocks of 120 frames with an overlap of 8 and the join between blocks; also test from `test` and on the 4060.
- Downscale reference images to ~768 px on the longer side: measure time and face identity.
- Saved video compression: some workflows save with `VHS_VideoCombine` (h264, crf 19) while this skill uses the automatic `SaveVideo` (~3 Mbps for a 5 s clip at 640×1152). Untested hypothesis for perceived sharpness differences.
- A chain of 8+ clips of 15 s (~2 min) to see where identity starts to give way.
- Shorter clips (12–13 s) at `draft`: with the anchor right after the line, clip length doesn't change the film, only render time (~30 min less over a 7-clip chain). Risk: less margin for late lines.
- A shorter anchor (9 or 17 frames) to shorten the ~1 s breath between lines.
- 5070 Ti: measure the next step of the ladder (1088×1920 at 10 s, ~2× the largest that passed; risk of running out). Measure again with 64 GB of RAM.
- Final at native 1088×1920 on a rented 80–96 GB GPU (`vastai` skill): measure time and peak VRAM for a 15 s clip and run the whole chain on the instance.
- Stable framing between `test` and `draft` (more precise camera description).
- SeedVR2 with larger blocks (97 or 121 frames) and SeedVR2 3B, if the director wants that texture again (`merge` was already checked with lanczos-upscaled blocks: 328/328 frames, no misalignment).
- **Lock the test's dialogue**: pass the approved test's audio to the draft as `<Audio N>` with `fully_copy`, keeping the voices as `reference` (respecting the 15 s total).
- MiniMax H3 Director: lay each clip on the timeline and use Retake + Retake Stitch to fix a line or seam without regenerating the clip.
- `ref_image_size: max` didn't change sharpness in the A/B; SLA attention on the production profile is still open.

## Script `video_h3.py`

```python
#!/usr/bin/env python3
"""MiniMax H3 video (ref2va): references, workflows (ComfyUI API format), anchors, review, assembly and upscale (RTX VSR default; SeedVR2 alternative).
Usage (always from the project folder):
  python video_h3.py init      <folder> <9:16|16:9> [profile] [prefix]
  python video_h3.py face      <sheet_9x16.png> <out.png>
  python video_h3.py pauses    <audio>
  python video_h3.py voice     <audio> <out.wav> <start_s> <end_s>
  python video_h3.py workflow  <folder> <clip.json> <preset> <seed> [seed ...]   (preset of the profile in config.json)
  python video_h3.py look      <costume_sheet.png> <out.png>                   (complete-look panel, top left)
  python video_h3.py speech    <video.mp4> [...]                                (segments with speech/sound above -32 dB)
  python video_h3.py anchor_at <video.mp4> <out.mp4> <t0>                       (25-frame anchor from t0; the default is the 1-frame one, a1.py)
  python video_h3.py seam_at   <previous_video.mp4> <t0> <new_video.mp4>        (checks the anchor_at seam)
  python video_h3.py assemble  <out.mp4> <video>:<start>:<end> [...]            (assembles the film; measures the jump at each join)
  python video_h3.py arrived   <prefix8> <name> <workflow.json> <sec> [anchor]  (organizes what the output fetch brought)
  python video_h3.py anchor    <previous_video.mp4> <out.mp4>                   (old method: last 25 frames)
  python video_h3.py seam      <previous_video.mp4> <new_video.mp4>
  python video_h3.py review    <video.mp4> <out.jpg>
  python video_h3.py concat    <out.mp4> [--anchor] <video> [video ...]
  python video_h3.py time      <folder> <workflow.json> <execution_seconds>
  python video_h3.py upscale   <folder> <video.mp4> [rtx|seedvr2] [multiplier]
                                                                        (cuts into blocks and writes the workflows; default rtx = fixed
                                                                         1080x1920; seedvr2 without a multiplier takes the longer side to 1920)
  python video_h3.py merge     <blocks_manifest.json> <out.mp4>         (joins the upscaled blocks with blending + original audio)
"""
import csv, json, os, subprocess, sys

# =====================================================================
# Hardware profiles: everything that changes when moving machines lives here.
# =====================================================================
PROFILES = {
    # RTX 5070 Ti 16 GB + 32 GB RAM. Ladder tested:
    # 704x1248 15 s = 15.5 min; 768x1344 15 s = 19.4 min; 1088x1920 5 s = 12.5 min; none ran out of VRAM.
    # The bottleneck is RAM (2-4.5 GB free at peak): model and text encoder don't fit entirely in 16 GB.
    "local_16gb": {
        "unet": "minimax_h3_fused_refdelta_r1024_turbo8_mystic07_int8_convrot.safetensors",
        "clip": "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors",
        "vae_video": "minimax_h3_video_vae_fp16.safetensors",
        "vae_audio": "minimax_h3_audio_vae_fp32.safetensors",
        "chunk_ff": [4, 4096],      # kept: the ladder was measured with it
        "steps": 4,
        "scheduler": "simple",
        "sampler": "res_multistep",
        "upscale_block": 73,        # SeedVR2 only (alternative): 73 frames is the safe value; a whole clip at once froze the RAM
        "presets": {
            "test":  (288, 512),     # live storyboard, 15 s: 70-92 s locally
            "draft": (768, 1344),    # the real take, 15 s: 19.4 min (tested ceiling for 15 s)
            "final": (768, 1344),
            "hd":    (1088, 1920),   # native Full HD, up to 5 s ONLY: 12.5 min
        },
        "max_sec": {"hd": 5},       # longer clips are refused on this preset
    },
    # RTX 4060 8 GB + 32 GB RAM.
    "local_8gb": {
        "unet": "minimax_h3_fused_refdelta_r1024_turbo8_mystic07_int8_convrot.safetensors",
        "clip": "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors",
        "vae_video": "minimax_h3_video_vae_fp16.safetensors",
        "vae_audio": "minimax_h3_audio_vae_fp32.safetensors",
        "chunk_ff": [4, 4096],      # MiniMaxChunkFeedForward (KJNodes): 2.3x faster on the 4060
        "steps": 4,                 # fused turbo checkpoint: 4 steps (8 doubles the time with no gain)
        "scheduler": "simple",
        "sampler": "res_multistep",
        "upscale_block": 73,        # SeedVR2 7B at 1088x1920: 73 frames (3 s) fit; ~10-11 min per block
    },
    # Card with more VRAM. Adjust the file names to what is installed there.
    "production": {
        "unet": "minimax_h3_fused_refdelta_r1024_turbo8_mystic07_int8_convrot.safetensors",
        "clip": "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors",
        "vae_video": "minimax_h3_video_vae_int8_convrot.safetensors",
        "vae_audio": "minimax_h3_audio_vae_fp32.safetensors",
        "chunk_ff": None,
        "steps": 4,
        "scheduler": "simple",
        "sampler": "res_multistep",
        "upscale_block": 145,       # a guess (SeedVR2): measure on the production machine (or the whole clip at once)
    },
}

# DEFAULT final upscale: RTX Video Super Resolution (DenoRTXVFXEasyUpscale node, VSR Ultra mode).
# Validated: 640x1152 -> 1080x1920, 124 frames in a single workflow, in under 30 s.
# Needs the nvvfx runtime in ComfyUI's Python (without it: "No module named 'nvvfx'").
# The node loads the block's frames as float32 into RAM (124 frames 1080x1920 ~ 3 GB): hence blocks of 120.
RTX = {"mode": "VSR Ultra", "block": 120, "fullhd": (1080, 1920)}

# ALTERNATIVE upscale (SeedVR2 7B Int8, native ComfyUI nodes). Same on both profiles.
# Over-sharpens freckles and pores (retouched-looking skin): the director preferred RTX VSR.
SEEDVR2 = {"unet": "seedvr2_7b_int8_convrot.safetensors", "vae": "seedvr2_ema_vae_fp16.safetensors",
           "color": "lab", "seed": 42}
UPSCALE_TARGET = 1920   # longer side after the SeedVR2 upscale. 544x960 -> 2x; 768x1344 -> ~1.43x.
                        # From 288x512 (3.75x) the face looks painted: don't use.
UPSCALE_OVERLAP = 8     # frames repeated between neighboring blocks, blended at the join

# Resolution presets (width, height) for 9:16; 16:9 swaps them. Multiples of 32.
PRESETS = {
    "test":   (288, 512),    # ~0.15 MP: check content, lines, timing and seams; ~4 min per 15 s clip on the 4060
    "draft":  (544, 960),    # ~0.52 MP: approved take; ~20 min per 15 s clip on the 4060; base for the 2x upscale
    "final":  (768, 1344),   # ~1 MP: production machine only (on the 4060: 13.5 min for 5 s and a poor result)
}

FPS = 24
ANCHOR_FRAMES = 25      # last ~1 s of the previous clip (image + audio) anchored at frame 0 of the next one
ANCHOR_CUT = 24         # frames at the start of the next clip that repeat the anchor; removed in the edit


def frames(sec):
    """Valid frame count for H3 (17k+5), as in the official template."""
    x = max(5, round(sec * FPS))
    return x + (5 - (x % 17)) % 17


def size(preset, fmt, profile=None):
    """Preset resolution; a profile may have its own presets (e.g. local_16gb uses 768x1344 as draft)."""
    w, h = PROFILES.get(profile, {}).get("presets", PRESETS)[preset]
    return (w, h) if fmt == "9:16" else (h, w)


# =====================================================================
# ref2va workflow (API format)
# =====================================================================
def wf_ref2va(profile, prompt, images, audios, w, h, sec, seed, prefix, anchor=None):
    p = PROFILES[profile]
    wf = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": p["unet"], "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": p["clip"], "type": "minimax", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": p["vae_video"]}},
        "4": {"class_type": "VAELoader", "inputs": {"vae_name": p["vae_audio"]}},
    }
    model = ["1", 0]
    if p["chunk_ff"]:
        wf["5"] = {"class_type": "MiniMaxChunkFeedForward",
                   "inputs": {"model": model, "chunks": p["chunk_ff"][0], "seq_threshold": p["chunk_ff"][1]}}
        model = ["5", 0]
    ref = {"clip": ["2", 0], "vae": ["3", 0], "audio_vae": ["4", 0], "prompt": prompt,
           "width": w, "height": h, "length": frames(sec), "ref_image_size": "match"}
    for i, img in enumerate(images):           # order = <Picture 1>, <Picture 2>...
        n = str(10 + i)
        wf[n] = {"class_type": "LoadImage", "inputs": {"image": img}}
        ref[f"ref_images.ref_image_{i}"] = [n, 0]
    for j, a in enumerate(audios):             # order = <Audio 1>, <Audio 2>...
        n = str(30 + j)
        wf[n] = {"class_type": "LoadAudio", "inputs": {"audio": a}}
        ref[f"ref_audios.ref_audio_{j}"] = [n, 0]
    cond = ["40", 0]
    if anchor:                                 # segment of the previous clip (file in ComfyUI's input)
        wf["20"] = {"class_type": "LoadVideo", "inputs": {"file": anchor}}
        wf["21"] = {"class_type": "GetVideoComponents", "inputs": {"video": ["20", 0]}}
        wf["50"] = {"class_type": "MiniMaxH3AddGuide", "inputs": {"positive": ["40", 0], "latent": ["40", 1], "frame_idx": 0,
                                                                  "vae": ["3", 0], "audio_vae": ["4", 0],
                                                                  "image": ["21", 0], "audio": ["21", 1]}}
        cond = ["50", 0]
    wf.update({
        "40": {"class_type": "MiniMaxH3ReferenceToVideo", "inputs": ref},
        "41": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "42": {"class_type": "BasicGuider", "inputs": {"model": model, "conditioning": cond}},
        "43": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": p["sampler"]}},
        "44": {"class_type": "BasicScheduler", "inputs": {"model": model, "scheduler": p["scheduler"], "steps": p["steps"], "denoise": 1.0}},
        "45": {"class_type": "SamplerCustomAdvanced", "inputs": {"noise": ["41", 0], "guider": ["42", 0], "sampler": ["43", 0],
                                                                 "sigmas": ["44", 0], "latent_image": ["40", 1]}},
        "46": {"class_type": "VAEDecode", "inputs": {"samples": ["45", 0], "vae": ["3", 0]}},
        "47": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["45", 0], "vae": ["4", 0]}},
        "48": {"class_type": "CreateVideo", "inputs": {"images": ["46", 0], "audio": ["47", 0], "fps": FPS}},
        "49": {"class_type": "SaveVideo", "inputs": {"video": ["48", 0], "filename_prefix": prefix,
                                                     "format": "auto", "format.codec": "auto"}},
    })
    return wf


# =====================================================================
# References
# =====================================================================
def face(sheet, out):
    """Crops the large face panel (top-left corner) from the 9:16 character sheet."""
    from PIL import Image
    import numpy as np
    im = Image.open(sheet).convert("RGB")
    a = np.array(im).astype(int)
    white = a.min(axis=2) > 245
    W, H = im.size

    def edge(mask, start):
        i = start
        while i < len(mask) and not mask[i]:
            i += 1
        return i
    m = 16
    col = white[m + 100:int(H * 0.3), :].mean(axis=0) > 0.97     # white vertical gutter
    row = white[:, m + 100:int(W * 0.5)].mean(axis=1) > 0.97     # white horizontal gutter
    x1 = edge(col, m + 200)
    y1 = edge(row, m + 200)
    box = (m, m, x1, y1)
    im.crop(box).save(out)
    print(out, box)


def look(sheet, out):
    """Crops the top-left panel (complete front look) from the 3x2 costume sheet."""
    from PIL import Image
    im = Image.open(sheet).convert("RGB"); W, H = im.size
    box = (int(W * 0.01), int(H * 0.012), int(W * 0.328), int(H * 0.584))
    im.crop(box).save(out)
    print(out, box)


def pauses(audio):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", audio, "-af", "silencedetect=noise=-30dB:d=0.15", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", audio],
                         capture_output=True, text=True).stdout.strip()
    print("duration", dur)
    for ln in r.splitlines():
        if "silence_" in ln:
            print(ln.split("]")[-1].strip())


def voice(audio, out, start, end):
    start, end = float(start), float(end); d = end - start
    af = f"afade=t=in:d=0.05,afade=t=out:st={max(0, d - 0.2):.2f}:d=0.2"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", str(start), "-to", str(end), "-i", audio,
                    "-af", af, "-ar", "48000", "-ac", "1", out], check=True)
    print(out, f"{d:.2f}s")


# =====================================================================
# Anchor between clips
# =====================================================================
def n_frames(video):
    return int(subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries",
                               "stream=nb_read_frames", "-of", "csv=p=0", video], capture_output=True, text=True).stdout.strip())


def speech(videos):
    """Segments with sound above -32 dB (0.1 s windows; merges gaps shorter than 0.4 s)."""
    import numpy as np
    for v in videos:
        raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", v, "-vn", "-ac", "1", "-ar", "16000", "-f", "s16le", "-"],
                             capture_output=True).stdout
        a = np.frombuffer(raw, np.int16).astype(float) / 32768; w = 1600
        db = [20 * np.log10(np.sqrt(np.mean(a[i * w:(i + 1) * w] ** 2)) + 1e-9) for i in range(len(a) // w)]
        on = [d > -32 for d in db]; segs = []; i = 0
        while i < len(on):
            if on[i]:
                j = i
                while j < len(on) and (on[j] or any(on[j:j + 4])):
                    j += 1
                segs.append((round(i * 0.1, 1), round(j * 0.1, 1))); i = j
            else:
                i += 1
        print(os.path.basename(v), segs)


def anchor_at(video, out, t0):
    """ANCHOR_FRAMES-frame anchor from t0 (s): the second right after the last line/action (alternative to a1.py's 1-frame anchor)."""
    n0 = round(float(t0) * FPS)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", video,
                    "-vf", f"select='between(n\\,{n0}\\,{n0 + ANCHOR_FRAMES - 1})',setpts=PTS-STARTPTS",
                    "-af", f"atrim=start={n0 / FPS}:end={(n0 + ANCHOR_FRAMES) / FPS},asetpts=PTS-STARTPTS",
                    "-c:v", "libx264", "-crf", "10", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k", out], check=True)
    print(out, f"frames {n0}-{n0 + ANCHOR_FRAMES - 1} ({n0 / FPS:.2f}-{(n0 + ANCHOR_FRAMES) / FPS:.2f} s)")


def anchor(video, out):
    """Old method: extracts the last ANCHOR_FRAMES frames + audio for the next clip's AddGuide."""
    n = n_frames(video); start = n - ANCHOR_FRAMES
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", video,
                    "-vf", f"select='gte(n\\,{start})',setpts=PTS-STARTPTS", "-af", f"atrim=start={start / FPS},asetpts=PTS-STARTPTS",
                    "-c:v", "libx264", "-crf", "10", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k", out], check=True)
    print(out, f"frames {start}-{n - 1} of {n}")


def _frames(video, n0, n1):
    import numpy as np
    w, h = map(int, subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                                    "-of", "csv=p=0", video], capture_output=True, text=True).stdout.strip().split(","))
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", video, "-vf", f"select='between(n\\,{n0}\\,{n1})'", "-vsync", "0",
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, h, w, 3).astype(float)


def seam_at(previous, t0, new):
    """Anchor repetition (expected ~6-8) and steps right after it (1-5 = continuous; ~70 = cut)."""
    import numpy as np
    n0 = round(float(t0) * FPS)
    a = _frames(previous, n0, n0 + ANCHOR_FRAMES - 1); b = _frames(new, 0, ANCHOR_FRAMES + 6)
    print("repetition:", [round(float(np.abs(b[i] - a[i]).mean()), 1) for i in range(0, ANCHOR_CUT, 4)],
          "| steps 20..28:", [round(float(np.abs(b[i + 1] - b[i]).mean()), 1) for i in range(ANCHOR_CUT - 4, ANCHOR_CUT + 4)])


def seam(previous, new):
    """Old method: the start of the new clip should repeat the end of the previous one (difference ~6-8)
    and the passage at frame ANCHOR_CUT should not jump (compare with the average inside the previous clip)."""
    import numpy as np
    n = n_frames(previous)
    a = _frames(previous, n - ANCHOR_FRAMES, n - 1)
    b = _frames(new, 0, ANCHOR_FRAMES + 6)
    rep = [round(float(np.abs(b[i] - a[i]).mean()), 1) for i in range(0, ANCHOR_CUT, 4)]
    base = round(float(np.mean([np.abs(a[i + 1] - a[i]).mean() for i in range(len(a) - 1)])), 1)
    steps = [round(float(np.abs(b[i + 1] - b[i]).mean()), 1) for i in range(ANCHOR_CUT - 4, ANCHOR_CUT + 4)]
    print("anchor repetition (frames 0..23):", rep)
    print("average motion at the end of the previous clip:", base)
    print(f"steps in the new clip, frames {ANCHOR_CUT - 4}..{ANCHOR_CUT + 4}:", steps,
          "(an isolated value above ~50 = cut; 5-15 = motion)")


# =====================================================================
# Review and assembly
# =====================================================================
def review(video, out):
    """Contact sheet (1.5 frames/s) + audio volume every 0.25 s (speech = above ~-30 dB)."""
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", video,
                    "-vf", "fps=1.5,scale=272:-1,tile=7x3", "-frames:v", "1", out], check=True)
    import numpy as np
    raw = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", video, "-vn", "-ac", "1", "-ar", "16000",
                          "-f", "s16le", "-"], capture_output=True).stdout
    a = np.frombuffer(raw, dtype=np.int16).astype(float) / 32768
    win = 4000
    rows = []
    for i in range(len(a) // win):
        db = 20 * np.log10(np.sqrt(np.mean(a[i * win:(i + 1) * win] ** 2)) + 1e-9)
        rows.append(f"{i * 0.25:5.2f}s {db:4.0f}dB {'#' * max(0, int((db + 50) / 3))}")
    print(out)
    print("\n".join(rows))


def assemble(out, parts):
    """Joins video:start:end (s) segments with a 25 ms audio micro-fade and measures the image jump at each join.
    1-frame anchor (a1.py, default): clip N up to (frame+1)/24; clip N+1 from 1/24 (= 0.0417).
    25-frame anchor (anchor_at): clip N up to t0_N + 25/24; clip N+1 from 25/24 (= 1.0417)."""
    import numpy as np
    parts = [p.rsplit(":", 2) for p in parts]
    ins, fc = [], ""
    for i, (v, a, b) in enumerate(parts):
        a, b = float(a), float(b); d = b - a
        ins += ["-i", v]
        fc += (f"[{i}:v]trim=start={a}:end={b},setpts=PTS-STARTPTS[v{i}];"
               f"[{i}:a]atrim=start={a}:end={b},asetpts=PTS-STARTPTS,afade=t=in:d=0.025,afade=t=out:st={d - 0.025:.3f}:d=0.025[a{i}];")
    fc += "".join(f"[v{i}][a{i}]" for i in range(len(parts))) + f"concat=n={len(parts)}:v=1:a=1[v][a]"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *ins, "-filter_complex", fc, "-map", "[v]", "-map", "[a]",
                    "-c:v", "libx264", "-crf", "18", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out], check=True)

    def frame(v, t):
        w, h = _wh(v)
        raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-ss", str(t), "-i", v, "-frames:v", "1", "-f", "rawvideo",
                              "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
        return np.frombuffer(raw, np.uint8)[:w * h * 3].astype(float)
    tot = 0
    for i, (v, a, b) in enumerate(parts):
        tot += float(b) - float(a)
        if i + 1 < len(parts):
            v2, a2, _ = parts[i + 1]
            print(f"join {i + 1}->{i + 2} at {tot:5.1f}s: jump {np.abs(frame(v, float(b) - 1 / FPS) - frame(v2, float(a2))).mean():.1f}")
    print(out, f"{tot:.1f}s")


def concat(out, videos, with_anchor=False):
    """Old method: joins the clips. With --anchor, removes from each clip (except the first) the frames that repeat the anchor."""
    n = len(videos)
    ins = sum([["-i", v] for v in videos], [])
    fc = ""
    for i in range(n):
        if with_anchor and i > 0:
            fc += (f"[{i}:v]trim=start_frame={ANCHOR_CUT},setpts=PTS-STARTPTS[v{i}];"
                   f"[{i}:a]atrim=start={ANCHOR_CUT / FPS},asetpts=PTS-STARTPTS[a{i}];")
        else:
            fc += f"[{i}:v]null[v{i}];[{i}:a]anull[a{i}];"
    fc += "".join(f"[v{i}][a{i}]" for i in range(n)) + f"concat=n={n}:v=1:a=1[v][a]"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *ins, "-filter_complex", fc,
                    "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-crf", "18", "-c:a", "aac", "-b:a", "192k",
                    "-movflags", "+faststart", out], check=True)
    print(out)


def arrived(folder, pre, name, wf, sec, anc=None):
    """Organizes what the output fetch brought (<prefix8>_000/_001.mp4): the larger video goes to videos/<name>.mp4,
    the anchor copy to videos/_echo/ (with an md5 check); logs the time, makes the contact sheet and lists the lines."""
    import glob, hashlib
    fs = sorted(glob.glob(os.path.join(folder, "videos", f"{pre}_*.mp4")), key=os.path.getsize)
    md5 = lambda p: hashlib.md5(open(p, "rb").read()).hexdigest()
    os.makedirs(os.path.join(folder, "videos", "_echo"), exist_ok=True)
    for f in fs[:-1]:
        if anc:
            print("anchor md5 ok" if md5(f) == md5(anc) else "ANCHOR DIFFERS!", f)
        subprocess.run(["mv", "-n", f, os.path.join(folder, "videos", "_echo", os.path.basename(f))])
    dst = os.path.join(folder, "videos", f"{name}.mp4")
    subprocess.run(["mv", "-n", fs[-1], dst])
    time_log(folder, wf, sec)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", dst,
                    "-vf", "fps=1.5,scale=272:-1,tile=7x3", "-frames:v", "1", os.path.join(folder, "videos", f"{name}_contact.jpg")], check=True)
    speech([dst])


# =====================================================================
# Final upscale (RTX VSR default; SeedVR2 alternative), in overlapping blocks
# =====================================================================
def wf_rtx(video, prefix, w_out, h_out, nframes):
    """RTX Video Super Resolution (VSR Ultra) through DenoRTXVFXEasyUpscale. Validated configuration."""
    vert = h_out >= w_out
    return {
        "1": {"class_type": "LoadVideo", "inputs": {"file": video}},
        "2": {"class_type": "GetVideoComponents", "inputs": {"video": ["1", 0]}},
        "3": {"class_type": "DenoRTXVFXEasyUpscale", "inputs": {
            "images": ["2", 0], "mode": RTX["mode"], "resize_type": "Manual", "scale": 2.0, "megapixels": 2.0,
            "width": w_out, "height": h_out, "divisible_by": "1", "device": 0,
            "ratio_preset": "9:16" if vert else "16:9", "resize_method": "Center Crop (Fill)"}},
        "12": {"class_type": "CreateVideo", "inputs": {"images": ["3", 0], "audio": ["2", 1], "fps": FPS}},
        "13": {"class_type": "SaveVideo", "inputs": {"video": ["12", 0], "filename_prefix": prefix,
               "format": "auto", "format.codec": "auto"},
               "_meta": {"title": f"rtxvsr {w_out}x{h_out} {nframes}"}},   # read by the time mode
    }


def wf_seedvr2(video, mult, prefix, w_out, h_out, nframes):
    t = {"tile_size": 512, "overlap": 128, "temporal_size": 32, "temporal_overlap": 8}
    return {
        "1": {"class_type": "LoadVideo", "inputs": {"file": video}},
        "2": {"class_type": "GetVideoComponents", "inputs": {"video": ["1", 0]}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": SEEDVR2["vae"]}},
        "4": {"class_type": "UNETLoader", "inputs": {"unet_name": SEEDVR2["unet"], "weight_dtype": "default"}},
        "5": {"class_type": "ResizeImageMaskNode", "inputs": {"input": ["2", 0], "resize_type": "scale by multiplier",
              "resize_type.multiplier": mult, "scale_method": "lanczos"}},
        "6": {"class_type": "SeedVR2Preprocess", "inputs": {"resized_images": ["5", 0]}},
        "7": {"class_type": "VAEEncodeTiled", "inputs": {"pixels": ["6", 0], "vae": ["3", 0], **t}},
        "8": {"class_type": "SeedVR2Conditioning", "inputs": {"model": ["4", 0], "vae_conditioning": ["7", 0]}},
        "9": {"class_type": "KSampler", "inputs": {"seed": SEEDVR2["seed"], "steps": 1, "cfg": 1, "sampler_name": "euler",
              "scheduler": "simple", "denoise": 1, "model": ["4", 0], "positive": ["8", 0], "negative": ["8", 1],
              "latent_image": ["7", 0]}},
        "10": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["9", 0], "vae": ["3", 0], **t}},
        "11": {"class_type": "SeedVR2PostProcessing", "inputs": {"images": ["10", 0], "original_resized_images": ["5", 0],
               "color_correction_method": SEEDVR2["color"]}},
        "12": {"class_type": "CreateVideo", "inputs": {"images": ["11", 0], "audio": ["2", 1], "fps": FPS}},
        "13": {"class_type": "SaveVideo", "inputs": {"video": ["12", 0], "filename_prefix": prefix,
               "format": "auto", "format.codec": "auto"},
               "_meta": {"title": f"seedvr2 {w_out}x{h_out} {nframes}"}},   # read by the time mode
    }


def _wh(video):
    return tuple(map(int, subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                                          "stream=width,height", "-of", "csv=p=0", video],
                                         capture_output=True, text=True).stdout.strip().split(",")))


def upscale(folder, video, engine="rtx", mult=None):
    """Cuts the video into blocks (rtx: RTX['block'] frames; seedvr2: PROFILES[profile]['upscale_block']) with UPSCALE_OVERLAP
    overlap, writes the blocks to upscale/ and one workflow per block to workflows/. Writes the manifest for merge.
    rtx (default): fixed 1080x1920 output (1920x1080 for 16:9). seedvr2: without a multiplier, takes the longer side to UPSCALE_TARGET."""
    c = cfg(folder)
    block = RTX["block"] if engine == "rtx" else PROFILES[c["profile"]]["upscale_block"]
    name = os.path.splitext(os.path.basename(video))[0]
    n = n_frames(video); w, h = _wh(video)
    if engine == "rtx":
        fw, fh = RTX["fullhd"]
        w_out, h_out = (fw, fh) if h >= w else (fh, fw)
        mult = w_out / w                                                   # informative only
    else:
        mult = mult or UPSCALE_TARGET / max(w, h)
        w_out, h_out = 2 * round(w * mult / 2), 2 * round(h * mult / 2)    # even numbers (H.264 requirement)
    if n <= block:
        starts = [0]
    else:
        starts = list(range(0, n - block, block - UPSCALE_OVERLAP)) + [n - block]
    os.makedirs(os.path.join(folder, "upscale"), exist_ok=True); os.makedirs(os.path.join(folder, "workflows"), exist_ok=True)
    blocks = []
    for i, start in enumerate(starts):
        q = min(block, n - start); end = start + q - 1
        fname = f"{name}_b{i}.mp4"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", video,
                        "-vf", f"select='between(n\\,{start}\\,{end})',setpts=PTS-STARTPTS",
                        "-af", f"atrim=start={start / FPS}:end={(end + 1) / FPS},asetpts=PTS-STARTPTS",
                        "-c:v", "libx264", "-crf", "10", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
                        os.path.join(folder, "upscale", fname)], check=True)
        wfp = os.path.join(folder, "workflows", f"up_{name}_b{i}.json")
        prefix = f"{c.get('output', 'video_h3')}/up_{name}_b{i}"
        wf = (wf_rtx(fname, prefix, w_out, h_out, q) if engine == "rtx"
              else wf_seedvr2(fname, mult, prefix, w_out, h_out, q))
        json.dump(wf, open(wfp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        blocks.append({"start": start, "end": end, "input": f"upscale/{fname}", "workflow": wfp,
                       "upscaled": f"upscale/{name}_b{i}_up.mp4"})
        print(f"block {i}: frames {start}-{end} -> upscale/{fname}  {wfp}")
    man = {"original": os.path.abspath(video), "engine": engine, "frames": n, "out_wh": [w_out, h_out], "blocks": blocks}
    mp = os.path.join(folder, "upscale", f"{name}_blocks.json")
    json.dump(man, open(mp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(mp, f"{engine}: {w}x{h} -> {w_out}x{h_out}", len(blocks), "blocks")


def merge(manifest, out):
    """Joins the upscaled blocks in order; on the frames repeated between two blocks, a linear blend from the previous
    one to the next. The audio comes from the original video (the upscale doesn't touch the sound)."""
    import numpy as np
    m = json.load(open(manifest, encoding="utf-8")); base = os.path.dirname(os.path.dirname(os.path.abspath(manifest)))
    W, H = m["out_wh"]; fsize = W * H * 3; bl = m["blocks"]
    enc = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                            "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-i", m["original"], "-map", "0:v", "-map", "1:a?",
                            "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
                            "-movflags", "+faststart", out], stdin=subprocess.PIPE)
    kept = {}; written = 0
    for i, b in enumerate(bl):
        nxt = bl[i + 1]["start"] if i + 1 < len(bl) else None
        ov0, ov1 = (b["start"], bl[i - 1]["end"]) if i > 0 else (None, None)
        dec = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", os.path.join(base, b["upscaled"]),
                                "-vf", f"scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
        k = 0
        while True:
            buf = dec.stdout.read(fsize)
            if len(buf) < fsize:
                break
            nq = b["start"] + k; k += 1
            if nq > b["end"]:
                break
            f = np.frombuffer(buf, np.uint8).reshape(H, W, 3)
            if nq in kept:
                t = (nq - ov0 + 1) / (ov1 - ov0 + 2)
                f = (kept.pop(nq).astype(np.float32) * (1 - t) + f.astype(np.float32) * t).round().astype(np.uint8)
            if nxt is not None and nq >= nxt:
                kept[nq] = f.copy(); continue   # uint8: float32 blows up the RAM when the overlap is large
            enc.stdin.write(f.tobytes()); written += 1
        dec.stdout.close(); dec.wait()
        if k - 1 < b["end"] - b["start"]:
            print(f"WARNING: block {i} has {k} frames, expected {b['end'] - b['start'] + 1}")
    enc.stdin.close(); enc.wait()
    print(out, f"{written} frames of {m['frames']}", f"{W}x{H}")


def time_log(folder, wfpath, seconds):
    """Logs the execution time in timings.csv (basis for sizing production)."""
    wf = json.load(open(wfpath, encoding="utf-8"))
    if "40" not in wf:      # upscale (RTX VSR or SeedVR2)
        tag, wh, q = wf["13"]["_meta"]["title"].split()
        lw, lh = wh.split("x")
        row = {"workflow": os.path.basename(wfpath), "profile": "rtx_vsr_ultra" if tag == "rtxvsr" else "seedvr2_7b_int8",
               "width": lw, "height": lh, "frames": q, "steps": 1, "images": 0, "audios": 1, "chunk_ff": False,
               "anchor": False, "seconds": seconds}
        return _write_time(folder, row)
    r = wf["40"]["inputs"]
    row = {"workflow": os.path.basename(wfpath), "profile": cfg(folder)["profile"], "width": r["width"], "height": r["height"],
           "frames": r["length"], "steps": wf["44"]["inputs"]["steps"],
           "images": sum(k.startswith("ref_images") for k in r), "audios": sum(k.startswith("ref_audios") for k in r),
           "chunk_ff": "5" in wf, "anchor": "50" in wf, "seconds": seconds}
    _write_time(folder, row)


def _write_time(folder, row):
    out = os.path.join(folder, "timings.csv"); new = not os.path.exists(out)
    with open(out, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(row))
        if new:
            w.writeheader()
        w.writerow(row)
    print(out, row)


# =====================================================================
def cfg(folder):
    return json.load(open(os.path.join(folder, "config.json"), encoding="utf-8"))


if __name__ == "__main__":
    a = sys.argv; mode = a[1]
    if mode == "init":
        os.makedirs(a[2], exist_ok=True)
        c = {"format": a[3], "profile": a[4] if len(a) > 4 else "local_16gb", "prefix": a[5] if len(a) > 5 else "h3"}
        json.dump(c, open(os.path.join(a[2], "config.json"), "w", encoding="utf-8"))
        print(c)
    elif mode == "face":
        face(a[2], a[3])
    elif mode == "look":
        look(a[2], a[3])
    elif mode == "pauses":
        pauses(a[2])
    elif mode == "voice":
        voice(a[2], a[3], a[4], a[5])
    elif mode == "workflow":
        folder, clip, preset = a[2], json.load(open(a[3], encoding="utf-8")), a[4]
        c = cfg(folder); w, h = size(preset, c["format"], c["profile"])
        lim = PROFILES[c["profile"]].get("max_sec", {}).get(preset)
        if lim and clip["seconds"] > lim:
            sys.exit(f"preset {preset} on profile {c['profile']} only accepts up to {lim} s (clip has {clip['seconds']} s)")
        prompt = open(os.path.join(folder, clip["prompt"]), encoding="utf-8").read().strip()
        for s in map(int, a[5:]):
            wf = wf_ref2va(c["profile"], prompt, clip["images"], clip["audios"], w, h, clip["seconds"], s,
                           f"{clip.get('output', 'video_h3')}/{clip['id']}_{preset}_s{s}", clip.get("anchor"))
            out = os.path.join(folder, "workflows", f"{clip['id']}_{preset}_s{s}.json")
            os.makedirs(os.path.dirname(out), exist_ok=True)
            json.dump(wf, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            print(out, f"{w}x{h}", frames(clip["seconds"]), "frames")
    elif mode == "arrived":
        arrived(".", a[2], a[3], a[4], a[5], a[6] if len(a) > 6 else None)
    elif mode == "review":
        review(a[2], a[3])
    elif mode == "speech":
        speech(a[2:])
    elif mode == "anchor_at":
        anchor_at(a[2], a[3], a[4])
    elif mode == "seam_at":
        seam_at(a[2], a[3], a[4])
    elif mode == "assemble":
        assemble(a[2], a[3:])
    elif mode == "anchor":
        anchor(a[2], a[3])
    elif mode == "seam":
        seam(a[2], a[3])
    elif mode == "concat":
        w_anchor = "--anchor" in a[3:]
        concat(a[2], [v for v in a[3:] if v != "--anchor"], w_anchor)
    elif mode == "time":
        time_log(a[2], a[3], a[4])
    elif mode == "upscale":
        extra = list(a[4:])
        engine = extra.pop(0) if extra and extra[0] in ("rtx", "seedvr2") else "rtx"
        upscale(a[2], a[3], engine, float(extra[0]) if extra else None)
    elif mode == "merge":
        merge(a[2], a[3])
```

## Script `a1.py` (1-frame anchor)

Save it in the project folder, next to `video_h3.py` (it imports `video_h3.py` and reads `config.json`). The upscale workflows go to `workflows/a1_<method>_<name>.json` and ComfyUI's output to the `a1/` subfolder. File names use the `prefix` from `config.json`.

```python
#!/usr/bin/env python3
"""1-frame anchor (default method): the chosen frame of clip N goes through RTX VSR (or SeedVR2),
is scaled back to the clip size, has its color matched to clip 1 and goes into frame 0 of clip N+1 together with 1 s of audio.
Run from the project folder (uses video_h3.py and config.json).
  python3 a1.py still   <video> <t_a> <t_b>                    motion per frame between t_a and t_b (choose a still frame)
  python3 a1.py cuts    <video>                                frames with a jump > 30 (cuts H3 invented)
  python3 a1.py ref     <clip1.mp4> [t]                        writes the color reference (clip 1 frame at t s, default 2.0)
  python3 a1.py prepare <video> <frame> <name> [rtx|seedvr2]   frame PNG, 1 s of audio and the upscale workflow
  python3 a1.py final   <name> <upscaled_png>                  scales down to the clip size (lanczos) and matches clip 1's color
  python3 a1.py wf      <clip.json> <preset> <seed> <name>     ref2va workflow with 2 guides at frame 0 (image + audio)
  python3 a1.py seam    <previous.mp4> <frame> <new.mp4>       checks the seam (previous frame x new frame 0)
Assembly: clip N up to (frame+1)/24 s; clip N+1 from 1/24 s (= 0.0417): python3 video_h3.py assemble ...
"""
import importlib.util, json, os, subprocess, sys
import numpy as np

D = "refs/anchor1"                 # PNGs, audios and color reference
COLOR_REF = f"{D}/color_ref_clip1.png"
FPS = 24
OUT = "a1"                         # ComfyUI output subfolder


def vh():
    s = importlib.util.spec_from_file_location("vh", "video_h3.py"); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
    return m


def pfx():
    try:
        return json.load(open("config.json", encoding="utf-8")).get("prefix", "h3")
    except FileNotFoundError:
        return "h3"


def wh(png):
    from PIL import Image
    return Image.open(png).size


def wf_upscale(png, prefix, method, w, h):
    """2x upscale of ONE image. RTX VSR Ultra (default: natural skin, seconds) or SeedVR2 7B (more texture)."""
    if method == "rtx":
        return {
            "1": {"class_type": "LoadImage", "inputs": {"image": png}},
            "3": {"class_type": "DenoRTXVFXEasyUpscale", "inputs": {
                "images": ["1", 0], "mode": "VSR Ultra", "resize_type": "Manual", "scale": 2.0, "megapixels": 2.0,
                "width": 2 * w, "height": 2 * h, "divisible_by": "1", "device": 0,
                "ratio_preset": "9:16" if h >= w else "16:9", "resize_method": "Center Crop (Fill)"}},
            "12": {"class_type": "SaveImage", "inputs": {"images": ["3", 0], "filename_prefix": prefix}},
        }
    t = {"tile_size": 512, "overlap": 128, "temporal_size": 32, "temporal_overlap": 8}
    return {
        "1": {"class_type": "LoadImage", "inputs": {"image": png}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "seedvr2_ema_vae_fp16.safetensors"}},
        "4": {"class_type": "UNETLoader", "inputs": {"unet_name": "seedvr2_7b_int8_convrot.safetensors", "weight_dtype": "default"}},
        "5": {"class_type": "ResizeImageMaskNode", "inputs": {"input": ["1", 0], "resize_type": "scale by multiplier",
              "resize_type.multiplier": 2.0, "scale_method": "lanczos"}},
        "6": {"class_type": "SeedVR2Preprocess", "inputs": {"resized_images": ["5", 0]}},
        "7": {"class_type": "VAEEncodeTiled", "inputs": {"pixels": ["6", 0], "vae": ["3", 0], **t}},
        "8": {"class_type": "SeedVR2Conditioning", "inputs": {"model": ["4", 0], "vae_conditioning": ["7", 0]}},
        "9": {"class_type": "KSampler", "inputs": {"seed": 42, "steps": 1, "cfg": 1, "sampler_name": "euler", "scheduler": "simple",
              "denoise": 1, "model": ["4", 0], "positive": ["8", 0], "negative": ["8", 1], "latent_image": ["7", 0]}},
        "10": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["9", 0], "vae": ["3", 0], **t}},
        "11": {"class_type": "SeedVR2PostProcessing", "inputs": {"images": ["10", 0], "original_resized_images": ["5", 0],
               "color_correction_method": "lab"}},
        "12": {"class_type": "SaveImage", "inputs": {"images": ["11", 0], "filename_prefix": prefix}},
    }


def small(v):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", v, "-vf", "scale=96:168", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, 168, 96, 3).astype(float)


if __name__ == "__main__":
    a = sys.argv; m = a[1] if len(a) > 1 else ""; P = pfx()
    if m == "still":
        v, ta, tb = a[2], float(a[3]), float(a[4]); n0 = int(ta * FPS)
        q = vh()._frames(v, n0, int(tb * FPS))
        d = [(n0 + i, np.abs(q[i] - q[i - 1]).mean()) for i in range(1, len(q))]
        for n, x in d:
            print(f"frame {n} ({n / FPS:.2f}s): {x:.1f}")
        n, x = min(d, key=lambda t: t[1]); print(f"stillest: frame {n} ({n / FPS:.2f}s) = {x:.1f}")
    elif m == "cuts":
        q = small(a[2]); d = [np.abs(q[i + 1] - q[i]).mean() for i in range(len(q) - 1)]
        print("cuts:", [(i + 1, round((i + 1) / FPS, 2), round(float(x), 1)) for i, x in enumerate(d) if x > 30])
    elif m == "ref":
        os.makedirs(D, exist_ok=True); t = a[3] if len(a) > 3 else "2"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", t, "-i", a[2], "-frames:v", "1", COLOR_REF], check=True)
        print(COLOR_REF)
    elif m == "prepare":
        v, n, name = a[2], int(a[3]), a[4]; method = a[5] if len(a) > 5 else "rtx"; os.makedirs(D, exist_ok=True)
        os.makedirs("workflows", exist_ok=True)
        raw_png = f"{D}/{P}_a1_{name}_raw.png"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", v, "-vf", f"select='eq(n\\,{n})'", "-vsync", "0",
                        "-frames:v", "1", raw_png], check=True)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", v, "-vn", "-af",
                        f"atrim=start={n / FPS}:end={(n + 25) / FPS},asetpts=PTS-STARTPTS", "-ar", "48000", "-ac", "1",
                        f"{D}/{P}_a1_{name}_audio.wav"], check=True)
        w, h = wh(raw_png)
        wfp = f"workflows/a1_{method}_{name}.json"
        json.dump(wf_upscale(os.path.basename(raw_png), f"{OUT}/a1_{method}_{name}", method, w, h), open(wfp, "w"), indent=1)
        print(raw_png, f"{D}/{P}_a1_{name}_audio.wav", wfp, f"t0 = {n / FPS:.4f}s; the clip ends at {(n + 1) / FPS:.4f}s in the edit")
    elif m == "final":
        from PIL import Image
        name, png = a[2], a[3]
        raw = np.asarray(Image.open(f"{D}/{P}_a1_{name}_raw.png").convert("RGB")).astype(float)
        h, w = raw.shape[:2]
        d = np.asarray(Image.open(png).convert("RGB").resize((w, h), Image.LANCZOS)).astype(float)
        o = d.copy()
        if os.path.exists(COLOR_REF):   # per-channel mean and std equal to clip 1's: holds back the chain's darkening
            ref = np.asarray(Image.open(COLOR_REF).convert("RGB")).astype(float)
            for c in range(3):
                o[..., c] = (d[..., c] - d[..., c].mean()) / (d[..., c].std() + 1e-6) * ref[..., c].std() + ref[..., c].mean()
        o = o.clip(0, 255)
        Image.fromarray(o.astype(np.uint8)).save(f"{D}/{P}_a1_{name}_final.png")
        print(f"{D}/{P}_a1_{name}_final.png  brightness {raw.mean():.1f} -> {o.mean():.1f}" + ("" if os.path.exists(COLOR_REF) else " (no color ref)"))
    elif m == "wf":
        V = vh(); clip, preset, seed, name = json.load(open(a[2], encoding="utf-8")), a[3], int(a[4]), a[5]
        c = V.cfg("."); w, h = V.size(preset, c["format"], c["profile"])
        prompt = open(clip["prompt"], encoding="utf-8").read().strip()
        pre = f"{clip['id']}a1_{preset}_s{seed}"
        wf = V.wf_ref2va(c["profile"], prompt, clip["images"], clip["audios"], w, h, clip["seconds"], seed,
                         f"{clip.get('output', 'video_h3')}/{pre}", None)
        wf["20"] = {"class_type": "LoadImage", "inputs": {"image": f"{P}_a1_{name}_final.png"}}
        wf["22"] = {"class_type": "LoadAudio", "inputs": {"audio": f"{P}_a1_{name}_audio.wav"}}
        wf["50"] = {"class_type": "MiniMaxH3AddGuide", "inputs": {"positive": ["40", 0], "latent": ["40", 1], "frame_idx": 0,
                                                                  "vae": ["3", 0], "image": ["20", 0]}}
        wf["51"] = {"class_type": "MiniMaxH3AddGuide", "inputs": {"positive": ["50", 0], "latent": ["40", 1], "frame_idx": 0,
                                                                  "audio_vae": ["4", 0], "audio": ["22", 0]}}
        wf["42"]["inputs"]["conditioning"] = ["51", 0]
        out = f"workflows/{pre}.json"; json.dump(wf, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1); print(out)
    elif m == "seam":
        V = vh(); n = int(a[3])
        p = V._frames(a[2], n - 5, n); b = V._frames(a[4], 0, 8)
        print(f"previous[{n}] x new[0]: {np.abs(b[0] - p[-1]).mean():.1f} (expected ~5-8) | motion in previous:",
              [round(float(np.abs(p[i + 1] - p[i]).mean()), 1) for i in range(len(p) - 1)], "| new steps 0..8:",
              [round(float(np.abs(b[i + 1] - b[i]).mean()), 1) for i in range(len(b) - 1)])
    else:
        print(__doc__)
```
