# codex-plugin Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `packages/codex-plugin` into a self-contained MCP server with a two-layer safety architecture (policy middleware + destructive gate), fix presence-only credential checks in both packages, and align all versions to 0.8.0.

**Architecture:** `src/executor.js` wraps the SwitchBot CLI; `src/policy.js` enforces policy.yaml rules (Layer 1); `src/tools.js` applies a safety tier gate (Layer 2) and builds the unified MCP return envelope. `src/server.js` wires these into a stdio MCP server via `@modelcontextprotocol/sdk`. The `.mcp.json` points to `${pluginDir}/src/server.js` instead of `npx …@latest`.

**Tech Stack:** Node.js ≥18, `@modelcontextprotocol/sdk ^1.0.0`, `js-yaml ^4.1.0`, Node built-in `node:test`

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `packages/codex-plugin/src/executor.js` | CLI args builder + runner (adapted from openclaw-skill/cli.js) |
| Create | `packages/codex-plugin/src/policy.js` | Load policy.yaml, Layer 1 middleware |
| Create | `packages/codex-plugin/src/tools.js` | TOOL_DEFINITIONS, safety tier map, Layer 2 gate, MCP envelope |
| Create | `packages/codex-plugin/src/server.js` | MCP stdio server entry point |
| Create | `packages/codex-plugin/tests/safety.test.js` | executor + tools unit tests |
| Create | `packages/codex-plugin/tests/policy.test.js` | policy middleware unit tests |
| Create | `packages/codex-plugin/tests/server.test.js` | TOOL_DEFINITIONS structure tests |
| Modify | `packages/codex-plugin/setup/check-credentials.js` | Presence-only: doctor → keychain describe |
| Modify | `packages/codex-plugin/tests/setup.test.js` | Update credential tests to match new API |
| Modify | `packages/codex-plugin/.mcp.json` | Point to local src/server.js |
| Modify | `packages/codex-plugin/package.json` | version 0.8.0, add deps, add `src/` to files |
| Modify | `packages/codex-plugin/.codex-plugin/plugin.json` | version → 0.8.0 |
| Modify | `packages/openclaw-skill/setup/check-credentials.js` | Presence-only (same logic) |
| Modify | `packages/openclaw-skill/package.json` | version → 0.7.1 |
| Modify | `manifest.json` (root) | version → 0.8.0, update codexPlugin block |
| Modify | `CODEX_INSTALL.md` | Add recommended-install banner, wrap legacy steps in `<details>` |

---

## Task 1: Add dependencies to codex-plugin

**Files:**
- Modify: `packages/codex-plugin/package.json`

- [ ] **Step 1: Update package.json — add deps and src/ to files**

Replace the `"files"` array and add `"dependencies"` in `packages/codex-plugin/package.json`:

```json
{
  "name": "@cly-org/switchbot-codex-plugin",
  "version": "0.8.0",
  "type": "module",
  "description": "SwitchBot Codex plugin — self-contained MCP server with policy-gated safety layer",
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
    "src/",
    ".codex-plugin/",
    ".mcp.json"
  ],
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "js-yaml": "^4.1.0"
  },
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

- [ ] **Step 2: Install dependencies**

Run from `packages/codex-plugin/`:

```
npm install
```

Expected: `node_modules/@modelcontextprotocol/sdk` and `node_modules/js-yaml` appear. Exit code 0.

- [ ] **Step 3: Commit**

```bash
git add packages/codex-plugin/package.json packages/codex-plugin/package-lock.json
git commit -m "chore(codex-plugin): bump to 0.8.0, add MCP SDK and js-yaml deps"
```

---

## Task 2: Create executor.js

Adapted from `packages/openclaw-skill/cli.js`. Key differences: `buildCliArgs` takes `(tool, params, { auditLog })` — the `--audit-log` flag is now controlled externally by `tools.js` rather than hardcoded. `runCli` accepts `exec` as an injectable second parameter.

**Files:**
- Create: `packages/codex-plugin/src/executor.js`
- Create: `packages/codex-plugin/tests/safety.test.js` (executor section)

- [ ] **Step 1: Write the failing executor tests**

Create `packages/codex-plugin/tests/safety.test.js`:

```js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { buildCliArgs, runCli, looksLikeAuthError } from '../src/executor.js';

describe('buildCliArgs', () => {
  it('devices_list → [devices, list, --no-cache, --json]', () => {
    assert.deepEqual(
      buildCliArgs('devices_list', {}),
      ['devices', 'list', '--no-cache', '--json']
    );
  });

  it('devices_status → [devices, status, <id>, --no-cache, --json]', () => {
    assert.deepEqual(
      buildCliArgs('devices_status', { deviceId: 'abc' }),
      ['devices', 'status', 'abc', '--no-cache', '--json']
    );
  });

  it('devices_describe → [devices, describe, <id>, --no-cache, --json]', () => {
    assert.deepEqual(
      buildCliArgs('devices_describe', { deviceId: 'abc' }),
      ['devices', 'describe', 'abc', '--no-cache', '--json']
    );
  });

  it('scenes_list → [scenes, list, --no-cache, --json]', () => {
    assert.deepEqual(
      buildCliArgs('scenes_list', {}),
      ['scenes', 'list', '--no-cache', '--json']
    );
  });

  it('devices_command without auditLog omits --audit-log', () => {
    const args = buildCliArgs('devices_command', { deviceId: 'x', command: 'turnOn' });
    assert.ok(!args.includes('--audit-log'));
    assert.ok(args.includes('devices'));
    assert.ok(args.includes('command'));
    assert.ok(args.includes('x'));
    assert.ok(args.includes('turnOn'));
  });

  it('devices_command with auditLog:true prepends --audit-log', () => {
    const args = buildCliArgs('devices_command', { deviceId: 'x', command: 'turnOn' }, { auditLog: true });
    assert.equal(args[0], '--audit-log');
    assert.ok(args.includes('devices'));
    assert.ok(args.includes('command'));
  });

  it('devices_command with parameter appends --params <value>', () => {
    const args = buildCliArgs('devices_command', { deviceId: 'x', command: 'setBrightness', parameter: '80' });
    const idx = args.indexOf('--params');
    assert.notEqual(idx, -1);
    assert.equal(args[idx + 1], '80');
  });

  it('scenes_run without auditLog omits --audit-log', () => {
    const args = buildCliArgs('scenes_run', { sceneId: 's1' });
    assert.ok(!args.includes('--audit-log'));
    assert.ok(args.includes('scenes'));
    assert.ok(args.includes('run'));
    assert.ok(args.includes('s1'));
  });

  it('scenes_run with auditLog:true prepends --audit-log', () => {
    const args = buildCliArgs('scenes_run', { sceneId: 's1' }, { auditLog: true });
    assert.equal(args[0], '--audit-log');
  });

  it('throws on unknown tool', () => {
    assert.throws(() => buildCliArgs('unknown_tool', {}), /unknown tool/);
  });
});

