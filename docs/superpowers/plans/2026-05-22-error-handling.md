# Error Handling & Auth Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all inline error strings with a centralized `error-messages.js` registry (reason + fix + hint), covering: auth-not-configured, login-failed, token-expired, cli-not-installed, cli-version-too-low; add uninstall verification output and re-login documentation.

**Architecture:** New `lib/error-messages.js` in each package defines a keyed registry; all setup/auth callers import `formatError(key)` instead of building strings. Script changes (bootstrap, uninstall) are Bash/PS string edits. Documentation appended to `troubleshooting.md`.

**Tech Stack:** Node.js ESM (`import`/`export`), Node built-in test runner (`node --test`), Bash, PowerShell 7

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `packages/openclaw-skill/lib/error-messages.js` | Error registry + `formatError()` |
| Create | `packages/openclaw-skill/tests/error-messages.test.js` | Unit tests for error-messages |
| Modify | `packages/openclaw-skill/setup/check-credentials.js` | Refactor to DI + use formatError |
| Modify | `packages/openclaw-skill/setup/check-cli.js` | Use formatError for error messages |
| Modify | `packages/openclaw-skill/cli.js` | Use formatError in setupRequired calls |
| Modify | `packages/openclaw-skill/bin/setup-flow.js` | Use formatError at failure points |
| Create | `packages/codex-plugin/lib/error-messages.js` | Identical copy for codex-plugin |
| Modify | `packages/codex-plugin/setup/check-credentials.js` | Use formatError |
| Modify | `packages/codex-plugin/bin/auth.js` | Use formatError for login-failed |
| Modify | `scripts/bootstrap.sh` | Add auth hint when doctor fails post-install |
| Modify | `scripts/bootstrap.ps1` | Same (PowerShell) |
| Modify | `scripts/uninstall.sh` | Print 4 verification commands at end |
| Modify | `scripts/uninstall.ps1` | Same (PowerShell) |
| Modify | `troubleshooting.md` | Add 3 new sections |

---

### Task 1: Create `packages/openclaw-skill/lib/error-messages.js` with tests

**Files:**
- Create: `packages/openclaw-skill/lib/error-messages.js`
- Create: `packages/openclaw-skill/tests/error-messages.test.js`

- [ ] **Step 1: Write the failing test**

```js
// packages/openclaw-skill/tests/error-messages.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ERRORS, formatError } from '../lib/error-messages.js';

describe('ERRORS registry', () => {
  const EXPECTED_KEYS = [
    'auth-not-configured',
    'auth-login-failed',
    'token-expired',
    'cli-not-installed',
    'cli-version-too-low',
  ];

  it('defines all required keys', () => {
    for (const key of EXPECTED_KEYS) {
      assert.ok(key in ERRORS, `missing key: ${key}`);
    }
  });

  it('each entry has reason, fix, and hint', () => {
    for (const [key, entry] of Object.entries(ERRORS)) {
      assert.ok(entry.reason, `${key}: missing reason`);
      assert.ok(entry.fix,    `${key}: missing fix`);
      assert.ok(entry.hint,   `${key}: missing hint`);
    }
  });
});

describe('formatError', () => {
  it('returns a string with Error:, Fix:, and Hint: lines', () => {
    const out = formatError('auth-not-configured');
    assert.match(out, /^Error:/m);
    assert.match(out, /Fix:/m);
    assert.match(out, /Hint:/m);
  });

  it('embeds the reason for auth-not-configured', () => {
    const out = formatError('auth-not-configured');
    assert.ok(out.includes('credentials are not configured'), out);
  });

  it('fix for token-expired contains logout && login', () => {
    const out = formatError('token-expired');
    assert.ok(out.includes('auth logout'), out);
    assert.ok(out.includes('auth login'), out);
  });

  it('throws for unknown key', () => {
    assert.throws(() => formatError('no-such-key'), /unknown error key/);
  });
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
cd packages/openclaw-skill
node --test tests/error-messages.test.js
```

Expected: `ERR_MODULE_NOT_FOUND` or similar — `lib/error-messages.js` does not exist yet.

- [ ] **Step 3: Create `lib/error-messages.js`**

