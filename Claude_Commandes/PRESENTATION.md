```
╔══════════════════════════════════════════════════════════════════════╗
║                                                                        ║
║     C X - F R E E   ·   FREE Codex from Claude Code                    ║
║     Code review & coding agent by DeepSeek / HuggingFace / NVIDIA      ║
║     ───────────────────────────────────────────────────────────       ║
║     No OpenAI account · No cost · 100% local (LiteLLM proxy)           ║
║                                                                        ║
╚══════════════════════════════════════════════════════════════════════╝
```

## In one sentence

You type a command **inside Claude Code** (e.g. `/cx-free-review deepseek`), and **Codex driven by a FREE LLM** (DeepSeek, HF or NVIDIA) does the analysis — exactly the kind of work `/codex:review` would do, but **without your OpenAI account** and **for free**.

---

## The problem it solves

```
  /codex:review  ──►  NATIVE Codex reviewer ──►  ☁️ OpenAI  ──►  💳 paid account required
                                                                  ❌ doesn't work on DeepSeek

  /cx-free-review ─►  codex exec -m deepseek ─►  🖥️ LiteLLM proxy :4000  ─►  DeepSeek/HF/NVIDIA
                                                                  ✅ free · ✅ open providers
```

---

## The 4 commands

```
┌──────────────────────────────┬───────────────────────────────────────────────┐
│ COMMAND                       │ WHAT IT DOES                                   │
├──────────────────────────────┼───────────────────────────────────────────────┤
│ /cx-free-review   [prov][ref] │ Full code review (= /codex:review)             │
│ /cx-free-critique [prov][ref] │ ADVERSARIAL red-team review, hunts the worst   │
│                               │ hidden bug + repro scenario                    │
│ /cx-free-task  [prov][--write]│ Any request to the agent (read, or file edits  │
│                <request>      │ with --write)                                  │
│ /cx-free-status               │ Proxy 4000 up/down + served models             │
└──────────────────────────────┴───────────────────────────────────────────────┘
```

**Providers** (`[prov]`): `deepseek` (default) · `deepseek-pro` · `hf` · `nvidia` · `glm`
**Review target** (`[ref]`): empty = uncommitted work · `main` = your branch vs `main`

---

## Feature details

### 🔍 `/cx-free-review` — the standard review
- Analyzes the git diff (uncommitted, or vs a base) **read-only** (touches nothing).
- Reads the files around the diff for context.
- Outputs: summary → findings sorted by severity `[CRITICAL/HIGH/MEDIUM/LOW]` with `file:line`, issue and fix → final recommendation (OK / fix / blocking).
- Covers: bugs & logic, security (injection, secrets, authz, validation), edge cases, regressions, concurrency, performance, quality.

### 🥷 `/cx-free-critique` — the adversarial review
- Red-team stance: **actively hunts the worst hidden bug**, as if a production incident depended on it.
- Gives a **concrete reproduction scenario** per finding.
- Ideal before a sensitive merge (payment, auth, data).

### 🤖 `/cx-free-task` — the do-anything agent
- Send any request: "explain this module", "write tests", "find why X crashes"…
- **Read-only by default**; add `--write` to let the agent **modify files**.

### 📊 `/cx-free-status` — the quick check
- Tells you whether the LiteLLM proxy (port 4000) is **UP/DOWN** and which **models** it serves.
- Handy when a call "times out": confirms in 1s whether it's just the proxy being down.

---

## Concrete examples

```bash
/cx-free-review deepseek            # review uncommitted work with DeepSeek
/cx-free-review hf main             # review your branch vs main with HuggingFace
/cx-free-task nvidia explain what this module does
/cx-free-critique deepseek-pro      # adversarial review with DeepSeek V4 Pro
/cx-free-task deepseek --write add the missing error handling in api.js
/cx-free-status                     # proxy + available models
```

---

## How it works (under the hood)

```
  You (Claude Code)
      │  /cx-free-review hf main
      ▼
  cx-free.ps1  ──(1) start proxy if down──►  litellm :4000
      │                                            │
      │  (2) codex exec -c model_provider=litellm   │ routes to
      │       -m hf  --sandbox read-only -o out.txt ▼
      ▼                                       HuggingFace / DeepSeek / NVIDIA
  Codex CLI (agent: git diff, reads files, reasons)
      │
      │  (3) clean final report
      ▼
  Shown in Claude Code
```

> It is not wired to the open Codex app window: it runs a headless `codex exec` turn on the **same free provider**. The result is identical.

---

## 30-second start

```powershell
# 1. Install (copies commands + helper + prompts)
pwsh -NoProfile -File "C:\Serveurs\Codex Free\Claude_Commandes\install.ps1"

# 2. Restart Claude Code

# 3. In any repo:
/cx-free-status
/cx-free-review deepseek
```

**Prerequisites**: `codex` CLI + `litellm` installed, and `model_reasoning_effort = "xhigh"` in `~/.codex/config.toml` (not `"max"`). The proxy starts itself on the first call.

---

## Bonus: also INSIDE the Codex app

The folder also installs 2 slash commands **directly in the Codex application** (via `~/.codex/prompts/`):
- `/cx-review` — code review on the active provider (DeepSeek/HF/NVIDIA).
- `/cx-critique` — adversarial review.

Type them in the Codex app itself when you're already there, alongside the `/cx-free-*` commands on the Claude Code side.

---

*Technical details & troubleshooting → `README.md`*
```
Sourire Concept · free Codex bridge
```
