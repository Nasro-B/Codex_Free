# 🚀 Codex Free

![Codex Banner](assets/codex_banner.png)

**Use the [OpenAI Codex](https://openai.com/codex/) application with free or cheaper LLMs** — DeepSeek, NVIDIA NIM, Hugging Face — via a transparent local proxy.

The Codex app is a powerful AI IDE (terminal, browser, file editor, MCP, plugins), but it requires a paid OpenAI subscription. **Codex Free** lets you use the same application with your own free or low-cost API keys, without modifying the app itself.

---

## 📋 Prerequisites

> ⚠️ **IMPORTANT**: You must first install the Codex application and connect your OpenAI account.
> The launcher does not replace Codex — it redirects its requests to other backends.

### 1. Install the Codex application

Download and install **OpenAI Codex** from the [Microsoft Store](https://apps.microsoft.com/detail/openai-codex) or from [openai.com/codex](https://openai.com/codex/).

### 2. Connect your OpenAI account

On the first launch of Codex:

- Sign in with your **OpenAI account** (even a free account works)
- The app will create its configuration file `config.toml` in `~\.codex\`
- Codex must start at least once normally to initialize its files

### 3. Install dependencies

```powershell
# Python 3.10+ required
python --version

# Install uv (modern Python package manager)
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"

# Install LiteLLM via uv
uv tool install litellm

# Verify installation
litellm --version
```

### 4. Get your API keys (free)

| Provider | Link | Cost |
|----------|------|------|
| **DeepSeek** | [platform.deepseek.com](https://platform.deepseek.com/) | ~$0.14/M tokens (flash) |
| **NVIDIA NIM** | [build.nvidia.com](https://build.nvidia.com/) | Free (1000 credits included) |
| **Hugging Face** | [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) | Free (Inference API) |

---

## ⚡ Quick Setup

```powershell
# 1. Clone or copy the project
git clone <repo-url> "C:\Serveurs\Codex Free"

# 2. Copy the template and fill in your API keys
cd "C:\Serveurs\Codex Free\litellm-codex"
cp .env.example .env
notepad .env    # ← fill in your keys here

# 3. Double-click the "Codex (menu).lnk" shortcut to launch!
```

---

## 🎯 Usage

### Launch via the menu

Double-click **`Codex (menu).lnk`** or run directly:

```powershell
pwsh -File "C:\Serveurs\Codex Free\codex-launch.ps1"
```

The interactive menu appears:

```
  ===== CODEX LAUNCHER =====

   1) DeepSeek-V4-flash      fast, cheap               [MCP OK]  <- recommended
   2) DeepSeek-V4-pro        more powerful (your key)   [MCP OK]
   3) NVIDIA DeepSeek-V4-pro unstable on NVIDIA side    [MCP OK]
   4) NVIDIA GLM-5.1         free, fast                 [MCP OK]
   5) HuggingFace Qwen3.6    free                       [MCP OK]
   6) My OpenAI account      gpt-5-codex                [account, MCP OK]
   7) Ollama cloud           minimax (ollama signin)    [cloud, MCP OK]

  Your choice (1-7):
```

Pick a number → the launcher:

1. Configures the model in `config.toml`
2. Keeps MCP servers enabled (automatic backup in `mcp-backup.toml`)
3. Starts the LiteLLM proxy if needed
4. Launches the Codex application

### Available Models

| # | Model | Provider | MCP | Proxy | Notes |
|---|-------|----------|-----|-------|-------|
| 1 | DeepSeek-V4-flash | DeepSeek | ✅ | ✅ | **Recommended** — fast and cheap |
| 2 | DeepSeek-V4-pro | DeepSeek | ✅ | ✅ | More powerful, more expensive |
| 3 | DeepSeek-V4-pro | NVIDIA NIM | ✅ | ✅ | Free but unstable on NVIDIA side |
| 4 | GLM-5.1 | NVIDIA NIM | ✅ | ✅ | Free and fast |
| 5 | Qwen3-Coder-Next | Hugging Face | ✅ | ✅ | Free (Inference API) |
| 6 | gpt-5-codex | OpenAI | ✅ | ❌ | Your OpenAI subscription |
| 7 | minimax-m3:cloud | Ollama cloud | ✅ | ❌ | Requires `ollama signin` |

> **MCP** = Model Context Protocol (external servers like Supabase, Playwright, Figma…).
> The launcher enables them for all menu choices (1→7) — MCP servers are managed by the Codex application itself, not by the remote LLM.
> `mcp-backup.toml` is a **safety net**: restore it manually if a Codex update wipes your MCP servers.

---

## 🏗️ How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Codex Application                         │
│              (thinks it's talking to OpenAI)                 │
│         sends its requests via the "Responses" API           │
└──────────────────────┬──────────────────────────────────────┘
                       │ http://localhost:4000/v1/
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   LiteLLM Proxy (:4000)                      │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  Wildcard "*": intercepts ANY model name             │     │
│  │  (gpt-5.5, gpt-5-codex, etc.) and redirects to     │     │
│  │  the backend selected in the menu                   │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  codex_deepseek_fix.py (pre-call callback)          │     │
│  │  Reorders tool_calls/outputs to satisfy             │     │
│  │  DeepSeek's strict validation                       │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                              │
│  Automatic bridge: Responses API → chat/completions          │
└──────────┬──────────┬──────────┬────────────────────────────┘
           │          │          │
           ▼          ▼          ▼
      DeepSeek    NVIDIA NIM   Hugging Face
```

