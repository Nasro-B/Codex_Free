# cx-free.ps1 — Bridge Claude Code -> Codex CLI on a FREE provider (DeepSeek/HF/NVIDIA via LiteLLM proxy).
# Modes: review, critique (adversarial review), task (free request), status (proxy/providers state).
# Usage:
#   pwsh -NoProfile -File cx-free.ps1 -Mode review   -Provider deepseek [-Base main] [-Repo <dir>]
#   pwsh -NoProfile -File cx-free.ps1 -Mode critique  -Provider hf       [-Base main] [-Repo <dir>]
#   pwsh -NoProfile -File cx-free.ps1 -Mode task      -Provider nvidia -Prompt "..." [-Write] [-Repo <dir>]
#   pwsh -NoProfile -File cx-free.ps1 -Mode status
param(
  [ValidateSet('review','critique','task','status')] [string]$Mode = 'review',
  [string]$Provider = 'deepseek',
  [string]$Base = '',
  [string]$Prompt = '',
  [switch]$Write,
  [string]$Repo = (Get-Location).Path
)
$ErrorActionPreference = 'Stop'
# Auto-detect the LiteLLM proxy folder (prefer the EN project, fall back to the FR one).
$proxyDir = @('C:\Serveurs\Codex Free\litellm-codex', 'C:\Serveurs\Codex Gratuit\litellm-codex') |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $proxyDir) { $proxyDir = 'C:\Serveurs\Codex Free\litellm-codex' }
function Test-ProxyUp { [bool](Get-NetTCPConnection -LocalPort 4000 -State Listen -ErrorAction SilentlyContinue) }

# --- status mode: report proxy + served models, without starting anything ---
if ($Mode -eq 'status') {
  $up = Test-ProxyUp
  Write-Host ("LiteLLM proxy (port 4000): " + $(if ($up) { 'UP' } else { 'DOWN (auto-starts on the next review/critique/task)' }))
  if ($up) {
    try {
      $m = Invoke-RestMethod -Uri 'http://127.0.0.1:4000/v1/models' -Headers @{ Authorization = 'Bearer sk-codex-local' } -TimeoutSec 8
      Write-Host ("Served models: " + (($m.data | ForEach-Object { $_.id }) -join ', '))
    } catch { Write-Host "  (/v1/models unreachable: $($_.Exception.Message))" }
  }
  Write-Host "cx-free providers: deepseek (default), deepseek-pro, hf, nvidia, glm"
  exit 0
}

# --- provider -> LiteLLM model name (must match the proxy config.yaml) ---
switch ($Provider.ToLower()) {
  { $_ -in 'deepseek','ds','deepseek-flash' } { $model = 'deepseek-flash' }
  'deepseek-pro'                              { $model = 'deepseek-pro' }
  { $_ -in 'hf','huggingface','qwen' }        { $model = 'hf' }
  { $_ -in 'nvidia','nvidia-deepseek','nv' }  { $model = 'nvidia-deepseek' }
  { $_ -in 'glm','nvidia-glm' }               { $model = 'nvidia-glm' }
  default { Write-Error "Unknown provider '$Provider' (deepseek|deepseek-pro|hf|nvidia|glm)"; exit 2 }
}

# --- ensure the LiteLLM proxy (port 4000) is up (start it detached otherwise) ---
if (-not (Test-ProxyUp)) {
  Write-Host "[cx-free] proxy 4000 is down -> starting..."
  $env:PYTHONUTF8 = '1'; $env:PYTHONIOENCODING = 'utf-8'
  if (Test-Path "$proxyDir\.env") {
    Get-Content "$proxyDir\.env" | ForEach-Object {
      if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
        $v = $matches[2].Trim().Trim('"').Trim("'"); if ($v) { Set-Item -Path "Env:$($matches[1])" -Value $v }
      }
    }
  }
  Start-Process litellm -ArgumentList '--config','config.yaml','--port','4000' -WorkingDirectory $proxyDir -WindowStyle Hidden | Out-Null
  for ($i = 0; $i -lt 45; $i++) { Start-Sleep -Seconds 1; if (Test-ProxyUp) { Start-Sleep -Seconds 2; break } }
}
if (-not (Test-ProxyUp)) { Write-Error "[cx-free] LiteLLM proxy (port 4000) unavailable."; exit 1 }