describe('runCli', () => {
  it('returns parsed JSON on success', async () => {
    const fakeExec = async () => ({ stdout: JSON.stringify({ status: 'ok' }) });
    const result = await runCli(['devices', 'list', '--json'], fakeExec);
    assert.deepEqual(result, { status: 'ok' });
  });

  it('returns setup-required when CLI is missing (ENOENT)', async () => {
    const err = Object.assign(new Error('not found'), { code: 'ENOENT' });
    const fakeExec = async () => { throw err; };
    const result = await runCli(['devices', 'list'], fakeExec);
    assert.equal(result.error.kind, 'setup-required');
    assert.equal(result.error.reason, 'cli-missing');
  });

  it('returns setup-required on auth error text', async () => {
    const err = Object.assign(new Error('token not set'), { stdout: 'token not set' });
    const fakeExec = async () => { throw err; };
    const result = await runCli(['devices', 'list'], fakeExec);
    assert.equal(result.error.kind, 'setup-required');
    assert.equal(result.error.reason, 'auth-missing');
  });
});

describe('looksLikeAuthError', () => {
  it('detects "token not set"', () => assert.ok(looksLikeAuthError('token not set')));
  it('detects "Unauthorized"', () => assert.ok(looksLikeAuthError('Unauthorized')));
  it('detects "401"', () => assert.ok(looksLikeAuthError('HTTP 401')));
  it('returns false for unrelated text', () => assert.ok(!looksLikeAuthError('device not found')));
  it('returns false for empty string', () => assert.ok(!looksLikeAuthError('')));
});
```

- [ ] **Step 2: Run tests — expect failure (module not found)**

```
cd packages/codex-plugin && node --test tests/safety.test.js
```

Expected: `ERR_MODULE_NOT_FOUND` for `../src/executor.js`.

- [ ] **Step 3: Create src/executor.js**

Create `packages/codex-plugin/src/executor.js`:

```js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const defaultExec = promisify(execFile);

const READ_TOOLS = new Set([
  'devices_list',
  'devices_status',
  'devices_describe',
  'scenes_list',
]);

export function buildCliArgs(tool, params = {}, { auditLog = false } = {}) {
  const flags = READ_TOOLS.has(tool) ? ['--no-cache', '--json'] : ['--json'];
  const prefix = auditLog ? ['--audit-log'] : [];
  switch (tool) {
    case 'devices_list':
      return ['devices', 'list', ...flags];
    case 'devices_status':
      return ['devices', 'status', params.deviceId, ...flags];
    case 'devices_describe':
      return ['devices', 'describe', params.deviceId, ...flags];
    case 'devices_command': {
      const args = [...prefix, 'devices', 'command', params.deviceId, params.command, ...flags];
      if (params.parameter != null) args.push('--params', String(params.parameter));
      return args;
    }
    case 'scenes_list':
      return ['scenes', 'list', ...flags];
    case 'scenes_run':
      return [...prefix, 'scenes', 'run', params.sceneId, ...flags];
    default:
      throw new Error(`unknown tool: ${tool}`);
  }
}

const AUTH_ERROR_PATTERNS = [
  /token\s+not\s+(set|configured|found)/i,
  /credentials?\s+not\s+(set|configured|found)/i,
  /no\s+credentials/i,
  /\b401\b/,
  /unauthorized/i,
  /missing\s+(token|credentials)/i,
  /switchbot\s+config\s+set-token/i,
];

export function looksLikeAuthError(text) {
  if (!text) return false;
  return AUTH_ERROR_PATTERNS.some((re) => re.test(text));
}

function setupRequired(reason, message) {
  return {
    error: {
      kind: 'setup-required',
      reason,
      message,
      nextStep: 'Run `switchbot auth login` in a terminal to configure credentials.',
    },
  };
}

export async function runCli(args, exec = defaultExec) {
  try {
    const { stdout } = await exec('switchbot', args, { timeout: 15000 });
    return JSON.parse(stdout);
  } catch (err) {
    if (err?.code === 'ENOENT') {
      return setupRequired(
        'cli-missing',
        'SwitchBot CLI (`switchbot`) is not installed on PATH. ' +
        'Install with: npm install -g @switchbot/openapi-cli@latest',
      );
    }
    const raw = (err?.stdout ?? err?.stderr ?? err?.message) ?? String(err);
    let parsed = null;
    try { parsed = JSON.parse(raw); } catch { /* non-JSON */ }

    const kind = parsed?.error?.kind;
    if (kind === 'auth' || kind === 'credentials' || kind === 'unauthorized') {
      return setupRequired('auth-missing', 'CLI has no credentials. Run: switchbot auth login');
    }
    if (!parsed && looksLikeAuthError(raw)) {
      return setupRequired('auth-missing', 'CLI rejected with auth error. Run: switchbot auth login');
    }
    if (parsed) return parsed;
    return { error: { kind: 'internal', message: raw } };
  }
}
```

- [ ] **Step 4: Run executor tests — expect all pass**

```
cd packages/codex-plugin && node --test tests/safety.test.js
```

Expected: all `buildCliArgs`, `runCli`, and `looksLikeAuthError` tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/codex-plugin/src/executor.js packages/codex-plugin/tests/safety.test.js
git commit -m "feat(codex-plugin): add executor.js with injectable exec and auditLog flag"
```

