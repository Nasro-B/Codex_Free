# codex-launch.ps1 (Codex Free - EN edition) - Pick a model, the Codex APPLICATION starts on it.
# DeepSeek/NVIDIA/HF/OpenAI/Ollama: external MCP servers preserved - the Codex app manages them,
# the codex_deepseek_fix callback reorders tool_calls for DeepSeek.
# Double-click the "Codex (menu)" shortcut.
#
# STANDALONE EDITION: uses its OWN Codex homes (.codex-free / .codex-free-openai).
# It NEVER touches ~/.codex nor ~/.codex-openai (those belong to the FR launcher in
# C:\Serveurs\Codex Gratuit). First run seeds a fresh config.toml automatically.

# Isolated Codex homes (dedicated to this edition):
#  - FREE_HOME   = free providers (LiteLLM/DeepSeek/NVIDIA/HF/Ollama) -> managed by THIS launcher
#  - OPENAI_HOME = OpenAI account home for this edition (fresh: the app will ask to sign in)
$FREE_HOME = "$env:USERPROFILE\.codex-free"
$OPENAI_HOME = "$env:USERPROFILE\.codex-free-openai"
$CONFIG = "$FREE_HOME\config.toml"
$SCRIPT_ROOT = $PSScriptRoot   # relocatable: every path derives from the script location
$PROXY = Join-Path $SCRIPT_ROOT "litellm-codex\start-litellm.ps1"
$MCPBAK = Join-Path $SCRIPT_ROOT "mcp-backup.toml"
$LITELLM_CATALOG = Join-Path $SCRIPT_ROOT "litellm-codex\litellm-models.json"
$AUMID = "OpenAI.Codex_2p2nqsd0c76g0!App"

# Switches the active Codex home (persistent User var = read by the Store app + the session)
function Set-CodexHome([string]$path) {
  [Environment]::SetEnvironmentVariable('CODEX_HOME', $path, 'User')
  $env:CODEX_HOME = $path
  Write-Host "[ok] CODEX_HOME -> $path" -ForegroundColor Green
}

