# Claude_Commandes — Free Claude Code ↔ Codex bridge (DeepSeek / HF / NVIDIA)

Slash commands **inside Claude Code** that get the work done (code review, agent task) by **Codex running on a FREE provider** (DeepSeek via the LiteLLM proxy, HuggingFace, NVIDIA) — **without using your OpenAI account**.

> Why: the native `/codex:review` only uses the OpenAI reviewer (paid account). These commands instead run `codex exec` forced onto a free provider, through the local LiteLLM proxy (port 4000).

## Available commands

| Command | Purpose |
| --- | --- |
| `/cx-free-review [provider] [base-ref]` | Full code review (free equivalent of `/codex:review`). |
| `/cx-free-critique [provider] [base-ref]` | **Adversarial** red-team review (equivalent of `/codex:adversarial-review`). |
| `/cx-free-task [provider] [--write] <request>` | Any request to the Codex agent (`--write` = allow file edits). |
| `/cx-free-status` | LiteLLM proxy (port 4000) state + available providers. |

**Providers**: `deepseek` (default), `deepseek-pro`, `hf`, `nvidia`, `glm`.
**Review target**: no `base-ref` → uncommitted work; with `base-ref` (e.g. `main`) → branch vs base.

### Examples

```
/cx-free-review deepseek            → review uncommitted work with DeepSeek
/cx-free-review hf main             → review your branch vs main with HuggingFace
/cx-free-task nvidia explain what this module does
/cx-free-critique deepseek-pro      → adversarial review with DeepSeek V4 Pro
/cx-free-status                     → proxy up/down + served models
```

## Install / re-integrate

```powershell
pwsh -NoProfile -File "C:\Serveurs\Codex Free\Claude_Commandes\install.ps1"
```

The installer copies:
- `commands\*.md` → `~/.claude/commands/`  (`/cx-free-*` slash commands)
- `scripts\cx-free.ps1` → `~/.claude/scripts/`  (the engine)
- `prompts\*.md` → `~/.codex/prompts/`  (bonus: `/cx-review` and `/cx-critique` **inside the Codex app** itself)

Restart Claude Code after installing to see the commands.

## Prerequisites

- **Codex CLI** (`codex`) installed and logged in (the OpenAI login is only a gate; LLM calls go to the free provider).
- **litellm** installed (`uv tool install litellm`).
- The **LiteLLM proxy** from `C:\Serveurs\Codex Free\litellm-codex` (keys in its `.env`). The helper auto-starts it on port 4000 if down (and falls back to the `Codex Gratuit` proxy folder if present).
- `~/.codex/config.toml`: `model_reasoning_effort` must be `"xhigh"` (NOT `"max"`, removed since codex-cli 0.118.0, otherwise `codex exec` refuses the config).

## How it works (under the hood)

`/cx-free-*` → `cx-free.ps1` which:
1. ensures the LiteLLM proxy (port 4000) is running (starts it otherwise);
2. runs `codex exec -c model_provider=litellm -m <model> --sandbox <ro|write> -o <file>` → the Codex agent runs on the chosen free provider (via the proxy);
3. returns the clean final report (MCP/skills noise is filtered out).

> It does not attach to the open Codex app window: it runs a headless `codex exec` turn on the same free provider. The result (DeepSeek/HF/NVIDIA does the analysis) is identical.

## Troubleshooting

- **`/cx-free-status` says DOWN** → normal if you haven't run anything; the first `/cx-free-*` starts the proxy.
- **"proxy 4000 unavailable"** → check `litellm` is installed + the keys in `C:\Serveurs\Codex Free\litellm-codex\.env`. Manual test: `pwsh -File "C:\Serveurs\Codex Free\litellm-codex\start-litellm.ps1"`.
- **`unknown variant 'max'`** → set `model_reasoning_effort = "xhigh"` in `~/.codex/config.toml`.
- **MCP errors (supabase/render) in the logs** → harmless (fast-fail in headless mode), the final report stays clean.

## Folder contents

```
Claude_Commandes/
├── README.md            (this file — technical & troubleshooting)
├── PRESENTATION.md      (visual overview of the features)
├── install.ps1          (installs commands + helper + prompts)
├── commands/            (Claude Code slash commands)
│   ├── cx-free-review.md
│   ├── cx-free-critique.md
│   ├── cx-free-task.md
│   └── cx-free-status.md
├── scripts/
│   └── cx-free.ps1      (the engine)
└── prompts/             (bonus: slash commands INSIDE the Codex app)
    ├── cx-review.md
    └── cx-critique.md
```