---

## Task 3: Create policy.js

**Files:**
- Create: `packages/codex-plugin/src/policy.js`
- Create: `packages/codex-plugin/tests/policy.test.js`

- [ ] **Step 1: Write failing policy tests**

Create `packages/codex-plugin/tests/policy.test.js`:

```js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { checkPolicy, loadPolicy } from '../src/policy.js';

// ── loadPolicy ─────────────────────────────────────────────────────────────

describe('loadPolicy', () => {
  it('returns null when file does not exist', async () => {
    const result = await loadPolicy('/nonexistent/path/policy.yaml');
    assert.equal(result, null);
  });

  it('parses allowedDevices list', async () => {
    const tmp = join(tmpdir(), `sb-policy-${Date.now()}.yaml`);
    await writeFile(tmp, 'allowedDevices:\n  - device-A\n  - device-B\n');
    try {
      const policy = await loadPolicy(tmp);
      assert.deepEqual(policy.allowedDevices, ['device-A', 'device-B']);
    } finally {
      await rm(tmp, { force: true });
    }
  });

  it('parses blockedCommands list', async () => {
    const tmp = join(tmpdir(), `sb-policy-${Date.now()}.yaml`);
    await writeFile(tmp, 'blockedCommands:\n  - lockOff\n  - setBrightness\n');
    try {
      const policy = await loadPolicy(tmp);
      assert.deepEqual(policy.blockedCommands, ['lockOff', 'setBrightness']);
    } finally {
      await rm(tmp, { force: true });
    }
  });
});

// ── checkPolicy - null policy ───────────────────────────────────────────────

describe('checkPolicy — null policy', () => {
  it('returns blocked:false for any call when policy is null', () => {
    const r = checkPolicy(null, { tool: 'devices_command', deviceId: 'x', command: 'turnOn' });
    assert.deepEqual(r, { blocked: false });
  });
});

// ── checkPolicy - quietHours ────────────────────────────────────────────────

describe('checkPolicy — quietHours', () => {
  function makeDate(h, m) {
    const d = new Date();
    d.setHours(h, m, 0, 0);
    return d;
  }

  it('blocks at 23:30 within 22:00–07:00 window', () => {
    const policy = { quietHours: { start: '22:00', end: '07:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(23, 30));
    assert.equal(r.blocked, true);
    assert.equal(r.reason, 'quietHours');
    assert.ok(r.message.includes('22:00'));
  });

  it('blocks at 03:00 within 22:00–07:00 window (crosses midnight)', () => {
    const policy = { quietHours: { start: '22:00', end: '07:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(3, 0));
    assert.equal(r.blocked, true);
  });

  it('does not block at 12:00 within 22:00–07:00 window', () => {
    const policy = { quietHours: { start: '22:00', end: '07:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(12, 0));
    assert.equal(r.blocked, false);
  });

  it('blocks within a same-day window (09:00–18:00) at 14:00', () => {
    const policy = { quietHours: { start: '09:00', end: '18:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(14, 0));
    assert.equal(r.blocked, true);
  });

  it('does not block outside a same-day window at 20:00', () => {
    const policy = { quietHours: { start: '09:00', end: '18:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(20, 0));
    assert.equal(r.blocked, false);
  });
});

// ── checkPolicy - allowedDevices ────────────────────────────────────────────

describe('checkPolicy — allowedDevices', () => {
  it('blocks device not in allowlist', () => {
    const policy = { allowedDevices: ['device-A'] };
    const r = checkPolicy(policy, { tool: 'devices_command', deviceId: 'device-B' });
    assert.equal(r.blocked, true);
    assert.equal(r.reason, 'allowedDevices');
  });

  it('allows device that is in allowlist', () => {
    const policy = { allowedDevices: ['device-A'] };
    const r = checkPolicy(policy, { tool: 'devices_command', deviceId: 'device-A' });
    assert.equal(r.blocked, false);
  });

  it('allows any device when allowedDevices is empty array', () => {
    const policy = { allowedDevices: [] };
    const r = checkPolicy(policy, { tool: 'devices_command', deviceId: 'device-X' });
    assert.equal(r.blocked, false);
  });

  it('skips check when deviceId is undefined', () => {
    const policy = { allowedDevices: ['device-A'] };
    const r = checkPolicy(policy, { tool: 'devices_list' });
    assert.equal(r.blocked, false);
  });
});

// ── checkPolicy - blockedCommands ───────────────────────────────────────────

describe('checkPolicy — blockedCommands', () => {
  it('blocks command in blockedCommands list', () => {
    const policy = { blockedCommands: ['lockOff'] };
    const r = checkPolicy(policy, { tool: 'devices_command', command: 'lockOff' });
    assert.equal(r.blocked, true);
    assert.equal(r.reason, 'blockedCommands');
  });

  it('allows command not in blockedCommands list', () => {
    const policy = { blockedCommands: ['lockOff'] };
    const r = checkPolicy(policy, { tool: 'devices_command', command: 'turnOn' });
    assert.equal(r.blocked, false);
  });

  it('skips check when command is undefined', () => {
    const policy = { blockedCommands: ['lockOff'] };
    const r = checkPolicy(policy, { tool: 'scenes_run' });
    assert.equal(r.blocked, false);
  });
});
```

