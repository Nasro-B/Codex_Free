# Codex Free EN

Standalone English edition of Codex Gratuit. It routes the Codex CLI and application through DeepSeek, Kimi, Mina, NVIDIA or HuggingFace without modifying the original Codex home.

## Isolation

This edition uses its own homes:

| Environment | Home | Runtime |
|---|---|---|
| Original Codex | C:\Users\Nasro\.codex | OpenAI application |
| Codex Gratuit FR | C:\Users\Nasro\.codex-openai | C:\Serveurs\Codex Gratuit |
| Codex Free EN | C:\Users\Nasro\.codex-free | C:\Serveurs\Codex Free |

Codex Free EN never reads or modifies .codex or .codex-openai. Its OpenAI login home is .codex-free-openai.

The provider environment file is local only:

~~~text
C:\Serveurs\Codex Free\litellm-codex\.env
~~~

Create it from litellm-codex\.env.example. Never commit it. The EN proxy listens on loopback ports 4200 and 4201. The FR proxy keeps ports 4000 and 4001, so both stacks can run at the same time.

## Providers and context windows

| Model | Provider | Context |
|---|---|---:|
| deepseek-flash | DeepSeek V4.1 Flash | 1,048,576 |
| deepseek-v4-flash | DeepSeek V4 Flash legacy | 1,048,576 |
| deepseek-v4-pro | DeepSeek V4 Pro | 1,048,576 |
| kimi-k2.6 | Kimi K2.6 | 262,144 |
| kimi-k3 | Kimi K3 | 1,048,576 |
| kimi-k2.7-code | Kimi K2.7 Code | 262,144 |
| kimi-k2.7-code-highspeed | Kimi K2.7 Code HighSpeed | 262,144 |
| mina-flash | Mina Flash, CloudZIR | 64,000 |
| mina-low | Mina Low, CloudZIR | 128,000 |
| mina-full | Mina Full, CloudZIR | 256,000 |
| nvidia-deepseek | NVIDIA DeepSeek V4 Pro | 1,048,576 |
| nvidia-glm | NVIDIA GLM-5.1 | 200,000 |
| hf | HuggingFace Qwen3 Coder Next | 262,144 |

The catalogue is litellm-codex\litellm-models.json. It contains metadata only and never contains provider keys.

Mina HTTP 402 means the CloudZIR balance is insufficient. It is not a local proxy failure.

## Installation

Install PowerShell 7, Node.js, Python/uv, LiteLLM and Codex CLI.

Create the provider file:

~~~powershell
Copy-Item 'C:\Serveurs\Codex Free\litellm-codex\.env.example' 'C:\Serveurs\Codex Free\litellm-codex\.env'
~~~

Then fill the local values in .env.

## Launch the application

Use the desktop shortcut Codex (menu), or run:

~~~powershell
pwsh -NoProfile -File 'C:\Serveurs\Codex Free\codex-launch.ps1'
~~~

The menu includes DeepSeek, Kimi, Mina, NVIDIA, HuggingFace, the standalone OpenAI home and Ollama.

To prepare the free runtime without launching the GUI:

~~~powershell
pwsh -NoProfile -File 'C:\Serveurs\Codex Free\codex-launch.ps1' -Model deepseek-flash -Headless
~~~

To select another initial model:

~~~powershell
pwsh -NoProfile -File 'C:\Serveurs\Codex Free\codex-launch.ps1' -Model kimi-k2.7-code
~~~

The application can switch between the models exposed by the catalogue. The launcher writes the selected default and prepares the local proxy before the GUI starts.

## Claude Code commands

Available commands:

- /cx-free-models
- /cx-free-health
- /cx-free-status
- /cx-free-task
- /cx-free-agent
- /cx-free-review
- /cx-free-critique
- /cx-free-plan

Install them:

~~~powershell
pwsh -NoProfile -File 'C:\Serveurs\Codex Free\Claude_Commandes\install.ps1'
~~~

The installer writes commands to the Claude home, the helper to .claude\scripts and custom prompts to .codex-free\prompts. It never installs prompts into the original .codex home.

The helper uses:

~~~text
CODEX_HOME=C:\Users\<user>\.codex-free
LiteLLM=127.0.0.1:4200
Bridge=127.0.0.1:4201
~~~

All cx-free commands are headless and do not launch the Codex GUI. They are read-only by default. Use the explicit write option only when file changes are intended.

## Security

- API keys stay only in litellm-codex\.env.
- auth.json, credentials.json, sessions, cookies and histories are never imported.
- OAuth connectors must be reconnected manually on another computer.
- The source, catalogue, documentation and Git history must not contain provider keys.
- The proxy has no hardcoded bearer token. It is bound to 127.0.0.1.

## Troubleshooting

Check the local bridge:

~~~powershell
pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode status
pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode models
pwsh -NoProfile -File "$env:USERPROFILE\.claude\scripts\cx-free.ps1" -Mode health -Model deepseek-flash
~~~

If the proxy is down, the first health, task, agent, review, critique or plan command starts it. If a provider returns 402, check its account balance. If a provider returns 429, wait for the provider rate limit and retry.

## Repository contents

- codex-launch.ps1: standalone launcher and model routing.
- litellm-codex: local proxy, bridge, callback and model catalogue.
- Claude_Commandes: Claude slash commands and headless helper.
- assets: application assets and icon.
- user: package or application user data.