```js
// packages/openclaw-skill/lib/error-messages.js
export const ERRORS = {
  'auth-not-configured': {
    reason: 'SwitchBot credentials are not configured.',
    fix:    'switchbot auth login',
    hint:   'Run the fix command, then restart your MCP client.',
  },
  'auth-login-failed': {
    reason: 'Login failed — the CLI returned a non-zero exit code.',
    fix:    'switchbot auth login',
    hint:   'Check your network connection and try again.',
  },
  'token-expired': {
    reason: 'Credentials exist but doctor check failed — token may be expired.',
    fix:    'switchbot auth logout && switchbot auth login',
    hint:   'After re-login, run `switchbot doctor` to verify.',
  },
  'cli-not-installed': {
    reason: 'switchbot CLI is not installed or not in PATH.',
    fix:    'npm install -g @switchbot/openapi-cli',
    hint:   'After install, run `switchbot doctor` to confirm.',
  },
  'cli-version-too-low': {
    reason: 'switchbot CLI version is below the required minimum (3.7.1).',
    fix:    'npm install -g @switchbot/openapi-cli@latest',
    hint:   'After upgrade, re-run setup.',
  },
};

export function formatError(key) {
  const e = ERRORS[key];
  if (!e) throw new Error(`unknown error key: ${key}`);
  return [
    `Error: ${e.reason}`,
    `  Fix:  ${e.fix}`,
    `  Hint: ${e.hint}`,
  ].join('\n');
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```
cd packages/openclaw-skill
node --test tests/error-messages.test.js
```

Expected: all tests PASS, no failures.

- [ ] **Step 5: Commit**

```bash
git add packages/openclaw-skill/lib/error-messages.js packages/openclaw-skill/tests/error-messages.test.js
git commit -m "feat(openclaw-skill): add lib/error-messages.js — centralized error registry"
```

---

### Task 2: Refactor `packages/openclaw-skill/setup/check-credentials.js`

**Files:**
- Modify: `packages/openclaw-skill/setup/check-credentials.js`

Context: `tryDoctor()` currently returns a plain boolean — it can't distinguish "credentials.configured === false" from "doctor exited non-zero". We need that distinction to map correctly to `auth-not-configured` vs `token-expired`.

- [ ] **Step 1: Write a failing test for the new behaviour**

Add to a new file `packages/openclaw-skill/tests/check-credentials.test.js`:

```js
// packages/openclaw-skill/tests/check-credentials.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { makeCheckCredentials } from '../setup/check-credentials.js';

// Helpers that mimic exec() behaviour
function execReturningDoctor(configured) {
  return async (cmd, args) => {
    if (args[0] === 'doctor') {
      return { stdout: JSON.stringify({ data: { credentials: { configured } } }) };
    }
    throw Object.assign(new Error('keychain error'), { code: 1 });
  };
}

function execDoctorFails() {
  return async (_cmd, args) => {
    if (args[0] === 'doctor') {
      const err = new Error('non-zero exit');
      err.code = 1;
      throw err;
    }
    throw Object.assign(new Error('keychain error'), { code: 1 });
  };
}

function execCliMissing() {
  return async () => {
    throw Object.assign(new Error('ENOENT'), { code: 'ENOENT' });
  };
}

function execKeychainOk() {
  return async (_cmd, args) => {
    if (args[0] === 'doctor') throw Object.assign(new Error('ENOENT'), { code: 'ENOENT' });
    if (args[1] === 'keychain') return { stdout: '{}' };
    throw new Error('unexpected');
  };
}

