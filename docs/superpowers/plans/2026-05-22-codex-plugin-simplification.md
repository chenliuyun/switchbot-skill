# Codex Plugin Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom Node.js MCP server in `packages/codex-plugin` with a direct reference to `switchbot mcp serve --tools all`, reducing 6 tools to 0 maintained tools and 24 CLI-native tools.

**Architecture:** The plugin stops running its own MCP process. `.mcp.json` points Codex directly at the `switchbot` binary. The `bin/auth.js` `onInstall` hook remains to verify the CLI is installed and credentials are configured. The plugin becomes a thin configuration + skill-documentation package with zero runtime Node.js dependencies.

**Tech Stack:** Node.js ≥ 18 (ESM), `@switchbot/openapi-cli` ≥ 3.3.0 (peer), no runtime npm dependencies.

---

## File Map

| File | Action | Why |
|---|---|---|
| `packages/codex-plugin/src/server.js` | **Delete** | Replaced by CLI MCP |
| `packages/codex-plugin/src/tools.js` | **Delete** | Replaced by CLI MCP |
| `packages/codex-plugin/src/executor.js` | **Delete** | Replaced by CLI MCP |
| `packages/codex-plugin/src/policy.js` | **Delete** | Policy enforcement moves to SKILL.md |
| `packages/codex-plugin/tests/safety.test.js` | **Delete** | Tests deleted code |
| `packages/codex-plugin/tests/server.test.js` | **Delete** | Tests deleted code |
| `packages/codex-plugin/tests/policy.test.js` | **Delete** | Tests deleted code |
| `packages/codex-plugin/tests/auth.test.js` | **Modify** | Remove `patchMcpJson` describe block + imports |
| `packages/codex-plugin/bin/auth.js` | **Modify** | Remove `patchMcpJson` function and call site |
| `packages/codex-plugin/.mcp.json` | **Modify** | Point to `switchbot mcp serve --tools all` |
| `packages/codex-plugin/package.json` | **Modify** | Remove two dependencies, update `files` and `description` |
| `packages/codex-plugin/skills/switchbot/SKILL.md` | **Modify** | Add policy compliance section; update audit logging section |

---

## Task 1: Trim `auth.test.js` and `bin/auth.js`

**Files:**
- Modify: `packages/codex-plugin/tests/auth.test.js`
- Modify: `packages/codex-plugin/bin/auth.js`

### Step 1.1 — Rewrite `tests/auth.test.js`

Replace the entire file. The `patchMcpJson` describe block (lines 97–127) and its imports (`mkdtemp`, `readFile`, `mkdir`, `join`, `tmpdir`) are removed. The five `runAuth` test cases are kept verbatim.

`packages/codex-plugin/tests/auth.test.js`:
```js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { makeRunAuth } from '../bin/auth.js';

function makeOkCliCheck(version = '3.3.0') {
  return async () => ({ ok: true, version });
}
function makeFailCliCheck(msg = 'not found') {
  return async () => ({ ok: false, message: msg });
}
function makeOkCredCheck(source = 'keychain') {
  return async () => ({ ok: true, source });
}
function makeFailCredCheck() {
  return async () => ({ ok: false, message: 'no creds' });
}
function makeSpawn(exitCode = 0) {
  const calls = [];
  const spawn = (cmd, args) => {
    calls.push({ cmd, args });
    return Promise.resolve(exitCode);
  };
  return { spawn, calls };
}

describe('runAuth', () => {
  it('exits 0 immediately when credentials already present', async () => {
    const { spawn, calls } = makeSpawn(0);
    const runAuth = makeRunAuth({
      checkCli: makeOkCliCheck(),
      checkCredentials: makeOkCredCheck('config'),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.equal(code, 0);
    assert.equal(calls.length, 0);
  });

  it('exits non-zero when CLI check fails', async () => {
    const { spawn } = makeSpawn(0);
    const runAuth = makeRunAuth({
      checkCli: makeFailCliCheck('CLI not found'),
      checkCredentials: makeFailCredCheck(),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.notEqual(code, 0);
  });

  it('calls auth login then doctor when no credentials', async () => {
    const { spawn, calls } = makeSpawn(0);
    const runAuth = makeRunAuth({
      checkCli: makeOkCliCheck(),
      checkCredentials: makeFailCredCheck(),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.equal(code, 0);
    assert.equal(calls.length, 2);
    assert.deepEqual(calls[0], { cmd: 'switchbot', args: ['auth', 'login'] });
    assert.deepEqual(calls[1], { cmd: 'switchbot', args: ['doctor'] });
  });

  it('exits with login exit code when auth login fails', async () => {
    const { spawn, calls } = makeSpawn(1);
    const runAuth = makeRunAuth({
      checkCli: makeOkCliCheck(),
      checkCredentials: makeFailCredCheck(),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.equal(code, 1);
    assert.equal(calls.length, 1);
    assert.deepEqual(calls[0], { cmd: 'switchbot', args: ['auth', 'login'] });
  });

  it('exits with doctor exit code when verification fails', async () => {
    let callCount = 0;
    const spawn = (cmd, args) => {
      callCount++;
      return Promise.resolve(callCount === 1 ? 0 : 2);
    };
    const runAuth = makeRunAuth({
      checkCli: makeOkCliCheck(),
      checkCredentials: makeFailCredCheck(),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.equal(code, 2);
  });
});
```

