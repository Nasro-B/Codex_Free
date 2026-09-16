# cx-free.ps1 - Claude Code bridge to the standalone Codex Free EN edition.
# All modes use the isolated .codex-free home and the local 4200/4201 proxy.
[CmdletBinding()]
param(
  [ValidateSet('review', 'critique', 'task', 'agent', 'plan', 'status', 'models', 'health')]
  [string]$Mode = 'review',
  [Alias('Provider')]
  [string]$Model = 'deepseek-flash',
  [string]$Base = '',
  [string]$Prompt = '',
  [switch]$Write,
  [string]$Repo = (Get-Location).Path,
  [string]$Root = 'C:\Serveurs\Codex Free'
)

$ErrorActionPreference = 'Stop'
$freeHome = Join-Path $env:USERPROFILE '.codex-free'
$homeLauncher = Join-Path $Root 'codex-launch.ps1'
$configPath = Join-Path $freeHome 'config.toml'
$catalogPath = Join-Path $Root 'litellm-codex\litellm-models.json'
$envFile = Join-Path $Root 'litellm-codex\.env'
$bridgeModelsUri = 'http://127.0.0.1:4201/v1/models'

$targetModels = [ordered]@{
  'kimi-k2.6' = [pscustomobject]@{ Label = 'Kimi K2.6'; Context = 262144 }
  'kimi-k2.7-code' = [pscustomobject]@{ Label = 'Kimi K2.7 Code'; Context = 262144 }
  'kimi-k2.7-code-highspeed' = [pscustomobject]@{ Label = 'Kimi K2.7 Code HighSpeed'; Context = 262144 }
  'kimi-k3' = [pscustomobject]@{ Label = 'Kimi K3'; Context = 1048576 }
  'deepseek-v4-pro' = [pscustomobject]@{ Label = 'DeepSeek V4 Pro'; Context = 1048576 }
  'deepseek-v4-flash' = [pscustomobject]@{ Label = 'DeepSeek V4 Flash legacy'; Context = 1048576 }
  'deepseek-flash' = [pscustomobject]@{ Label = 'DeepSeek V4.1 Flash'; Context = 1048576 }
  'mina-flash' = [pscustomobject]@{ Label = 'Mina Flash (CloudZIR)'; Context = 64000 }
  'mina-low' = [pscustomobject]@{ Label = 'Mina Low (CloudZIR)'; Context = 128000 }
  'mina-full' = [pscustomobject]@{ Label = 'Mina Full (CloudZIR)'; Context = 256000 }
  'nvidia-deepseek' = [pscustomobject]@{ Label = 'NVIDIA DeepSeek V4 Pro'; Context = 1048576 }
  'nvidia-glm' = [pscustomobject]@{ Label = 'NVIDIA GLM-5.1'; Context = 200000 }
  'hf' = [pscustomobject]@{ Label = 'HuggingFace Qwen3 Coder Next'; Context = 262144 }
}

$aliases = @{
  'deepseek' = 'deepseek-flash'
  'ds' = 'deepseek-flash'
  'deepseek-pro' = 'deepseek-v4-pro'
  'deepseek-v4.1-flash' = 'deepseek-flash'
  'kimi' = 'kimi-k2.6'
  'kimi-2.6' = 'kimi-k2.6'
  'kimi-3' = 'kimi-k3'
  'nvidia' = 'nvidia-deepseek'
  'glm' = 'nvidia-glm'
  'huggingface' = 'hf'
  'qwen' = 'hf'
}

$inputModel = $Model.Trim().ToLowerInvariant()
if ($aliases.ContainsKey($inputModel)) {
  $inputModel = $aliases[$inputModel]
}
if (-not $targetModels.Contains($inputModel)) {
  throw "Model '$Model' is not available in Codex Free EN. Use /cx-free-models for the list."
}
$resolvedModel = $inputModel

function Import-DotEnv([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Provider environment file not found: $Path. Copy .env.example to .env and fill it locally."
  }
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
      $name = $Matches[1]
      $value = $Matches[2].Trim().Trim('"').Trim("'")
      if (-not [string]::IsNullOrWhiteSpace($value) -and $value -notmatch '^replace-with-') {
        Set-Item -Path "Env:$name" -Value $value
      }
    }
  }
}