describe('makeCheckCredentials', () => {
  it('returns ok:true when doctor says configured', async () => {
    const check = makeCheckCredentials(execReturningDoctor(true));
    assert.deepEqual(await check(), { ok: true });
  });

  it('returns auth-not-configured when doctor says not configured and keychain fails', async () => {
    const check = makeCheckCredentials(execReturningDoctor(false));
    const result = await check();
    assert.equal(result.ok, false);
    assert.match(result.message, /credentials are not configured/);
    assert.match(result.message, /switchbot auth login/);
  });

  it('returns token-expired when doctor command exits non-zero', async () => {
    const check = makeCheckCredentials(execDoctorFails());
    const result = await check();
    assert.equal(result.ok, false);
    assert.match(result.message, /doctor check failed/);
    assert.match(result.message, /auth logout/);
  });

  it('returns ok:true when CLI missing but keychain succeeds', async () => {
    const check = makeCheckCredentials(execKeychainOk());
    assert.deepEqual(await check(), { ok: true });
  });

  it('returns auth-not-configured when CLI missing and keychain fails', async () => {
    const check = makeCheckCredentials(execCliMissing());
    const result = await check();
    assert.equal(result.ok, false);
    assert.match(result.message, /credentials are not configured/);
  });
});
```

- [ ] **Step 2: Run tests to confirm they fail**

```
cd packages/openclaw-skill
node --test tests/check-credentials.test.js
```

Expected: `TypeError: makeCheckCredentials is not a function` (not yet exported).

- [ ] **Step 3: Rewrite `check-credentials.js`**

```js
// packages/openclaw-skill/setup/check-credentials.js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { formatError } from '../lib/error-messages.js';

async function tryDoctor(exec) {
  try {
    const { stdout } = await exec('switchbot', ['doctor', '--json'], { timeout: 10000 });
    const parsed = JSON.parse(stdout);
    const data = parsed?.data ?? parsed;
    return data?.credentials?.configured === true
      ? { ok: true }
      : { ok: false, reason: 'not-configured' };
  } catch (err) {
    if (err?.code === 'ENOENT') throw err;
    return { ok: false, reason: 'doctor-failed' };
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
    let doctorResult = null;
    try {
      doctorResult = await tryDoctor(exec);
      if (doctorResult.ok) return { ok: true };
    } catch {
      // CLI missing — fall through to keychain
    }

    // Doctor ran but exited non-zero → likely token expired
    if (doctorResult?.reason === 'doctor-failed') {
      return { ok: false, message: formatError('token-expired') };
    }

    // Doctor says not configured, or CLI missing — try keychain as fallback
    if (await tryKeychainDescribe(exec)) return { ok: true };

    return { ok: false, message: formatError('auth-not-configured') };
  };
}

