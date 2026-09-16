# Codex Free EN from Claude Code

`/cx-free-*` commands run Codex CLI headless through the standalone English edition. They use the isolated home `C:\Users\<user>\.codex-free`, the provider file in this repository and the local proxy on ports 4200 and 4201.

They never use the original `C:\Users\<user>\.codex` home, the FR `C:\Users\<user>\.codex-openai` home, or the Codex GUI.

## Commands

| Command | Purpose |
|---|---|
| `/cx-free-models` | List models and context windows. |
| `/cx-free-health [model]` | Prepare the local runtime and check the visible model list. |
| `/cx-free-status` | Show the local home and process state without starting anything. |
| `/cx-free-task [model] [--write] request` | Run a general Codex task. |
| `/cx-free-agent [model] [--write] mission` | Run an explicit delegated Codex agent. |
| `/cx-free-review [model] [base-ref]` | Perform a read-only code review. |
| `/cx-free-critique [model] [base-ref]` | Perform a read-only adversarial review. |
| `/cx-free-plan [model] request` | Prepare a read-only implementation plan. |

The default model is `deepseek-flash`. Available model identifiers are:

- `deepseek-flash`, `deepseek-v4-flash`, `deepseek-v4-pro`
- `kimi-k2.6`, `kimi-k2.7-code`, `kimi-k2.7-code-highspeed`, `kimi-k3`
- `mina-flash`, `mina-low`, `mina-full`
- `nvidia-deepseek`, `nvidia-glm`, `hf`

Compatibility aliases include `deepseek`, `ds`, `deepseek-pro`, `deepseek-v4.1-flash`, `kimi`, `kimi-2.6`, `kimi-3`, `nvidia`, `glm`, `huggingface` and `qwen`.

## Examples

```text
/cx-free-models
/cx-free-health kimi-k2.7-code
/cx-free-task deepseek-flash explain this module
/cx-free-agent kimi-k2.7-code inspect this repository
/cx-free-review kimi-k2.7-code main
/cx-free-critique deepseek-v4-pro
/cx-free-plan deepseek-flash prepare the migration plan
```

`task` and `agent` are read-only unless `--write` is explicitly supplied. Review, critique and plan are always read-only.

## Installation

```powershell
pwsh -NoProfile -File 'C:\Serveurs\Codex Free\Claude_Commandes\install.ps1'
```

The installer copies the slash commands to Claude, the helper to `.claude\scripts` and the custom Codex prompts to `.codex-free\prompts`. It never installs them in the original `.codex` home.

## Runtime

```text
CODEX_HOME = C:\Users\<user>\.codex-free
LiteLLM     = 127.0.0.1:4200
Bridge      = 127.0.0.1:4201
```

The first health, task, agent, review, critique or plan call prepares the proxy. It does not launch the Codex application. The FR stack uses 4000/4001, so it can run at the same time as this EN stack.

## Security

Provider keys stay only in `litellm-codex\.env`, which is ignored by Git. The source, catalogue and documentation contain no provider key. The old local proxy credential was removed from the current source. OAuth credentials, cookies, sessions and histories are not imported.
