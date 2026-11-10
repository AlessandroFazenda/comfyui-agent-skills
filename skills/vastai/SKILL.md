---
name: "vastai"
description: "Manages GPUs on Vast.ai with the vastai CLI: search offers, create/stop/destroy instances, SSH, copy files, volumes and billing. Includes a provisioning script to run ComfyUI + MiniMax H3 on a rented GPU."
---

# vastai

Based on the official `vast-ai/vast-cli` skill (vastai/SKILL.md), adapted for rendering MiniMax H3 / ComfyUI on rented GPUs. Optional: it is infrastructure, not ComfyUI itself.

Reply in the user's language.

## Setup

- Run the `vastai` commands in a POSIX shell (Linux, macOS or WSL/Git Bash on Windows).
- Configurable files (default `<VASTAI_DIR>`, e.g. `~/vastai`): `api_key.txt` (API key), `vastai_ed25519` / `.pub` (SSH key already registered on the account). The helper scripts of this skill live in `scripts/` next to this file: `provision_h3.sh`, `run_wf.py`.
- Never display (cat/echo) the API key or the private key, and never ask for them in the chat.
- One-time setup (repeat at the start of each session if the environment is ephemeral):

```bash
pip3 install --user -q vastai
export PATH=$HOME/.local/bin:$PATH
mkdir -p ~/.config/vastai ~/.ssh
cp <VASTAI_DIR>/api_key.txt ~/.config/vastai/vast_api_key && chmod 600 ~/.config/vastai/vast_api_key
cp <VASTAI_DIR>/vastai_ed25519 <VASTAI_DIR>/vastai_ed25519.pub ~/.ssh/ && chmod 600 ~/.ssh/vastai_ed25519
vastai show user --raw    # checks login and balance
```

- If each shell call starts a fresh shell, repeat `export PATH=$HOME/.local/bin:$PATH` in every call.
- Before `create instance`, show the user the chosen offer (GPU, $/h, disk, location, bandwidth cost) and wait for their OK. Check the balance before creating.
- Search offers in any region (no `geolocation` filter), choosing by price and performance; filter by region only if the user asks.

## Instance lifecycle

1. **At the start, check for a stopped instance.** Run `vastai show instances --raw`. If there is a `stopped` instance that fits the job (suitable GPU and disk, already provisioned), offer to restart it with `vastai start instance <id>` instead of creating another. That avoids repeating the provisioning (~7 min and ~56 GB of bandwidth).
2. **After a start:** wait for `actual_status == running` and reread `ssh_host`/`ssh_port` (they may change). Processes don't survive a stop: run `provision_h3.sh` again (it is idempotent: it skips models that already exist and just starts ComfyUI).
3. **If the start doesn't progress** (stuck in `scheduling`/no GPU for more than ~2 min, because someone else rented the GPU): tell the user and ask whether to wait or create a new instance.
4. **Create a new one** when there is no usable stopped instance or the user asks (showing the offer and waiting for the OK).
5. **At the end of the job: always destroy.** Download the outputs to the user's folder, then confirm the instance ID with the user and run `vastai destroy instance <id> -y`. A stopped instance keeps charging storage (sometimes more than the running GPU). Keep it (`vastai stop instance <id>`) only if the user explicitly asks to keep it; never suggest stopping as the default. If kept, confirm it is `stopped` and report its hourly storage cost.
6. **Never destroy without the user's confirmation**, including instances in an error state (`exited`, `unknown`, `offline`): tell the user and wait for their decision.

## Network and SSH

- Per-instance shortcut (`ssh_host`/`ssh_port` from `vastai show instance <id> --raw`):

```bash
cat > ~/vssh <<EOF
#!/bin/bash
exec ssh -i ~/.ssh/vastai_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ServerAliveInterval=30 -p PORT root@HOST "\$@"
EOF
chmod +x ~/vssh
~/vssh 'nvidia-smi'                                        # remote command
scp -i ~/.ssh/vastai_ed25519 -P PORT file root@HOST:/workspace/       # upload
scp -i ~/.ssh/vastai_ed25519 -P PORT root@HOST:/workspace/out.mp4 .   # download
```

