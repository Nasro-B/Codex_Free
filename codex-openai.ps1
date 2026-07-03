# codex-openai.ps1 (Codex Free - EN edition) - Launch Codex on this edition's OpenAI home.
# Switches CODEX_HOME to ~/.codex-free-openai then starts the desktop app.
# STANDALONE: never touches ~/.codex nor ~/.codex-openai (they belong to the FR launcher).
# Fresh home: the app will ask to sign in on first launch.
$OPENAI_HOME = "$env:USERPROFILE\.codex-free-openai"
$AUMID = "OpenAI.Codex_2p2nqsd0c76g0!App"

[Environment]::SetEnvironmentVariable('CODEX_HOME', $OPENAI_HOME, 'User')
$env:CODEX_HOME = $OPENAI_HOME
Write-Host "[ok] CODEX_HOME -> $OPENAI_HOME (Codex Free OpenAI home)" -ForegroundColor Green

# The app only reads CODEX_HOME at ITS startup: if an instance is running (e.g. free mode),
# Start-Process would merely refocus it -> close it first.
# Filters on the Store package path so the 'codex' CLI is NEVER killed.
$procs = Get-Process Codex -ErrorAction SilentlyContinue | Where-Object { $_.Path -match 'OpenAI\.Codex' }
if ($procs) {
  Write-Host "[..] Codex app already open - closing it so the new home applies..." -ForegroundColor Yellow
  $procs | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object { $null = $_.CloseMainWindow() }
  Start-Sleep -Seconds 2
  Get-Process Codex -ErrorAction SilentlyContinue | Where-Object { $_.Path -match 'OpenAI\.Codex' } | Stop-Process -Force -ErrorAction SilentlyContinue
  for ($i = 0; $i -lt 10; $i++) {
    if (-not (Get-Process Codex -ErrorAction SilentlyContinue | Where-Object { $_.Path -match 'OpenAI\.Codex' })) { break }
    Start-Sleep -Milliseconds 500
  }
  Write-Host "[ok] app closed" -ForegroundColor Green
}

Write-Host "[go] starting Codex on the Codex Free OpenAI home..." -ForegroundColor Cyan
Start-Process "shell:AppsFolder\$AUMID"