- [ ] **Step 2: Run tests — expect failure (module not found)**

```
cd packages/codex-plugin && node --test tests/policy.test.js
```

Expected: `ERR_MODULE_NOT_FOUND` for `../src/policy.js`.

- [ ] **Step 3: Create src/policy.js**

Create `packages/codex-plugin/src/policy.js`:

```js
import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { resolve } from 'node:path';
import { load as parseYaml } from 'js-yaml';

export const DEFAULT_POLICY_PATH = '~/.config/openclaw/switchbot/policy.yaml';

function expandHome(p) {
  if (p === '~' || p.startsWith('~/') || p.startsWith('~\\')) {
    return resolve(homedir(), p.slice(2));
  }
  return p;
}

export async function loadPolicy(policyPath = DEFAULT_POLICY_PATH) {
  const fullPath = expandHome(policyPath);
  try {
    const content = await readFile(fullPath, 'utf8');
    return parseYaml(content) ?? null;
  } catch (err) {
    if (err.code === 'ENOENT') return null;
    throw err;
  }
}

function isInQuietHours({ start, end }, now) {
  const [sh, sm] = start.split(':').map(Number);
  const [eh, em] = end.split(':').map(Number);
  const current = now.getHours() * 60 + now.getMinutes();
  const startMin = sh * 60 + sm;
  const endMin = eh * 60 + em;
  if (startMin <= endMin) {
    return current >= startMin && current < endMin;
  }
  // crosses midnight
  return current >= startMin || current < endMin;
}

export function checkPolicy(policy, { tool, deviceId, command }, now = new Date()) {
  if (!policy) return { blocked: false };

  if (policy.quietHours?.start && policy.quietHours?.end) {
    if (isInQuietHours(policy.quietHours, now)) {
      return {
        blocked: true,
        reason: 'quietHours',
        message: `Blocked during quiet hours (${policy.quietHours.start}–${policy.quietHours.end})`,
      };
    }
  }

  if (deviceId && policy.allowedDevices?.length > 0) {
    if (!policy.allowedDevices.includes(deviceId)) {
      return {
        blocked: true,
        reason: 'allowedDevices',
        message: `Device '${deviceId}' is not in the allowed devices list`,
      };
    }
  }

  if (command && policy.blockedCommands?.length > 0) {
    if (policy.blockedCommands.includes(command)) {
      return {
        blocked: true,
        reason: 'blockedCommands',
        message: `Command '${command}' is blocked by policy`,
      };
    }
  }

  return { blocked: false };
}
```

- [ ] **Step 4: Run policy tests — expect all pass**

```
cd packages/codex-plugin && node --test tests/policy.test.js
```

Expected: all 15 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/codex-plugin/src/policy.js packages/codex-plugin/tests/policy.test.js
git commit -m "feat(codex-plugin): add policy.js — quietHours/allowedDevices/blockedCommands middleware"
```

---

## Task 4: Create tools.js (safety tier gate + MCP envelope)

**Files:**
- Create: `packages/codex-plugin/src/tools.js`
- Modify: `packages/codex-plugin/tests/safety.test.js` (append tools section)

- [ ] **Step 1: Append tools tests to safety.test.js**

Append to the bottom of `packages/codex-plugin/tests/safety.test.js`:

```js
import { getTier, callTool, TOOL_DEFINITIONS } from '../src/tools.js';

describe('getTier', () => {
  it('devices_list → read', () => assert.equal(getTier('devices_list', undefined, null), 'read'));
  it('devices_status → read', () => assert.equal(getTier('devices_status', undefined, null), 'read'));
  it('devices_describe → read', () => assert.equal(getTier('devices_describe', undefined, null), 'read'));
  it('scenes_list → read', () => assert.equal(getTier('scenes_list', undefined, null), 'read'));

  it('scenes_run defaults to mutation', () => {
    assert.equal(getTier('scenes_run', undefined, null), 'mutation');
  });

  it('scenes_run upgrades to destructive when policy.scenesTier = destructive', () => {
    assert.equal(getTier('scenes_run', undefined, { scenesTier: 'destructive' }), 'destructive');
  });

  it('devices_command with lockOff → destructive', () => {
    assert.equal(getTier('devices_command', 'lockOff', null), 'destructive');
  });

  it('devices_command with turnOn → mutation', () => {
    assert.equal(getTier('devices_command', 'turnOn', null), 'mutation');
  });

  it('devices_command with setBrightness → mutation', () => {
    assert.equal(getTier('devices_command', 'setBrightness', null), 'mutation');
  });
});

