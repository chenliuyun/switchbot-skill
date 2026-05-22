# Codex Bootstrap Prompt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `switchbot-codex-install` CLI command and a `BOOTSTRAP.md` snippet so any user can paste one prompt into Codex to install the SwitchBot plugin end-to-end, with only `switchbot auth login` requiring human interaction.

**Architecture:** `bin/install.js` exports `makeInstall({ checkCli, runInherit, packageRoot })` — same dependency-injection pattern as `bin/auth.js`. It auto-installs the CLI if missing, registers the package in Codex's plugin marketplace, then runs `codex plugin add` (which triggers the existing `onInstall` → `bin/auth.js` hook). `BOOTSTRAP.md` ships two copyable prompts: one for GitHub Clone path and one for the npm path.

**Tech Stack:** Node.js ≥ 18 (ESM), `node:child_process` spawn with `shell: true` (Windows `.cmd` compatibility), `node:path`, `node:url`. No new dependencies.

---

## File Map

| File | Action | Why |
|---|---|---|
| `packages/codex-plugin/bin/install.js` | **Create** | `switchbot-codex-install` binary |
| `packages/codex-plugin/tests/install.test.js` | **Create** | Unit tests for `makeInstall` |
| `packages/codex-plugin/package.json` | **Modify** | Add `switchbot-codex-install` to `bin` |
| `BOOTSTRAP.md` | **Create** | Standalone copyable bootstrap prompts |
| `README.md` | **Modify** | Add "Section 0: One-Paste Install" above existing install sections |

---

## Task 1: `bin/install.js` — TDD

**Files:**
- Create: `packages/codex-plugin/tests/install.test.js`
- Create: `packages/codex-plugin/bin/install.js`

### Step 1.1 — Write the failing tests

Create `packages/codex-plugin/tests/install.test.js`:

```js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { makeInstall } from '../bin/install.js';

function makeOkCliCheck(version = '3.3.0') {
  return async () => ({ ok: true, version });
}
function makeFailCliCheck() {
  return async () => ({ ok: false, message: 'CLI not found' });
}
function makeSpawn(exitCode = 0) {
  const calls = [];
  const spawn = (cmd, args) => {
    calls.push({ cmd, args });
    return Promise.resolve(exitCode);
  };
  return { spawn, calls };
}

const TEST_ROOT = '/fake/switchbot-codex-plugin';

describe('makeInstall', () => {
  it('skips npm install when CLI is already present', async () => {
    const { spawn, calls } = makeSpawn(0);
    const install = makeInstall({
      checkCli: makeOkCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 0);
    assert.equal(calls.length, 2);
    assert.deepEqual(calls[0], { cmd: 'codex', args: ['plugin', 'marketplace', 'add', TEST_ROOT] });
    assert.deepEqual(calls[1], { cmd: 'codex', args: ['plugin', 'add', 'switchbot@switchbot-codex-plugin'] });
  });

  it('runs npm install first when CLI is missing, then registers and adds plugin', async () => {
    const { spawn, calls } = makeSpawn(0);
    const install = makeInstall({
      checkCli: makeFailCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 0);
    assert.equal(calls.length, 3);
    assert.deepEqual(calls[0], { cmd: 'npm', args: ['install', '-g', '@switchbot/openapi-cli@latest'] });
    assert.deepEqual(calls[1], { cmd: 'codex', args: ['plugin', 'marketplace', 'add', TEST_ROOT] });
    assert.deepEqual(calls[2], { cmd: 'codex', args: ['plugin', 'add', 'switchbot@switchbot-codex-plugin'] });
  });

  it('exits with npm install exit code and stops when CLI install fails', async () => {
    const { spawn, calls } = makeSpawn(1);
    const install = makeInstall({
      checkCli: makeFailCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 1);
    assert.equal(calls.length, 1);
    assert.deepEqual(calls[0], { cmd: 'npm', args: ['install', '-g', '@switchbot/openapi-cli@latest'] });
  });

  it('exits with marketplace add exit code and stops when registration fails', async () => {
    let callCount = 0;
    const spawn = (cmd, args) => {
      callCount++;
      return Promise.resolve(callCount === 1 ? 2 : 0);
    };
    const install = makeInstall({
      checkCli: makeOkCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 2);
    assert.equal(callCount, 1);
  });

  it('propagates plugin add exit code', async () => {
    let callCount = 0;
    const spawn = (cmd, args) => {
      callCount++;
      return Promise.resolve(callCount === 2 ? 3 : 0);
    };
    const install = makeInstall({
      checkCli: makeOkCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 3);
    assert.equal(callCount, 2);
  });
});
```