### The Wildcard Mechanism

The Codex app sends its requests using OpenAI model names (e.g., `gpt-5.5`, `gpt-5-codex`). The LiteLLM proxy uses a **catch-all wildcard `"*"`** that intercepts **any** model name and redirects it to the backend selected in the menu.

This means no matter what model the app displays — it's the **launcher menu** that decides which backend receives the requests.

### The DeepSeek Fix

The Codex app sometimes sends **parallel** tool calls in an order that DeepSeek rejects:

```
function_call → function_call → message(assistant) → function_call_output → function_call_output
                                 ↑ DeepSeek rejects this here
```

The `codex_deepseek_fix.py` callback automatically reorders:

```
function_call → function_call → function_call_output → function_call_output → message(assistant)
                                                                                ↑ moved after
```

This reordering is harmless for NVIDIA/HF and fixes the issue for DeepSeek.

### MCP Server Management

MCP servers (Supabase, Playwright, Figma, Render…) are enabled for **all** menu choices (1→7) — `Launch-App` is called with `withMcp = $true` everywhere. Concretely:

- **All choices**: MCP servers are kept in `config.toml` — the Codex application manages them, not the remote LLM
- **`mcp-backup.toml`**: manual backup of external MCP servers, a safety net for restoring after a Codex update
- The internal `node_repl` server (used by Codex for its built-in browser) is **never touched**

> ℹ️ The launcher still contains a `Strip-MCP` function (which used to disable external MCP servers for chat-style APIs like DeepSeek). It is **no longer triggered** in the current flow: historically the DeepSeek/NVIDIA/HF choices disabled MCP, that is no longer the case.

---

## 🔗 Bonus 1 — Drive free Codex from Claude Code (`Claude_Commandes/`)

The [`Claude_Commandes/`](Claude_Commandes/) folder adds **slash commands inside Claude Code** that make the review/task run on **Codex powered by a free provider** (DeepSeek/HF/NVIDIA via the same LiteLLM proxy `:4000`) — **without using your OpenAI account**.

> Why: the native `/codex:review` only uses the OpenAI reviewer (paid). These commands instead run `codex exec` forced onto the chosen free provider.

| Command | Purpose |
|---------|---------|
| `/cx-free-review [provider] [base-ref]` | Code review (free equivalent of `/codex:review`) |
| `/cx-free-critique [provider] [base-ref]` | **Adversarial** red-team review |
| `/cx-free-task [provider] [--write] <request>` | Any request to the agent (`--write` = allow file edits) |
| `/cx-free-status` | LiteLLM proxy (port 4000) state + served models |

**Providers**: `deepseek` (default), `deepseek-pro`, `hf`, `nvidia`, `glm`. **Review target**: no `base-ref` → uncommitted work; with `base-ref` (e.g. `main`) → branch vs base.

Install:

```powershell
pwsh -NoProfile -File "C:\Serveurs\Codex Free\Claude_Commandes\install.ps1"
```

The installer copies the commands to `~/.claude/commands/`, the `cx-free.ps1` engine to `~/.claude/scripts/`, and — as a bonus — the `/cx-review` + `/cx-critique` prompts to `~/.codex/prompts/` (usable directly inside the Codex app). Details and troubleshooting: [Claude_Commandes/README.md](Claude_Commandes/README.md).

> ⚠️ `codex exec` requires `model_reasoning_effort = "xhigh"` in `~/.codex/config.toml` — the `"max"` value was removed in codex-cli 0.118.0.

---

## 🤖 Bonus 2 — Team of 15 Codex sub-agents (`user/.codex/agents/`)

