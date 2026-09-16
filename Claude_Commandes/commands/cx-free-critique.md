---
description: Adversarial read-only review through Codex Free EN
argument-hint: "[model] [base-ref]"
allowed-tools: Bash(pwsh:*), Read, Glob, Grep
---
Run an adversarial, read-only review through the standalone Codex Free EN runtime.

Raw arguments: `$ARGUMENTS`

1. Treat the first token as a model or alias when it matches one.
2. Treat the second token as an optional Git base reference, for example `main`.
3. Run:

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode critique -Model <model> -Repo "<cwd>" [-Base <base>]
```

Return the report from Codex Free EN, including concrete reproduction scenarios for findings. This command is read-only and does not launch the GUI.