- [ ] Write the file above

### Step 1.2 — Run tests, verify they fail

```
cd packages/codex-plugin
node --test tests/install.test.js
```

Expected: Error such as `Cannot find module '../bin/install.js'`

- [ ] Run and confirm failure

### Step 1.3 — Implement `bin/install.js`

Create `packages/codex-plugin/bin/install.js`:

```js
#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve, basename } from 'node:path';
import { checkCli as defaultCheckCli } from '../setup/check-cli.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const defaultPackageRoot = resolve(__dirname, '..');

function defaultRunInherit(cmd, args) {
  return new Promise((resolveFn) => {
    const p = spawn(cmd, args, { stdio: 'inherit', shell: true });
    p.on('close', code => resolveFn(code ?? 0));
    p.on('error', () => resolveFn(127));
  });
}

export function makeInstall({ checkCli, runInherit, packageRoot }) {
  return async function install() {
    const cliCheck = await checkCli();
    if (!cliCheck.ok) {
      process.stderr.write('[switchbot-codex] CLI not found. Installing @switchbot/openapi-cli...\n');
      const installCode = await runInherit('npm', ['install', '-g', '@switchbot/openapi-cli@latest']);
      if (installCode !== 0) {
        process.stderr.write('[switchbot-codex] CLI install failed. Run manually: npm install -g @switchbot/openapi-cli@latest\n');
        return installCode;
      }
    } else {
      process.stderr.write(`[switchbot-codex] CLI ${cliCheck.version} detected.\n`);
    }

    process.stderr.write(`[switchbot-codex] Registering plugin at ${packageRoot}...\n`);
    const marketplaceCode = await runInherit('codex', ['plugin', 'marketplace', 'add', packageRoot]);
    if (marketplaceCode !== 0) {
      process.stderr.write('[switchbot-codex] Marketplace registration failed.\n');
      return marketplaceCode;
    }

    const pluginName = `switchbot@${basename(packageRoot)}`;
    process.stderr.write(`[switchbot-codex] Adding plugin ${pluginName}...\n`);
    return runInherit('codex', ['plugin', 'add', pluginName]);
  };
}

const isMain = process.argv[1]?.replace(/\\/g, '/').endsWith('bin/install.js');
if (isMain) {
  const install = makeInstall({
    checkCli: defaultCheckCli,
    runInherit: defaultRunInherit,
    packageRoot: defaultPackageRoot,
  });
  install().then(code => process.exit(code)).catch(err => {
    process.stderr.write(`[switchbot-codex] Fatal: ${err instanceof Error ? err.message : String(err)}\n`);
    process.exit(1);
  });
}
```

- [ ] Write the file above

### Step 1.4 — Run tests, verify they pass

```
node --test tests/install.test.js
```

Expected: `# pass 5  # fail 0`

- [ ] Run and confirm

### Step 1.5 — Commit

```
git add packages/codex-plugin/bin/install.js packages/codex-plugin/tests/install.test.js
git commit -m "feat(codex-plugin): add switchbot-codex-install — auto-registers plugin in Codex marketplace"
```

- [ ] Commit

---

## Task 2: Update `package.json`

**Files:**
- Modify: `packages/codex-plugin/package.json`

### Step 2.1 — Add bin entry

In `packages/codex-plugin/package.json`, change the `bin` field from:

```json
"bin": {
  "switchbot-codex-auth": "./bin/auth.js"
}
```

To:

```json
"bin": {
  "switchbot-codex-auth": "./bin/auth.js",
  "switchbot-codex-install": "./bin/install.js"
}
```

- [ ] Apply the edit

### Step 2.2 — Run full test suite

```
node --test tests/*.test.js
```

Expected: all pass, `# fail 0`

- [ ] Run and confirm