describe('callTool', () => {
  it('destructive command without confirmed returns requiresConfirmation:true', async () => {
    const fakeExec = async () => { throw new Error('should not be called'); };
    const result = await callTool('devices_command',
      { deviceId: 'id1', command: 'lockOff' },
      { exec: fakeExec, policy: null }
    );
    assert.equal(result.requiresConfirmation, true);
    assert.equal(result.safetyTier, 'destructive');
    assert.ok(result.message.includes('lockOff'));
    assert.equal(result.auditLogPath, undefined);
  });

  it('destructive command with confirmed:true executes and includes auditLogPath', async () => {
    let capturedArgs;
    const fakeExec = async (cmd, args) => {
      capturedArgs = args;
      return { stdout: JSON.stringify({ status: 'success' }) };
    };
    const result = await callTool('devices_command',
      { deviceId: 'id1', command: 'lockOff', confirmed: true },
      { exec: fakeExec, policy: null }
    );
    assert.equal(result.requiresConfirmation, false);
    assert.equal(result.safetyTier, 'destructive');
    assert.ok(result.auditLogPath, 'auditLogPath must be present for destructive');
    assert.ok(capturedArgs.includes('--audit-log'));
  });

  it('mutation command executes with --audit-log and includes auditLogPath', async () => {
    let capturedArgs;
    const fakeExec = async (cmd, args) => {
      capturedArgs = args;
      return { stdout: JSON.stringify({ status: 'ok' }) };
    };
    const result = await callTool('devices_command',
      { deviceId: 'id1', command: 'turnOn' },
      { exec: fakeExec, policy: null }
    );
    assert.equal(result.safetyTier, 'mutation');
    assert.equal(result.requiresConfirmation, false);
    assert.ok(result.auditLogPath);
    assert.ok(capturedArgs.includes('--audit-log'));
  });

  it('read tool executes without --audit-log and no auditLogPath', async () => {
    let capturedArgs;
    const fakeExec = async (cmd, args) => {
      capturedArgs = args;
      return { stdout: JSON.stringify([]) };
    };
    const result = await callTool('devices_list', {}, { exec: fakeExec, policy: null });
    assert.equal(result.safetyTier, 'read');
    assert.equal(result.requiresConfirmation, false);
    assert.equal(result.auditLogPath, undefined);
    assert.ok(!capturedArgs.includes('--audit-log'));
  });

  it('scenes_run with scenesTier:destructive and no confirmed returns requiresConfirmation', async () => {
    const fakeExec = async () => { throw new Error('should not be called'); };
    const result = await callTool('scenes_run',
      { sceneId: 's1' },
      { exec: fakeExec, policy: { scenesTier: 'destructive' } }
    );
    assert.equal(result.requiresConfirmation, true);
    assert.equal(result.safetyTier, 'destructive');
  });
});
```

- [ ] **Step 2: Run tests — expect failure (tools module not found)**

```
cd packages/codex-plugin && node --test tests/safety.test.js
```

Expected: `ERR_MODULE_NOT_FOUND` for `../src/tools.js`.

- [ ] **Step 3: Create src/tools.js**

Create `packages/codex-plugin/src/tools.js`:

```js
import { buildCliArgs, runCli } from './executor.js';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const defaultExec = promisify(execFile);

const DESTRUCTIVE_COMMANDS = new Set(['lockOff']);

const AUDIT_LOG_PATH = '~/.config/openclaw/switchbot/audit.log';

export function getTier(toolName, command, policy) {
  if (
    toolName === 'devices_list' ||
    toolName === 'devices_status' ||
    toolName === 'devices_describe' ||
    toolName === 'scenes_list'
  ) {
    return 'read';
  }
  if (toolName === 'scenes_run') {
    return policy?.scenesTier === 'destructive' ? 'destructive' : 'mutation';
  }
  if (toolName === 'devices_command') {
    return DESTRUCTIVE_COMMANDS.has(command) ? 'destructive' : 'mutation';
  }
  return 'mutation';
}

export async function callTool(toolName, args = {}, { exec = defaultExec, policy = null } = {}) {
  const tier = getTier(toolName, args.command, policy);
  const auditLog = tier === 'mutation' || tier === 'destructive';

  if (tier === 'destructive' && !args.confirmed) {
    return {
      requiresConfirmation: true,
      safetyTier: 'destructive',
      message:
        `Command '${args.command || toolName}' requires explicit user confirmation. ` +
        'Call again with confirmed: true after the user has approved.',
    };
  }

  const cliArgs = buildCliArgs(toolName, args, { auditLog });
  const result = await runCli(cliArgs, exec);

  const envelope = { result, safetyTier: tier, requiresConfirmation: false };
  if (auditLog) envelope.auditLogPath = AUDIT_LOG_PATH;
  return envelope;
}

export const TOOL_DEFINITIONS = [
  {
    name: 'devices_list',
    description: 'List all SwitchBot devices. Safety tier: read.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'devices_status',
    description: 'Get the current status of a SwitchBot device. Safety tier: read.',
    inputSchema: {
      type: 'object',
      properties: {
        deviceId: { type: 'string', description: 'SwitchBot device ID' },
      },
      required: ['deviceId'],
    },
  },
  {
    name: 'devices_describe',
    description: 'Get metadata about a SwitchBot device (type, capabilities). Safety tier: read.',
    inputSchema: {
      type: 'object',
      properties: {
        deviceId: { type: 'string', description: 'SwitchBot device ID' },
      },
      required: ['deviceId'],
    },
  },
  {
    name: 'devices_command',
    description:
      'Send a command to a SwitchBot device. Safety tier: mutation for most commands; ' +
      'destructive for lock commands (lockOff) — requires confirmed: true.',
    inputSchema: {
      type: 'object',
      properties: {
        deviceId: { type: 'string', description: 'SwitchBot device ID' },
        command: { type: 'string', description: 'Command name, e.g. turnOn, turnOff, lockOff' },
        parameter: {
          type: 'string',
          description: 'Optional command parameter value (e.g. brightness level)',
        },
        confirmed: {
          type: 'boolean',
          description:
            'Must be true to execute destructive-tier commands (e.g. lockOff). ' +
            'Obtain explicit user consent before setting this.',
        },
      },
      required: ['deviceId', 'command'],
    },
  },
  {
    name: 'scenes_list',
    description: 'List all SwitchBot scenes. Safety tier: read.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'scenes_run',
    description:
      'Run a SwitchBot scene. Safety tier: mutation by default; ' +
      'destructive when policy.yaml sets scenesTier: destructive (requires confirmed: true).',
    inputSchema: {
      type: 'object',
      properties: {
        sceneId: { type: 'string', description: 'SwitchBot scene ID' },
        confirmed: {
          type: 'boolean',
          description: 'Required when scenesTier is set to destructive in policy.yaml.',
        },
      },
      required: ['sceneId'],
    },
  },
];
```

- [ ] **Step 4: Run all safety tests — expect all pass**

```
cd packages/codex-plugin && node --test tests/safety.test.js
```

Expected: all `buildCliArgs`, `runCli`, `looksLikeAuthError`, `getTier`, and `callTool` tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/codex-plugin/src/tools.js packages/codex-plugin/tests/safety.test.js
git commit -m "feat(codex-plugin): add tools.js — safety tier gate, TOOL_DEFINITIONS, MCP envelope"
```

