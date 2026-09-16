# Codex Free EN `config.toml` reference

The isolated free-provider configuration is stored at:

```text
C:\Users\<user>\.codex-free\config.toml
```

The launcher creates and updates this file. It never edits the original `C:\Users\<user>\.codex` home or the FR `C:\Users\<user>\.codex-openai` home.

## Active model and provider

```toml
model = "deepseek-flash"
model_reasoning_effort = "xhigh"
model_provider = "litellm"
sandbox_mode = "danger-full-access"
```

The launcher rewrites `model` and `model_provider` when a model is selected. `max` is not a valid reasoning effort for current Codex CLI versions used by this setup.

## Codex Free EN provider

```toml
[model_providers.litellm]
name = "LiteLLM"
base_url = "http://127.0.0.1:4201/v1/"
wire_api = "responses"
env_key = "LITELLM_KEY"
model_catalog_json = "C:\\Serveurs\\Codex Free\\litellm-codex\\litellm-models.json"
```

The bridge on port 4201 adapts the local LiteLLM service on port 4200 and exposes the model catalogue to Codex. The catalogue contains the context windows for DeepSeek, Kimi, Mina, NVIDIA and HuggingFace.

## Available model identifiers

```text
deepseek-flash
deepseek-v4-flash
deepseek-v4-pro
kimi-k2.6
kimi-k2.7-code
kimi-k2.7-code-highspeed
kimi-k3
mina-flash
mina-low
mina-full
nvidia-deepseek
nvidia-glm
hf
```

The exact context values are maintained in `litellm-codex/litellm-models.json`. Do not copy provider keys into this file.

## MCP and plugins

The launcher preserves the Codex-managed MCP and plugin sections in the isolated home. The internal Codex runtime entries remain managed by the Codex application. External connectors that require OAuth must be authenticated separately in this home.

## Recovery after an update

1. Run `codex-launch.ps1 -Model deepseek-flash -Headless`.
2. Confirm that `.codex-free\config.toml` points to bridge port 4201.
3. Run `Claude_Commandes\scripts\cx-free.ps1 -Mode models` and `-Mode health`.
4. Confirm that the provider file remains local at `litellm-codex\.env`.

Do not copy `auth.json`, sessions, cookies or histories from another Codex home.
