# ollama-launch-models.json — Reference

**Location**: `C:\Users\<user>\.codex\ollama-launch-models.json`

**Role**: Catalog of models known to the Codex application. Codex reads this file to determine the `context_window` of each model. Without a correct entry, the context defaults to **65,536 tokens**.

---

## General Structure

```json
{
  "models": [
    {
      "slug": "unique-identifier",
      "display_name": "Name displayed in Codex",
      "context_window": 1048576,
      "max_context_window": 1048576,
      "effective_context_window_percent": 95,
      "input_modalities": ["text"],
      "supports_parallel_tool_calls": true,
      ...
    },
    ...
  ]
}
```

The key fields for context are `context_window` and `max_context_window`.

---

## LiteLLM Entries (DeepSeek / NVIDIA / HuggingFace)

These 5 entries are **essential** for the launcher to work properly. If a Codex update erases them, they must be added back.

### 1. deepseek-flash

```json
{
  "slug": "deepseek-flash",
  "display_name": "DeepSeek V4 Flash",
  "description": "DeepSeek V4 Flash via LiteLLM",
  "context_window": 1048576,
  "max_context_window": 1048576,
  "effective_context_window_percent": 95,
  "input_modalities": ["text"],
  "supports_parallel_tool_calls": true,
  "supports_reasoning_summaries": false,
  "supports_search_tool": false,
  "supported_in_api": true,
  "visibility": "list",
  "priority": 100,
  "shell_type": "default",
  "support_verbosity": false,
  "supports_image_detail_original": false,
  "supported_reasoning_levels": [],
  "experimental_supported_tools": [],
  "additional_speed_tiers": [],
  "truncation_policy": { "limit": 10000, "mode": "bytes" },
  "default_reasoning_summary": "auto",
  "auto_compact_token_limit": null,
  "apply_patch_tool_type": null,
  "availability_nux": null,
  "base_instructions": null,
  "default_reasoning_level": null,
  "default_verbosity": null,
  "model_messages": null,
  "upgrade": null,
  "web_search_tool_type": "text"
}
```

### 2. deepseek-pro

Same values as `deepseek-flash`, only the slug and display_name change:
- `"slug": "deepseek-pro"`
- `"display_name": "DeepSeek V4 Pro"`
- `"description": "DeepSeek V4 Pro via LiteLLM"`
- `"context_window": 1048576`
- `"max_context_window": 1048576`

### 3. nvidia-deepseek

- `"slug": "nvidia-deepseek"`
- `"display_name": "NVIDIA DeepSeek V4 Pro"`
- `"description": "NVIDIA DeepSeek V4 Pro via LiteLLM"`
- `"context_window": 262144`
- `"max_context_window": 262144`

### 4. nvidia-glm

- `"slug": "nvidia-glm"`
- `"display_name": "NVIDIA GLM-5.1"`
- `"description": "NVIDIA GLM-5.1 via LiteLLM"`
- `"context_window": 262144`
- `"max_context_window": 262144`

### 5. hf

- `"slug": "hf"`
- `"display_name": "HuggingFace Qwen3 Coder Next"`
- `"description": "HuggingFace Qwen3 via LiteLLM"`
- `"context_window": 262144`
- `"max_context_window": 262144`

---

## Verification After a Codex Update

1. Open `C:\Users\<user>\.codex\ollama-launch-models.json`
2. Look for the slugs: `deepseek-flash`, `deepseek-pro`, `nvidia-deepseek`, `nvidia-glm`, `hf`
3. Verify their `context_window` is not `65536`
4. If missing or incorrect: restore from this document

## Automatic Backups

Codex sometimes creates `.bak` files before modification:
```
ollama-launch-models.json.bak
ollama-launch-models.json.20260616*.bak
```
