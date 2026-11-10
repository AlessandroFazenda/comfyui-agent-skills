# comfyui-agent-skills

[English](#english) · [Português](#português)

---

## English

Agent skills that drive a **local ComfyUI** to make reference sheets (characters, locations, costumes, props) and then dialogue clips with **MiniMax H3**. They follow the open [`SKILL.md` format](https://agentskills.io), so they work in Claude Code, Codex, Cursor and other agents that support skills and MCP.

The agent writes the ComfyUI workflows itself (the Python scripts are embedded in each `SKILL.md`), runs them through the [comfy-mcp](https://docs.comfy.org/agent-tools/mcp) server, shows you the results and asks for approval at each step. You direct; the agent operates ComfyUI.

### Skills

| Skill | What it does |
|---|---|
| [`character-sheet`](skills/character-sheet/SKILL.md) | 9:16 character sheet with 17 panels. Gemma 4 describes the character from an image and/or a brief; FLUX.2 klein generates the base and the panels. Humans, aliens, dragons, anime… |
| [`environment-sheet`](skills/environment-sheet/SKILL.md) | Location sheet. Needs a detailed brief; if yours is short, Gemma suggests details for you to approve. FLUX.2 klein + Qwen-Image-Edit generate the base, the camera angles and the plates. |
| [`costume-sheet`](skills/costume-sheet/SKILL.md) | Isolated pieces + the complete look (front, ¾, back). Gemma turns your brief into FLUX.2 klein prompts, and **you approve the prompts before any image is generated**. |
| [`upscale-prop`](skills/upscale-prop/SKILL.md) | Upscales and restores prop images (clothes, objects) with SeedVR2 7B Int8, faithful to the original. |
| [`video-h3`](skills/video-h3/SKILL.md) | Dialogue clips with a local MiniMax H3 (ref2va) from the sheets, props and voice references, assembled into a Full HD film. |
| [`vastai`](skills/vastai/SKILL.md) | Optional. Rents a GPU on Vast.ai (`vastai` CLI) for heavy H3 renders, with a provisioning script. |

### Order of use

1. **Sheets:** `character-sheet` for each character, `costume-sheet` for their clothes, `environment-sheet` for each location, `upscale-prop` for small or blurry prop images.
2. **Video:** `video-h3` takes those images plus a voice reference per character and a script. It always starts with a very-low-resolution test (288×512, "live storyboard"), then the real render, then the Full HD upscale. You approve each stage.
3. **Optional:** `vastai` when a render is too heavy for your GPU.

### Requirements

**ComfyUI and comfy-mcp**

- ComfyUI **0.40 or newer** (the MiniMax H3, SeedVR2 and Gemma 4 nodes are native).
- The **comfy-mcp** server, Comfy's local MCP server. Follow the [official guide](https://docs.comfy.org/agent-tools/mcp); in short:

  ```bash
  pip install comfy-mcp "comfy-cli>=1.14.0"
  comfy install          # or: comfy set-default <path-to-your-ComfyUI>
  comfy launch           # leave it running (the agent can also start it)
  ```

  Then register it in your agent. Set `COMFY_BIN` to the absolute path of `comfy` if your agent doesn't inherit your shell's `PATH`:

  ```bash
  # Claude Code
  claude mcp add comfy-mcp -e COMFY_BIN=/path/to/venv/bin/comfy -- comfy-mcp
  # Codex
  codex mcp add comfy-mcp --env COMFY_BIN=/path/to/venv/bin/comfy -- comfy-mcp
  ```

  Claude Desktop and Cursor use this JSON (`claude_desktop_config.json`, or `~/.cursor/mcp.json` / `.cursor/mcp.json`):

  ```json
  {
    "mcpServers": {
      "comfy-mcp": {
        "command": "comfy-mcp",
        "env": { "COMFY_BIN": "/path/to/venv/bin/comfy" }
      }
    }
  }
  ```

  The skills use the local server, not the Comfy Cloud one (`cloud.comfy.org/mcp`). Browser-only clients such as claude.ai can't reach a local MCP server.

**Custom nodes**

| Pack | Needed by |
|---|---|
| [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF) | `environment-sheet` (camera angles with Qwen-Image-Edit GGUF) |
| [ComfyUI-KJNodes](https://github.com/kijai/ComfyUI-KJNodes) | `video-h3` (`MiniMaxChunkFeedForward`, local profiles) |
| `deno-custom-nodes` + NVIDIA's `nvvfx` runtime | `video-h3` (Full HD with RTX Video Super Resolution, node `DenoRTXVFXEasyUpscale`). The runtime is installed manually into ComfyUI's Python; the skill asks before touching it and falls back to SeedVR2 without it |

`character-sheet`, `costume-sheet` and `upscale-prop` use only native nodes.

**Shell side** (where the agent runs commands): Python 3.10+ with **Pillow** (all skills) and **numpy** (`video-h3`), plus **ffmpeg** (`video-h3`).

**Models.** Each `SKILL.md` has a "Requirements (models)" table with file names, ComfyUI folders and sources. The agent can download missing models through comfy-mcp, except FLUX.2 klein 9B, which is a gated repo (accept the terms on Hugging Face and download it yourself). Main models:

- Gemma 4 (E4B or E2B), FLUX.2 klein (9B or 4B) + VAE and text encoders: sheets.
- Qwen-Image-Edit 2511 GGUF + Lightning and multiple-angles LoRAs: `environment-sheet`.
- SeedVR2 7B Int8: `upscale-prop` and the alternative video upscale.
- MiniMax H3 fused turbo int8 + Qwen3-VL nvfp4 text encoder + video and audio VAEs: `video-h3`.

### Hardware profiles

| | 16 GB GPU (tested: RTX 5070 Ti, 32 GB RAM) | Smaller GPU (tested: RTX 4060 8 GB) |
|---|---|---|
| Sheets | Gemma 4 E4B + FLUX.2 klein 9B | Gemma 4 E2B + FLUX.2 klein 4B |
| Full character sheet | ~3 min | < 10 min |
| H3 test, 15 s at 288×512 | ~1.2 min | ~4 min |
| H3 render, 15 s | 768×1344, ~19 min | 544×960, ~20–23 min |
| Full HD | RTX VSR → 1080×1920 (default) | SeedVR2 2× (RTX VSR not tested yet) |

On the 16 GB card the H3 bottleneck is system RAM, not VRAM: close heavy programs before a render.

### Rented GPUs (Vast.ai)

- The `vastai` skill shows you the offer (GPU, price per hour, disk, bandwidth cost) and waits for your OK before renting anything.
- **At the end of the job the instance is always destroyed**, after the outputs are downloaded and you confirm the instance ID. A stopped instance keeps charging storage. It is kept only if you explicitly ask.
- Your API key and SSH key stay in files on your machine (`<VASTAI_DIR>`, e.g. `~/vastai`). The agent never prints them and never asks for them in the chat.
- Comfy Cloud is not a good fit for H3 (expensive, and a 30 min / 1 h limit per execution).

### Installation

**Claude Code** (as a plugin):

```
/plugin marketplace add AlessandroFazenda/comfyui-agent-skills
/plugin install comfyui-agent-skills@comfyui-agent-skills
```

**Any agent:** copy the folders in `skills/` into your agent's skills folder, for example `~/.claude/skills/` (Claude Code) or `~/.codex/skills/` (Codex). Check your agent's docs for its location. Keep each folder whole: `vastai` has a `scripts/` subfolder.

The skills work best with an agent that can run shell commands on the same machine as ComfyUI. If they are on different machines, the skills explain which paths are seen by the shell and which by the comfy-mcp host.

### Placeholders

The skills contain no personal paths. Replace these when the agent asks, or tell it up front:

- `<EXTRA_MODEL_PATHS_YAML>`: your `extra_model_paths.yaml`, if your models live outside the ComfyUI folder (e.g. ComfyUI Desktop).
- `<VASTAI_DIR>`: the folder with your Vast.ai API key and SSH key.

### Licenses of the models

- **FLUX.2 klein 9B** is under the FLUX Non-Commercial License. For commercial work, use klein 4B (Apache 2.0) even on a 16 GB GPU, or get a license from Black Forest Labs.
- The other models have their own licenses; check each model card before commercial use.
- comfy-mcp is licensed AGPL-3.0-or-later or commercially, by Comfy.

### License

The skills and scripts in this repo are MIT licensed (see [LICENSE](LICENSE)). The models and comfy-mcp keep their own licenses (above).

### Credits

The `vastai` skill is based on the official `vast-ai/vast-cli` skill, adapted for ComfyUI + MiniMax H3.

---

## Português

Skills de agente que controlam um **ComfyUI local** para criar fichas de referência (personagens, locações, figurinos, props) e depois clipes com diálogo no **MiniMax H3**. Elas seguem o formato aberto [`SKILL.md`](https://agentskills.io), então funcionam no Claude Code, Codex, Cursor e outros agentes com suporte a skills e MCP.

O próprio agente monta os workflows do ComfyUI (os scripts Python estão embutidos em cada `SKILL.md`), roda tudo pelo servidor [comfy-mcp](https://docs.comfy.org/agent-tools/mcp), mostra os resultados e pede sua aprovação a cada etapa. Você dirige; o agente opera o ComfyUI.

As skills estão em inglês, mas respondem no idioma do usuário.

### Skills

| Skill | O que faz |
|---|---|
| [`character-sheet`](skills/character-sheet/SKILL.md) | Ficha de personagem 9:16 com 17 painéis. O Gemma 4 descreve o personagem a partir de uma imagem e/ou briefing; o FLUX.2 klein gera a base e os painéis. Humanos, ETs, dragões, anime… |
| [`environment-sheet`](skills/environment-sheet/SKILL.md) | Ficha de locação. Exige briefing detalhado; se o seu for curto, o Gemma sugere detalhes para você aprovar. FLUX.2 klein + Qwen-Image-Edit geram a base, os ângulos de câmera e os plates. |
| [`costume-sheet`](skills/costume-sheet/SKILL.md) | Peças isoladas + look completo (frente, ¾, costas). O Gemma transforma o briefing em prompts do FLUX.2 klein, e **você aprova os prompts antes de qualquer imagem ser gerada**. |
| [`upscale-prop`](skills/upscale-prop/SKILL.md) | Amplia e restaura imagens de props (roupas, objetos) com SeedVR2 7B Int8, fiel ao original. |
| [`video-h3`](skills/video-h3/SKILL.md) | Clipes com diálogo no MiniMax H3 local (ref2va) a partir das fichas, props e referências de voz, montados num filme em Full HD. |
| [`vastai`](skills/vastai/SKILL.md) | Opcional. Aluga uma GPU na Vast.ai (CLI `vastai`) para renders pesados do H3, com script de provisionamento. |

### Ordem de uso

1. **Fichas:** `character-sheet` para cada personagem, `costume-sheet` para as roupas, `environment-sheet` para cada locação, `upscale-prop` para imagens de props pequenas ou borradas.
2. **Vídeo:** `video-h3` usa essas imagens, uma referência de voz por personagem e um roteiro. Sempre começa com um teste em baixíssima resolução (288×512, "storyboard vivo"), depois o render de verdade e por fim a ampliação para Full HD. Você aprova cada etapa.
3. **Opcional:** `vastai` quando o render for pesado demais para a sua GPU.

### Requisitos

**ComfyUI e comfy-mcp**

- ComfyUI **0.40 ou mais novo** (os nós do MiniMax H3, SeedVR2 e Gemma 4 são nativos).
- O servidor **comfy-mcp**, o MCP local da Comfy. Siga o [guia oficial](https://docs.comfy.org/agent-tools/mcp); em resumo:

  ```bash
  pip install comfy-mcp "comfy-cli>=1.14.0"
  comfy install          # ou: comfy set-default <caminho-do-seu-ComfyUI>
  comfy launch           # deixe rodando (o agente também consegue iniciar)
  ```

  Depois registre o servidor no seu agente. Defina `COMFY_BIN` com o caminho absoluto do `comfy` se o agente não herdar o `PATH` do seu shell:

  ```bash
  # Claude Code
  claude mcp add comfy-mcp -e COMFY_BIN=/caminho/do/venv/bin/comfy -- comfy-mcp
  # Codex
  codex mcp add comfy-mcp --env COMFY_BIN=/caminho/do/venv/bin/comfy -- comfy-mcp
  ```

  Claude Desktop e Cursor usam este JSON (`claude_desktop_config.json`, ou `~/.cursor/mcp.json` / `.cursor/mcp.json`):

  ```json
  {
    "mcpServers": {
      "comfy-mcp": {
        "command": "comfy-mcp",
        "env": { "COMFY_BIN": "/caminho/do/venv/bin/comfy" }
      }
    }
  }
  ```

  As skills usam o servidor local, não o do Comfy Cloud (`cloud.comfy.org/mcp`). Clientes só de navegador, como o claude.ai, não alcançam um MCP local.

**Custom nodes**

| Pacote | Usado por |
|---|---|
| [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF) | `environment-sheet` (ângulos de câmera com Qwen-Image-Edit GGUF) |
| [ComfyUI-KJNodes](https://github.com/kijai/ComfyUI-KJNodes) | `video-h3` (`MiniMaxChunkFeedForward`, perfis locais) |
| `deno-custom-nodes` + runtime `nvvfx` da NVIDIA | `video-h3` (Full HD com RTX Video Super Resolution, nó `DenoRTXVFXEasyUpscale`). O runtime é instalado manualmente no Python do ComfyUI; a skill pergunta antes de mexer e, sem ele, usa o SeedVR2 |

`character-sheet`, `costume-sheet` e `upscale-prop` usam só nós nativos.

**No shell** (onde o agente roda comandos): Python 3.10+ com **Pillow** (todas as skills) e **numpy** (`video-h3`), mais **ffmpeg** (`video-h3`).

**Modelos.** Cada `SKILL.md` tem uma tabela "Requirements (models)" com nomes de arquivo, pastas do ComfyUI e origem. O agente baixa os modelos que faltam pelo comfy-mcp, menos o FLUX.2 klein 9B, que é repositório restrito (aceite os termos no Hugging Face e baixe você mesmo). Principais modelos:

- Gemma 4 (E4B ou E2B), FLUX.2 klein (9B ou 4B) + VAE e text encoders: fichas.
- Qwen-Image-Edit 2511 GGUF + LoRAs Lightning e multiple-angles: `environment-sheet`.
- SeedVR2 7B Int8: `upscale-prop` e a ampliação alternativa de vídeo.
- MiniMax H3 fused turbo int8 + text encoder Qwen3-VL nvfp4 + VAEs de vídeo e áudio: `video-h3`.

### Perfis de hardware

| | GPU de 16 GB (testado: RTX 5070 Ti, 32 GB de RAM) | GPU menor (testado: RTX 4060 8 GB) |
|---|---|---|
| Fichas | Gemma 4 E4B + FLUX.2 klein 9B | Gemma 4 E2B + FLUX.2 klein 4B |
| Ficha de personagem completa | ~3 min | < 10 min |
| Teste H3, 15 s em 288×512 | ~1,2 min | ~4 min |
| Render H3, 15 s | 768×1344, ~19 min | 544×960, ~20–23 min |
| Full HD | RTX VSR → 1080×1920 (padrão) | SeedVR2 2× (RTX VSR ainda não testado) |

Na placa de 16 GB o gargalo do H3 é a RAM do sistema, não a VRAM: feche programas pesados antes de um render.

### GPU alugada (Vast.ai)

- A skill `vastai` mostra a oferta (GPU, preço por hora, disco, custo de banda) e espera seu OK antes de alugar qualquer coisa.
- **No fim do trabalho a instância é sempre destruída**, depois de baixar os resultados e você confirmar o ID da instância. Instância parada continua cobrando storage. Ela só é mantida se você pedir explicitamente.
- A API key e a chave SSH ficam em arquivos na sua máquina (`<VASTAI_DIR>`, ex.: `~/vastai`). O agente nunca as exibe e nunca pede no chat.
- O Comfy Cloud não serve bem para o H3 (caro, e limite de 30 min / 1 h por execução).

### Instalação

**Claude Code** (como plugin):

```
/plugin marketplace add AlessandroFazenda/comfyui-agent-skills
/plugin install comfyui-agent-skills@comfyui-agent-skills
```

**Qualquer agente:** copie as pastas de `skills/` para a pasta de skills do seu agente, por exemplo `~/.claude/skills/` (Claude Code) ou `~/.codex/skills/` (Codex). Confira na documentação do agente qual é a pasta. Copie cada pasta inteira: a `vastai` tem a subpasta `scripts/`.

As skills funcionam melhor com um agente que roda comandos de shell na mesma máquina do ComfyUI. Se estiverem em máquinas diferentes, as skills explicam quais caminhos são vistos pelo shell e quais pelo host do comfy-mcp.

### Placeholders

As skills não têm caminhos pessoais. Substitua estes quando o agente perguntar, ou avise logo no início:

- `<EXTRA_MODEL_PATHS_YAML>`: o seu `extra_model_paths.yaml`, se os modelos ficam fora da pasta do ComfyUI (ex.: ComfyUI Desktop).
- `<VASTAI_DIR>`: a pasta com a API key e a chave SSH da Vast.ai.

### Licenças dos modelos

- O **FLUX.2 klein 9B** está sob a FLUX Non-Commercial License. Para trabalho comercial, use o klein 4B (Apache 2.0) mesmo numa GPU de 16 GB, ou obtenha uma licença com a Black Forest Labs.
- Os outros modelos têm licenças próprias; confira o model card de cada um antes de uso comercial.
- O comfy-mcp é licenciado pela Comfy como AGPL-3.0-or-later ou comercial.

### Licença

As skills e scripts deste repo têm licença MIT (veja [LICENSE](LICENSE)). Os modelos e o comfy-mcp mantêm as próprias licenças (acima).

### Créditos

A skill `vastai` é baseada na skill oficial `vast-ai/vast-cli`, adaptada para ComfyUI + MiniMax H3.