The [`user/.codex/agents/`](user/.codex/agents/) folder contains **15 specialized sub-agents** for Codex CLI (multi-agent), tailored for a Node/Express + React/Vike + Supabase/Postgres + Vercel + LLM stack: `codebase-explorer`, `code-reviewer`, `security-auditor`, `debugger`, `test-engineer`, `db-migration-reviewer`, `performance-optimizer`, `refactorer`, `ai-llm-engineer`, `frontend-ux-reviewer`, `deployment-release-engineer`, `backend-api-reviewer`, `compliance-rgpd-auditor`, `integration-resilience-reviewer`, `docs-changelog-maintainer`.

Each agent declares a `sandbox_mode` (`read-only` for reviewers/auditors, `workspace-write` for the 4 "doers": debugger, test-engineer, refactorer, docs-changelog-maintainer). Copy the `*.toml` files into `~/.codex/agents/` and enable `multi_agent = true` under `[features]` in `config.toml`. Details: [user/.codex/agents/README.md](user/.codex/agents/README.md).

---

## 📁 Project Structure

```
C:\Serveurs\Codex Free\
├── codex-launch.ps1          # Main launcher (interactive menu)
├── mcp-backup.toml           # Backup of external MCP servers (manual safety net)
├── Codex (menu).lnk          # Windows shortcut (double-click to launch)
├── .gitignore                # Git security (excludes .env, config.yaml, secrets)
├── config.toml.md            # Doc: structure of ~/.codex/config.toml (no secrets)
├── ollama-launch-models.json.md  # Doc: structure of ollama-launch-models.json (no secrets)
│
├── litellm-codex/            # LiteLLM Proxy
│   ├── start-litellm.ps1     # Starts the proxy (loads .env, runs litellm)
│   ├── config.yaml           # LiteLLM config (AUTO-GENERATED by codex-launch.ps1 — do not edit)
│   ├── codex_deepseek_fix.py # Callback: reorders tool_calls for DeepSeek
│   ├── litellm-models.json   # Lightweight catalog exposed to Codex (real context_window)
│   ├── .env                  # 🔒 API keys (NEVER COMMIT)
│   └── .env.example          # Template without secrets
│
├── Claude_Commandes/         # Claude Code → free Codex bridge (/cx-free-* slash commands)
│   ├── install.ps1           # Installs commands + helper + prompts
│   ├── README.md             # Technical & troubleshooting doc
│   ├── PRESENTATION.md       # Visual overview of /cx-free-*
│   ├── commands/             # Claude Code slash commands (cx-free-review|critique|task|status)
│   ├── scripts/cx-free.ps1   # The engine (runs codex exec on the free provider)
│   └── prompts/              # Bonus: /cx-review and /cx-critique INSIDE the Codex app
│
└── user/.codex/agents/       # 15 Codex sub-agents (*.toml) — review/audit team
    └── README.md             # Agent team doc
```

### Important Files Outside the Project

| File | Location | Role |
|------|----------|------|
| `config.toml` | `C:\Users\<user>\.codex\config.toml` | Main Codex config — modified by the launcher |
| `ollama-launch-models.json` | `C:\Users\<user>\.codex\ollama-launch-models.json` | Model catalog and their context_window |

> 📚 **Detailed documentation**: see `config.toml.md` and `ollama-launch-models.json.md` in this project.

---

## ⚙️ Configuration

### API Keys (`litellm-codex/.env`)

Copy `.env.example` to `.env` and fill in your keys:

```env
# DeepSeek (https://platform.deepseek.com/)
DEEPSEEK_API_KEY=[REMOVED_API_KEY]

# NVIDIA Build (https://build.nvidia.com/) — 1 key per model
NVIDIA_API_KEY_DEEPSEEK=[REMOVED_API_KEY]
NVIDIA_API_KEY_GLM=[REMOVED_API_KEY]

# Hugging Face (https://huggingface.co/settings/tokens)
HF_TOKEN=[REMOVED_API_KEY]
```

### Adding a New Model

1. Add your API key to `.env`
2. In `codex-launch.ps1`, add an entry in the `Update-LiteLLMConfig` `switch`:

   ```powershell
   'my-model' { $wcModel = 'provider/model-name'; $wcBase = 'https://api.example.com'; $wcKey = 'MY_API_KEY' }
   ```

3. Add the corresponding slug in `ollama-launch-models.json` (see [ollama-launch-models.json.md](ollama-launch-models.json.md))
4. Add an option in the menu and the final `switch`

### Custom MCP Servers