- [ ] Write the file above (overwrite the existing one)

### Step 1.2 — Run tests (should still pass — `bin/auth.js` unchanged)

```
cd packages/codex-plugin
node --test tests/auth.test.js
```

Expected: `# pass 5  # fail 0`

- [ ] Run the command, confirm output

### Step 1.3 — Rewrite `bin/auth.js`

Remove `patchMcpJson`, the `writeFile` / `dirname` / `join` / `fileURLToPath` imports (no longer needed), and the `binDir` + `patchMcpJson` call in the `isMain` block.

`packages/codex-plugin/bin/auth.js`:
```js
#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { checkCli as defaultCheckCli } from '../setup/check-cli.js';
import { checkCredentials as defaultCheckCredentials } from '../setup/check-credentials.js';

function defaultRunInherit(cmd, args) {
  return new Promise((resolve) => {
    const p = spawn(cmd, args, { stdio: 'inherit' });
    p.on('close', code => resolve(code ?? 0));
    p.on('error', () => resolve(127));
  });
}

export function makeRunAuth({ checkCli, checkCredentials, runInherit }) {
  return async function runAuth() {
    const cliCheck = await checkCli();
    if (!cliCheck.ok) {
      process.stderr.write(`[switchbot-codex] ${cliCheck.message}\n`);
      return 1;
    }
    process.stderr.write(`[switchbot-codex] CLI ${cliCheck.version} detected.\n`);

    const credCheck = await checkCredentials();
    if (credCheck.ok) {
      process.stderr.write(`[switchbot-codex] Credentials present (${credCheck.source}). Skipping login.\n`);
      return 0;
    }

    process.stderr.write('[switchbot-codex] Starting browser login...\n');
    const loginCode = await runInherit('switchbot', ['auth', 'login']);
    if (loginCode !== 0) {
      process.stderr.write('[switchbot-codex] Browser login failed. Retry: switchbot auth login\n');
      return loginCode;
    }

    process.stderr.write('[switchbot-codex] Verifying credentials via doctor...\n');
    const doctorCode = await runInherit('switchbot', ['doctor']);
    if (doctorCode !== 0) {
      process.stderr.write('[switchbot-codex] Verification failed. Run: switchbot doctor\n');
      return doctorCode;
    }

    process.stderr.write('[switchbot-codex] Setup complete.\n');
    return 0;
  };
}

const isMain = process.argv[1]?.replace(/\\/g, '/').endsWith('bin/auth.js');
if (isMain) {
  const runAuth = makeRunAuth({
    checkCli: defaultCheckCli,
    checkCredentials: defaultCheckCredentials,
    runInherit: defaultRunInherit,
  });
  runAuth().then(code => process.exit(code)).catch(err => {
    process.stderr.write(`[switchbot-codex] Fatal: ${err instanceof Error ? err.message : String(err)}\n`);
    process.exit(1);
  });
}
```

