---
description: ADVERSARIAL (red team) review by the Codex agent on a FREE provider (DeepSeek/HF/NVIDIA)
argument-hint: "[deepseek|deepseek-pro|hf|nvidia|glm] [base-ref]"
allowed-tools: Bash(pwsh:*), Read, Glob, Grep
---
ADVERSARIAL review (actively hunts the worst hidden bug, with a repro scenario) by the Codex agent on a FREE provider — free equivalent of `/codex:adversarial-review`.

Raw arguments: `$ARGUMENTS`

Steps:
1. Parse `$ARGUMENTS`:
   - 1st token = **provider** (`deepseek` default, `deepseek-pro`, `hf`, `nvidia`, `glm`).
   - 2nd optional token = **git base ref** (e.g. `main`).
2. Run:
   ```
   pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode critique -Provider <provider> -Repo "<cwd>" [-Base <base>]
   ```
   The helper starts the proxy on port 4000 if needed. It is slow (~30s–2min); offer `run_in_background` for a large diff.
3. Return **verbatim** the section after `===== CODEX REPORT` (analysis done by DeepSeek/HF/NVIDIA). Do not add your own analysis.
