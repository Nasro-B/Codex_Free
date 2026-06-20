# install.ps1 — Installs the cx-free commands into Claude Code (+ Codex custom prompts).
# Usage: pwsh -NoProfile -File "C:\Serveurs\Codex Free\Claude_Commandes\install.ps1"
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot

$claudeCmd     = Join-Path $env:USERPROFILE '.claude\commands'
$claudeScripts = Join-Path $env:USERPROFILE '.claude\scripts'
$codexPrompts  = Join-Path $env:USERPROFILE '.codex\prompts'
New-Item -ItemType Directory -Force $claudeCmd, $claudeScripts, $codexPrompts | Out-Null

# 1) Claude Code slash commands
Copy-Item "$src\commands\*.md" $claudeCmd -Force
# 2) PowerShell helper
Copy-Item "$src\scripts\*.ps1" $claudeScripts -Force
# 3) Codex app custom prompts (bonus: /cx-review, /cx-critique inside the Codex app)
if (Test-Path "$src\prompts") { Copy-Item "$src\prompts\*.md" $codexPrompts -Force }

Write-Host "[ok] Claude Code slash commands installed:" -ForegroundColor Green
Get-ChildItem "$claudeCmd\cx-free-*.md" | ForEach-Object { Write-Host ("   /" + $_.BaseName) }
Write-Host "[ok] Helper: $claudeScripts\cx-free.ps1" -ForegroundColor Green
Write-Host "[ok] Codex app prompts: /cx-review, /cx-critique" -ForegroundColor Green

# 4) Prerequisite checks
Write-Host "`n=== Prerequisites ===" -ForegroundColor Cyan
$codexOk = [bool](Get-Command codex -ErrorAction SilentlyContinue)
$litellmOk = [bool](Get-Command litellm -ErrorAction SilentlyContinue)
Write-Host ("  codex CLI    : " + $(if ($codexOk) { 'OK' } else { 'MISSING (npm i -g @openai/codex)' }))
Write-Host ("  litellm      : " + $(if ($litellmOk) { 'OK' } else { 'MISSING (uv tool install litellm)' }))
Write-Host ("  proxy 4000   : " + $(if (Get-NetTCPConnection -LocalPort 4000 -State Listen -ErrorAction SilentlyContinue) { 'UP' } else { 'DOWN (auto-starts on first call)' }))

# 5) Codex config reminder (the update removed "max")
$cfg = Join-Path $env:USERPROFILE '.codex\config.toml'
if ((Test-Path $cfg) -and (Select-String -Path $cfg -Pattern '^\s*model_reasoning_effort\s*=\s*"max"' -Quiet)) {
  Write-Host "`n[!] config.toml has model_reasoning_effort=\"max\" -> invalid since codex-cli 0.118.0." -ForegroundColor Yellow
  Write-Host "    Replace it with \"xhigh\" or 'codex exec' refuses to load the config." -ForegroundColor Yellow
}

Write-Host "`nRestart Claude Code (or reload the session) to see the /cx-free-* commands." -ForegroundColor Cyan
