# codex-launch.ps1 (Codex Free - EN edition) - Pick a model, the Codex APPLICATION starts on it.
# DeepSeek/NVIDIA/HF/OpenAI/Ollama: external MCP servers preserved - the Codex app manages them,
# the codex_deepseek_fix callback reorders tool_calls for DeepSeek.
# Double-click the "Codex (menu)" shortcut.
#
# STANDALONE EDITION: uses its OWN Codex homes (.codex-free / .codex-free-openai).
# It NEVER touches ~/.codex nor ~/.codex-openai (those belong to the FR launcher in
# C:\Serveurs\Codex Gratuit). First run seeds a fresh config.toml automatically.

[CmdletBinding()]
param(
  [ValidateSet('deepseek-flash', 'deepseek-v4-flash', 'deepseek-v4-pro', 'kimi-k2.6', 'kimi-k3', 'kimi-k2.7-code', 'kimi-k2.7-code-highspeed', 'mina-flash', 'mina-low', 'mina-full', 'nvidia-deepseek', 'nvidia-glm', 'hf', 'gpt-5.5', 'minimax-m3:cloud')]
  [string]$Model = '',
  [switch]$Headless,
  [switch]$Menu
)

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
  if (Test-Path $CONFIG) {
    $lines = Get-Content -LiteralPath $CONFIG
    $updated = $lines -replace 'http://127\.0\.0\.1:4001/v1/', 'http://127.0.0.1:4201/v1/'
    if (($updated -join "`n") -ne ($lines -join "`n")) {
      Set-Content -LiteralPath $CONFIG -Value $updated -Encoding utf8
      Write-Host '[ok] updated the isolated Codex Free EN bridge to port 4201' -ForegroundColor Green
    }
    return
  }
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
base_url = "http://127.0.0.1:4201/v1/"
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
    Write-Host "[!] node is not installed (required by the 4201 bridge). Install Node.js." -ForegroundColor Red
  exit 1
}

function Port-Up([int]$p) {
  try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', $p); $t.Close(); return $true }
  catch { return $false }
}

