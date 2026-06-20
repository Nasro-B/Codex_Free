# Codex Elite Agents (English)

A roster of **15 specialized subagents** for **Codex CLI** (multi-agent), tuned for a
Node.js/Express + React/Vike + Supabase/Postgres + Vercel + LLM stack. Same team also available
for Claude Code (`.claude/agents/*.md`) and Qwen Code (`.qwen/agents/*.md`).

## Install

1. Copy every `*.toml` in this folder into your Codex agents directory:
   - Windows: `C:\Users\<you>\.codex\agents\`
   - macOS/Linux: `~/.codex/agents/`
2. Make sure multi-agent is enabled in `~/.codex/config.toml`:
   ```toml
   [features]
   multi_agent = true
   ```
3. A model backend must be reachable (e.g. your LiteLLM bridge on `:4000`, or OpenAI). If the backend
   is down, dispatch will time out — that is a backend issue, not an agent issue.

## Permissions (sandbox)

Each agent declares a `sandbox_mode`:
- `read-only` — reviewers/auditors (cannot modify files).
- `workspace-write` — the 4 "doers" that edit (debugger, test-engineer, refactorer, docs-changelog-maintainer).

This is safer than a global `danger-full-access`: a reviewer physically cannot write.

## Roster

| Agent | Sandbox | Role |
| --- | --- | --- |
| codebase-explorer | read-only | Fast code/architecture search |
| code-reviewer | read-only | Bugs, security, conventions on recent changes |
| security-auditor | read-only | OWASP, secrets, injection, authz, CVE, RLS |
| debugger | workspace-write | Root-cause-first debugging, one minimal verified fix |
| test-engineer | workspace-write | TDD: write & run tests, coverage gaps |
| db-migration-reviewer | read-only | Replayable migrations, schema, indexes, RLS |
| performance-optimizer | read-only | Hot paths, queries, bundle, CWV, leaks |
| refactorer | workspace-write | Dead code, duplication, simplify (behavior unchanged) |
| ai-llm-engineer | read-only | Fallback chains, RAG, anti-hallucination, token cost |
| frontend-ux-reviewer | read-only | React/Vike, a11y (WCAG AA), SEO, CWV, i18n |
| deployment-release-engineer | read-only | Env vars, build, CI (advisory — never deploys) |
| backend-api-reviewer | read-only | Validation, errors, authz, idempotency, rate-limit |
| compliance-rgpd-auditor | read-only | GDPR art.15/17, tenant isolation, EU cosmetics |
| integration-resilience-reviewer | read-only | Webhooks, timeouts, retries, idempotency |
| docs-changelog-maintainer | workspace-write | Updates docs/changelog to match reality |

## Usage

In a `codex` session, ask it to use an agent by name — e.g. *"use the security-auditor agent on lib/"* —
or let Codex auto-delegate based on each agent's description.

Each agent follows anti-hallucination rules: every finding cites `file:line` + real proof, severity
matches evidence, counts are measured (not guessed), and proposed fixes for high-severity items are
marked "untested".
