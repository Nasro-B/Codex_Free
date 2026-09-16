# Codex Free EN model catalogue reference

The active catalogue is the repository file:

```text
C:\Serveurs\Codex Free\litellm-codex\litellm-models.json
```

Codex reads the catalogue through the isolated `.codex-free` configuration. Each entry must keep `context_window` and `max_context_window` synchronized with the intended provider limit. An absent entry can make Codex fall back to an incorrect smaller context.

## Current context windows

| Model | Context window |
|---|---:|
| `deepseek-flash` | 1,048,576 |
| `deepseek-v4-flash` | 1,048,576 |
| `deepseek-v4-pro` | 1,048,576 |
| `kimi-k2.6` | 262,144 |
| `kimi-k2.7-code` | 262,144 |
| `kimi-k2.7-code-highspeed` | 262,144 |
| `kimi-k3` | 1,048,576 |
| `mina-flash` | 64,000 |
| `mina-low` | 128,000 |
| `mina-full` | 256,000 |
| `nvidia-deepseek` | 1,048,576 |
| `nvidia-glm` | 200,000 |
| `hf` | 262,144 |

The `deepseek-v4-flash` entry is retained as a compatibility identifier. The provider route is the current DeepSeek V4.1 Flash route.

## Verification

Run:

```powershell
pwsh -NoProfile -File 'C:\Serveurs\Codex Free\Claude_Commandes\scripts\cx-free.ps1' -Mode models
pwsh -NoProfile -File 'C:\Serveurs\Codex Free\Claude_Commandes\scripts\cx-free.ps1' -Mode health -Model deepseek-flash
```

These checks validate the catalogue and the local bridge without launching the Codex GUI. Provider completion errors remain separate from catalogue and bridge errors.