function Test-PortUp([int]$Port) {
  return [bool](Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Get-Catalog() {
  if (-not (Test-Path -LiteralPath $catalogPath)) {
    throw "Model catalogue not found: $catalogPath"
  }
  return Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
}

function Show-Models() {
  $catalog = Get-Catalog
  $rows = foreach ($name in $targetModels.Keys) {
    $spec = $targetModels[$name]
    $entry = @($catalog.models | Where-Object { $_.slug -eq $name } | Select-Object -First 1)
    $context = if ($entry) { [int]$entry.context_window } else { $spec.Context }
    $modalities = if ($entry -and $entry.input_modalities) { (@($entry.input_modalities) -join ',') } else { 'text' }
    [pscustomobject]@{
      Model = $name
      Label = $spec.Label
      Context = $context
      Modalities = $modalities
      State = if ($entry -and $entry.visibility -eq 'list') { 'configured' } else { 'missing' }
    }
  }
  $rows | Format-Table -AutoSize
}

function Start-CodexFreeHeadless() {
  Import-DotEnv $envFile
  $env:CODEX_HOME = $freeHome
  $proxyReady = (Test-PortUp 4200) -and (Test-PortUp 4201)
  $bridgeConfigured = (Test-Path -LiteralPath $configPath) -and [bool](Select-String -LiteralPath $configPath -Pattern '127\.0\.0\.1:4201' -Quiet -ErrorAction SilentlyContinue)
  if ($proxyReady -and $bridgeConfigured) {
    Write-Host '[ok] reusing the existing Codex Free EN headless runtime (4200 + 4201).'
    return
  }
  if (-not (Test-Path -LiteralPath $homeLauncher)) {
    throw "Codex Free launcher not found: $homeLauncher"
  }
  $pwsh = Get-Command pwsh -ErrorAction Stop
  $pwshPath = if ($pwsh.Source) { $pwsh.Source } else { $pwsh.Path }
  $launcherOutput = @(& $pwshPath -NoLogo -NoProfile -File $homeLauncher -Model $resolvedModel -Headless 2>&1)
  $launcherCode = $LASTEXITCODE
  if ($launcherCode -ne 0) {
    $tail = ($launcherOutput | Select-Object -Last 15) -join [Environment]::NewLine
    throw ("Codex Free proxy preparation failed (code {0}).{1}{2}" -f $launcherCode, [Environment]::NewLine, $tail)
  }
  if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Codex Free configuration was not created: $configPath"
  }
}

function Show-Status() {
  Import-DotEnv $envFile
  Write-Host "Codex Free EN home : $freeHome"
  Write-Host ("LiteLLM proxy 4200 : " + $(if (Test-PortUp 4200) { 'UP' } else { 'DOWN' }))
  Write-Host ("API bridge 4201    : " + $(if (Test-PortUp 4201) { 'UP' } else { 'DOWN' }))
  Write-Host "Providers           : DeepSeek, Kimi, Mina, NVIDIA, HuggingFace"
  Write-Host "GUI is not launched by cx-free commands."
}

function Test-Health() {
  Start-CodexFreeHeadless
  $headers = @{}
  if (-not [string]::IsNullOrWhiteSpace($env:LITELLM_KEY)) {
    $headers.Authorization = "Bearer $($env:LITELLM_KEY)"
  }
  $response = Invoke-RestMethod -Uri $bridgeModelsUri -Headers $headers -TimeoutSec 15
  $ids = @($response.data | ForEach-Object { $_.id } | Where-Object { $_ -ne '*' })
  [pscustomobject]@{
    Home = $freeHome
    Proxy4200 = if (Test-PortUp 4200) { 'UP' } else { 'DOWN' }
    Bridge4201 = if (Test-PortUp 4201) { 'UP' } else { 'DOWN' }
    SelectedModel = $resolvedModel
    SelectedModelVisible = ($ids -contains $resolvedModel)
    ModelCount = $ids.Count
  } | Format-List
}

function Get-ReviewPrompt([string]$ReviewMode) {
  $target = if ($Base) {
    "Compare the current branch with '$Base' using git diff $Base...HEAD and git log --oneline $Base..HEAD."
  } else {
    'Review uncommitted work with git status, git diff, git diff --cached and relevant untracked files.'
  }
  if ($ReviewMode -eq 'review') {
    return @"
You are a senior code reviewer. Perform a rigorous read-only review of this repository. $target
Read the relevant files for context, not only the diff. Report only real, verifiable issues.
Answer in English:
1. Short summary.
2. Findings ordered by severity: [CRITICAL|HIGH|MEDIUM|LOW] file:line - issue - proposed fix.
3. Cover bugs, security, network errors, edge cases, concurrency, performance and regressions.
4. Verdict: OK, fixes needed or blocking.
"@
  }
  return @"
You are an adversarial code reviewer. Actively seek the most dangerous real bug in this repository. Work read-only. $target
For every finding, give a concrete reproduction scenario, impact and fix. Do not invent findings: point to real files and lines.
Answer in English:
1. Most dangerous bug, if any.
2. Other findings ordered by severity.
3. Checked angles with no issue found.
4. Verdict: blocking, fixes needed or OK.
"@
}

function Get-PlanPrompt() {
  $request = if ([string]::IsNullOrWhiteSpace($Prompt)) {
    'Analyze the current repository and propose the next highest-priority improvements.'
  } else {
    $Prompt
  }
  return @"
You are a pragmatic software architect. Analyze this repository read-only and prepare an implementation plan for:
$request
Inspect the real code, tests and relevant configuration. Do not modify files and do not invent endpoints.
Answer in English with: observed context, proven problems, numbered plan, files, tests, risks and acceptance criteria.
"@
}

function Get-AgentPrompt() {
  $mission = if ([string]::IsNullOrWhiteSpace($Prompt)) {
    'Inspect the repository and propose the next useful action.'
  } else {
    $Prompt
  }
  return @"
You are a Codex agent delegated from Claude Code. Work methodically in the current repository and do not invent code or architecture.
Mission:
$mission

Inspect the real context first. Run useful checks. In read-only mode, do not modify anything. If workspace write is authorized, apply only necessary changes and verify them with focused tests. Return an English report with files changed, commands run, results, risks and remaining work.
"@
}

function Invoke-Codex([string]$RunMode) {
  if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw 'Codex CLI is not available in PATH.'
  }
  if ($RunMode -in @('task', 'agent') -and [string]::IsNullOrWhiteSpace($Prompt)) {
    throw "Mode $RunMode requires -Prompt."
  }
  Start-CodexFreeHeadless
  $env:CODEX_HOME = $freeHome
  $sandbox = if ($RunMode -in @('task', 'agent') -and $Write) { 'workspace-write' } else { 'read-only' }
  $promptText = switch ($RunMode) {
    'review' { Get-ReviewPrompt 'review' }
    'critique' { Get-ReviewPrompt 'critique' }
    'plan' { Get-PlanPrompt }
    'agent' { Get-AgentPrompt }
    default { $Prompt }
  }
  $suffix = [Guid]::NewGuid().ToString('N')
  $outFile = Join-Path $env:TEMP ("cx-free-en-$suffix.txt")
  $logFile = Join-Path $env:TEMP ("cx-free-en-$suffix.log")
  $codexCommand = Get-Command codex -ErrorAction Stop
  $codexPath = if ($codexCommand.Source) { $codexCommand.Source } else { $codexCommand.Path }
  $codexArguments = @(
    'exec',
    '-c', 'model_provider=litellm',
    '-m', $resolvedModel,
    '--sandbox', $sandbox,
    '--skip-git-repo-check',
    '--color', 'never',
    '-C', $Repo,
    '-o', $outFile,
    $promptText
  )
  Write-Host "[cx-free] Codex Free EN: model=$resolvedModel sandbox=$sandbox repo=$Repo"
  Write-Host '[cx-free] running headless through proxy 4200/4201...'
  $code = 1
  try {
    $runnerPath = $codexPath
    $runnerArguments = New-Object System.Collections.Generic.List[string]
    if ($codexPath -match '\.ps1$') {
      $pwshCommand = Get-Command pwsh -ErrorAction Stop
      $runnerPath = if ($pwshCommand.Source) { $pwshCommand.Source } else { $pwshCommand.Path }
      [void]$runnerArguments.Add('-NoLogo')
      [void]$runnerArguments.Add('-NoProfile')
      [void]$runnerArguments.Add('-File')
      [void]$runnerArguments.Add($codexPath)
    }
    foreach ($argument in $codexArguments) { [void]$runnerArguments.Add([string]$argument) }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $runnerPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    foreach ($argument in $runnerArguments) { [void]$startInfo.ArgumentList.Add($argument) }
    $child = [System.Diagnostics.Process]::new()
    $child.StartInfo = $startInfo
    if (-not $child.Start()) { throw 'Codex child process could not start.' }
    $child.WaitForExit()
    $code = $child.ExitCode
    $child.Dispose()
    Write-Host ''
    Write-Host "===== CODEX FREE EN REPORT ($resolvedModel) ====="
    if ((Test-Path -LiteralPath $outFile) -and ((Get-Item -LiteralPath $outFile).Length -gt 0)) {
      Get-Content -Raw -LiteralPath $outFile
    } else {
      Write-Host '(no final report captured)'
    }
    if ($code -ne 0) {
      Write-Host ''
      Write-Host "----- codex exited with code $code; log tail -----"
      if (Test-Path -LiteralPath $logFile) {
        Get-Content -Tail 20 -LiteralPath $logFile
      }
    }
  } finally {
    Remove-Item -LiteralPath $outFile, $logFile -ErrorAction SilentlyContinue
  }
  exit $code
}

switch ($Mode) {
  'status' { Show-Status; exit 0 }
  'models' { Show-Models; exit 0 }
  'health' { Test-Health; exit 0 }
  default { Invoke-Codex $Mode }
}
