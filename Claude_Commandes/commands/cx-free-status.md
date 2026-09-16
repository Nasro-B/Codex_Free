---
description: Show Codex Free EN home and local proxy state
allowed-tools: Bash(pwsh:*)
---
Run:

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode status
```

Return the home, proxy ports, provider families and the fact that the GUI is not launched. This command does not start the proxy.
