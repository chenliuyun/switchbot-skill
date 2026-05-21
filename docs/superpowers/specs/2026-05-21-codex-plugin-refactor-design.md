# Design: codex-plugin Refactor — Self-Contained MCP + Security Layer

**Date:** 2026-05-21  
**Status:** Approved  
**Scope:** `packages/codex-plugin` (major), `packages/openclaw-skill` (patch), root `manifest.json`, `CODEX_INSTALL.md`

---

## Problem Statement

The current repo has four converging issues that degrade safety and reproducibility:

1. `packages/codex-plugin/.mcp.json` uses `@cly-org/switchbot-openclaw-skill@latest` — runtime behavior can change unpredictably after install.
2. MCP entry has two narratives: `index.js` registers 6 filtered tools, but `bin/start.js` hands off to `switchbot mcp serve` (up to 24 CLI tools), bypassing the wrapper's safety filter.
3. Security enforcement lives only in `SKILL.md` natural language — a model accessing MCP tools directly can bypass all destructive-action rules.
4. `check-credentials.js` reads `token`/`secret` fields from `switchbot config show --json`, which is unnecessarily permissive for a setup check.

---

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| MCP path | Wrapper (6 tools) | Safer for Codex; security logic stays in one place |
| codex-plugin dependency | Self-contained (no external npm at runtime) | Version coherence; no `@latest` surprise |
| Change scope | Both packages + docs | Full alignment in one push |
| Security layer | Policy middleware (Layer 1) + destructive gate (Layer 2) | Two independent, separately testable layers |

---

## Package Structure

### After

```
packages/
  codex-plugin/          v0.8.0
    src/
      server.js          MCP server entry point
      tools.js           6 tool definitions with safety tier metadata
      policy.js          policy.yaml loader + middleware
      executor.js        CLI execution, enforces --audit-log
    setup/
      check-credentials.js   presence-only, never reads token/secret
      check-cli.js
    bin/
      auth.js            onInstall hook (unchanged)
    .mcp.json            "node ${pluginDir}/src/server.js"
    .codex-plugin/
      plugin.json        version 0.8.0
      hooks.json
    skills/switchbot/SKILL.md
    tests/
      server.test.js
      policy.test.js
      safety.test.js
      credentials.test.js

  openclaw-skill/        v0.7.1  (patch only)
    setup/
      check-credentials.js   presence-only (synced with codex-plugin)
```

### Version Alignment

| Artifact | Before | After |
|---|---|---|
| `packages/codex-plugin` | 0.7.1 | 0.8.0 |
| `packages/openclaw-skill` | 0.7.0 | 0.7.1 |
| Root `manifest.json` | 0.7.0 | 0.8.0 |
| `manifest.json` `codexPlugin.mcpServer` field | `npx -y ...@latest` | removed (self-contained) |

---

## MCP Server (src/server.js)

Replaces the external `npx -y @cly-org/switchbot-openclaw-skill@latest` reference. Starts a local MCP server registering exactly 6 tools, each routed through the two-layer safety pipeline.

`.mcp.json` after:

```json
{
  "mcpServers": {
    "switchbot": {
      "command": "node",
      "args": ["${pluginDir}/src/server.js"],
      "description": "SwitchBot smart-home MCP server (6 tools, policy-gated)"
    }
  }
}
```

---

## Security Layer

### Layer 1: Policy Middleware (`src/policy.js`)

Runs before every tool invocation that touches a device or scene.

**Checks (in order):**
1. Load `~/.config/openclaw/switchbot/policy.yaml` — if absent, use a permissive default (read = allow, mutation = allow + audit-log, destructive = require confirmed).
2. `quietHours`: if current local time is within the configured window, reject with `{ blocked: true, reason: 'quietHours', window: '...' }`.
3. `allowedDevices`: if the deviceId is not in the allowlist (and list is non-empty), reject.
4. `blockedCommands`: if the command string matches a blocked entry, reject.

### Layer 2: Destructive Confirmation Gate (`src/tools.js`)

Applies only to `devices_command` and `scenes_run`.

**Safety Tier Mapping (hardcoded):**

| Command category | Tier |
|---|---|
| Query / status read | `read` |
| Light on/off, IR commands | `mutation` |
| Lock on/off, mechanical push, plug power-off | `destructive` |
| Scene execution | `mutation` (default) |
| Scene execution with `scenesTier: destructive` in policy.yaml | `destructive` |

Scenes default to `mutation` — determining scene device contents at runtime is out of scope. Users who have scenes that affect locks or other destructive-tier devices should set `scenesTier: destructive` in their policy.yaml.

**Gate logic:**
- `read`: pass through.
- `mutation`: execute, force `--audit-log`.
- `destructive` + no `confirmed: true` → return confirmation request (do not execute).
- `destructive` + `confirmed: true` → execute, force `--audit-log`.

**Tool schema addition (`devices_command`):**

```json
{
  "name": "confirmed",
  "type": "boolean",
  "description": "Must be true to execute destructive-tier commands. Obtain explicit user confirmation before setting this."
}
```

### Unified MCP Return Envelope

All 6 tools return:

```json
{
  "result": {},
  "safetyTier": "mutation",
  "requiresConfirmation": false
}
```

Mutation and destructive tools additionally include `auditLogPath`:

```json
{
  "result": {},
  "safetyTier": "mutation",
  "requiresConfirmation": false,
  "auditLogPath": "~/.switchbot/audit.log"
}
```

Destructive unconfirmed response:

```json
{
  "requiresConfirmation": true,
  "safetyTier": "destructive",
  "message": "Command 'lockOff' affects a lock. Call again with confirmed: true after obtaining explicit user consent."
}
```

---

## Credential Check Fix

Both `packages/codex-plugin/setup/check-credentials.js` and `packages/openclaw-skill/setup/check-credentials.js` replace direct token/secret field inspection with:

```
Step 1: switchbot doctor --json
  → credentials.configured === true → ok
  → command not found (old CLI) → Step 2

Step 2: switchbot auth keychain describe --json
  → exit code 0 → ok (read exit code only, never inspect field values)
  → exit code non-zero → not configured
```

Rule: never read, log, or pass through `token` or `secret` field values.

---

## CODEX_INSTALL.md

Add at the top of the file:

```markdown
> **Recommended install:** Codex app → Plugins → Add from local path → `packages/codex-plugin/`
> Or: `codex plugin marketplace add .`
>
> The manual steps below are a **Legacy path** for older Codex versions without plugin support.
```

Wrap all existing manual steps (edit `~/.codex/config.toml`, clone repo, write `AGENTS.md`) in a `<details><summary>Legacy: Manual Installation</summary>` block. Content unchanged, visibility reduced.

---

## Test Coverage

| File | Scenarios |
|---|---|
| `tests/server.test.js` | All 6 tools registered; envelope schema present on every response |
| `tests/policy.test.js` | quietHours rejects; allowedDevices rejects unlisted device; blockedCommands rejects; absent policy.yaml uses permissive default |
| `tests/safety.test.js` | destructive without `confirmed` returns `requiresConfirmation: true`; destructive with `confirmed: true` executes with `--audit-log`; mutation executes with `--audit-log`; read executes without `--audit-log` |
| `tests/credentials.test.js` | doctor success path; doctor absent → keychain fallback; keychain exit-0 → ok; keychain exit-1 → not configured; token/secret fields never appear in return value |

---

## Out of Scope

- Changes to `@switchbot/openapi-cli` CLI source.
- Adding `switchbot auth status` command to CLI (credential check uses existing commands).
- openclaw-skill MCP tool additions or removals.
- Codex marketplace publication (separate release step).
