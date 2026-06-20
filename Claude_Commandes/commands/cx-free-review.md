---
description: Code review by the Codex agent on a FREE provider (DeepSeek/HF/NVIDIA), no OpenAI
argument-hint: "[deepseek|deepseek-pro|hf|nvidia|glm] [base-ref]"
allowed-tools: Bash(pwsh:*), Read, Glob, Grep
---
FREE equivalent of `/codex:review`: has the Codex agent review your code running on a free provider (via the local LiteLLM proxy), instead of the native OpenAI reviewer.

Raw arguments: `$ARGUMENTS`

Steps:
1. Parse `$ARGUMENTS`:
   - 1st token = **provider** among `deepseek` (default), `deepseek-pro`, `hf`, `nvidia`, `glm`.
   - 2nd optional token = **git base ref** (e.g. `main`) → compares the branch to that base. Otherwise reviews uncommitted work.
2. Run the helper (replace `<provider>`, `<base>`, `<cwd>` = absolute path of the current repo):
   ```
   pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode review -Provider <provider> -Repo "<cwd>" [-Base <base>]
   ```
   - The helper starts the proxy on port 4000 by itself if needed.
   - It is slow (~30s to 2min). For a large diff, offer to run it in the background (`run_in_background`).
3. Return **verbatim** the section after `===== CODEX REPORT` — this is the review done by DeepSeek/HF/NVIDIA. Do NOT add your own review; just relay Codex's report.
4. If the helper errors (proxy down, unknown provider, not a git repo), explain the error and the fix.