- [ ] Write the file above (overwrite the existing one)

### Step 1.4 — Run tests again

```
node --test tests/auth.test.js
```

Expected: `# pass 5  # fail 0`

- [ ] Run and confirm

### Step 1.5 — Commit

```
git add packages/codex-plugin/tests/auth.test.js packages/codex-plugin/bin/auth.js
git commit -m "refactor(codex-plugin): remove patchMcpJson — no longer needed with CLI MCP"
```

- [ ] Commit

---

## Task 2: Delete `src/` and three test files

**Files:**
- Delete: `packages/codex-plugin/src/server.js`
- Delete: `packages/codex-plugin/src/tools.js`
- Delete: `packages/codex-plugin/src/executor.js`
- Delete: `packages/codex-plugin/src/policy.js`
- Delete: `packages/codex-plugin/tests/safety.test.js`
- Delete: `packages/codex-plugin/tests/server.test.js`
- Delete: `packages/codex-plugin/tests/policy.test.js`

### Step 2.1 — Delete the files

```
cd packages/codex-plugin
Remove-Item src/server.js, src/tools.js, src/executor.js, src/policy.js
Remove-Item tests/safety.test.js, tests/server.test.js, tests/policy.test.js
Remove-Item src -Recurse
```

- [ ] Run the commands

### Step 2.2 — Run remaining tests

```
node --test tests/auth.test.js tests/setup.test.js
```

Expected: all pass, no reference to deleted files.

- [ ] Run and confirm

### Step 2.3 — Commit

```
git add -A packages/codex-plugin/src packages/codex-plugin/tests
git commit -m "refactor(codex-plugin): delete custom MCP server — replaced by switchbot mcp serve"
```

- [ ] Commit

---

## Task 3: Update `.mcp.json` and `package.json`

**Files:**
- Modify: `packages/codex-plugin/.mcp.json`
- Modify: `packages/codex-plugin/package.json`

### Step 3.1 — Rewrite `.mcp.json`

`packages/codex-plugin/.mcp.json`:
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

- [ ] Write the file above

### Step 3.2 — Rewrite `package.json`

`packages/codex-plugin/package.json`:
```json
{
  "name": "@cly-org/switchbot-codex-plugin",
  "version": "0.8.0",
  "type": "module",
  "description": "SwitchBot Codex plugin — wires Codex to the SwitchBot CLI MCP server (24 tools, zero Node.js dependencies)",
  "author": {
    "name": "chenliuyun",
    "url": "https://github.com/chenliuyun"
  },
  "homepage": "https://github.com/chenliuyun/switchbot-skill/tree/main/packages/codex-plugin",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/chenliuyun/switchbot-skill.git",
    "directory": "packages/codex-plugin"
  },
  "bugs": "https://github.com/chenliuyun/switchbot-skill/issues",
  "license": "MIT",
  "keywords": ["codex", "switchbot", "smart-home", "iot", "mcp"],
  "engines": { "node": ">=18" },
  "bin": {
    "switchbot-codex-auth": "./bin/auth.js"
  },
  "files": [
    "bin/",
    "setup/",
    "skills/",
    ".codex-plugin/",
    ".mcp.json"
  ],
  "peerDependencies": {
    "@switchbot/openapi-cli": ">=3.3.0"
  },
  "publishConfig": {
    "access": "public"
  },
  "scripts": {
    "test": "node --test tests/*.test.js"
  }
}
```

- [ ] Write the file above

### Step 3.3 — Regenerate `node_modules` and `package-lock.json`

```
npm install
```

Expected: installs zero runtime packages; `node_modules/` shrinks to only devDependencies (none declared) — directory may disappear entirely or become empty.

- [ ] Run `npm install`

### Step 3.4 — Run tests

```
node --test tests/*.test.js
```

Expected: all pass.

- [ ] Run and confirm

### Step 3.5 — Commit

