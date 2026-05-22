# Codex Plugin Simplification — Design Spec

**Date:** 2026-05-22
**Status:** Approved

---

## Problem

The current `packages/codex-plugin` runs its own Node.js MCP server that
shell-execs the SwitchBot CLI for every tool call. This creates a redundant
layer: the CLI (`switchbot mcp serve`) already ships a native MCP server with
24 tools, handles safety tiers, and reads credentials from the OS keychain
automatically. The plugin duplicates a 6-tool subset with extra maintenance
cost (`@modelcontextprotocol/sdk`, `js-yaml`, path-patching workarounds).

---

## Goal

Replace the custom Node.js MCP server with a direct reference to
`switchbot mcp serve --tools all`. The plugin becomes a thin configuration
package: a `.mcp.json`, an `onInstall` auth helper, and skill documentation.

---

## Architecture Change

**Before (3 layers):**
```
Codex → [codex-plugin MCP server (Node.js)] → execFile → [switchbot CLI]
```

**After (1 layer):**
```
Codex → [switchbot mcp serve --tools all]
```

---

## File Changes

### Delete

| Path | Reason |
|---|---|
| `packages/codex-plugin/src/server.js` | Replaced by CLI MCP |
| `packages/codex-plugin/src/tools.js` | Replaced by CLI MCP |
| `packages/codex-plugin/src/executor.js` | Replaced by CLI MCP |
| `packages/codex-plugin/src/policy.js` | Replaced by AI policy compliance |
| `packages/codex-plugin/tests/safety.test.js` | Tests deleted src/ code |
| `packages/codex-plugin/tests/server.test.js` | Tests deleted src/ code |
| `packages/codex-plugin/tests/policy.test.js` | Tests deleted src/ code |

### Modify

**`.mcp.json`** — point to CLI binary instead of `bin/server.js`:
```json
{
  "mcpServers": {
    "switchbot": {
      "command": "switchbot",
      "args": ["mcp", "serve", "--tools", "all"],
      "description": "SwitchBot smart-home MCP server (24 tools, via CLI)"
    }
  }
}
```
Credentials are not included — the CLI reads them automatically from
env var → OS keychain → config file. The `onInstall` hook ensures the
keychain is configured before first use.

**`bin/auth.js`** — remove `patchMcpJson()` and its call site (~20 lines).
`makeRunAuth` / `checkCli` / `checkCredentials` are kept unchanged; the
`onInstall` hook still needs them.

**`package.json`** — remove both runtime dependencies and update `files`:
```json
{
  "dependencies": {},
  "files": ["bin/", "setup/", "skills/", ".codex-plugin/", ".mcp.json"]
}
```

**`SKILL.md`** — add policy compliance section (see below).

### Keep Unchanged

- `setup/check-cli.js`
- `setup/check-credentials.js`
- `tests/auth.test.js` (minus `patchMcpJson` cases)
- `tests/setup.test.js`
- `.codex-plugin/plugin.json`
- `.codex-plugin/hooks.json`
- `skills/`

---

## Policy Compliance (SKILL.md addition)

The code-level policy gate (`quietHours`, `allowedDevices`, `blockedCommands`)
is removed. The AI enforces policy by calling `policy_validate` at the start
of control sessions.

New section to insert in SKILL.md after "Safety gates":

```markdown
## Policy compliance

Before executing any mutation or destructive action, check whether the user
has a policy file:

1. Call `policy_validate` (with `live: true`) at the start of each session
   that will involve device control — not on every single command.
2. If `policy_validate` returns a valid policy, honour these fields:
   - `quiet_hours` — during the window, ask the user for explicit confirmation
     before any mutation, even if the tier would normally auto-run.
   - `confirmations.always_confirm` — treat listed commands as destructive
     (require explicit user confirmation).
   - `confirmations.never_confirm` — treat listed commands as pre-approved
     by the user; skip the confirmation prompt.
3. If no policy file exists (`ENOENT` or `present: false`), proceed with the
   default safety tiers — no additional prompt needed.

Never write to policy.yaml without showing the user a diff and getting
explicit approval first.
```

---

## Safety Trade-offs

| Concern | Before | After |
|---|---|---|
| Destructive commands | `confirmed:true` required | Default CLI profile rejects outright (stronger) |
| `quietHours` enforcement | Hard code gate | AI checks `policy_validate` at session start |
| `allowedDevices` enforcement | Hard code gate | AI checks `policy_validate` at session start |
| Audit log for mutations | `--audit-log` prepended by Node.js layer | Not written by MCP mutations — acceptable for the typical smart-home use case |
| Tool count | 6 | 24 |

The audit log loss is acceptable: the typical smart-home session is low-frequency,
and the 24-tool set includes `audit_query` and `audit_stats` for historical review.
Users who require complete audit trails should run `switchbot` CLI commands
directly with `--audit-log`.

---

## Testing

After implementation, verify:

1. `node bin/auth.js` exits 0 when credentials present; exits non-zero when CLI missing.
2. `npm test` passes (only `auth.test.js` and `setup.test.js` remain).
3. Start MCP server manually: `switchbot mcp serve --tools all` — confirm 24 tools listed.
4. Codex picks up `.mcp.json` and the `switchbot` MCP server appears in the tool list.
