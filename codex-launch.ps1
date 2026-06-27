# codex-launch.ps1 — Pick a model, the Codex APPLICATION starts on it.
# DeepSeek/NVIDIA/HF (chat API): MCP auto-cut (incompatible). OpenAI/Ollama: MCP active.
# Double-click the "Codex (menu)" shortcut.

$CONFIG = "$env:USERPROFILE\.codex\config.toml"
$PROXY = "C:\Serveurs\Codex Free\litellm-codex\start-litellm.ps1"
$MCPBAK = "C:\Serveurs\Codex Free\mcp-backup.toml"
$AUMID = "OpenAI.Codex_2p2nqsd0c76g0!App"

# Basic checks
if (-not (Test-Path $CONFIG)) {
  Write-Host "[!] config.toml not found: $CONFIG" -ForegroundColor Red
  Write-Host "    Launch the Codex app once first to generate it." -ForegroundColor Yellow
  exit 1
}
if (-not (Get-Command litellm -ErrorAction SilentlyContinue)) {
  Write-Host "[!] litellm not installed. Install it: uv tool install litellm" -ForegroundColor Red
  exit 1
}

function Port-Up([int]$p) {
  try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', $p); $t.Close(); return $true }
  catch { return $false }
}

function Ensure-Proxy {
  if (Port-Up 4000) { Write-Host "[ok] LiteLLM proxy already running" -ForegroundColor Green; return }
  Write-Host "[..] starting LiteLLM proxy..." -ForegroundColor Yellow
  $proxyDir = Split-Path $PROXY
  Start-Process pwsh -ArgumentList '-NoExit', '-File', "`"$PROXY`"" -WorkingDirectory $proxyDir -WindowStyle Minimized
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    if (Port-Up 4000) { Start-Sleep -Seconds 2; Write-Host "[ok] proxy ready" -ForegroundColor Green; return }
  }
  Write-Host "[!] proxy not ready after 40s — check the minimized window" -ForegroundColor Red
}

# Writes the selected model+provider as DEFAULT (the Codex app reads the default on startup)
function Set-Default([string]$model, [string]$provider) {
  $lines = Get-Content $CONFIG
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[') { break }
    if ($lines[$i] -match '^\s*model\s*=') { $lines[$i] = "model = `"$model`"" }
    if ($lines[$i] -match '^\s*model_provider\s*=') { $lines[$i] = "model_provider = `"$provider`"" }
  }
  Set-Content -Path $CONFIG -Value $lines -Encoding utf8
}

# Manages the GLOBAL model catalog (top-level model_catalog_json).
#  - openai  : NO global catalog -> the Codex app shows its REAL OpenAI models (gpt-5.5, gpt-5-codex...).
#  - ollama  : global catalog = ollama-launch-models.json (ollama cloud models).
#  - litellm : no global -> the scoped [model_providers.litellm] catalog is authoritative.
# Without this, the global ollama-launch-models.json hid the OpenAI models behind deepseek/nvidia/hf.
function Set-Catalog([string]$provider) {
  $ollamaCat = "$env:USERPROFILE\.codex\ollama-launch-models.json"
  $lines = Get-Content $CONFIG
  $out = New-Object System.Collections.Generic.List[string]
  $inHeader = $true
  foreach ($ln in $lines) {
    if ($ln -match '^\s*\[') { $inHeader = $false }
    if ($inHeader -and $ln -match '^\s*model_catalog_json\s*=') { continue }  # remove any existing global catalog
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

# Removes external MCP servers (incompatible with chat APIs like DeepSeek)
# IMPORTANT: node_repl is Codex's INTERNAL server — we NEVER touch it.
function Strip-MCP {
  $lines = Get-Content $CONFIG
  $out = New-Object System.Collections.Generic.List[string]
  $mcp = New-Object System.Collections.Generic.List[string]
  $inMcp = $false
  $mcpName = ""
  foreach ($ln in $lines) {
    if ($ln -match '^\s*\[mcp_servers\.([^\]]+)\]') { $inMcp = $true; $mcpName = $matches[1] }
    elseif ($ln -match '^\s*\[' -and $ln -notmatch '^\s*\[mcp_servers\.') { $inMcp = $false; $mcpName = "" }
    # node_repl (+ node_repl.env) = Codex internal server → keep in config
    if ($inMcp -and $mcpName -notmatch '^node_repl') { $mcp.Add($ln) }
    else { $out.Add($ln) }
  }
  if ($mcp.Count -gt 0) {
    Set-Content -Path $MCPBAK -Value $mcp -Encoding utf8
    Set-Content -Path $CONFIG -Value $out -Encoding utf8
    Write-Host "[ok] $($mcp.Count) external MCP lines saved" -ForegroundColor Yellow
  }
}

# Restores external MCP servers (for OpenAI/Ollama which support them)
# IMPORTANT: we ignore node_repl in the check — it is always present (injected by Codex).
function Restore-MCP {
  # Check if EXTERNAL servers (excluding node_repl) are already present
  $hasExternal = Get-Content $CONFIG | Select-String '^\s*\[mcp_servers\.(?!node_repl)' -Quiet
  if ($hasExternal) { Write-Host "[i] external MCP already present" -ForegroundColor DarkYellow; return }
  if (-not (Test-Path $MCPBAK)) { Write-Host "[!] mcp-backup.toml not found" -ForegroundColor Red; return }
  Add-Content -Path $CONFIG -Value "" -Encoding utf8
  Add-Content -Path $CONFIG -Value (Get-Content $MCPBAK) -Encoding utf8
  Write-Host "[ok] external MCP restored from mcp-backup.toml" -ForegroundColor Green
}

# Regenerates config.yaml: the wildcard '*' routes ANY model name sent by the app
# Codex (gpt-5.5, gpt-5-codex, upcoming gpt-5.x...) to the provider chosen in the menu.
# => the menu is the source of truth, no matter what the app's model selector shows.
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

  # wildcard params (api_base optional: HF doesn't have one; extra_body thinking:false for deepseek-v4-pro NVIDIA)
  $wc = New-Object System.Collections.Generic.List[string]
  $wc.Add("      model: $wcModel")
  if ($wcBase) { $wc.Add("      api_base: $wcBase") }
  $wc.Add("      api_key: os.environ/$wcKey")
  $wc.Add("      use_chat_completions_api: true")
  if ($wcThink) { $wc.Add('      extra_body: {"chat_template_kwargs": {"thinking": false}}') }
  if ($wcThinkDS) { $wc.Add('      reasoning_effort: high'); $wc.Add('      extra_body: {"thinking": {"type": "enabled"}}') }
  $wcParams = $wc -join "`n"

  # actual contexts: DeepSeek 1M, NVIDIA/HF 256k — exposed via model_info so that
  # Codex receives them when it queries /v1/models (otherwise defaults to 65536 -> compact 62000).
  $dsInfo = "      model_info:`n        context_window: 1048576`n        max_context_window: 1048576"
  $nvInfo = "      model_info:`n        context_window: 262144`n        max_context_window: 262144"
  $hfInfo = "      model_info:`n        context_window: 262144`n        max_context_window: 262144"

  $yaml = @"
# LiteLLM proxy — Responses API (Codex) -> chat/completions (DeepSeek/NVIDIA/HF) bridge
# AUTO-GENERATED by codex-launch.ps1 on each launch — do not edit manually.
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
$nvInfo

  - model_name: nvidia-glm
    litellm_params:
      model: nvidia_nim/z-ai/glm-5.1
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_API_KEY_GLM
      use_chat_completions_api: true
$nvInfo

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

# Stops the LiteLLM proxy (process listening on 4000 + its parent pwsh window)
function Stop-Proxy {
  if (-not (Port-Up 4000)) { return }
  Write-Host "[..] stopping existing LiteLLM proxy (config reload)..." -ForegroundColor Yellow
  try {
    $conns = Get-NetTCPConnection -LocalPort 4000 -State Listen -ErrorAction SilentlyContinue
    foreach ($c in $conns) {
      $procId = $c.OwningProcess
      if (-not $procId) { continue }
      $parent = (Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue).ParentProcessId
      Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
      if ($parent) {
        $pp = Get-Process -Id $parent -ErrorAction SilentlyContinue
        if ($pp -and $pp.ProcessName -match 'pwsh|powershell') { Stop-Process -Id $parent -Force -ErrorAction SilentlyContinue }
      }
    }
  }
  catch { Write-Host "[!] error stopping proxy: $_" -ForegroundColor Red }
  for ($i = 0; $i -lt 20; $i++) { if (-not (Port-Up 4000)) { break }; Start-Sleep -Milliseconds 500 }
}

function Launch-App([string]$model, [string]$provider, [bool]$needProxy, [bool]$withMcp) {
  Set-Default $model $provider
  Set-Catalog $provider   # catalog: openai=native, ollama=ollama-launch-models.json, litellm=scoped
  if ($withMcp) { Restore-MCP; Write-Host "[ok] MCP/memory ACTIVE" -ForegroundColor Green }
  else { Strip-MCP; Write-Host "[i] MCP disabled for this session (the chat API doesn't support them)" -ForegroundColor DarkYellow }
  if ($needProxy) {
    Update-LiteLLMConfig $model   # menu = source of truth: wildcard points to this provider
    Stop-Proxy                    # force LiteLLM to reload the new config
    Ensure-Proxy
  }
  Write-Host "[go] starting the Codex application on '$model'..." -ForegroundColor Cyan
  Write-Host "    (if the app was already open, close it and relaunch to apply)" -ForegroundColor DarkGray
  Start-Process "shell:AppsFolder\$AUMID"
}

Write-Host ""
Write-Host "  ===== CODEX LAUNCHER =====" -ForegroundColor Cyan
Write-Host ""
Write-Host "   1) DeepSeek-V4-flash      fast, cheap               [MCP OK]  <- recommended"
Write-Host "   2) DeepSeek-V4-pro        more powerful (your key)  [MCP OK]"
Write-Host "   3) NVIDIA DeepSeek-V4-pro unstable on NVIDIA side   [MCP OK]"
Write-Host "   4) NVIDIA GLM-5.1         free, fast                [MCP OK]"
Write-Host "   5) HuggingFace Qwen3.6    free                      [MCP OK]"
Write-Host "   6) My OpenAI account      gpt-5-codex               [account, MCP OK]"
Write-Host "   7) Ollama cloud           minimax (ollama signin)   [cloud, MCP OK]"
Write-Host ""
$c = Read-Host "  Your choice (1-7)"

switch ($c) {
  '1' { Launch-App "deepseek-flash"   "litellm"                  $true  $true }
  '2' { Launch-App "deepseek-v4-pro"     "litellm"                  $true  $true }
  '3' { Launch-App "nvidia-deepseek"  "litellm"                  $true  $true }
  '4' { Launch-App "nvidia-glm"       "litellm"                  $true  $true }
  '5' { Launch-App "hf"               "litellm"                  $true  $true }
  '6' { Launch-App "gpt-5-codex"      "openai"                   $false $true }
  '7' { Launch-App "minimax-m3:cloud" "ollama-launch-codex-app"  $false $true }
  default { Write-Host "Invalid choice. Relaunch the launcher." -ForegroundColor Red }
}