```
git add packages/codex-plugin/.mcp.json packages/codex-plugin/package.json packages/codex-plugin/package-lock.json
git commit -m "feat(codex-plugin): switch to switchbot mcp serve --tools all; drop npm dependencies"
```

- [ ] Commit

---

## Task 4: Update `skills/switchbot/SKILL.md`

**Files:**
- Modify: `packages/codex-plugin/skills/switchbot/SKILL.md`

This file is the skill instruction set Codex reads. Two changes:
1. Insert a **Policy compliance** section after the Safety gates section.
2. Replace the **Audit logging** section — MCP tool calls (`send_command`, `run_scene`) do not write an audit log; update the guidance accordingly.

### Step 4.1 — Insert Policy compliance section

Locate the `---` separator after the Safety gates table (after the `quiet_hours` bullet, before `## Audit logging`). Insert the new section there.

Find this text block in `packages/codex-plugin/skills/switchbot/SKILL.md`:

```
- `quiet_hours: { start, end }` — during quiet hours, even `mutation`
  actions need confirmation.

---

## Audit logging
```

Replace with:

```
- `quiet_hours: { start, end }` — during quiet hours, even `mutation`
  actions need confirmation.

---

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

---

## Audit logging
```

- [ ] Apply the edit

### Step 4.2 — Update the Audit logging section body

Find this block:

```
## Audit logging

For every action at `mutation` tier or above, pass `--audit-log` at the
root flag level so the action is recorded:

```bash
switchbot --audit-log devices command <id> turnOn
```

If the user has `audit.log_path` set in `policy.yaml`, pass that path
explicitly: `--audit-log /path/to/file`. Without a path, the CLI appends
to `~/.switchbot/audit.log` by default. The audit log is append-only JSONL
— one line per action, with timestamp, command, arguments, and result.

You don't have to ask the user whether to log; just log. The log is the
user's receipt.
```

Replace with:

```
## Audit logging

When operating through the MCP tools (`send_command`, `run_scene`), the CLI
does not automatically write an audit log entry. To review past activity use
the built-in audit tools:

- `audit_query` — filter audit log entries by time range, device, or result.
- `audit_stats` — summarise counts by command, device, and result.

If the user asks for a full audit trail, advise them to run mutation commands
directly via the CLI with `--audit-log`:

```bash
switchbot --audit-log devices command <id> turnOn
```
```

- [ ] Apply the edit

### Step 4.3 — Commit

```
git add packages/codex-plugin/skills/switchbot/SKILL.md
git commit -m "docs(codex-plugin): add policy compliance section; update audit logging for MCP context"
```

- [ ] Commit

---

## Task 5: Final verification

### Step 5.1 — Run full test suite

```
cd packages/codex-plugin
node --test tests/*.test.js
```

Expected output contains:
```
# tests <N>
# pass <N>
# fail 0
```

- [ ] Run and confirm `fail 0`

### Step 5.2 — Verify CLI MCP server starts and lists 24 tools

```
switchbot mcp tools
```

Expected: last line reads `Total: 24 tool(s), 1 resource(s)`

- [ ] Run and confirm

### Step 5.3 — Verify `.mcp.json` is valid JSON with correct shape

```
node -e "const j = JSON.parse(require('fs').readFileSync('.mcp.json','utf8')); console.log(j.mcpServers.switchbot.command, j.mcpServers.switchbot.args)"
```

Expected: `switchbot [ 'mcp', 'serve', '--tools', 'all' ]`

- [ ] Run and confirm

### Step 5.4 — Verify `node_modules` has no runtime deps

```
node -e "const p=JSON.parse(require('fs').readFileSync('package.json','utf8')); console.log('deps:', JSON.stringify(p.dependencies ?? {}))"
```

Expected: `deps: {}`

- [ ] Run and confirm

### Step 5.5 — Smoke-test `bin/auth.js` (credentials already present)

```
node bin/auth.js
```

Expected: prints `[switchbot-codex] CLI 3.x.x detected.` then `[switchbot-codex] Credentials present (…). Skipping login.` and exits 0.

- [ ] Run and confirm exit 0