---

## Task 5: Create server.js and server.test.js

**Files:**
- Create: `packages/codex-plugin/src/server.js`
- Create: `packages/codex-plugin/tests/server.test.js`

- [ ] **Step 1: Write server structure tests**

Create `packages/codex-plugin/tests/server.test.js`:

```js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { TOOL_DEFINITIONS } from '../src/tools.js';

const EXPECTED_TOOLS = [
  'devices_list',
  'devices_status',
  'devices_describe',
  'devices_command',
  'scenes_list',
  'scenes_run',
];

describe('TOOL_DEFINITIONS', () => {
  it('has exactly 6 tools', () => {
    assert.equal(TOOL_DEFINITIONS.length, 6);
  });

  it('contains all expected tool names', () => {
    const names = TOOL_DEFINITIONS.map((t) => t.name);
    for (const expected of EXPECTED_TOOLS) {
      assert.ok(names.includes(expected), `Missing tool: ${expected}`);
    }
  });

  it('every tool has an inputSchema with type:object', () => {
    for (const tool of TOOL_DEFINITIONS) {
      assert.ok(tool.inputSchema, `${tool.name} missing inputSchema`);
      assert.equal(tool.inputSchema.type, 'object', `${tool.name} inputSchema.type != object`);
      assert.ok(Array.isArray(tool.inputSchema.required), `${tool.name} missing required array`);
    }
  });

  it('devices_command has boolean confirmed property', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'devices_command');
    assert.ok(tool, 'devices_command not found');
    assert.ok(
      tool.inputSchema.properties.confirmed,
      'devices_command missing confirmed parameter',
    );
    assert.equal(tool.inputSchema.properties.confirmed.type, 'boolean');
  });

  it('scenes_run has boolean confirmed property', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'scenes_run');
    assert.ok(tool, 'scenes_run not found');
    assert.ok(tool.inputSchema.properties.confirmed, 'scenes_run missing confirmed parameter');
    assert.equal(tool.inputSchema.properties.confirmed.type, 'boolean');
  });

  it('all tools have non-empty description mentioning safety tier', () => {
    for (const tool of TOOL_DEFINITIONS) {
      assert.ok(
        tool.description && tool.description.toLowerCase().includes('safety tier'),
        `${tool.name} description missing 'Safety tier'`,
      );
    }
  });
});
```

- [ ] **Step 2: Run tests — expect all pass (uses tools.js, no new module needed)**

```
cd packages/codex-plugin && node --test tests/server.test.js
```

Expected: all 6 structural tests pass.

- [ ] **Step 3: Create src/server.js**

Create `packages/codex-plugin/src/server.js`:

```js
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { fileURLToPath } from 'node:url';
import { TOOL_DEFINITIONS, callTool } from './tools.js';
import { loadPolicy, checkPolicy } from './policy.js';

export function createMcpServer() {
  const server = new Server(
    { name: 'switchbot', version: '0.8.0' },
    { capabilities: { tools: {} } },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: TOOL_DEFINITIONS,
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args = {} } = request.params;

    const policy = await loadPolicy().catch(() => null);

    const policyResult = checkPolicy(policy, {
      tool: name,
      deviceId: args.deviceId,
      command: args.command,
    });

    if (policyResult.blocked) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              blocked: true,
              reason: policyResult.reason,
              message: policyResult.message,
            }),
          },
        ],
      };
    }

    const result = await callTool(name, args, { policy });
    return {
      content: [{ type: 'text', text: JSON.stringify(result) }],
    };
  });

  return server;
}

const __filename = fileURLToPath(import.meta.url);
if (process.argv[1] === __filename) {
  const server = createMcpServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}
```

- [ ] **Step 4: Commit**

```bash
git add packages/codex-plugin/src/server.js packages/codex-plugin/tests/server.test.js
git commit -m "feat(codex-plugin): add MCP server.js with policy + safety gate handlers"
```

---

## Task 6: Wire up .mcp.json

**Files:**
- Modify: `packages/codex-plugin/.mcp.json`

- [ ] **Step 1: Replace .mcp.json content**

Replace the entire content of `packages/codex-plugin/.mcp.json` with:

```json
{
  "mcpServers": {
    "switchbot": {
      "command": "node",
      "args": ["${pluginDir}/src/server.js"],
      "description": "SwitchBot smart-home MCP server (6 tools, policy-gated, self-contained)"
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/codex-plugin/.mcp.json
git commit -m "fix(codex-plugin): point .mcp.json to local src/server.js (remove @latest npx)"
```

---

## Task 7: Fix check-credentials.js in codex-plugin (presence-only)

Replaces token/secret field inspection with: (1) `switchbot doctor --json` checking `credentials.configured`, then (2) `switchbot auth keychain describe --json` checking exit code only.

**Files:**
- Modify: `packages/codex-plugin/setup/check-credentials.js`
- Modify: `packages/codex-plugin/tests/setup.test.js`

- [ ] **Step 1: Update setup.test.js — replace broken credential tests**

In `packages/codex-plugin/tests/setup.test.js`, replace the entire `describe('checkCredentials', ...)` block (lines 56–104) with:

