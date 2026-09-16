# Claude Commands for Codex Free EN

These slash commands run Codex CLI headless through the standalone English runtime in C:\Serveurs\Codex Free.

They use:

- C:\Users\<user>\.codex-free;
- LiteLLM on 127.0.0.1:4200;
- the API bridge on 127.0.0.1:4201;
- provider keys from C:\Serveurs\Codex Free\litellm-codex\.env.

They do not use the original .codex home or the FR .codex-openai home. They never launch the Codex GUI.

## Commands

| Command | Purpose |
|---|---|
| /cx-free-models | List model names and context windows |
| /cx-free-health | Prepare the runtime and check the visible models |
| /cx-free-status | Show home and proxy state without starting the GUI |
| /cx-free-task [model] [--write] request | Run a general task |
| /cx-free-agent [model] [--write] mission | Run an explicit Codex agent |
| /cx-free-review [model] [base-ref] | Review repository changes |
| /cx-free-critique [model] [base-ref] | Perform an adversarial review |
| /cx-free-plan [model] request | Prepare a read-only implementation plan |

The default model is deepseek-flash. Supported model names are:

- kimi-k2.6
- kimi-k2.7-code
- kimi-k2.7-code-highspeed
- kimi-k3
- deepseek-v4-pro
- deepseek-v4-flash
- deepseek-flash
- mina-flash
- mina-low
- mina-full
- nvidia-deepseek
- nvidia-glm
- hf

Aliases include deepseek, ds, deepseek-pro, deepseek-v4.1-flash, kimi, kimi-2.6, kimi-3, nvidia, glm, huggingface and qwen.

## Examples

~~~text
/cx-free-models
/cx-free-health kimi-k2.7-code
/cx-free-task deepseek-flash explain this module
/cx-free-agent kimi-k2.7-code inspect this repository
/cx-free-review kimi-k2.7-code main
/cx-free-critique deepseek-v4-pro
/cx-free-plan deepseek-flash prepare the migration plan
~~~

Without --write, task and agent calls use a read-only sandbox. The review, critique and plan modes are always read-only.

## Installation

~~~powershell
pwsh -NoProfile -File 'C:\Serveurs\Codex Free\Claude_Commandes\install.ps1'
~~~

The installer copies:

- commands to the Claude commands directory;
- cx-free.ps1 to the Claude scripts directory;
- custom prompts to C:\Users\<user>\.codex-free\prompts.

It never installs prompts in C:\Users\<user>\.codex.

## Prerequisites

- Codex CLI available in PATH;
- PowerShell 7;
- Node.js;
- LiteLLM;
- C:\Serveurs\Codex Free\litellm-codex\.env created from .env.example;
- C:\Users\<user>\.codex-free\config.toml, created automatically by the launcher.

The helper imports the local .env into its process, sets CODEX_HOME to .codex-free, prepares the proxy and then calls codex exec.

## Troubleshooting

If status is DOWN, run health, task, agent, review, critique or plan to start the proxy. The EN edition uses 4200/4201, so it can run alongside the FR edition on 4000/4001.

An HTTP 402 from Mina means the CloudZIR account balance is insufficient. An HTTP 429 means the upstream provider is rate-limiting the request.

The API key and OAuth security material are never copied by this integration. OAuth connectors must be reconnected manually on a new PC.