function Ensure-Proxy {
  if ((Port-Up 4200) -and (Port-Up 4201)) { Write-Host "[ok] LiteLLM proxy + 4201 bridge already up" -ForegroundColor Green; return }
  Write-Host "[..] starting LiteLLM proxy + 4201 bridge..." -ForegroundColor Yellow
  $proxyDir = Split-Path $PROXY
  $proxyOut = Join-Path $env:TEMP 'codex-free-en-proxy.out.log'
  $proxyErr = Join-Path $env:TEMP 'codex-free-en-proxy.err.log'
  Start-Process pwsh -ArgumentList '-NoExit', '-File', "`"$PROXY`"" -WorkingDirectory $proxyDir -WindowStyle Minimized -RedirectStandardOutput $proxyOut -RedirectStandardError $proxyErr
  $proxyStartupTimeoutSeconds = 240
  for ($i = 0; $i -lt $proxyStartupTimeoutSeconds; $i++) {
    Start-Sleep -Seconds 1
    if ((Port-Up 4200) -and (Port-Up 4201)) { Start-Sleep -Seconds 2; Write-Host "[ok] proxy ready (4200 + 4201)" -ForegroundColor Green; return }
  }
  throw "Codex Free EN proxy not ready after $proxyStartupTimeoutSeconds seconds on ports 4200 and 4201. Check the proxy process and provider environment file."
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
  $wcThinkKimi26 = $false
  $wcTemperature = $null
  switch ($menuModel) {
    'deepseek-flash' { $wcModel = 'deepseek/deepseek-v4-flash'; $wcBase = 'https://api.deepseek.com'; $wcKey = 'DEEPSEEK_API_KEY' }
    'deepseek-v4-flash' { $wcModel = 'deepseek/deepseek-v4-flash'; $wcBase = 'https://api.deepseek.com'; $wcKey = 'DEEPSEEK_API_KEY' }
    'deepseek-v4-pro' { $wcModel = 'deepseek/deepseek-v4-pro'; $wcBase = 'https://api.deepseek.com'; $wcKey = 'DEEPSEEK_API_KEY'; $wcThinkDS = $true }
    'kimi-k2.6' { $wcModel = 'moonshot/kimi-k2.6'; $wcBase = 'https://api.moonshot.ai/v1'; $wcKey = 'MOONSHOT_API_KEY'; $wcThinkKimi26 = $true }
    'kimi-k3' { $wcModel = 'moonshot/kimi-k3'; $wcBase = 'https://api.moonshot.ai/v1'; $wcKey = 'MOONSHOT_API_KEY' }
    'kimi-k2.7-code' { $wcModel = 'moonshot/kimi-k2.7-code'; $wcBase = 'https://api.moonshot.ai/v1'; $wcKey = 'MOONSHOT_API_KEY' }
    'kimi-k2.7-code-highspeed' { $wcModel = 'moonshot/kimi-k2.7-code-highspeed'; $wcBase = 'https://api.moonshot.ai/v1'; $wcKey = 'MOONSHOT_API_KEY'; $wcTemperature = 1 }
    'mina-flash' { $wcModel = 'openai/mina-flash'; $wcBase = 'https://api.cloudzir.com/v1'; $wcKey = 'CLOUDZIR_API_KEY' }
    'mina-low' { $wcModel = 'openai/mina-low'; $wcBase = 'https://api.cloudzir.com/v1'; $wcKey = 'CLOUDZIR_API_KEY' }
    'mina-full' { $wcModel = 'openai/mina-full'; $wcBase = 'https://api.cloudzir.com/v1'; $wcKey = 'CLOUDZIR_API_KEY' }
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
  if ($wcThinkKimi26) { $wc.Add('      extra_body: {"thinking": {"type": "enabled"}}') }
  if ($null -ne $wcTemperature) { $wc.Add("      temperature: $wcTemperature") }
  $wcParams = $wc -join "`n"

  # real context windows: DeepSeek direct 1M, NVIDIA DeepSeek 1M, NVIDIA GLM-5.1 200k, HF/Qwen 256k.
  # model_info must be a SIBLING of litellm_params (indent 4) - nested inside, LiteLLM ignores it.
  $dsInfo = "    model_info:`n      context_window: 1048576`n      max_context_window: 1048576"
  $nvDsInfo = "    model_info:`n      context_window: 1048576`n      max_context_window: 1048576"
  $glmInfo = "    model_info:`n      context_window: 200000`n      max_context_window: 200000"
  $hfInfo = "    model_info:`n      context_window: 262144`n      max_context_window: 262144"

  $yaml = @"
# LiteLLM proxy - Responses API (Codex) -> chat/completions bridge (DeepSeek/Kimi/Mina/NVIDIA/HF)
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

  - model_name: deepseek-v4-flash
    litellm_params:
      model: deepseek/deepseek-v4-flash
      api_base: https://api.deepseek.com
      api_key: os.environ/DEEPSEEK_API_KEY
      use_chat_completions_api: true
    model_info:
      context_window: 1048576
      max_context_window: 1048576

  - model_name: kimi-k2.6
    litellm_params:
      model: moonshot/kimi-k2.6
      api_base: https://api.moonshot.ai/v1
      api_key: os.environ/MOONSHOT_API_KEY
      use_chat_completions_api: true
      extra_body: {"thinking": {"type": "enabled"}}
    model_info:
      context_window: 262144
      max_context_window: 262144

  - model_name: kimi-k3
    litellm_params:
      model: moonshot/kimi-k3
      api_base: https://api.moonshot.ai/v1
      api_key: os.environ/MOONSHOT_API_KEY
      use_chat_completions_api: true
      reasoning_effort: max
    model_info:
      context_window: 1048576
      max_context_window: 1048576

  - model_name: kimi-k2.7-code
    litellm_params:
      model: moonshot/kimi-k2.7-code
      api_base: https://api.moonshot.ai/v1
      api_key: os.environ/MOONSHOT_API_KEY
      use_chat_completions_api: true
    model_info:
      context_window: 262144
      max_context_window: 262144

  - model_name: kimi-k2.7-code-highspeed
    litellm_params:
      model: moonshot/kimi-k2.7-code-highspeed
      api_base: https://api.moonshot.ai/v1
      api_key: os.environ/MOONSHOT_API_KEY
      use_chat_completions_api: true
      temperature: 1
    model_info:
      context_window: 262144
      max_context_window: 262144

  - model_name: mina-flash
    litellm_params:
      model: openai/mina-flash
      api_base: https://api.cloudzir.com/v1
      api_key: os.environ/CLOUDZIR_API_KEY
      use_chat_completions_api: true
    model_info:
      context_window: 64000
      max_context_window: 64000

  - model_name: mina-low
    litellm_params:
      model: openai/mina-low
      api_base: https://api.cloudzir.com/v1
      api_key: os.environ/CLOUDZIR_API_KEY
      use_chat_completions_api: true
    model_info:
      context_window: 128000
      max_context_window: 128000

  - model_name: mina-full
    litellm_params:
      model: openai/mina-full
      api_base: https://api.cloudzir.com/v1
      api_key: os.environ/CLOUDZIR_API_KEY
      use_chat_completions_api: true
    model_info:
      context_window: 256000
      max_context_window: 256000

  # catch-all: routes to the menu provider ($menuModel)
  - model_name: "*"
    litellm_params:
$wcParams

litellm_settings:
  drop_params: true
  callbacks: codex_deepseek_fix.handler
"@

  Set-Content -Path $yamlPath -Value $yaml -Encoding utf8
  Write-Host "[ok] config.yaml regenerated: wildcard '*' -> $menuModel" -ForegroundColor Green
}