const defaultExec = promisify(execFile);
export const checkCredentials = makeCheckCredentials(defaultExec);
```

- [ ] **Step 4: Run all openclaw-skill tests**

```
cd packages/openclaw-skill
node --test tests/*.test.js
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/openclaw-skill/setup/check-credentials.js packages/openclaw-skill/tests/check-credentials.test.js
git commit -m "feat(openclaw-skill): refactor check-credentials — DI + structured error messages"
```

---

### Task 3: Update `packages/openclaw-skill/setup/check-cli.js`

**Files:**
- Modify: `packages/openclaw-skill/setup/check-cli.js`

Replace the two inline Chinese error strings with `formatError('cli-not-installed')`.

- [ ] **Step 1: Edit `check-cli.js`**

Replace the entire file content:

```js
// setup/check-cli.js — verify switchbot CLI is installed; auto-install via npm if missing
import { execFile, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import { formatError } from '../lib/error-messages.js';

const exec = promisify(execFile);

async function cliExists() {
  try {
    await exec('switchbot', ['--version'], { timeout: 8000 });
    return true;
  } catch {
    return false;
  }
}

function npmExists() {
  try {
    execFileSync('npm', ['--version'], { timeout: 8000, stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

export async function checkCli() {
  if (await cliExists()) return { ok: true };

  if (!npmExists()) {
    return {
      ok: false,
      message:
        'Error: Node.js / npm is not installed.\n' +
        '  Fix:  Install Node.js from https://nodejs.org, then reopen the SwitchBot channel.\n' +
        '  Hint: Node 18 or later is required.',
    };
  }

  process.stderr.write('[switchbot-channel] CLI not found — auto-installing @switchbot/openapi-cli…\n');
  try {
    execFileSync('npm', ['install', '-g', '@switchbot/openapi-cli'], {
      stdio: 'inherit',
      timeout: 120_000,
    });
  } catch (err) {
    return {
      ok: false,
      message:
        `Error: CLI installation failed: ${err instanceof Error ? err.message : String(err)}\n` +
        `  Fix:  npm install -g @switchbot/openapi-cli\n` +
        `  Hint: Check your network connection and npm permissions.`,
    };
  }

  if (!(await cliExists())) {
    return {
      ok: false,
      message: formatError('cli-not-installed') +
        '\n  (CLI was installed but `switchbot` is still not on PATH — reopen your terminal.)',
    };
  }

  process.stderr.write('[switchbot-channel] CLI installed.\n');
  return { ok: true };
}
```

- [ ] **Step 2: Run all openclaw-skill tests**

```
cd packages/openclaw-skill
node --test tests/*.test.js
```

Expected: all tests PASS (no tests reference the old Chinese strings).

- [ ] **Step 3: Commit**

```bash
git add packages/openclaw-skill/setup/check-cli.js
git commit -m "feat(openclaw-skill): check-cli — replace inline strings with structured error format"
```

---

### Task 4: Update `packages/openclaw-skill/cli.js`

**Files:**
- Modify: `packages/openclaw-skill/cli.js`

Replace the two inline error strings in `runCli()` with `formatError(key)`.

- [ ] **Step 1: Edit `cli.js`** — add import and replace messages

At the top of `cli.js`, add:
```js
import { formatError } from './lib/error-messages.js';
```

Then replace the `setupRequired` calls in `runCli()`:

```js
// packages/openclaw-skill/cli.js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { formatError } from './lib/error-messages.js';

const exec = promisify(execFile);

const READ_TOOLS = new Set([
  'devices_list',
  'devices_status',
  'devices_describe',
  'scenes_list',
]);

export function buildCliArgs({ tool, params = {} }) {
  const flags = READ_TOOLS.has(tool) ? ['--no-cache', '--json'] : ['--json'];
  switch (tool) {
    case 'devices_list':
      return ['devices', 'list', ...flags];
    case 'devices_status':
      return ['devices', 'status', params.deviceId, ...flags];
    case 'devices_describe':
      return ['devices', 'describe', params.deviceId, ...flags];
    case 'devices_command': {
      const args = ['--audit-log', 'devices', 'command', params.deviceId, params.command, ...flags];
      if (params.params) {
        args.push('--params', JSON.stringify(params.params));
      }
      return args;
    }
    case 'scenes_list':
      return ['scenes', 'list', ...flags];
    case 'scenes_run':
      return ['--audit-log', 'scenes', 'run', params.sceneId, ...flags];
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
      nextStep: 'Run `switchbot-openclaw setup` in a terminal to bootstrap the CLI.',
    },
  };
}

export async function runCli(args) {
  try {
    const { stdout } = await exec('switchbot', args, { timeout: 15000 });
    return JSON.parse(stdout);
  } catch (err) {
    if (err && err.code === 'ENOENT') {
      return setupRequired('cli-missing', formatError('cli-not-installed'));
    }
    const raw = (err && (err.stdout ?? err.stderr ?? err.message)) ?? String(err);
    let parsed = null;
    try { parsed = JSON.parse(raw); } catch { /* non-JSON failure */ }

    const envelopeKind = parsed?.error?.kind;
    if (envelopeKind === 'auth' || envelopeKind === 'credentials' || envelopeKind === 'unauthorized') {
      return setupRequired('auth-missing', formatError('auth-not-configured'));
    }
    if (!parsed && looksLikeAuthError(raw)) {
      return setupRequired('auth-missing', formatError('auth-not-configured'));
    }
    if (parsed) return parsed;
    return { error: { kind: 'internal', message: raw } };
  }
}
```

- [ ] **Step 2: Run all openclaw-skill tests**

```
cd packages/openclaw-skill
node --test tests/*.test.js
```

Expected: all tests PASS. The `looksLikeAuthError` and `buildCliArgs` tests are unchanged so they should pass trivially.

- [ ] **Step 3: Commit**

```bash
git add packages/openclaw-skill/cli.js
git commit -m "feat(openclaw-skill): cli.js — use formatError for setupRequired messages"
```

---

### Task 5: Update `packages/openclaw-skill/bin/setup-flow.js`

**Files:**
- Modify: `packages/openclaw-skill/bin/setup-flow.js`

Replace the three failure-path inline strings with `formatError(key)`.

- [ ] **Step 1: Edit `setup-flow.js`**

Add the import at the top and replace the three failure outputs:

```js
// packages/openclaw-skill/bin/setup-flow.js
import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { formatError } from '../lib/error-messages.js';

const exec = promisify(execFile);
const REQUIRED_CLI = '3.7.1';

async function hasCli() {
  try {
    await exec('switchbot', ['--version'], { timeout: 5000 });
    return true;
  } catch (err) {
    if (err && err.code === 'ENOENT') return false;
    return true;
  }
}

async function cliVersion() {
  try {
    const { stdout } = await exec('switchbot', ['--version'], { timeout: 5000 });
    const m = stdout.trim().match(/\d+\.\d+\.\d+/);
    return m ? m[0] : null;
  } catch {
    return null;
  }
}

function versionAtLeast(have, need) {
  const a = have.split('.').map((n) => parseInt(n, 10) || 0);
  const b = need.split('.').map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const ai = a[i] ?? 0;
    const bi = b[i] ?? 0;
    if (ai > bi) return true;
    if (ai < bi) return false;
  }
  return true;
}

async function npmPrefix() {
  try {
    const { stdout } = await exec('npm', ['config', 'get', 'prefix'], { timeout: 5000 });
    return stdout.trim();
  } catch {
    return null;
  }
}

function prefixLikelyNeedsSudo(prefix) {
  if (!prefix) return false;
  if (process.platform === 'win32') return false;
  return /^\/usr(\/|$)/.test(prefix) || /^\/opt(\/|$)/.test(prefix);
}

function runInherit(cmd, args) {
  return new Promise((resolve) => {
    const p = spawn(cmd, args, { stdio: 'inherit' });
    p.on('close', (code) => resolve(code ?? 0));
    p.on('error', () => resolve(127));
  });
}

export async function runSetup() {
  console.log('SwitchBot plugin setup');
  console.log('======================');
  console.log('');

  // Step 1: CLI on PATH?
  if (!(await hasCli())) {
    console.log('[1/3] SwitchBot CLI not found on PATH.');
    console.log('');
    console.log(formatError('cli-not-installed'));
    const prefix = await npmPrefix();
    if (prefixLikelyNeedsSudo(prefix)) {
      console.log('');
      console.log(`Your npm global prefix is system-owned (${prefix}), so the install`);
      console.log('will fail with EACCES unless you pick one of:');
      console.log('  sudo npm install -g @switchbot/openapi-cli@latest');
      console.log('  — or change the prefix first:');
      console.log('      npm config set prefix ~/.npm-global');
      console.log('      export PATH="$HOME/.npm-global/bin:$PATH"');
    }
    console.log('');
    console.log('Then re-run: switchbot-openclaw setup');
    process.exit(1);
  }

  const version = await cliVersion();
  console.log(`[1/3] SwitchBot CLI detected (version: ${version ?? 'unknown'}).`);

  // Step 2: version gate
  if (!version) {
    console.log('');
    console.log(formatError('cli-version-too-low'));
    process.exit(1);
  }
  if (!versionAtLeast(version, REQUIRED_CLI)) {
    console.log('');
    console.log(`[2/3] CLI ${version} is below the ${REQUIRED_CLI} minimum required by this plugin.`);
    console.log(formatError('cli-version-too-low'));
    process.exit(1);
  }
  console.log(`[2/3] Version satisfies >= ${REQUIRED_CLI}.`);
  console.log('');

  // Step 3: auth / connectivity via doctor
  console.log('[3/3] Running `switchbot doctor` to verify credentials and connectivity...');
  console.log('');
  const code = await runInherit('switchbot', ['doctor']);
  if (code !== 0) {
    console.log('');
    console.log(formatError('token-expired'));
    console.log('');
    console.log('Then re-run: switchbot-openclaw setup');
    process.exit(1);
  }

  console.log('');
  console.log('Setup complete.');
  console.log('Restart your MCP host (OpenClaw / Claude Desktop / Cursor / …) to');
  console.log('pick up the switchbot plugin. The MCP server starts automatically');
  console.log('when invoked with no arguments: `switchbot-openclaw`.');
}
```

- [ ] **Step 2: Run all openclaw-skill tests**

```
cd packages/openclaw-skill
node --test tests/*.test.js
```

Expected: all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add packages/openclaw-skill/bin/setup-flow.js
git commit -m "feat(openclaw-skill): setup-flow — use formatError at all failure exit points"
```

---

### Task 6: Update `packages/codex-plugin` — error-messages + auth + check-credentials

**Files:**
- Create: `packages/codex-plugin/lib/error-messages.js`
- Modify: `packages/codex-plugin/setup/check-credentials.js`
- Modify: `packages/codex-plugin/bin/auth.js`

- [ ] **Step 1: Write failing tests for codex-plugin**

Create `packages/codex-plugin/tests/error-messages.test.js`:

```js
// packages/codex-plugin/tests/error-messages.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ERRORS, formatError } from '../lib/error-messages.js';

describe('codex-plugin ERRORS registry', () => {
  const EXPECTED_KEYS = [
    'auth-not-configured',
    'auth-login-failed',
    'token-expired',
    'cli-not-installed',
    'cli-version-too-low',
  ];

  it('defines all required keys', () => {
    for (const key of EXPECTED_KEYS) {
      assert.ok(key in ERRORS, `missing key: ${key}`);
    }
  });

  it('each entry has reason, fix, and hint', () => {
    for (const [key, entry] of Object.entries(ERRORS)) {
      assert.ok(entry.reason, `${key}: missing reason`);
      assert.ok(entry.fix,    `${key}: missing fix`);
      assert.ok(entry.hint,   `${key}: missing hint`);
    }
  });
});

describe('formatError (codex-plugin)', () => {
  it('returns structured output for auth-login-failed', () => {
    const out = formatError('auth-login-failed');
    assert.match(out, /Error:/);
    assert.match(out, /Fix:/);
    assert.match(out, /Hint:/);
    assert.ok(out.includes('auth login'), out);
  });

  it('throws for unknown key', () => {
    assert.throws(() => formatError('no-such-key'), /unknown error key/);
  });
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
cd packages/codex-plugin
node --test tests/error-messages.test.js
```

Expected: `ERR_MODULE_NOT_FOUND`.

- [ ] **Step 3: Create `packages/codex-plugin/lib/error-messages.js`** (identical to openclaw-skill)

```js
// packages/codex-plugin/lib/error-messages.js
export const ERRORS = {
  'auth-not-configured': {
    reason: 'SwitchBot credentials are not configured.',
    fix:    'switchbot auth login',
    hint:   'Run the fix command, then restart your MCP client.',
  },
  'auth-login-failed': {
    reason: 'Login failed — the CLI returned a non-zero exit code.',
    fix:    'switchbot auth login',
    hint:   'Check your network connection and try again.',
  },
  'token-expired': {
    reason: 'Credentials exist but doctor check failed — token may be expired.',
    fix:    'switchbot auth logout && switchbot auth login',
    hint:   'After re-login, run `switchbot doctor` to verify.',
  },
  'cli-not-installed': {
    reason: 'switchbot CLI is not installed or not in PATH.',
    fix:    'npm install -g @switchbot/openapi-cli',
    hint:   'After install, run `switchbot doctor` to confirm.',
  },
  'cli-version-too-low': {
    reason: 'switchbot CLI version is below the required minimum (3.7.1).',
    fix:    'npm install -g @switchbot/openapi-cli@latest',
    hint:   'After upgrade, re-run setup.',
  },
};

export function formatError(key) {
  const e = ERRORS[key];
  if (!e) throw new Error(`unknown error key: ${key}`);
  return [
    `Error: ${e.reason}`,
    `  Fix:  ${e.fix}`,
    `  Hint: ${e.hint}`,
  ].join('\n');
}
```

- [ ] **Step 4: Update `packages/codex-plugin/setup/check-credentials.js`**

```js
// packages/codex-plugin/setup/check-credentials.js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { formatError } from '../lib/error-messages.js';

async function tryDoctor(exec) {
  try {
    const { stdout } = await exec('switchbot', ['doctor', '--json'], { timeout: 10000 });
    const parsed = JSON.parse(stdout);
    const data = parsed?.data ?? parsed;
    return data?.credentials?.configured === true
      ? { ok: true }
      : { ok: false, reason: 'not-configured' };
  } catch (err) {
    if (err?.code === 'ENOENT') throw err;
    return { ok: false, reason: 'doctor-failed' };
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
    let doctorResult = null;
    try {
      doctorResult = await tryDoctor(exec);
      if (doctorResult.ok) return { ok: true, source: 'doctor' };
    } catch {
      // CLI missing — fall through to keychain
    }

    if (doctorResult?.reason === 'doctor-failed') {
      return { ok: false, message: formatError('token-expired') };
    }

    if (await tryKeychainDescribe(exec)) return { ok: true, source: 'keychain' };

    return { ok: false, message: formatError('auth-not-configured') };
  };
}

const defaultExec = promisify(execFile);
export const checkCredentials = makeCheckCredentials(defaultExec);
```

- [ ] **Step 5: Update `packages/codex-plugin/bin/auth.js`**

Replace the two inline auth-failure strings:

```js
#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { checkCli as defaultCheckCli } from '../setup/check-cli.js';
import { checkCredentials as defaultCheckCredentials } from '../setup/check-credentials.js';
import { formatError } from '../lib/error-messages.js';

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
      process.stderr.write(`[switchbot-codex] ${formatError('auth-login-failed')}\n`);
      return loginCode;
    }

    process.stderr.write('[switchbot-codex] Verifying credentials via doctor...\n');
    const doctorCode = await runInherit('switchbot', ['doctor']);
    if (doctorCode !== 0) {
      process.stderr.write(`[switchbot-codex] ${formatError('token-expired')}\n`);
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

- [ ] **Step 6: Run all codex-plugin tests**

```
cd packages/codex-plugin
node --test tests/*.test.js
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add packages/codex-plugin/lib/error-messages.js \
        packages/codex-plugin/tests/error-messages.test.js \
        packages/codex-plugin/setup/check-credentials.js \
        packages/codex-plugin/bin/auth.js
git commit -m "feat(codex-plugin): add error-messages module + use formatError in auth and check-credentials"
```

---

### Task 7: Update `scripts/bootstrap.sh` and `scripts/bootstrap.ps1`

**Files:**
- Modify: `scripts/bootstrap.sh`
- Modify: `scripts/bootstrap.ps1`

Add a clear hint when `switchbot doctor` fails after installation.

- [ ] **Step 1: Edit `scripts/bootstrap.sh`**

Find the section near line 338 where `switchbot doctor` is called. Replace the failure branch:

Find this block:
```bash
  if switchbot doctor 2>&1 | grep -q "0 fail"; then
    ok "switchbot doctor passed."
  else
    warn "switchbot doctor reported issues — run 'switchbot doctor' for details."
  fi
```

Replace with:
```bash
  if switchbot doctor 2>&1 | grep -q "0 fail"; then
    ok "switchbot doctor passed."
  else
    echo ""
    echo "Error: SwitchBot credentials are not configured."
    echo "  Fix:  switchbot auth login"
    echo "  Hint: Run the fix command, then restart your MCP client."
    echo ""
  fi
```

- [ ] **Step 2: Edit `scripts/bootstrap.ps1`**

Find the equivalent doctor-failure block in bootstrap.ps1 and replace the warning with:

```powershell
  $doctorOut = & switchbot doctor 2>&1
  if ($doctorOut -match '0 fail') {
    Write-Host '[ok] switchbot doctor passed.'
  } else {
    Write-Host ''
    Write-Host 'Error: SwitchBot credentials are not configured.'
    Write-Host '  Fix:  switchbot auth login'
    Write-Host '  Hint: Run the fix command, then restart your MCP client.'
    Write-Host ''
  }
```

Note: locate the exact existing doctor block in bootstrap.ps1 before editing — the pattern should be similar to the Bash version.

- [ ] **Step 3: Commit**

```bash
git add scripts/bootstrap.sh scripts/bootstrap.ps1
git commit -m "feat(scripts): bootstrap — show auth fix hint when doctor fails post-install"
```

---

### Task 8: Update `scripts/uninstall.sh` and `scripts/uninstall.ps1`

**Files:**
- Modify: `scripts/uninstall.sh`
- Modify: `scripts/uninstall.ps1`

Append the 4 verification commands after "Uninstall complete."

- [ ] **Step 1: Edit `scripts/uninstall.sh`**

Find the last line:
```bash
echo "Uninstall complete."
```

Replace with:
```bash
echo "Uninstall complete."
echo ""
echo "Verify the uninstall is clean — all commands below should fail or return empty:"
echo "  switchbot --version      # expected: command not found"
echo "  ls ~/.switchbot/         # expected: no such file or directory"
echo "  ls ~/.config/openclaw/   # expected: no such file or directory"
echo "  switchbot doctor         # expected: command not found"
```

- [ ] **Step 2: Edit `scripts/uninstall.ps1`**

Find the last line:
```powershell
Write-Host 'Uninstall complete.'
```

Replace with:
```powershell
Write-Host 'Uninstall complete.'
Write-Host ''
Write-Host 'Verify the uninstall is clean — all commands below should fail or return empty:'
Write-Host '  switchbot --version                        # expected: not recognized'
Write-Host '  Test-Path $env:USERPROFILE\.switchbot      # expected: False'
Write-Host '  Test-Path $env:APPDATA\openclaw            # expected: False'
Write-Host '  switchbot doctor                           # expected: not recognized'
```

- [ ] **Step 3: Commit**

```bash
git add scripts/uninstall.sh scripts/uninstall.ps1
git commit -m "feat(scripts): uninstall — print 4-step clean-uninstall verification at end"
```

---

### Task 9: Update `troubleshooting.md`

**Files:**
- Modify: `troubleshooting.md`

Append three new sections before the "Reporting an issue" section.

- [ ] **Step 1: Edit `troubleshooting.md`**

Find the line:
```markdown
## Reporting an issue
```

Insert the following block immediately before it:

```markdown
---

## Uninstalling

Run the uninstall script for your platform:

**macOS / Linux:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/uninstall.sh) \
  --agent claude-global --remove-cli --remove-policy --remove-credentials
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/uninstall.ps1 | iex
# Then in the same terminal:
Uninstall-SwitchBotSkill -Agent claude-global -RemoveCli -RemovePolicy -RemoveCredentials
```

Replace `claude-global` with your agent target if different (see `--help` for the full list).

---

## Verifying a Clean Uninstall

After uninstalling, run these four checks — all should return "not found" or `False`:

**macOS / Linux:**
```bash
switchbot --version      # expected: command not found
ls ~/.switchbot/         # expected: no such file or directory
ls ~/.config/openclaw/   # expected: no such file or directory
switchbot doctor         # expected: command not found
```

**Windows (PowerShell):**
```powershell
switchbot --version                              # expected: not recognized
Test-Path $env:USERPROFILE\.switchbot            # expected: False
Test-Path $env:APPDATA\openclaw                  # expected: False
switchbot doctor                                 # expected: not recognized
```

---

## Re-authenticating (Re-login)

Use this when you see **"credentials are not configured"** or **"token may be expired"**:

```bash
switchbot auth logout           # clear the existing token
switchbot auth login            # open browser to re-authenticate
switchbot doctor                # verify the new credentials are valid
```

After `switchbot doctor` shows no failures, restart your MCP client (Claude / Copilot / Codex / Cursor).

---

```

- [ ] **Step 2: Commit**

```bash
git add troubleshooting.md
git commit -m "docs: add Uninstalling, Verifying Clean Uninstall, and Re-login sections to troubleshooting.md"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| `error-messages.js` module with 5 keys | Task 1, Task 6 |
| `check-credentials.js` — auth-not-configured | Task 2, Task 6 |
| `check-credentials.js` — token-expired (doctor non-zero) | Task 2, Task 6 |
| `cli.js` — auth patterns → formatError | Task 4 |
| `setup-flow.js` — cli-not-installed, cli-version-too-low, token-expired | Task 5 |
| `auth.js` — auth-login-failed | Task 6 |
| `bootstrap.sh/.ps1` — post-install auth hint | Task 7 |
| `uninstall.sh/.ps1` — verification commands | Task 8 |
| `troubleshooting.md` — 3 new sections | Task 9 |
| Tests for new modules | Task 1, Task 2, Task 6 |

All spec requirements are covered. No placeholders. Type/name consistency: `formatError` is consistent across all tasks; `makeCheckCredentials` introduced in Task 2 and mirrored in Task 6; `tryDoctor` returns `{ ok, reason }` in both packages.