To add your own MCP servers, edit `~\.codex\config.toml`:

```toml
[mcp_servers.my_server]
url = "https://my-mcp-server.com/mcp"
```

A backup is automatically created in `mcp-backup.toml`. If lost after a Codex update, restore from this backup.

---

## 🔄 Recovery After a Codex Update

A Codex application update can **overwrite** `config.toml` and `ollama-launch-models.json`. Here's what to check/restore:

### 1. Model context (most critical)

If the context drops back to **65,536 tokens** instead of 1M/256k:

- Check `C:\Users\<user>\.codex\ollama-launch-models.json`
- The slugs `deepseek-flash`, `deepseek-pro`, `nvidia-deepseek`, `nvidia-glm`, `hf` must exist with the correct `context_window`
- Reference: [ollama-launch-models.json.md](ollama-launch-models.json.md)

### 2. LiteLLM Provider

Verify that `C:\Users\<user>\.codex\config.toml` contains:

```toml
[model_providers.litellm]
name = "LiteLLM"
base_url = "http://localhost:4000/v1/"
wire_api = "responses"
env_key = "LITELLM_KEY"
model_catalog_json = "C:\\Serveurs\\Codex Free\\litellm-codex\\litellm-models.json"
```

### 3. Active model (written by the launcher)

The launcher **does not use profiles**: the `Set-Default` function writes the model and provider directly at the **top** of `config.toml` (before the first `[...]` section), on every launch based on the menu:

```toml
model = "deepseek-flash"     # ← rewritten on every launch
model_provider = "litellm"
```

Valid model names (which must match the `model_list` in `config.yaml` and the slugs in `litellm-models.json`):

| Menu choice | `model` written | `model_provider` |
|-------------|-----------------|------------------|
| 1 | `deepseek-flash` | `litellm` |
| 2 | `deepseek-pro` | `litellm` |
| 3 | `nvidia-deepseek` | `litellm` |
| 4 | `nvidia-glm` | `litellm` |
| 5 | `hf` | `litellm` |
| 6 | `gpt-5-codex` | `openai` |
| 7 | `minimax-m3:cloud` | `ollama-launch-codex-app` |

### 4. MCP Servers

If your MCP servers have disappeared, restore them from `mcp-backup.toml`:

```powershell
# Copy the [mcp_servers.*] sections from mcp-backup.toml to config.toml
```

### 5. Sandbox

Verify `sandbox_mode = "danger-full-access"` (required for Codex to execute shell commands).

Full reference: [config.toml.md](config.toml.md)

---

## 🔧 Troubleshooting

### The proxy won't start

```powershell
# Verify that litellm is installed
litellm --version

# Check if port 4000 is already in use
Get-NetTCPConnection -LocalPort 4000 -ErrorAction SilentlyContinue

# Run manually to see errors
pwsh -File "C:\Serveurs\Codex Free\litellm-codex\start-litellm.ps1"
```

### The Codex app doesn't respond with DeepSeek

- Check your DeepSeek API key in `.env`
- Verify the proxy is running: open `http://localhost:4000/health` in a browser
- Check the minimized proxy window for errors

### My MCP servers have disappeared

If after a Codex update your MCP servers are no longer in `config.toml`, restore them from `mcp-backup.toml`:

```powershell
# Manually copy the [mcp_servers.*] sections from mcp-backup.toml to config.toml
```

### The DeepSeek fix callback won't load

The proxy must start with the correct working directory. If you see `ModuleNotFoundError: No module named 'codex_deepseek_fix'` in the proxy window, verify that:

- `start-litellm.ps1` contains `Set-Location -Path $dir` before `litellm`
- `codex-launch.ps1` uses `-WorkingDirectory` in `Start-Process`

### `codex exec` refuses the config: `unknown variant 'max'`

Since **codex-cli 0.118.0**, the `model_reasoning_effort = "max"` value no longer exists. If `codex exec` (used by the `/cx-free-*` commands) refuses to load the config, replace it in `~/.codex/config.toml`:

```toml
model_reasoning_effort = "xhigh"   # not "max"
```

---

## 🔒 Security

- The `.env` file contains your API keys — it is excluded from Git via `.gitignore`
- The proxy runs **locally only** (`localhost:4000`) — not accessible from outside
- The proxy `master_key` (`sk-codex-local`) is for local access only

> **Never commit `.env`** — use `.env.example` as a template for other users.

---

## 📜 License

Personal project. The OpenAI Codex application belongs to OpenAI. This project does not modify the application — it redirects its API requests through a local proxy.