### Step 2.3 — Commit

```
git add packages/codex-plugin/package.json
git commit -m "feat(codex-plugin): register switchbot-codex-install binary in package.json"
```

- [ ] Commit

---

## Task 3: `BOOTSTRAP.md` and README update

**Files:**
- Create: `BOOTSTRAP.md` (repo root)
- Modify: `README.md`

### Step 3.1 — Create `BOOTSTRAP.md`

Create `BOOTSTRAP.md` at the repo root:

````markdown
# SwitchBot Codex Bootstrap

Paste one of the prompts below into Codex chat. Codex will run the setup
commands automatically. The only step that requires human interaction is
`switchbot auth login` — this opens a browser window for OAuth.

---

## Option A — GitHub Clone (available now)

Copy and paste into Codex:

```
请帮我安装 SwitchBot Codex 插件，按顺序执行以下命令：
1. npm install -g @switchbot/openapi-cli@latest
2. git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
3. codex plugin marketplace add ~/switchbot-skill
4. codex plugin add switchbot@switchbot-skill

全部成功后，提示我在终端运行 `switchbot auth login` 完成浏览器授权。
```

---

## Option B — npm (after publishing `@cly-org/switchbot-codex-plugin`)

Copy and paste into Codex:

```
请帮我安装 SwitchBot Codex 插件：
1. npm install -g @cly-org/switchbot-codex-plugin
2. switchbot-codex-install

完成后提示我运行 `switchbot auth login`。
```

---

After auth completes, ask Codex:

> List my SwitchBot devices and tell me which ones are currently on.
````

- [ ] Write the file above

### Step 3.2 — Update `README.md`

Find this block in `README.md`:

```markdown
## Install

### A. Codex (recommended)
```

Replace with:

```markdown
## Install

### 0. One-Paste Install

Paste one prompt into Codex — it handles CLI install, plugin registration,
and will prompt you for `switchbot auth login` when ready.
See [`BOOTSTRAP.md`](./BOOTSTRAP.md) for the full copyable snippets.

**GitHub Clone path** (available now — paste into Codex chat):

```
请帮我安装 SwitchBot Codex 插件，按顺序执行以下命令：
1. npm install -g @switchbot/openapi-cli@latest
2. git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
3. codex plugin marketplace add ~/switchbot-skill
4. codex plugin add switchbot@switchbot-skill

全部成功后，提示我在终端运行 `switchbot auth login` 完成浏览器授权。
```

---

### A. Codex (manual steps)
```

- [ ] Apply the edit

### Step 3.3 — Verify README renders correctly

```
node -e "const fs = require('fs'); const txt = fs.readFileSync('README.md','utf8'); console.log(txt.includes('### 0. One-Paste Install') ? 'OK' : 'MISSING')"
```

Expected: `OK`

- [ ] Run and confirm

### Step 3.4 — Commit

```
git add BOOTSTRAP.md README.md
git commit -m "docs: add one-paste bootstrap prompt for Codex plugin install"
```

- [ ] Commit

---

## Task 4: Final verification

### Step 4.1 — Run full test suite

```
cd packages/codex-plugin
node --test tests/*.test.js
```

Expected: `# fail 0`

- [ ] Run and confirm

### Step 4.2 — Verify bin is declared correctly

```
node -e "const p=JSON.parse(require('fs').readFileSync('packages/codex-plugin/package.json','utf8')); console.log(JSON.stringify(p.bin))"
```

Expected: `{"switchbot-codex-auth":"./bin/auth.js","switchbot-codex-install":"./bin/install.js"}`

- [ ] Run and confirm

### Step 4.3 — Smoke-test install.js dry run (confirm it starts without crashing)

```
cd packages/codex-plugin
node -e "import('./bin/install.js').then(() => console.log('import OK'))"
```

Expected: `import OK` (no syntax errors)

- [ ] Run and confirm

### Step 4.4 — Verify BOOTSTRAP.md exists and contains both option blocks

```
node -e "const t=require('fs').readFileSync('BOOTSTRAP.md','utf8'); console.log(t.includes('Option A') && t.includes('Option B') ? 'OK' : 'MISSING')"
```

Expected: `OK`

- [ ] Run and confirm