# --- build the prompt per mode ---
if ($Mode -eq 'review' -or $Mode -eq 'critique') {
  if ($Base) { $target = "Compare the branch against '$Base': ``git diff $Base...HEAD`` (+ ``git log --oneline $Base..HEAD``)." }
  else       { $target = "Review UNCOMMITTED work: ``git status --short --untracked-files=all``, then ``git diff`` and ``git diff --cached``, and read untracked files." }

  if ($Mode -eq 'review') {
    $promptText = @"
You are a senior code reviewer. Do a RIGOROUS code review of this repository's git changes, READ-ONLY (do not modify anything, do not commit).
$target
Read the relevant files for context, not just the diff. Only report REAL, verifiable issues (zero invention).
Output in English:
1. Summary (1-3 sentences).
2. Findings sorted from most to least severe: [CRITICAL|HIGH|MEDIUM|LOW] file:line - issue - proposed fix (code snippet if useful). Cover: bugs/logic, security (injection, secrets, authz, validation), edge cases and unhandled errors, regressions, concurrency, performance, then quality (readability, duplication, naming).
3. Final recommendation: OK to merge / fix before merge / blocking.
If nothing notable: say so clearly.
"@
  } else {
    $promptText = @"
You are an ADVERSARIAL code reviewer (red team). ACTIVELY hunt for the worst hidden bug in this repository's git changes, as if a production incident depended on it. READ-ONLY (do not modify anything, do not commit).
$target
Read the relevant files to understand the real execution context. For each finding, give a concrete reproduction scenario. Zero hallucination: every finding points to a real file:line; if not provable, mark it "to verify".
Output in English:
1. The most dangerous bug (if any): file:line, repro scenario, impact, fix.
2. Other findings sorted by severity: [CRITICAL|HIGH|MEDIUM|LOW] file:line - issue - repro - fix. Target: boundary values, null/undefined, network/timeout errors, races, await ordering, secrets, authz bypass, injection (SQL/command/prompt), dates/timezones, money/rounding, idempotency, retries.
3. Angles checked with no issue found (coverage).
4. Verdict: blocking / fix needed / OK.
"@
  }
  $sandbox = 'read-only'
} else {
  # task
  if (-not $Prompt) { Write-Error "[cx-free] -Prompt is required in task mode."; exit 2 }
  $promptText = $Prompt
  $sandbox = if ($Write) { 'workspace-write' } else { 'read-only' }
}

# --- run codex exec forced onto the free provider ---
$outFile = Join-Path $env:TEMP ("cx-free-" + [System.Guid]::NewGuid().ToString('N') + ".txt")
$logFile = Join-Path $env:TEMP ("cx-free-log-" + [System.Guid]::NewGuid().ToString('N') + ".txt")
Write-Host "[cx-free] mode=$Mode provider=$Provider model=$model sandbox=$sandbox repo=$Repo"
Write-Host "[cx-free] codex exec running (via LiteLLM proxy)..."
$codexArgs = @(
  'exec',
  '-c','model_provider=litellm',
  '-m', $model,
  '--sandbox', $sandbox,
  '--skip-git-repo-check',
  '--color','never',
  '-C', $Repo,
  '-o', $outFile,
  $promptText
)
# Empty/closed stdin (otherwise codex exec hangs on "Reading additional input from stdin...").
# All codex noise (MCP/skills logs) -> file; only the final report is shown.
$null | & codex @codexArgs *> $logFile
$code = $LASTEXITCODE

Write-Host ""
Write-Host "===== CODEX REPORT ($Provider / $model) ====="
if ((Test-Path $outFile) -and ((Get-Item $outFile).Length -gt 0)) {
  Get-Content -Raw $outFile
} else {
  Write-Host "(no final report captured)"
}
if ($code -ne 0) {
  Write-Host ""
  Write-Host "----- codex exited (code $code); log tail: -----"
  if (Test-Path $logFile) { Get-Content -Tail 15 $logFile }
}
Remove-Item $outFile, $logFile -ErrorAction SilentlyContinue
exit $code
