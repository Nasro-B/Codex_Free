---
description: Request/task to the Codex agent on a FREE provider (DeepSeek/HF/NVIDIA), no OpenAI
argument-hint: "[deepseek|deepseek-pro|hf|nvidia|glm] [--write] <your request>"
allowed-tools: Bash(pwsh:*), Read, Glob, Grep
---
Send any request to the Codex agent running on a FREE provider (via the local LiteLLM proxy).

Raw arguments: `$ARGUMENTS`

Steps:
1. Parse `$ARGUMENTS`:
   - If the 1st token is one of `deepseek`, `deepseek-pro`, `hf`, `nvidia`, `glm` → it is the **provider**; otherwise provider = `deepseek` and everything is the request.
   - Optional flag `--write` → lets the agent **modify files** (workspace-write sandbox). Without it, read-only.
   - The rest = the **request** (prompt).
2. Run:
   ```
   pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode task -Provider <provider> -Repo "<cwd>" [-Write] -Prompt "<request>"
   ```
   The helper starts the proxy on port 4000 if needed. It is slow (~30s–2min); offer `run_in_background` for a heavy request.
3. Return **verbatim** the section after `===== CODEX REPORT` (the answer from DeepSeek/HF/NVIDIA).
4. On error (proxy down, unknown provider), explain and fix.