```js
import { makeCheckCredentials } from '../setup/check-credentials.js';

describe('checkCredentials', () => {
  it('returns ok:true source:doctor when doctor reports credentials.configured:true', async () => {
    const fakeExec = async (cmd, args) => {
      if (args.includes('doctor')) {
        return { stdout: JSON.stringify({ data: { credentials: { configured: true } } }) };
      }
      throw new Error('unexpected call');
    };
    const check = makeCheckCredentials(fakeExec);
    const result = await check();
    assert.deepEqual(result, { ok: true, source: 'doctor' });
  });

  it('falls back to keychain describe when doctor fails', async () => {
    const fakeExec = async (cmd, args) => {
      if (args.includes('doctor')) throw new Error('doctor failed');
      if (args.includes('describe')) return { stdout: '{}' };
      throw new Error('unexpected');
    };
    const check = makeCheckCredentials(fakeExec);
    const result = await check();
    assert.deepEqual(result, { ok: true, source: 'keychain' });
  });

  it('returns ok:false when both doctor and keychain describe fail', async () => {
    const fakeExec = async () => { throw new Error('all fail'); };
    const check = makeCheckCredentials(fakeExec);
    const result = await check();
    assert.equal(result.ok, false);
    assert.match(result.message, /switchbot auth login/);
  });

  it('never passes token or secret values to exec', async () => {
    const passedArgs = [];
    const fakeExec = async (cmd, args) => {
      passedArgs.push(...args);
      if (args.includes('doctor')) {
        return { stdout: JSON.stringify({ data: { credentials: { configured: true } } }) };
      }
      throw new Error('unexpected');
    };
    const check = makeCheckCredentials(fakeExec);
    await check();
    const sensitive = passedArgs.filter(
      (a) => typeof a === 'string' && (a.includes('token') || a.includes('secret'))
    );
    assert.deepEqual(sensitive, [], `Sensitive args leaked: ${sensitive.join(', ')}`);
  });

  it('falls back to keychain when doctor returns credentials.configured:false', async () => {
    const fakeExec = async (cmd, args) => {
      if (args.includes('doctor')) {
        return { stdout: JSON.stringify({ data: { credentials: { configured: false } } }) };
      }
      if (args.includes('describe')) return { stdout: '{}' };
      throw new Error('unexpected');
    };
    const check = makeCheckCredentials(fakeExec);
    const result = await check();
    assert.deepEqual(result, { ok: true, source: 'keychain' });
  });
});
```

- [ ] **Step 2: Run tests — expect credential tests to fail (still old impl)**

```
cd packages/codex-plugin && node --test tests/setup.test.js
```

Expected: `checkCli` tests pass; `checkCredentials` tests fail.

- [ ] **Step 3: Replace check-credentials.js**

Replace the entire content of `packages/codex-plugin/setup/check-credentials.js` with:

```js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

async function tryDoctor(exec) {
  try {
    const { stdout } = await exec('switchbot', ['doctor', '--json'], { timeout: 10000 });
    const data = (JSON.parse(stdout)?.data ?? JSON.parse(stdout));
    return data?.credentials?.configured === true;
  } catch (err) {
    if (err?.code === 'ENOENT') throw err;
    return false;
  }
}

async function tryKeychainDescribe(exec) {
  try {
    await exec('switchbot', ['auth', 'keychain', 'describe', '--json'], { timeout: 8000 });
    return true;
  } catch {
    return false;
  }
}

export function makeCheckCredentials(exec) {
  return async function checkCredentials() {
    try {
      if (await tryDoctor(exec)) return { ok: true, source: 'doctor' };
    } catch {
      // CLI missing — fall through to keychain
    }
    if (await tryKeychainDescribe(exec)) return { ok: true, source: 'keychain' };
    return {
      ok: false,
      message: 'SwitchBot credentials not configured. Run: switchbot auth login',
    };
  };
}

const defaultExec = promisify(execFile);
export const checkCredentials = makeCheckCredentials(defaultExec);
```

- [ ] **Step 4: Run all setup tests — expect all pass**

```
cd packages/codex-plugin && node --test tests/setup.test.js
```

Expected: all `checkCli` and `checkCredentials` tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/codex-plugin/setup/check-credentials.js packages/codex-plugin/tests/setup.test.js
git commit -m "fix(codex-plugin): presence-only credential check — doctor→keychain describe, no token/secret reads"
```

---

## Task 8: Fix check-credentials.js in openclaw-skill (presence-only)

Same logic as Task 7 but without dependency injection (openclaw-skill uses module-level exec).

**Files:**
- Modify: `packages/openclaw-skill/setup/check-credentials.js`

- [ ] **Step 1: Replace check-credentials.js**

Replace the entire content of `packages/openclaw-skill/setup/check-credentials.js` with:

```js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execFile);

async function tryDoctor() {
  try {
    const { stdout } = await exec('switchbot', ['doctor', '--json'], { timeout: 10000 });
    const data = (JSON.parse(stdout)?.data ?? JSON.parse(stdout));
    return data?.credentials?.configured === true;
  } catch (err) {
    if (err?.code === 'ENOENT') throw err;
    return false;
  }
}

async function tryKeychainDescribe() {
  try {
    await exec('switchbot', ['auth', 'keychain', 'describe', '--json'], { timeout: 8000 });
    return true;
  } catch {
    return false;
  }
}