- If the agent runs in a sandbox with restricted network, SSH may fail with `Could not resolve hostname` or a refused connection. Ask the user to allow outbound SSH to `*.vast.ai`, or use an HTTP CONNECT proxy through `-o ProxyCommand=...` if their environment provides one.
- Always use `timeout N ~/vssh ... </dev/null` and run long processes with `(setsid nohup CMD > log 2>&1 < /dev/null &)`; otherwise the call hangs.
- Image `vastai/pytorch:@vastai-automatic-tag`: Python at `/venv/main/bin/python` (`python` isn't on the PATH over SSH); `/workspace` may not exist (create it).

## Costs (lessons)

- **Bandwidth can cost more than the GPU.** In one test: GPU US$ 0.03, disk US$ 0.01, 56.5 GB download at US$ 0.026/GB = **US$ 1.47**. When searching offers, show and prefer a low `inet_down_cost` (some hosts have free download); H3 provisioning downloads ~56 GB.
- A stopped instance keeps charging storage (and may charge more than when running); this is why the default is to destroy at the end.
- Check the spend afterwards with `vastai show invoices-v1 --charges --limit 5 --latest-first --raw`.
- Comfy Cloud is not a good fit for H3 (expensive, and a 30 min/1 h limit per execution); a rented GPU is.

## MiniMax H3 on Vast

- `scripts/provision_h3.sh`: clones/updates ComfyUI, downloads the fused turbo int8 H3, the Qwen3-VL nvfp4 text encoder, the VAEs (video int8 and fp16, audio) and SeedVR2 (skipping what already exists), starts ComfyUI on 127.0.0.1:8188 and checks the H3 node. Upload it to `/workspace/provision_h3.sh` and run it in the background; log at `/workspace/provision.log` (`[prov]` lines). ~7 min on an RTX 3090 with 1.3 Gbps the first time.
- Generate: upload the workflow (API format, the same one as in the `video-h3` skill) and `scripts/run_wf.py`; run `/venv/main/bin/python run_wf.py wf.json` on the instance; output in `/workspace/ComfyUI/output/`. Download to the project folder.
- RTX 3090 (driver 560 / CUDA 12.6): 288x512, 5 s, 4 steps = **~42 s** per clip. The `int8_convrot` video VAE failed on that driver ("CUDA driver version is insufficient", comfy_kitchen kernel); `fp16` worked. On a machine with a newer driver, try int8.
- To see ComfyUI in the browser: tunnel `ssh -N -L 8188:127.0.0.1:8188 ...` (ComfyUI listens on localhost only).
- When done: follow the "Instance lifecycle" (download, then destroy with confirmation).

> Command is `vastai` (lowercase). Always use `--raw` for machine-readable JSON output.

## Quick start

```bash
vastai show user                                    # Verify auth + check balance
vastai show instances --raw                         # Stopped instance to reuse?
vastai start instance <id>                          # Reuse it
vastai search offers 'gpu_name=RTX_4090 num_gpus=1 verified=true rentable=true' -o 'dlperf_usd-'
vastai create instance <OFFER_ID> --image vastai/pytorch:@vastai-automatic-tag --disk 200 --ssh
# Response: {"success": true, "new_contract": <INSTANCE_ID>}
vastai show instance <INSTANCE_ID>                  # Poll until actual_status == "running"
vastai destroy instance <INSTANCE_ID> -y            # End of work (after the user confirms)
```

## Global flags

```
--api-key KEY    Override stored API key
--raw            Output machine-readable JSON (agents should always use this)
--full           Print full results (don't page with less)
--explain        Show underlying API calls
--curl           Show equivalent curl command
--no-color       Disable colored output
--retry RETRY    Set retry limit for API calls
```

## Query syntax

Operators: `=`, `!=`, `>`, `>=`, `<`, `<=`, `in`, `notin`.

```bash
'gpu_name=RTX_4090 num_gpus=1'           # Exact match + numeric
'gpu_ram>=48 reliability>0.95'           # Greater-than filters
'geolocation=EU dph_total<=2.0'          # Region + price cap
```

Filter fields: `num_gpus`, `gpu_name`, `gpu_ram`, `cpu_ram`, `disk_space`, `reliability`, `compute_cap`, `inet_up`, `inet_down`, `inet_down_cost`, `dph_total`, `geolocation`, `direct_port_count`, `verified`, `rentable`, `cuda_max_good`

Sort fields: `score` (default), `dlperf_usd`, `dph_total`, `num_gpus`, `reliability`

## Instances

```bash
vastai show instances --raw                              # All instances as JSON
vastai show instance <id>                                # Poll single instance
vastai create instance <offer-id> --image IMAGE --disk 200 --ssh
vastai start instance <id>                               # Start stopped instance
vastai stop instance <id>                                # Stop (preserves disk, no GPU charges, storage still charged)
vastai reboot instance <id>
vastai destroy instance <id> -y                          # Delete permanently (only after the user confirms)
vastai label instance <id> --label "name"
```

create instance flags: `--image`, `--disk GB`, `--ssh`/`--jupyter`, `--direct`, `--label`, `--env '-e K=V -p 8080:8080'`, `--onstart FILE`, `--onstart-cmd CMD`, `--bid_price PRICE` (spot), `--template_hash HASH`, `--create-volume ID`, `--link-volume ID`, `--cancel-unavail`.

Status (`actual_status`): `null`/`created` provisioning; `loading` image downloading; `running` GPU charges apply; `stopped` disk charges only; `frozen` GPU charges apply; `exited`/`unknown`/`offline` will never reach running.

> Poll loop warning: if status becomes `exited`, `unknown` or `offline`, stop polling and tell the user (do not destroy on your own). Always use a timeout.

> Charges: storage starts at creation; GPU starts at `running`. Stopped instances keep paying storage, and restart is not guaranteed if the GPU gets rented by someone else. Disk size cannot be changed after creation.

## Interruptible (spot)

`search offers --type bid` shows `min_bid`, but `create instance` rents on-demand unless you pass `--bid_price <floor>`. When outbid, the instance goes to `stopped` (storage still charged); resume with `update instance --bid_price`.

## Search

```bash
vastai search offers 'num_gpus=1 gpu_name=RTX_3090 cpu_ram>=60 disk_space>=200 inet_down>=800 reliability>0.98' -o 'dph_total' --storage 200 --raw
vastai search offers --type bid
vastai search offers -n 'gpu_name=H100_SXM'             # No default filters
vastai search templates "comfy"
```

Flags: `--type on-demand|reserved|bid`, `-o FIELD[-]`, `--limit`, `--storage GB`, `-n`

## File copy

```bash
vastai copy local:./data/ <id>:/workspace/data/          # Local -> instance (rsync)
vastai copy <id>:/workspace/results/ local:./results/    # Instance -> local
```

Never copy to `/root` or `/` — it breaks SSH permissions on the instance.

## Logs

```bash
vastai logs <id> --tail 100
vastai logs <id> --filter "error"
```

## Volumes

```bash
vastai search volumes
vastai show volumes
vastai create volume <offer_id> -s SIZE -n NAME
vastai delete volume <id>
```

Volumes are tied to the physical machine where they were created.

## Account & billing

```bash
vastai show user                                         # Balance
vastai show invoices-v1 --charges --limit 50 --latest-first
```

## Common errors

| Error | Fix |
|---|---|
| `401 Unauthorized` | Key in `api_key.txt` invalid/expired: ask the user to replace the file content |
| `Insufficient credits` | Add credits at https://cloud.vast.ai/billing/ |
| `No offers found` | Relax filters, try `-n` |
| `Permission denied` (SSH) | Check `-i ~/.ssh/vastai_ed25519`; `vastai attach ssh` for older instances |
| `Could not resolve hostname` (SSH) | Restricted network in the agent's sandbox: ask the user to allow outbound SSH |
| `Connection refused` | Wait for `running` |
| Start stuck in scheduling | GPU rented by someone else: ask the user (wait or create new) |
| Hangs on destroy | Add `-y` |

Full docs index: https://docs.vast.ai/llms.txt
