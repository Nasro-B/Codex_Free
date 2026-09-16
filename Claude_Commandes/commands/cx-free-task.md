---
description: Run a Codex Free EN task through a selected provider
argument-hint: "[model] [--write] <your request>"
allowed-tools: Bash(pwsh:*), Read, Glob, Grep
---
Run a task with the standalone Codex Free EN runtime.

Raw arguments: `$ARGUMENTS`

1. If the first token is a supported model or alias, use it. Otherwise use `deepseek-flash`.
2. If `--write` is present, pass `-Write`; otherwise keep the task read-only.
3. Pass the remaining text as `-Prompt`.
4. Run:

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode task -Model <model> -Repo "<cwd>" [-Write] -Prompt "<request>"
```

Return the Codex report and preserve any error or exit code. The helper uses `.codex-free` and never launches the Codex GUI.
