---
description: Free Codex bridge state — LiteLLM proxy (port 4000) + available providers
allowed-tools: Bash(pwsh:*)
---
Show the state of the free Codex bridge (LiteLLM proxy + cx-free providers), without launching anything else.

Steps:
1. Run:
   ```
   pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode status
   ```
2. Return the output: proxy UP/DOWN on 4000, models served by the proxy, and the list of usable providers (`deepseek`, `deepseek-pro`, `hf`, `nvidia`, `glm`).
3. If the proxy is DOWN, remind that it auto-starts on the next `/cx-free-review`, `/cx-free-critique` or `/cx-free-task`.