export async function checkCredentials() {
  try {
    if (await tryDoctor()) return { ok: true };
  } catch {
    // CLI missing
  }
  if (await tryKeychainDescribe()) return { ok: true };
  return {
    ok: false,
    message:
      'SwitchBot 账号尚未配置。请在终端运行以下命令完成配置：\n\n  switchbot auth login\n\n' +
      '（token 和 secret 可在 SwitchBot App → 个人中心 → 开发者选项 中获取）',
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/openclaw-skill/setup/check-credentials.js
git commit -m "fix(openclaw-skill): presence-only credential check — doctor→keychain describe"
```

---

## Task 9: Version alignment

**Files:**
- Modify: `packages/openclaw-skill/package.json`
- Modify: `packages/codex-plugin/.codex-plugin/plugin.json`
- Modify: `manifest.json` (root)

- [ ] **Step 1: Bump openclaw-skill to 0.7.1**

In `packages/openclaw-skill/package.json`, change line 4:

```json
"version": "0.7.1",
```

- [ ] **Step 2: Bump codex-plugin plugin.json to 0.8.0**

In `packages/codex-plugin/.codex-plugin/plugin.json`, change line 3:

```json
"version": "0.8.0",
```

- [ ] **Step 3: Update root manifest.json**

In `manifest.json`, make these two changes:

Change line 4:
```json
"version": "0.8.0",
```

Replace the `"codexPlugin"` block (lines 64–69):
```json
"codexPlugin": {
  "status": "repo-marketplace",
  "path": "./packages/codex-plugin",
  "marketplace": "./.agents/plugins/marketplace.json"
},
```

- [ ] **Step 4: Commit**

```bash
git add packages/openclaw-skill/package.json packages/codex-plugin/.codex-plugin/plugin.json manifest.json
git commit -m "chore: version alignment — openclaw-skill 0.7.1, codex-plugin 0.8.0, root manifest 0.8.0"
```

---

## Task 10: Update CODEX_INSTALL.md

**Files:**
- Modify: `CODEX_INSTALL.md`

- [ ] **Step 1: Add recommended-install banner and wrap legacy content**

Replace the entire content of `CODEX_INSTALL.md` with:

```markdown
# SwitchBot Skill — Codex Install

> **Recommended install:** Codex app → Plugins → Add from local path → `packages/codex-plugin/`
> Or via CLI: `codex plugin marketplace add .`
>
> The manual steps below are a **Legacy path** for older Codex versions that do not support the plugin system.

---

<details>
<summary>Legacy: Manual Installation (older Codex without plugin support)</summary>

You are a Codex agent. Read this section completely, then execute every step below.
Do **not** ask the user for SwitchBot tokens or secrets — those come from the browser login in Step 5.

---

## Step 1: Check Node.js

Run: `node --version`

If Node.js is missing or below v18, tell the user to install it from https://nodejs.org and stop.

---

## Step 2: Install the SwitchBot CLI

Run:

```
npm install -g @switchbot/openapi-cli@latest
```

Then confirm: `switchbot --version` must print `3.3.0` or higher.
If it prints a lower version, stop and tell the user to check their npm global prefix.

---

## Step 3: Enable plugin hooks in Codex config

Read `~/.codex/config.toml` (create the file if it does not exist).

Ensure the file contains:

```toml
[features]
plugin_hooks = true
```

Rules:
- If the file does not exist → create it with just those two lines.
- If a `[features]` section exists but `plugin_hooks` is missing → add the key under it.
- If `plugin_hooks` exists but is not `true` → update it to `true`.
- Do not touch any other keys in the file.

---

## Step 4: Write AGENTS.md

Clone or update the skill repo:

```
git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
```

If `~/switchbot-skill` already exists, run `git -C ~/switchbot-skill pull origin main` instead.

Read `~/switchbot-skill/SKILL.md`.
Strip the YAML front matter block (the lines from the first `---` to the second `---`, inclusive).
Write the remaining content to `~/.codex/AGENTS.md`, creating the directory if needed.

---

## Step 5: Authenticate

Tell the user:

> "A browser window will open — sign in with your SwitchBot account.
> Your credentials are stored securely in the OS keychain; you only do this once."

Run: `switchbot auth login`

If the browser cannot open (headless or SSH environment), run:

```
switchbot auth login --no-open
```

and show the printed URL to the user so they can open it on any machine.

---

## Step 6: Verify

Run both:

```
switchbot --version
switchbot doctor
```

`doctor` must end with `0 fail`.
If it reports failures, show the output and tell the user to follow the printed fix commands, then re-run `switchbot doctor` before continuing.

---

## Step 7: Done

Tell the user:

> "SwitchBot skill installed for Codex.
> Restart Codex if it is already open, then try:
> **List my SwitchBot devices and tell me which ones are currently on.**"

</details>
```

- [ ] **Step 2: Run all tests to verify nothing broke**

```
cd packages/codex-plugin && npm test
```

Expected: all tests in `tests/setup.test.js`, `tests/auth.test.js`, `tests/safety.test.js`, `tests/policy.test.js`, `tests/server.test.js` pass.

- [ ] **Step 3: Commit**

```bash
git add CODEX_INSTALL.md
git commit -m "docs: demote CODEX_INSTALL.md manual steps to Legacy, add recommended plugin-install path"
```

---

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| Self-contained codex-plugin (remove @latest) | Tasks 5, 6 |
| Wrapper 6 tools (not CLI native 24) | Task 4 (TOOL_DEFINITIONS) |
| Policy middleware (quietHours, allowedDevices, blockedCommands) | Task 3 |
| Destructive gate with confirmed: true | Task 4 (callTool) |
| Audit-log for mutation + destructive | Task 4 (callTool) |
| MCP return envelope (safetyTier, requiresConfirmation, auditLogPath) | Task 4 |
| Presence-only credential check (codex-plugin) | Task 7 |
| Presence-only credential check (openclaw-skill) | Task 8 |
| Version alignment 0.8.0 / 0.7.1 | Task 9 |
| CODEX_INSTALL.md legacy banner | Task 10 |
| Tests: server, policy, safety, credentials | Tasks 2–5, 7 |

All spec requirements covered. No gaps found.
