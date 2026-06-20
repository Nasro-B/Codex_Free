# Starts the LiteLLM proxy (Responses->chat bridge for Codex)
# Usage: pwsh -File "C:\Serveurs\Codex Free\litellm-codex\start-litellm.ps1"
$dir = $PSScriptRoot   # auto-locates: the script finds its .env/config.yaml wherever it is

# Force UTF-8 (otherwise the LiteLLM banner crashes the Windows cp1252 console)
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

# Load keys from .env into the process environment
Get-Content "$dir\.env" | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
    $name = $matches[1]; $val = $matches[2]
    $val = $val.Trim().Trim('"').Trim("'")   # strip optional quotes
    if ($val) { Set-Item -Path "Env:$name" -Value $val }
  }
}
Write-Host "[ok] keys loaded: NVIDIA=$([bool]$env:NVIDIA_API_KEY) DEEPSEEK=$([bool]$env:DEEPSEEK_API_KEY) HF=$([bool]$env:HF_TOKEN)"

# Start the proxy on port 4000
# IMPORTANT: Set-Location so Python can find codex_deepseek_fix.py via CWD
Set-Location -Path $dir
litellm --config "$dir\config.yaml" --port 4000
