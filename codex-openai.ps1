# codex-openai.ps1 — Launch Codex on YOUR OpenAI ACCOUNT (home ~/.codex, default, untouched).
# Switches CODEX_HOME to ~/.codex then starts the desktop app.
# Counterpart of the free launcher (codex-launch.ps1 -> home ~/.codex-openai).
$OPENAI_HOME = "$env:USERPROFILE\.codex"
$AUMID = "OpenAI.Codex_2p2nqsd0c76g0!App"

[Environment]::SetEnvironmentVariable('CODEX_HOME', $OPENAI_HOME, 'User')
$env:CODEX_HOME = $OPENAI_HOME
Write-Host "[ok] CODEX_HOME -> $OPENAI_HOME (OpenAI account)" -ForegroundColor Green
Write-Host "[go] starting Codex on your OpenAI account..." -ForegroundColor Cyan
Write-Host "    (if the app was already open, close it and relaunch to apply the home)" -ForegroundColor DarkGray
Start-Process "shell:AppsFolder\$AUMID"
