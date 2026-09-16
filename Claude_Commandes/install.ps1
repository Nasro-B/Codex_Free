# install.ps1 - Installs the cx-free commands into Claude Code and the standalone Codex Free EN home.
# Usage: pwsh -NoProfile -File "C:\Serveurs\Codex Free\Claude_Commandes\install.ps1"
[CmdletBinding()]
param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot

$claudeCmd     = Join-Path $env:USERPROFILE '.claude\commands'
$claudeScripts = Join-Path $env:USERPROFILE '.claude\scripts'
$codexPrompts  = Join-Path $env:USERPROFILE '.codex-free\prompts'
New-Item -ItemType Directory -Force $claudeCmd, $claudeScripts, $codexPrompts | Out-Null

# 1) Claude Code slash commands
Copy-Item "$src\commands\*.md" $claudeCmd -Force
# 2) PowerShell helper, with the actual repository root embedded for portable installs
$helperSource = Join-Path $src 'scripts\cx-free.ps1'
$helperDestination = Join-Path $claudeScripts 'cx-free.ps1'
$helperText = Get-Content -LiteralPath $helperSource -Raw
$helperText = $helperText.Replace("[string]`$Root = 'C:\Serveurs\Codex Free'", "[string]`$Root = '$Root'")
Set-Content -LiteralPath $helperDestination -Value $helperText -Encoding utf8
# 3) Codex Free EN custom prompts, never the original .codex home.
if (Test-Path "$src\prompts") { Copy-Item "$src\prompts\*.md" $codexPrompts -Force }

Write-Host "[ok] Claude Code slash commands installed:" -ForegroundColor Green
Get-ChildItem "$claudeCmd\cx-free-*.md" | ForEach-Object { Write-Host ("   /" + $_.BaseName) }
Write-Host "[ok] Helper: $claudeScripts\cx-free.ps1" -ForegroundColor Green
Write-Host "[ok] Codex Free EN prompts: $codexPrompts" -ForegroundColor Green

# 4) Prerequisite checks
Write-Host "`n=== Prerequisites ===" -ForegroundColor Cyan
$codexOk = [bool](Get-Command codex -ErrorAction SilentlyContinue)
$litellmOk = [bool](Get-Command litellm -ErrorAction SilentlyContinue)
Write-Host ("  codex CLI    : " + $(if ($codexOk) { 'OK' } else { 'MISSING (npm i -g @openai/codex)' }))
Write-Host ("  litellm      : " + $(if ($litellmOk) { 'OK' } else { 'MISSING (uv tool install litellm)' }))
Write-Host ("  proxy 4200/4201: " + $(if ((Get-NetTCPConnection -LocalPort 4200 -State Listen -ErrorAction SilentlyContinue) -and (Get-NetTCPConnection -LocalPort 4201 -State Listen -ErrorAction SilentlyContinue)) { 'UP' } else { 'DOWN (auto-starts on first call)' }))

# 5) Codex config reminder (the update removed "max")
$cfg = Join-Path $env:USERPROFILE '.codex-free\config.toml'
if ((Test-Path $cfg) -and (Select-String -Path $cfg -Pattern '^\s*model_reasoning_effort\s*=\s*"max"' -Quiet)) {
  Write-Host "`n[!] config.toml has model_reasoning_effort=\"max\" -> invalid since codex-cli 0.118.0." -ForegroundColor Yellow
  Write-Host "    Replace it with \"xhigh\" or 'codex exec' refuses to load the config." -ForegroundColor Yellow
}

Write-Host "`nRestart Claude Code (or reload the session) to see the /cx-free-* commands." -ForegroundColor Cyan