# Stops the proxy stack: LiteLLM (4200, + its parent pwsh window) and the Node bridge (4201)
function Stop-Proxy {
  $proxyDir = Split-Path $PROXY
  $dirPattern = [regex]::Escape($proxyDir)
  $owned = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -match $dirPattern
  })
  if (-not ((Port-Up 4200) -or (Port-Up 4201)) -and $owned.Count -eq 0) { return }
  Write-Host "[..] stopping the existing proxy (config reload)..." -ForegroundColor Yellow
  $ids = @($owned.ProcessId | Sort-Object -Descending -Unique)
  foreach ($port in 4200, 4201) {
    $ids += @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess)
  }
  foreach ($procId in @($ids | Where-Object { $_ -and $_ -ne $PID } | Sort-Object -Descending -Unique)) {
    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
  }
  for ($i = 0; $i -lt 20; $i++) { if (-not ((Port-Up 4200) -or (Port-Up 4201))) { break }; Start-Sleep -Milliseconds 500 }
}

function Launch-App([string]$model, [string]$provider, [bool]$needProxy, [bool]$withMcp) {
  # --- OpenAI account: dedicated home for THIS edition (fresh home => the app asks to sign in) ---
  if ($provider -eq 'openai') {
    Set-CodexHome $OPENAI_HOME
    if ($Headless) {
      Write-Host "[ok] Codex Free EN OpenAI home prepared for headless use (~/.codex-free-openai)." -ForegroundColor Green
      return
    }
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
    $configPath = Join-Path (Split-Path $PROXY) 'config.yaml'
    $beforeHash = if (Test-Path -LiteralPath $configPath) { (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash } else { '' }
    Update-LiteLLMConfig $model
    $afterHash = if (Test-Path -LiteralPath $configPath) { (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash } else { '' }
    $proxyReady = (Port-Up 4200) -and (Port-Up 4201)
    if (-not $proxyReady -or $beforeHash -ne $afterHash) {
      Stop-Proxy
      Ensure-Proxy
    } else {
      Write-Host '[ok] reusing the existing Codex Free EN proxy (4200 + 4201)' -ForegroundColor Green
    }
  }
  if ($Headless) {
    Write-Host "[ok] Codex Free EN prepared for headless execution on '$model'." -ForegroundColor Green
    return
  }
  Close-CodexApp   # the app only reads CODEX_HOME at startup - close any open instance
  Write-Host "[go] starting the Codex application (FREE) on '$model'..." -ForegroundColor Cyan
  Start-Process "shell:AppsFolder\$AUMID"
}

if (-not $Model -or $Menu) {
  Write-Host ""
  Write-Host "  ===== CODEX LAUNCHER (Free EN edition) =====" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "   1) DeepSeek V4.1 Flash    fast, cheap                [MCP OK]  <- recommended"
  Write-Host "   2) DeepSeek V4 Pro        stronger                   [MCP OK]"
  Write-Host "   3) Kimi K2.6              reasoning, 256k            [MCP OK]"
  Write-Host "   4) Kimi K3                flagship, 1M               [MCP OK]"
  Write-Host "   5) Kimi K2.7 Code         coding, 256k               [MCP OK]"
  Write-Host "   6) Kimi K2.7 Code HS      high speed, 256k           [MCP OK]"
  Write-Host "   7) Mina Flash             CloudZIR, 64k               [MCP OK]"
  Write-Host "   8) Mina Low               CloudZIR, 128k              [MCP OK]"
  Write-Host "   9) Mina Full              CloudZIR, 256k              [MCP OK]"
  Write-Host "  10) NVIDIA DeepSeek V4 Pro unstable on NVIDIA side    [MCP OK]"
  Write-Host "  11) NVIDIA GLM-5.1         free, fast                 [MCP OK]"
  Write-Host "  12) HuggingFace Qwen3      free                       [MCP OK]"
  Write-Host "  13) OpenAI account         home ~/.codex-free-openai  [account, MCP OK]"
  Write-Host "  14) Ollama cloud           minimax (ollama signin)    [cloud]"
  Write-Host ""
  $choice = Read-Host "  Your choice (1-14)"
  $Model = switch ($choice) {
    '1' { 'deepseek-flash' }
    '2' { 'deepseek-v4-pro' }
    '3' { 'kimi-k2.6' }
    '4' { 'kimi-k3' }
    '5' { 'kimi-k2.7-code' }
    '6' { 'kimi-k2.7-code-highspeed' }
    '7' { 'mina-flash' }
    '8' { 'mina-low' }
    '9' { 'mina-full' }
    '10' { 'nvidia-deepseek' }
    '11' { 'nvidia-glm' }
    '12' { 'hf' }
    default { throw 'Invalid choice.' }
  }
}

switch ($Model) {
  'gpt-5.5' { Launch-App $Model 'openai' $false $true }
  'minimax-m3:cloud' { Launch-App $Model 'ollama-launch-codex-app' $false $true }
  default { Launch-App $Model 'litellm' $true $true }
}