# Closes the Codex app if it is already running: it only reads CODEX_HOME at ITS startup -
# otherwise Start-Process would merely refocus the open instance (still on the old home).
# Filters on the Store package path (OpenAI.Codex) so the 'codex' CLI is NEVER killed.
function Close-CodexApp {
  $procs = Get-Process Codex -ErrorAction SilentlyContinue | Where-Object { $_.Path -match 'OpenAI\.Codex' }
  if (-not $procs) { return }
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

# Seeds a fresh FREE_HOME config.toml on first run (standalone edition - no dependency on
# any pre-existing home). No secrets, no MCP servers, no account data in the seed.
function Ensure-FreeHomeConfig {
  if (Test-Path $CONFIG) { return }
  Write-Host "[..] first run: seeding $CONFIG" -ForegroundColor Yellow
  New-Item -ItemType Directory -Force -Path $FREE_HOME | Out-Null
  $seed = @"
# ~/.codex-free/config.toml - FREE-PROVIDERS HOME (Codex Free EN edition)
# Managed by $SCRIPT_ROOT\codex-launch.ps1. Independent from ~/.codex and ~/.codex-openai.
model = "deepseek-flash"
model_provider = "litellm"
model_reasoning_effort = "xhigh"
sandbox_mode = "danger-full-access"

[features]
multi_agent = true

[model_providers.litellm]
name = "LiteLLM"
base_url = "http://127.0.0.1:4001/v1/"
wire_api = "responses"
env_key = "LITELLM_KEY"

[model_providers.ollama-launch-codex-app]
name = "Ollama"
base_url = "http://127.0.0.1:11434/v1/"
wire_api = "responses"

[sandbox_workspace_write]
network_access = true
"@
  Set-Content -Path $CONFIG -Value $seed -Encoding utf8
  Write-Host "[ok] fresh config.toml created (the app will ask to sign in on first launch)" -ForegroundColor Green
}

# Basic checks
if (-not (Get-Command litellm -ErrorAction SilentlyContinue)) {
  Write-Host "[!] litellm is not installed. Install it: uv tool install litellm" -ForegroundColor Red
  exit 1
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host "[!] node is not installed (required by the 4001 bridge). Install Node.js." -ForegroundColor Red
  exit 1
}

function Port-Up([int]$p) {
  try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', $p); $t.Close(); return $true }
  catch { return $false }
}

function Ensure-Proxy {
  if ((Port-Up 4000) -and (Port-Up 4001)) { Write-Host "[ok] LiteLLM proxy + 4001 bridge already up" -ForegroundColor Green; return }
  Write-Host "[..] starting LiteLLM proxy + 4001 bridge..." -ForegroundColor Yellow
  $proxyDir = Split-Path $PROXY
  Start-Process pwsh -ArgumentList '-NoExit', '-File', "`"$PROXY`"" -WorkingDirectory $proxyDir -WindowStyle Minimized
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    if ((Port-Up 4000) -and (Port-Up 4001)) { Start-Sleep -Seconds 2; Write-Host "[ok] proxy ready (4000 + 4001)" -ForegroundColor Green; return }
  }
  Write-Host "[!] proxy not ready after 40s - check the minimized window" -ForegroundColor Red
}

# Writes the chosen model+provider as DEFAULT (the Codex app reads the default at startup)
function Set-Default([string]$model, [string]$provider) {
  $lines = Get-Content $CONFIG
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[') { break }
    if ($lines[$i] -match '^\s*model\s*=') { $lines[$i] = "model = `"$model`"" }
    if ($lines[$i] -match '^\s*model_provider\s*=') { $lines[$i] = "model_provider = `"$provider`"" }
  }
  Set-Content -Path $CONFIG -Value $lines -Encoding utf8
}

# Forces model_reasoning_effort="xhigh" on every launch.
# The app sometimes rewrites "max" (its UI setting), a value REJECTED by codex-cli 0.118+
# ("unknown variant max, expected ... xhigh") -> 'codex exec' would not start anymore.
function Set-Reasoning {
  $lines = Get-Content $CONFIG
  $done = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[') { break }
    if ($lines[$i] -match '^\s*model_reasoning_effort\s*=') { $lines[$i] = 'model_reasoning_effort = "xhigh"'; $done = $true }
  }
  if (-not $done) { $lines = @('model_reasoning_effort = "xhigh"') + $lines }
  Set-Content -Path $CONFIG -Value $lines -Encoding utf8
}

# Writes/refreshes model_catalog_json INSIDE the [model_providers.litellm] section (scoped catalog).
# IMPORTANT: TOML literal string with single quotes - a Windows path inside an unescaped
# double-quoted basic string ("C:\...") is invalid TOML (\S, \l...) = unreadable config.
function Set-LiteLLMScopedCatalog {
  $catalog = $LITELLM_CATALOG
  $lines = Get-Content $CONFIG
  $out = New-Object System.Collections.Generic.List[string]
  $inLite = $false
  $done = $false
  foreach ($ln in $lines) {
    if ($ln -match '^\s*\[model_providers\.litellm\]') { $inLite = $true; $done = $false; $out.Add($ln); continue }
    if ($inLite -and $ln -match '^\s*\[') {
      if (-not $done) { $out.Add("model_catalog_json = '$catalog'") }
      $inLite = $false
    }
    if ($inLite -and $ln -match '^\s*model_catalog_json\s*=') {
      $out.Add("model_catalog_json = '$catalog'")
      $done = $true
      continue
    }
    $out.Add($ln)
  }
  if ($inLite -and -not $done) { $out.Add("model_catalog_json = '$catalog'") }
  Set-Content -Path $CONFIG -Value $out -Encoding utf8
}

# Manages the GLOBAL model catalog (top-level model_catalog_json).
#  - openai  : NO global catalog -> the app shows its REAL OpenAI models.
#  - ollama  : global catalog = ollama-launch-models.json (ollama cloud models).
#  - litellm : no global -> the scoped catalog in [model_providers.litellm] wins.
function Set-Catalog([string]$provider) {
  if ($provider -eq 'litellm') { Set-LiteLLMScopedCatalog }
  $ollamaCat = "$FREE_HOME\ollama-launch-models.json"
  $lines = Get-Content $CONFIG
  $out = New-Object System.Collections.Generic.List[string]
  $inHeader = $true
  foreach ($ln in $lines) {
    if ($ln -match '^\s*\[') { $inHeader = $false }
    if ($inHeader -and $ln -match '^\s*model_catalog_json\s*=') { continue }  # drop any existing global catalog
    $out.Add($ln)
  }
  if ($provider -eq 'ollama-launch-codex-app') {
    $final = New-Object System.Collections.Generic.List[string]
    $added = $false
    foreach ($ln in $out) {
      $final.Add($ln)
      if (-not $added -and $ln -match '^\s*model_provider\s*=') {
        $final.Add("model_catalog_json = '$ollamaCat'")   # TOML literal string: no escaping
        $added = $true
      }
    }
    $out = $final
  }
  Set-Content -Path $CONFIG -Value $out -Encoding utf8
}

# Cuts external MCP servers (kept for completeness - not triggered in the current flow).
# IMPORTANT: node_repl is Codex's INTERNAL server - NEVER touched.
function Strip-MCP {
  $lines = Get-Content $CONFIG
  $out = New-Object System.Collections.Generic.List[string]
  $mcp = New-Object System.Collections.Generic.List[string]
  $inMcp = $false
  $mcpName = ""
  foreach ($ln in $lines) {
    if ($ln -match '^\s*\[mcp_servers\.([^\]]+)\]') { $inMcp = $true; $mcpName = $matches[1] }
    elseif ($ln -match '^\s*\[' -and $ln -notmatch '^\s*\[mcp_servers\.') { $inMcp = $false; $mcpName = "" }
    if ($inMcp -and $mcpName -notmatch '^node_repl') { $mcp.Add($ln) }
    else { $out.Add($ln) }
  }
  if ($mcp.Count -gt 0) {
    Set-Content -Path $MCPBAK -Value $mcp -Encoding utf8
    Set-Content -Path $CONFIG -Value $out -Encoding utf8
    Write-Host "[ok] $($mcp.Count) external MCP lines backed up" -ForegroundColor Yellow
  }
}

# Restores external MCP servers from mcp-backup.toml (if present in this folder).
# This standalone edition ships WITHOUT a backup file: add your own MCP servers in the
# app (or drop a mcp-backup.toml here) - nothing is inherited from the FR launcher.
function Restore-MCP {
  $hasExternal = Get-Content $CONFIG | Select-String '^\s*\[mcp_servers\.(?!node_repl)' -Quiet
  if ($hasExternal) { Write-Host "[i] external MCP already present" -ForegroundColor DarkYellow; return }
  if (-not (Test-Path $MCPBAK)) { Write-Host "[i] no mcp-backup.toml in this folder (nothing to restore)" -ForegroundColor DarkYellow; return }
  Add-Content -Path $CONFIG -Value "" -Encoding utf8
  Add-Content -Path $CONFIG -Value (Get-Content $MCPBAK) -Encoding utf8
  Write-Host "[ok] external MCP restored from mcp-backup.toml" -ForegroundColor Green
}

# Regenerates config.yaml: the '*' wildcard routes ANY model name sent by the Codex app
# (gpt-5.5, gpt-5-codex, upcoming gpt-5.x...) to the provider picked in the menu.
function Update-LiteLLMConfig([string]$menuModel) {
  $yamlPath = Join-Path (Split-Path $PROXY) 'config.yaml'

  $wcThink = $false
  $wcThinkDS = $false
  switch ($menuModel) {
    'deepseek-flash' { $wcModel = 'deepseek/deepseek-v4-flash'; $wcBase = 'https://api.deepseek.com'; $wcKey = 'DEEPSEEK_API_KEY' }
    'deepseek-v4-pro' { $wcModel = 'deepseek/deepseek-v4-pro'; $wcBase = 'https://api.deepseek.com'; $wcKey = 'DEEPSEEK_API_KEY'; $wcThinkDS = $true }
    'nvidia-deepseek' { $wcModel = 'nvidia_nim/deepseek-ai/deepseek-v4-pro'; $wcBase = 'https://integrate.api.nvidia.com/v1'; $wcKey = 'NVIDIA_API_KEY_DEEPSEEK'; $wcThink = $true }
    'nvidia-glm' { $wcModel = 'nvidia_nim/z-ai/glm-5.1'; $wcBase = 'https://integrate.api.nvidia.com/v1'; $wcKey = 'NVIDIA_API_KEY_GLM' }
    'hf' { $wcModel = 'huggingface/Qwen/Qwen3-Coder-Next'; $wcBase = ''; $wcKey = 'HF_TOKEN' }
    default { $wcModel = 'deepseek/deepseek-v4-flash'; $wcBase = 'https://api.deepseek.com'; $wcKey = 'DEEPSEEK_API_KEY' }
  }

  $wc = New-Object System.Collections.Generic.List[string]
  $wc.Add("      model: $wcModel")
  if ($wcBase) { $wc.Add("      api_base: $wcBase") }
  $wc.Add("      api_key: os.environ/$wcKey")
  $wc.Add("      use_chat_completions_api: true")
  if ($wcThink) { $wc.Add('      extra_body: {"chat_template_kwargs": {"thinking": false}}') }
  if ($wcThinkDS) { $wc.Add('      reasoning_effort: high'); $wc.Add('      extra_body: {"thinking": {"type": "enabled"}}') }
  $wcParams = $wc -join "`n"

  # real context windows: DeepSeek direct 1M, NVIDIA DeepSeek 1M, NVIDIA GLM-5.1 200k, HF/Qwen 256k.
  # model_info must be a SIBLING of litellm_params (indent 4) - nested inside, LiteLLM ignores it.
  $dsInfo = "    model_info:`n      context_window: 1048576`n      max_context_window: 1048576"
  $nvDsInfo = "    model_info:`n      context_window: 1048576`n      max_context_window: 1048576"
  $glmInfo = "    model_info:`n      context_window: 200000`n      max_context_window: 200000"
  $hfInfo = "    model_info:`n      context_window: 262144`n      max_context_window: 262144"

  $yaml = @"
# LiteLLM proxy - Responses API (Codex) -> chat/completions bridge (DeepSeek/NVIDIA/HF)
# AUTO-GENERATED by codex-launch.ps1 on every launch - do not edit by hand.
model_list:
  - model_name: deepseek-flash
    litellm_params:
      model: deepseek/deepseek-v4-flash
      api_base: https://api.deepseek.com
      api_key: os.environ/DEEPSEEK_API_KEY
      use_chat_completions_api: true
$dsInfo

  - model_name: deepseek-v4-pro
    litellm_params:
      model: deepseek/deepseek-v4-pro
      api_base: https://api.deepseek.com
      api_key: os.environ/DEEPSEEK_API_KEY
      use_chat_completions_api: true
      reasoning_effort: high
      extra_body: {"thinking": {"type": "enabled"}}
$dsInfo

  - model_name: nvidia-deepseek
    litellm_params:
      model: nvidia_nim/deepseek-ai/deepseek-v4-pro
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_API_KEY_DEEPSEEK
      use_chat_completions_api: true
      extra_body: {"chat_template_kwargs": {"thinking": false}}
$nvDsInfo

  - model_name: nvidia-glm
    litellm_params:
      model: nvidia_nim/z-ai/glm-5.1
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_API_KEY_GLM
      use_chat_completions_api: true
$glmInfo

  - model_name: hf
    litellm_params:
      model: huggingface/Qwen/Qwen3-Coder-Next
      api_key: os.environ/HF_TOKEN
      use_chat_completions_api: true
$hfInfo

  # catch-all: routes to the menu provider ($menuModel)
  - model_name: "*"
    litellm_params:
$wcParams

litellm_settings:
  drop_params: true
  callbacks: codex_deepseek_fix.handler

general_settings:
  master_key: sk-codex-local
"@

  Set-Content -Path $yamlPath -Value $yaml -Encoding utf8
  Write-Host "[ok] config.yaml regenerated: wildcard '*' -> $menuModel" -ForegroundColor Green
}

# Stops the proxy stack: LiteLLM (4000, + its parent pwsh window) and the Node bridge (4001)
function Stop-Proxy {
  if (-not ((Port-Up 4000) -or (Port-Up 4001))) { return }
  Write-Host "[..] stopping the existing proxy (config reload)..." -ForegroundColor Yellow
  foreach ($port in 4000, 4001) {
    try {
      $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
      foreach ($c in $conns) {
        $procId = $c.OwningProcess
        if (-not $procId -or $procId -eq $PID) { continue }
        $parent = $null
        if ($port -eq 4000) {
          $parent = (Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue).ParentProcessId
        }
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        if ($parent -and $parent -ne $PID) {
          $pp = Get-Process -Id $parent -ErrorAction SilentlyContinue
          if ($pp -and $pp.ProcessName -match 'pwsh|powershell') { Stop-Process -Id $parent -Force -ErrorAction SilentlyContinue }
        }
      }
    }
    catch { Write-Host "[!] error stopping proxy (port $port): $_" -ForegroundColor Red }
  }
  for ($i = 0; $i -lt 20; $i++) { if (-not ((Port-Up 4000) -or (Port-Up 4001))) { break }; Start-Sleep -Milliseconds 500 }
}

function Launch-App([string]$model, [string]$provider, [bool]$needProxy, [bool]$withMcp) {
  # --- OpenAI account: dedicated home for THIS edition (fresh home => the app asks to sign in) ---
  if ($provider -eq 'openai') {
    Set-CodexHome $OPENAI_HOME
    Close-CodexApp   # the app only reads CODEX_HOME at startup - close any open instance
    Write-Host "[go] Codex on this edition's OpenAI home (~/.codex-free-openai)..." -ForegroundColor Cyan
    Start-Process "shell:AppsFolder\$AUMID"
    return
  }
  # --- Free providers: dedicated home ~/.codex-free (managed only here) ---
  Set-CodexHome $FREE_HOME
  Ensure-FreeHomeConfig
  Set-Default $model $provider
  Set-Reasoning
  Set-Catalog $provider
  if ($withMcp) { Restore-MCP; Write-Host "[ok] MCP/memory ACTIVE" -ForegroundColor Green }
  else { Strip-MCP; Write-Host "[i] MCP cut for this session" -ForegroundColor DarkYellow }
  if ($needProxy) {
    Update-LiteLLMConfig $model
    Stop-Proxy
    Ensure-Proxy
  }
  Close-CodexApp   # the app only reads CODEX_HOME at startup - close any open instance
  Write-Host "[go] starting the Codex application (FREE) on '$model'..." -ForegroundColor Cyan
  Start-Process "shell:AppsFolder\$AUMID"
}

Write-Host ""
Write-Host "  ===== CODEX LAUNCHER (Free EN edition) =====" -ForegroundColor Cyan
Write-Host ""
Write-Host "   1) DeepSeek-V4-flash      fast, cheap                [MCP OK]  <- recommended"
Write-Host "   2) DeepSeek-V4-pro        stronger (your account)   [MCP OK]"
Write-Host "   3) NVIDIA DeepSeek-V4-pro unstable on NVIDIA side    [MCP OK]"
Write-Host "   4) NVIDIA GLM-5.1         free, fast                 [MCP OK]"
Write-Host "   5) HuggingFace Qwen3      free                       [MCP OK]"
Write-Host "   6) OpenAI account         home ~/.codex-free-openai  [account, MCP OK]"
Write-Host "   7) Ollama cloud           minimax (ollama signin)    [cloud]"
Write-Host ""
$c = Read-Host "  Your choice (1-7)"

switch ($c) {
  '1' { Launch-App "deepseek-flash"   "litellm"                  $true  $true  }
  '2' { Launch-App "deepseek-v4-pro"  "litellm"                  $true  $true  }
  '3' { Launch-App "nvidia-deepseek"  "litellm"                  $true  $true  }
  '4' { Launch-App "nvidia-glm"       "litellm"                  $true  $true  }
  '5' { Launch-App "hf"               "litellm"                  $true  $true  }
  '6' { Launch-App "gpt-5.5"          "openai"                   $false $true  }
  '7' { Launch-App "minimax-m3:cloud" "ollama-launch-codex-app"  $false $true  }
  default { Write-Host "Invalid choice. Restart the launcher." -ForegroundColor Red }
}
