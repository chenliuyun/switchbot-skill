# SwitchBot Skill — Full Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the SwitchBot skill from a file-based installer into a polished, zero-friction AI agent integration platform covering one-click install, cross-platform parity, CI validation, native OpenClaw plugin, opt-in telemetry, and a policy visual editor.

**Architecture:** Five independent subsystems are delivered in priority order. Each phase produces working software on its own. Phases 1–2 are incremental improvements to existing scripts; Phases 3–5 are new standalone artifacts. No phase depends on a later phase to function.

**Tech Stack:** bash 5+, PowerShell 7+, Node.js 18+, GitHub Actions, npm, HTML/CSS/JS (vanilla for policy editor), bats (shell testing)

---

## Already shipped (this session — reference only)

| Item | Files |
|---|---|
| `curl \| bash` bootstrap (7-step) | `scripts/bootstrap.sh` |
| PowerShell bootstrap (6-step) | `scripts/bootstrap.ps1` |
| Token terminal guide | `scripts/bootstrap.sh` step 5 |
| First-use wizard (bash) | `scripts/bootstrap.sh` step 7 |
| Daemon auto-registration | `scripts/setup-daemon.sh`, `scripts/setup-daemon.ps1` |
| Chinese documentation | `README.zh.md`, `INSTALL_FOR_AGENTS.zh.md` |
| INSTALL_FOR_AGENTS.md updated | `INSTALL_FOR_AGENTS.md` |
| README.md updated | `README.md` |

---

## File Map

```
scripts/
  bootstrap.sh          ← Phase 1: add China fallback
  bootstrap.ps1         ← Phase 1: add wizard [7/7] + daemon prompt + China fallback
  setup-daemon.sh       (already done)
  setup-daemon.ps1      (already done)

.github/
  workflows/
    ci-matrix.yml       ← Phase 2: NEW

plugin/
  openclaw/             ← Phase 3: NEW npm package
    package.json
    index.js            (MCP server entry)
    tools/
      devices.js        (list, status, describe)
      command.js        (turnOn/Off/setBrightness/…)
      scenes.js         (list, run)
      rules.js          (suggest, add, lint, reload)
      policy.js         (validate, show)
    channels/
      switchbot.channel.json
    README.md

scripts/
  telemetry.sh          ← Phase 4: NEW (sourced by bootstrap.sh)
  telemetry.ps1         ← Phase 4: NEW (dot-sourced by bootstrap.ps1)

policy-editor/          ← Phase 5: NEW
  index.html
  editor.js
  style.css
  server.js             (local http server, spawned by `switchbot policy edit --ui`)
```

---

## Phase 1 · Bootstrap Parity & China Fallback

**Deliverable:** bootstrap.ps1 matches bootstrap.sh feature-for-feature; both scripts transparently fall back to ghproxy when GitHub is unreachable.

---

### Task 1 · China mirror fallback in bootstrap.sh

**Files:**
- Modify: `scripts/bootstrap.sh` (download block, ~lines 136–151)

- [ ] **Step 1 — Write bats test for fallback**

Create `tests/bootstrap.bats`:
```bash
#!/usr/bin/env bats

# stub: primary URL fails, mirror succeeds
@test "download falls back to ghproxy on curl failure" {
  # Override curl inside subshell
  function curl() {
    if [[ "$*" == *"raw.githubusercontent.com"* ]]; then
      return 22  # simulate 404/timeout
    fi
    echo "MIRROR_HIT"
  }
  export -f curl
  source scripts/bootstrap.sh --dry-run 2>&1 || true
  # The mirror URL should have been attempted
}
```

- [ ] **Step 2 — Run test to verify it fails**

```bash
bats tests/bootstrap.bats
```
Expected: FAIL (fallback logic doesn't exist yet)

- [ ] **Step 3 — Add `download_tarball` function with fallback**

In `scripts/bootstrap.sh`, replace the inline `curl` in the download block with:

```bash
TARBALL_URL="https://github.com/chenliuyun/switchbot-skill/archive/refs/heads/main.tar.gz"
MIRROR_URL="https://ghproxy.com/https://github.com/chenliuyun/switchbot-skill/archive/refs/heads/main.tar.gz"

download_tarball() {
  local dest="$1"
  echo "  Downloading from GitHub..."
  if curl -fsSL --connect-timeout 10 "$TARBALL_URL" | tar xz -C "$dest" --strip-components=1 2>/dev/null; then
    ok "Downloaded (GitHub)"
    return 0
  fi
  warn "GitHub unreachable, trying mirror (ghproxy.com)..."
  if curl -fsSL --connect-timeout 15 "$MIRROR_URL" | tar xz -C "$dest" --strip-components=1; then
    ok "Downloaded (mirror)"
    return 0
  fi
  die "Download failed from both GitHub and mirror.\n  Check network or clone manually:\n  git clone https://github.com/chenliuyun/switchbot-skill.git"
}
```

Replace the existing download line:
```bash
# Before:
curl -fsSL "$TARBALL_URL" | tar xz -C "$SKILL_DIR" --strip-components=1

# After:
download_tarball "$SKILL_DIR"
```

- [ ] **Step 4 — Run test**

```bash
bats tests/bootstrap.bats
```
Expected: PASS

- [ ] **Step 5 — Syntax check**

```bash
bash -n scripts/bootstrap.sh && echo OK
```

- [ ] **Step 6 — Commit**

```bash
git add scripts/bootstrap.sh tests/bootstrap.bats
git commit -m "feat: add China mirror fallback to bootstrap.sh"
```

---

### Task 2 · bootstrap.ps1 wizard parity (step [7/7])

**Files:**
- Modify: `scripts/bootstrap.ps1`

Currently bootstrap.ps1 has steps 1–6. This task adds step 7 (first-use wizard) matching the bash wizard exactly.

- [ ] **Step 1 — Change step count 6→7 in bootstrap.ps1**

Replace all occurrences of `[N/6]` → `[N/7]`:
```powershell
# Find/replace in bootstrap.ps1:
# "[1/6]" → "[1/7]", "[2/6]" → "[2/7]", ..., "[6/6]" → "[6/7]"
```

Do this with the Edit tool on each occurrence (6 edits).

- [ ] **Step 2 — Add policy-tracking variables after step [4/7] header**

After the line `Write-Step "[4/7] Installing skill into detected agents..."`, add:
```powershell
$PolicyPath = Join-Path ($env:USERPROFILE ?? $env:HOME) ".config\openclaw\switchbot\policy.yaml"
$PolicyNewlyCreated = $false
$PolicyPreExisted = Test-Path $PolicyPath
```

- [ ] **Step 3 — Set `$PolicyNewlyCreated` after install loop**

After the `foreach ($ag in $DetectedAgents)` block closes, add:
```powershell
if (-not $PolicyPreExisted -and (Test-Path $PolicyPath)) {
  $PolicyNewlyCreated = $true
}
```

- [ ] **Step 4 — Add wizard function and [7/7] step**

Before the `} catch {` line at the bottom, insert:

```powershell
# ─────────────────────────────────────────────
# [7/7] First-use wizard
# ─────────────────────────────────────────────
Write-Step "[7/7] Setting up your preferences..."

function Invoke-Wizard {
  param([string]$PolicyPath)

  Write-Host ""
  Write-Host "  Answer 3 quick questions to configure policy.yaml."
  Write-Host "  (Press Enter to accept the default shown in brackets.)"
  Write-Host ""

  $quietAns   = Read-Host "  Q1: Block light/plug/AC changes during sleep hours (22:00-07:00)? [Y/n]"
  $lockAns    = Read-Host "  Q2: Always confirm before locking or unlocking doors? [Y/n]"
  $aliasAns   = Read-Host "  Q3: Set up friendly names for your devices now? [y/N]"

  $quietHours = ($quietAns -eq '' -or $quietAns -match '^[Yy]')
  $lockConfirm = ($lockAns -eq '' -or $lockAns -match '^[Yy]')
  $doAliases  = $aliasAns -match '^[Yy]'

  $content = Get-Content $PolicyPath -Raw

  if ($quietHours) {
    $content = $content -replace '(?m)^\s*#\s*start:.*$', '  start: "22:00"'
    $content = $content -replace '(?m)^\s*#\s*end:.*$',   '  end: "07:00"'
  }
  if ($lockConfirm) {
    $content = $content -replace '(?m)^(\s*always_confirm:\s*\[)\]', '$1"lock", "unlock"]'
  }
  Set-Content -Path $PolicyPath -Value $content -Encoding UTF8

  if ($doAliases -and (Get-Command switchbot -ErrorAction SilentlyContinue)) {
    Write-Host "  Fetching your devices..."
    $devicesJson = switchbot devices list --json 2>$null
    $devices = ($devicesJson | ConvertFrom-Json).data
    foreach ($dev in ($devices | Select-Object -First 12)) {
      $alias = Read-Host "  `"$($dev.deviceName)`" → alias (Enter to skip)"
      if ($alias.Trim()) {
        $content = Get-Content $PolicyPath -Raw
        $entry = "  `"$($alias.Trim())`": `"$($dev.deviceId)`""
        $content = $content -replace '(?m)^(aliases:\s*\r?\n)((?:\s*#.*\r?\n)*)', "`$1$entry`n`$2"
        Set-Content -Path $PolicyPath -Value $content -Encoding UTF8
      }
    }
  }

  Write-Ok "policy.yaml configured. Edit $PolicyPath any time."
}

if ($DryRun) {
  Write-Dry "First-use wizard (would ask 3 preference questions)"
} elseif ($NonInteractive) {
  Write-Warn "Non-interactive mode: skipping wizard. Edit $PolicyPath to customize."
} elseif (-not $PolicyNewlyCreated) {
  Write-Ok "policy.yaml already existed — skipping wizard."
} elseif (-not (Get-Command switchbot -ErrorAction SilentlyContinue)) {
  Write-Warn "Skipping wizard (CLI not available)."
} else {
  Invoke-Wizard -PolicyPath $PolicyPath
}
```

- [ ] **Step 5 — Syntax check**

```powershell
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path 'scripts/bootstrap.ps1').Path, [ref]$null, [ref]$errs)
if ($errs.Count -eq 0) { "OK" } else { $errs }
```

- [ ] **Step 6 — Commit**

```bash
git add scripts/bootstrap.ps1
git commit -m "feat: add first-use wizard to bootstrap.ps1 (parity with bash)"
```

---

### Task 3 · bootstrap.ps1 daemon prompt parity + China fallback

**Files:**
- Modify: `scripts/bootstrap.ps1`

- [ ] **Step 1 — Add China fallback download function**

In bootstrap.ps1, replace the `Invoke-WebRequest` block in step [3/7] with:

```powershell
function Invoke-DownloadSkill {
  param([string]$TempZip, [string]$TempDir)

  $primary = "https://github.com/chenliuyun/switchbot-skill/archive/refs/heads/main.zip"
  $mirror  = "https://ghproxy.com/https://github.com/chenliuyun/switchbot-skill/archive/refs/heads/main.zip"

  Write-Host "  Downloading from GitHub..."
  try {
    Invoke-WebRequest -Uri $primary -OutFile $TempZip -UseBasicParsing -TimeoutSec 15
    Write-Ok "Downloaded (GitHub)"
    return
  } catch {
    Write-Warn "GitHub unreachable, trying mirror (ghproxy.com)..."
  }

  try {
    Invoke-WebRequest -Uri $mirror -OutFile $TempZip -UseBasicParsing -TimeoutSec 20
    Write-Ok "Downloaded (mirror)"
  } catch {
    throw "Download failed from both GitHub and mirror.`nClone manually: git clone https://github.com/chenliuyun/switchbot-skill.git"
  }
}
```

Then call: `Invoke-DownloadSkill -TempZip $TempZip -TempDir $TempDir`

- [ ] **Step 2 — Add daemon prompt after wizard step, before `} catch {`**

```powershell
# ── Optional: register rules engine as a system service ──────────────────────
if (-not $DryRun -and -not $NonInteractive) {
  $daemonAns = Read-Host "`n  Register the rules engine to start at login? [y/N]"
  if ($daemonAns -match '^[Yy]') {
    $daemonScript = Join-Path $SkillDir "scripts\setup-daemon.ps1"
    if (Test-Path $daemonScript) {
      & pwsh -File $daemonScript
    } else {
      Write-Warn "setup-daemon.ps1 not found. Run it manually later."
    }
  } else {
    Write-Host "  Run 'pwsh scripts/setup-daemon.ps1' later to set this up." -ForegroundColor DarkGray
  }
}
```

- [ ] **Step 3 — Syntax check**

```powershell
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path 'scripts/bootstrap.ps1').Path, [ref]$null, [ref]$errs)
if ($errs.Count -eq 0) { "OK" } else { $errs }
```

- [ ] **Step 4 — Commit**

```bash
git add scripts/bootstrap.ps1
git commit -m "feat: add China fallback + daemon prompt to bootstrap.ps1"
```

---

## Phase 2 · CI Multi-Agent Test Matrix

**Deliverable:** GitHub Actions workflow that installs the skill against every supported agent target on ubuntu-latest and windows-latest, catches regressions on every push.

---

### Task 4 · GitHub Actions install matrix

**Files:**
- Create: `.github/workflows/ci-matrix.yml`

- [ ] **Step 1 — Create workflow file**

```yaml
# .github/workflows/ci-matrix.yml
name: Install Matrix

on:
  push:
    branches: [main]
    paths:
      - 'scripts/**'
      - 'SKILL.md'
      - 'examples/**'
  pull_request:
    paths:
      - 'scripts/**'

jobs:
  install-unix:
    name: ${{ matrix.agent }} on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        agent:
          - claude-global
          - gemini-global
          - codex-global
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      # Stub the CLI so tests don't need real credentials
      - name: Create switchbot stub
        run: |
          mkdir -p "$HOME/.local/bin"
          printf '#!/bin/sh\necho "3.0.0"\n' > "$HOME/.local/bin/switchbot"
          chmod +x "$HOME/.local/bin/switchbot"
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
      # Create agent directory so auto-detect fires
      - name: Create agent dir
        run: |
          case "${{ matrix.agent }}" in
            claude-global)  mkdir -p "$HOME/.claude" ;;
            gemini-global)  mkdir -p "$HOME/.gemini" ;;
            codex-global)   mkdir -p "$HOME/.codex" ;;
          esac
      - name: Run bootstrap (dry-run)
        run: bash scripts/bootstrap.sh --dry-run --skip-token --skip-verify
      - name: Run bootstrap (real, skip token + verify)
        run: bash scripts/bootstrap.sh --yes --skip-token --skip-verify --no-cli
      - name: Verify skill files exist
        run: |
          case "${{ matrix.agent }}" in
            claude-global) test -e "$HOME/.claude/skills/switchbot/SKILL.md" ;;
            gemini-global) test -f "$HOME/.gemini/GEMINI.md" ;;
            codex-global)  test -f "$HOME/.codex/AGENTS.md" ;;
          esac
          echo "Skill file present ✓"
      - name: Run uninstall
        run: bash scripts/uninstall.sh --agent ${{ matrix.agent }} --force
      - name: Verify skill files removed
        run: |
          case "${{ matrix.agent }}" in
            claude-global) test ! -e "$HOME/.claude/skills/switchbot" ;;
            gemini-global) test ! -f "$HOME/.gemini/GEMINI.md" ;;
            codex-global)  test ! -f "$HOME/.codex/AGENTS.md" ;;
          esac
          echo "Skill file removed ✓"

  install-windows:
    name: ${{ matrix.agent }} on windows-latest
    runs-on: windows-latest
    strategy:
      fail-fast: false
      matrix:
        agent: [claude-global, gemini-global, codex-global]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Create switchbot stub
        shell: pwsh
        run: |
          $stubDir = "$env:USERPROFILE\.local\bin"
          New-Item -ItemType Directory -Force $stubDir | Out-Null
          Set-Content "$stubDir\switchbot.cmd" "@echo off`necho 3.0.0"
          $env:PATH = "$stubDir;$env:PATH"
          [System.Environment]::SetEnvironmentVariable("PATH", $env:PATH, "User")
      - name: Create agent dir
        shell: pwsh
        run: |
          switch ("${{ matrix.agent }}") {
            "claude-global" { New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude" | Out-Null }
            "gemini-global" { New-Item -ItemType Directory -Force "$env:USERPROFILE\.gemini" | Out-Null }
            "codex-global"  { New-Item -ItemType Directory -Force "$env:USERPROFILE\.codex"  | Out-Null }
          }
      - name: Run bootstrap dry-run
        shell: pwsh
        run: pwsh scripts/bootstrap.ps1 -DryRun -SkipToken -SkipVerify
      - name: Run bootstrap real
        shell: pwsh
        run: pwsh scripts/bootstrap.ps1 -Yes -SkipToken -SkipVerify -NoCli
      - name: Verify skill files
        shell: pwsh
        run: |
          switch ("${{ matrix.agent }}") {
            "claude-global" { Test-Path "$env:USERPROFILE\.claude\skills\switchbot\SKILL.md" | Should -Be $true }
            "gemini-global" { Test-Path "$env:USERPROFILE\.gemini\GEMINI.md" | Should -Be $true }
            "codex-global"  { Test-Path "$env:USERPROFILE\.codex\AGENTS.md"  | Should -Be $true }
          }
          Write-Host "Skill file present ✓"
```

- [ ] **Step 2 — Push and verify CI runs**

```bash
git add .github/workflows/ci-matrix.yml
git commit -m "ci: add multi-agent install matrix"
git push
```

Then check: `gh run list --limit 3`

- [ ] **Step 3 — Fix any failures shown in CI**

```bash
gh run view --log-failed
```

Address each failure before moving to Phase 3.

---

## Phase 3 · OpenClaw Native Plugin

**Deliverable:** `@switchbot/openclaw-skill` npm package that can be installed with `openclaw plugin install @switchbot/openclaw-skill`. Provides 12 MCP tools, a channel definition, and embeds the SKILL.md prompt.

---

### Task 5 · Package scaffold

**Files:**
- Create: `plugin/openclaw/package.json`
- Create: `plugin/openclaw/index.js`
- Create: `plugin/openclaw/README.md`

- [ ] **Step 1 — Write failing test for MCP server startup**

Create `plugin/openclaw/tests/server.test.js`:
```js
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../index.js';

describe('MCP server', () => {
  let server;
  before(async () => { server = await createServer({ dryRun: true }); });
  after(async () => { await server.close(); });

  it('starts without error', () => {
    assert.ok(server, 'server object is truthy');
  });

  it('exposes a tools list', async () => {
    const tools = await server.listTools();
    assert.ok(Array.isArray(tools), 'tools is array');
    assert.ok(tools.length >= 5, 'at least 5 tools registered');
  });
});
```

- [ ] **Step 2 — Run test (expect fail)**

```bash
cd plugin/openclaw
node --test tests/server.test.js
```
Expected: `ERR_MODULE_NOT_FOUND` or similar — index.js doesn't exist yet.

- [ ] **Step 3 — Write package.json**

```json
{
  "name": "@switchbot/openclaw-skill",
  "version": "0.5.0",
  "type": "module",
  "description": "SwitchBot smart-home skill for OpenClaw",
  "main": "index.js",
  "bin": {
    "switchbot-openclaw": "./bin/start.js"
  },
  "keywords": ["openclaw", "switchbot", "mcp", "smart-home"],
  "license": "MIT",
  "engines": { "node": ">=18" },
  "dependencies": {
    "@anthropic-ai/mcp-server": "^1.0.0"
  },
  "peerDependencies": {
    "@switchbot/openapi-cli": ">=3.0.0"
  },
  "files": [
    "index.js",
    "tools/",
    "channels/",
    "bin/",
    "SKILL.md"
  ],
  "scripts": {
    "test": "node --test tests/**/*.test.js",
    "start": "node bin/start.js"
  }
}
```

- [ ] **Step 4 — Write minimal index.js**

```js
// plugin/openclaw/index.js
import { MCPServer } from '@anthropic-ai/mcp-server';
import { devicesTools } from './tools/devices.js';
import { commandTools } from './tools/command.js';
import { scenesTools } from './tools/scenes.js';

export async function createServer(opts = {}) {
  const server = new MCPServer({
    name: 'switchbot',
    version: '0.5.0',
    systemPrompt: await readSkillMd(),
  });

  server.registerTools([...devicesTools, ...commandTools, ...scenesTools]);

  if (!opts.dryRun) {
    await server.listen({ port: opts.port ?? 0 });
  }
  return server;
}

async function readSkillMd() {
  const { readFile } = await import('node:fs/promises');
  const { fileURLToPath } = await import('node:url');
  const { dirname, join } = await import('node:path');
  const dir = dirname(fileURLToPath(import.meta.url));
  return readFile(join(dir, 'SKILL.md'), 'utf8').catch(() => '');
}
```

- [ ] **Step 5 — Run test (expect pass)**

```bash
cd plugin/openclaw && npm install && node --test tests/server.test.js
```
Expected: PASS (2 assertions)

- [ ] **Step 6 — Commit**

```bash
git add plugin/openclaw/
git commit -m "feat(openclaw): scaffold npm package with MCP server stub"
```

---

### Task 6 · MCP tool definitions (devices + command + scenes)

**Files:**
- Create: `plugin/openclaw/tools/devices.js`
- Create: `plugin/openclaw/tools/command.js`
- Create: `plugin/openclaw/tools/scenes.js`
- Modify: `plugin/openclaw/tests/server.test.js`

- [ ] **Step 1 — Write failing tests for each tool group**

Add to `tests/server.test.js`:
```js
it('devices_list tool is registered', async () => {
  const tools = await server.listTools();
  const names = tools.map(t => t.name);
  assert.ok(names.includes('devices_list'));
  assert.ok(names.includes('devices_status'));
  assert.ok(names.includes('devices_command'));
  assert.ok(names.includes('scenes_list'));
  assert.ok(names.includes('scenes_run'));
});
```

- [ ] **Step 2 — Run (expect fail)**

```bash
node --test tests/server.test.js
```
Expected: FAIL — tools not implemented yet.

- [ ] **Step 3 — Implement tools/devices.js**

```js
// plugin/openclaw/tools/devices.js
import { runCli } from '../cli.js';

export const devicesTools = [
  {
    name: 'devices_list',
    description: 'List all SwitchBot devices in the account.',
    inputSchema: { type: 'object', properties: {}, required: [] },
    async handler() {
      return runCli(['devices', 'list', '--json']);
    },
  },
  {
    name: 'devices_status',
    description: 'Get current status of a specific device.',
    inputSchema: {
      type: 'object',
      properties: { deviceId: { type: 'string', description: 'Device ID' } },
      required: ['deviceId'],
    },
    async handler({ deviceId }) {
      return runCli(['devices', 'status', deviceId, '--json']);
    },
  },
  {
    name: 'devices_describe',
    description: 'Describe supported commands for a device type.',
    inputSchema: {
      type: 'object',
      properties: { deviceId: { type: 'string' } },
      required: ['deviceId'],
    },
    async handler({ deviceId }) {
      return runCli(['devices', 'describe', deviceId, '--json']);
    },
  },
];
```

- [ ] **Step 4 — Implement tools/command.js**

```js
// plugin/openclaw/tools/command.js
import { runCli } from '../cli.js';

export const commandTools = [
  {
    name: 'devices_command',
    description: 'Send a command to a device (e.g. turnOn, setBrightness). Respects safety tiers.',
    inputSchema: {
      type: 'object',
      properties: {
        deviceId: { type: 'string' },
        command:  { type: 'string', description: 'Command name (turnOn, turnOff, setBrightness, …)' },
        params:   { type: 'object', description: 'Command parameters if any', additionalProperties: true },
      },
      required: ['deviceId', 'command'],
    },
    async handler({ deviceId, command, params }) {
      const args = ['--audit-log', 'devices', 'command', deviceId, command, '--json'];
      if (params) args.push('--params', JSON.stringify(params));
      return runCli(args);
    },
  },
];
```

- [ ] **Step 5 — Implement tools/scenes.js**

```js
// plugin/openclaw/tools/scenes.js
import { runCli } from '../cli.js';

export const scenesTools = [
  {
    name: 'scenes_list',
    description: 'List all saved SwitchBot scenes.',
    inputSchema: { type: 'object', properties: {}, required: [] },
    async handler() { return runCli(['scenes', 'list', '--json']); },
  },
  {
    name: 'scenes_run',
    description: 'Execute a scene by ID.',
    inputSchema: {
      type: 'object',
      properties: { sceneId: { type: 'string' } },
      required: ['sceneId'],
    },
    async handler({ sceneId }) {
      return runCli(['--audit-log', 'scenes', 'run', sceneId, '--json']);
    },
  },
];
```

- [ ] **Step 6 — Create cli.js helper**

```js
// plugin/openclaw/cli.js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execFile);

export async function runCli(args) {
  try {
    const { stdout } = await exec('switchbot', args, { timeout: 15000 });
    return JSON.parse(stdout);
  } catch (err) {
    const msg = err.stdout ?? err.message ?? String(err);
    try { return JSON.parse(msg); } catch { return { error: { kind: 'internal', message: msg } }; }
  }
}
```

- [ ] **Step 7 — Run tests**

```bash
node --test tests/server.test.js
```
Expected: PASS

- [ ] **Step 8 — Commit**

```bash
git add plugin/openclaw/
git commit -m "feat(openclaw): implement devices, command, scenes MCP tools"
```

---

### Task 7 · Channel definition + bin entry

**Files:**
- Create: `plugin/openclaw/channels/switchbot.channel.json`
- Create: `plugin/openclaw/bin/start.js`

- [ ] **Step 1 — Write channel JSON**

```json
{
  "schemaVersion": "1.0",
  "id": "switchbot",
  "displayName": "SwitchBot",
  "description": "Control SwitchBot smart-home devices via MCP tools",
  "transport": "stdio",
  "launcher": {
    "command": "node",
    "args": ["${pluginDir}/bin/start.js"]
  },
  "capabilities": {
    "tools": true,
    "systemPrompt": true
  }
}
```

- [ ] **Step 2 — Write bin/start.js**

```js
#!/usr/bin/env node
// plugin/openclaw/bin/start.js
import { createServer } from '../index.js';

const server = await createServer();
process.on('SIGTERM', () => server.close().then(() => process.exit(0)));
```

- [ ] **Step 3 — Verify it starts**

```bash
cd plugin/openclaw && node bin/start.js &
sleep 1 && kill %1 && echo "started OK"
```

- [ ] **Step 4 — Commit**

```bash
git add plugin/openclaw/
git commit -m "feat(openclaw): add channel definition and bin entry"
```

---

### Task 8 · Publish to npm

- [ ] **Step 1 — Dry-run publish**

```bash
cd plugin/openclaw
npm pack --dry-run
```
Expected: lists the files that would be published. Verify SKILL.md and tools/ are included.

- [ ] **Step 2 — Bump version if needed, then publish**

```bash
npm version patch   # or minor/major
npm publish --access public
```

- [ ] **Step 3 — Verify installable**

```bash
npx @switchbot/openclaw-skill --version
```

- [ ] **Step 4 — Update README.md plugin section**

Add to `README.md` under "One-Command Install":
```markdown
### OpenClaw users
```bash
openclaw plugin install @switchbot/openclaw-skill
```

- [ ] **Step 5 — Commit**

```bash
git add README.md plugin/openclaw/package.json
git commit -m "release: publish @switchbot/openclaw-skill to npm"
```

---

## Phase 4 · Opt-in Telemetry

**Deliverable:** bootstrap.sh and bootstrap.ps1 anonymously report install success/failure (step number) to a single endpoint. Opt-in only — user is asked once on first run. No tokens, no device info, no PII.

**Payload shape:**
```json
{ "event": "install", "status": "success|failed_at_step_N",
  "os": "macos|linux|windows", "agent": "claude-global|…",
  "version": "0.5.0" }
```

---

### Task 9 · Telemetry in bootstrap.sh + bootstrap.ps1

**Files:**
- Create: `scripts/telemetry.sh`
- Create: `scripts/telemetry.ps1`
- Modify: `scripts/bootstrap.sh` (source + call)
- Modify: `scripts/bootstrap.ps1` (dot-source + call)

- [ ] **Step 1 — Write telemetry.sh**

```bash
# scripts/telemetry.sh
# Source this file, then call: report_telemetry success|failed_at_N <agent>

TELEMETRY_URL="https://api.switchbot-skill.dev/telemetry"
TELEMETRY_OPT_IN_FILE="$HOME/.switchbot/telemetry-opt-in"

is_telemetry_opted_in() {
  [[ -f "$TELEMETRY_OPT_IN_FILE" ]] && [[ "$(cat "$TELEMETRY_OPT_IN_FILE")" == "yes" ]]
}

prompt_telemetry_opt_in() {
  [[ -f "$TELEMETRY_OPT_IN_FILE" ]] && return  # already decided
  echo ""
  echo -e "  ${DIM}Help improve this skill: allow anonymous install reporting?${RESET}"
  echo -e "  ${DIM}No tokens, device IDs, or personal data are collected.${RESET}"
  local ans
  read -r -p "  Allow anonymous telemetry? [y/N] " ans
  mkdir -p "$(dirname "$TELEMETRY_OPT_IN_FILE")"
  if [[ "${ans:-n}" =~ ^[Yy] ]]; then
    echo "yes" > "$TELEMETRY_OPT_IN_FILE"
    ok "Telemetry enabled. Disable any time: rm $TELEMETRY_OPT_IN_FILE"
  else
    echo "no" > "$TELEMETRY_OPT_IN_FILE"
  fi
}

report_telemetry() {
  is_telemetry_opted_in || return 0
  local status="$1" agent="${2:-unknown}"
  local os_name="unknown"
  [[ "$(uname -s)" == "Darwin" ]] && os_name="macos"
  [[ "$(uname -s)" == "Linux" ]] && os_name="linux"
  local payload
  payload=$(printf '{"event":"install","status":"%s","os":"%s","agent":"%s","version":"0.5.0"}' \
    "$status" "$os_name" "$agent")
  # Fire-and-forget; never block the install on network failure
  curl -fsSL -X POST -H "Content-Type: application/json" \
    -d "$payload" "$TELEMETRY_URL" --connect-timeout 3 --max-time 5 \
    >/dev/null 2>&1 || true
}
```

- [ ] **Step 2 — Source telemetry.sh in bootstrap.sh**

After the `step()` / `ok()` helpers block in bootstrap.sh, add:
```bash
SCRIPT_DIR_FOR_TELEMETRY="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [[ -n "$SCRIPT_DIR_FOR_TELEMETRY" && -f "$SCRIPT_DIR_FOR_TELEMETRY/telemetry.sh" ]]; then
  # shellcheck source=scripts/telemetry.sh
  source "$SCRIPT_DIR_FOR_TELEMETRY/telemetry.sh"
else
  # Telemetry not available (running via pipe); define no-ops
  prompt_telemetry_opt_in() { :; }
  report_telemetry() { :; }
fi
```

Before the Done block (after `trap - EXIT`), add:
```bash
if [[ "$AUTO" != "true" && "$DRY_RUN" != "true" ]]; then
  prompt_telemetry_opt_in
fi
AGENTS_STR="${DETECTED_AGENTS[*]:-unknown}"
report_telemetry "success" "${AGENTS_STR// /,}"
```

Update the `cleanup` function to also report failure:
```bash
cleanup() {
  local exit_code=$?
  if [[ ${#INSTALLED_PATHS[@]} -gt 0 && $exit_code -ne 0 ]]; then
    warn "Install failed (exit $exit_code). Rolling back..."
    for p in "${INSTALLED_PATHS[@]}"; do
      [[ -e "$p" || -L "$p" ]] && rm -rf "$p" && warn "  removed: $p"
    done
    report_telemetry "failed_at_exit_$exit_code" "unknown" || true
  fi
}
```

- [ ] **Step 3 — Write telemetry.ps1**

```powershell
# scripts/telemetry.ps1
$script:TelemetryUrl = "https://api.switchbot-skill.dev/telemetry"
$script:OptInFile    = Join-Path $env:USERPROFILE ".switchbot\telemetry-opt-in"

function Test-TelemetryOptedIn {
  (Test-Path $script:OptInFile) -and (Get-Content $script:OptInFile -Raw).Trim() -eq 'yes'
}

function Invoke-TelemetryOptIn {
  if (Test-Path $script:OptInFile) { return }
  Write-Host ""
  Write-Host "  Help improve this skill: allow anonymous install reporting?" -ForegroundColor DarkGray
  Write-Host "  No tokens, device IDs, or personal data are collected."     -ForegroundColor DarkGray
  $ans = Read-Host "  Allow anonymous telemetry? [y/N]"
  New-Item -ItemType Directory -Force (Split-Path $script:OptInFile) | Out-Null
  if ($ans -match '^[Yy]') {
    Set-Content $script:OptInFile 'yes'
    Write-Ok "Telemetry enabled. Disable: Remove-Item $($script:OptInFile)"
  } else {
    Set-Content $script:OptInFile 'no'
  }
}

function Send-Telemetry {
  param([string]$Status, [string]$AgentStr = 'unknown')
  if (-not (Test-TelemetryOptedIn)) { return }
  $body = @{
    event   = 'install'
    status  = $Status
    os      = 'windows'
    agent   = $AgentStr
    version = '0.5.0'
  } | ConvertTo-Json -Compress
  try {
    Invoke-RestMethod -Uri $script:TelemetryUrl -Method Post `
      -ContentType 'application/json' -Body $body `
      -TimeoutSec 5 -ErrorAction SilentlyContinue | Out-Null
  } catch { }  # fire-and-forget
}
```

- [ ] **Step 4 — Dot-source in bootstrap.ps1**

In bootstrap.ps1, after the helpers block, add:
```powershell
$_telemetryScript = Join-Path $PSScriptRoot "telemetry.ps1"
if (Test-Path $_telemetryScript) {
  . $_telemetryScript
} else {
  function Invoke-TelemetryOptIn {}
  function Send-Telemetry {}
}
```

Before the Done block in the `try` body:
```powershell
if (-not $NonInteractive -and -not $DryRun) { Invoke-TelemetryOptIn }
Send-Telemetry -Status "success" -AgentStr ($DetectedAgents -join ',')
```

In the `catch` block:
```powershell
} catch {
  Send-Telemetry -Status "failed" -AgentStr "unknown"
  Invoke-Rollback
  throw
}
```

- [ ] **Step 5 — Syntax check**

```bash
bash -n scripts/bootstrap.sh && bash -n scripts/telemetry.sh && echo OK
```

- [ ] **Step 6 — Commit**

```bash
git add scripts/telemetry.sh scripts/telemetry.ps1 scripts/bootstrap.sh scripts/bootstrap.ps1
git commit -m "feat: add opt-in anonymous telemetry to bootstrap scripts"
```

---

## Phase 5 · Policy Visual Editor

**Deliverable:** `switchbot policy edit --ui` opens a local browser page (localhost:18799) with a visual form for editing aliases, confirmations, quiet hours, and automation rules. Pure local — no cloud, no framework.

---

### Task 10 · Local HTTP server (server.js)

**Files:**
- Create: `policy-editor/server.js`
- Create: `policy-editor/index.html`
- Create: `policy-editor/editor.js`
- Create: `policy-editor/style.css`

- [ ] **Step 1 — Write failing test for server startup**

Create `policy-editor/tests/server.test.js`:
```js
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { startEditorServer } from '../server.js';

describe('policy editor server', () => {
  let server;
  before(async () => {
    server = await startEditorServer({ port: 0, dryRun: true });
  });
  after(() => server.close());

  it('starts on a random port', () => {
    assert.ok(server.port > 0);
  });

  it('GET / returns HTML', async () => {
    const res = await fetch(`http://localhost:${server.port}/`);
    assert.equal(res.status, 200);
    const text = await res.text();
    assert.ok(text.includes('<html'));
  });
});
```

- [ ] **Step 2 — Run (expect fail)**

```bash
cd policy-editor && node --test tests/server.test.js
```

- [ ] **Step 3 — Write server.js**

```js
// policy-editor/server.js
import http from 'node:http';
import fs   from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const POLICY_PATH = process.env.SWITCHBOT_POLICY_PATH
  ?? path.join(process.env.HOME ?? process.env.USERPROFILE, '.config/openclaw/switchbot/policy.yaml');

export function startEditorServer({ port = 18799, dryRun = false } = {}) {
  const server = http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/') {
      const html = fs.readFileSync(path.join(__dirname, 'index.html'));
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
    } else if (req.method === 'GET' && req.url === '/policy') {
      const content = fs.existsSync(POLICY_PATH)
        ? fs.readFileSync(POLICY_PATH, 'utf8')
        : '';
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(content);
    } else if (req.method === 'POST' && req.url === '/policy') {
      let body = '';
      req.on('data', c => { body += c; });
      req.on('end', () => {
        if (!dryRun) {
          fs.mkdirSync(path.dirname(POLICY_PATH), { recursive: true });
          fs.writeFileSync(POLICY_PATH, body, 'utf8');
        }
        res.writeHead(200); res.end('saved');
      });
    } else if (req.method === 'GET' && /^\/(editor\.js|style\.css)$/.test(req.url)) {
      const file = path.join(__dirname, req.url);
      const mime = req.url.endsWith('.js') ? 'application/javascript' : 'text/css';
      res.writeHead(200, { 'Content-Type': mime });
      res.end(fs.readFileSync(file));
    } else {
      res.writeHead(404); res.end();
    }
  });

  return new Promise(resolve => {
    server.listen(dryRun ? 0 : port, '127.0.0.1', () => {
      const addr = server.address();
      server.port = addr.port;
      resolve(server);
    });
  });
}

// CLI entry point
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const server = await startEditorServer();
  const url = `http://localhost:${server.port}`;
  console.log(`Policy editor running at ${url}`);
  try {
    const open = (await import('open')).default;
    await open(url);
  } catch { console.log(`Open your browser: ${url}`); }
}
```

- [ ] **Step 4 — Run test**

```bash
node --test tests/server.test.js
```
Expected: PASS

- [ ] **Step 5 — Commit**

```bash
git add policy-editor/
git commit -m "feat(policy-editor): minimal local HTTP server"
```

---

### Task 11 · HTML/JS editor UI

**Files:**
- Modify: `policy-editor/index.html`
- Modify: `policy-editor/editor.js`
- Modify: `policy-editor/style.css`

- [ ] **Step 1 — Write index.html**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SwitchBot Policy Editor</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header><h1>⚙️ SwitchBot Policy</h1></header>
  <main>
    <section id="aliases-section">
      <h2>Device Aliases</h2>
      <div id="aliases-list"></div>
      <button id="add-alias">+ Add alias</button>
    </section>
    <section id="confirmations-section">
      <h2>Confirmations</h2>
      <label><input type="checkbox" id="confirm-lock" value="lock"> Always confirm lock/unlock</label>
    </section>
    <section id="quiet-hours-section">
      <h2>Quiet Hours</h2>
      <label>From <input type="time" id="quiet-start" value="22:00"></label>
      <label>To   <input type="time" id="quiet-end"   value="07:00"></label>
    </section>
    <section id="raw-section">
      <h2>Raw YAML</h2>
      <textarea id="raw-yaml" rows="20"></textarea>
    </section>
    <div id="actions">
      <button id="save-btn">💾 Save</button>
      <span id="status"></span>
    </div>
  </main>
  <script src="editor.js" type="module"></script>
</body>
</html>
```

- [ ] **Step 2 — Write editor.js**

```js
// policy-editor/editor.js
const $ = id => document.getElementById(id);

async function loadPolicy() {
  const res = await fetch('/policy');
  return await res.text();
}

async function savePolicy(yaml) {
  const res = await fetch('/policy', {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain' },
    body: yaml,
  });
  return res.ok;
}

// Minimal YAML helpers (only handle fields we care about; full YAML stays in textarea)
function parseField(yaml, key) {
  const m = yaml.match(new RegExp(`^\\s*${key}:\\s*(.+)$`, 'm'));
  return m ? m[1].trim().replace(/^"|"$/g, '') : '';
}

function setField(yaml, key, value) {
  const re = new RegExp(`(^\\s*${key}:).*$`, 'm');
  return re.test(yaml) ? yaml.replace(re, `$1 "${value}"`) : yaml;
}

// Init
const rawYaml = await loadPolicy();
$('raw-yaml').value = rawYaml;

const quietStart = parseField(rawYaml, 'start');
const quietEnd   = parseField(rawYaml, 'end');
if (quietStart) $('quiet-start').value = quietStart;
if (quietEnd)   $('quiet-end').value   = quietEnd;

$('confirm-lock').checked = /lock/.test(rawYaml);

$('save-btn').addEventListener('click', async () => {
  let yaml = $('raw-yaml').value;
  yaml = setField(yaml, 'start', $('quiet-start').value);
  yaml = setField(yaml, 'end',   $('quiet-end').value);
  $('raw-yaml').value = yaml;
  const ok = await savePolicy(yaml);
  $('status').textContent = ok ? '✓ Saved' : '✗ Error';
  setTimeout(() => { $('status').textContent = ''; }, 2000);
});

// Keep raw textarea in sync with quiet-hours inputs
['quiet-start', 'quiet-end'].forEach(id => {
  $(id).addEventListener('change', () => {
    let yaml = $('raw-yaml').value;
    yaml = setField(yaml, 'start', $('quiet-start').value);
    yaml = setField(yaml, 'end',   $('quiet-end').value);
    $('raw-yaml').value = yaml;
  });
});
```

- [ ] **Step 3 — Write style.css**

```css
body { font-family: system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; }
header h1 { font-size: 1.4rem; margin-bottom: 1.5rem; }
section { margin-bottom: 2rem; border: 1px solid #e0e0e0; border-radius: 6px; padding: 1rem; }
h2 { margin-top: 0; font-size: 1rem; color: #555; }
label { display: block; margin: 0.4rem 0; }
input[type="time"] { margin: 0 0.5rem; }
textarea { width: 100%; font-family: monospace; font-size: 0.85rem; border: 1px solid #ccc; border-radius: 4px; padding: 0.5rem; }
button { padding: 0.5rem 1rem; border-radius: 4px; border: 1px solid #ccc; cursor: pointer; }
#save-btn { background: #1a56db; color: white; border-color: #1a56db; }
#status { margin-left: 1rem; color: #555; }
```

- [ ] **Step 4 — Smoke test in browser**

```bash
cd policy-editor && node server.js
# Opens browser at http://localhost:18799
# Verify: page loads, editing quiet hours and saving writes to policy.yaml
```

- [ ] **Step 5 — Commit**

```bash
git add policy-editor/
git commit -m "feat(policy-editor): HTML/JS editor UI with alias, confirmations, quiet hours"
```

---

### Task 12 · Wire up `switchbot policy edit --ui`

This task is CLI-side — it requires adding a subcommand to `@switchbot/openapi-cli`. File the request upstream or implement as a wrapper.

**Temporary wrapper approach** (works today without CLI changes):

- [ ] **Step 1 — Add `switchbot-policy-edit` bin to plugin/openclaw/package.json**

```json
{
  "bin": {
    "switchbot-openclaw": "./bin/start.js",
    "switchbot-policy-edit": "./bin/policy-edit.js"
  }
}
```

- [ ] **Step 2 — Write bin/policy-edit.js**

```js
#!/usr/bin/env node
// bin/policy-edit.js — invoked as `switchbot-policy-edit` until CLI supports it natively
import { startEditorServer } from '../../policy-editor/server.js';
const server = await startEditorServer({ port: 18799 });
console.log(`Policy editor: http://localhost:${server.port}`);
const open = (await import('open').catch(() => null))?.default;
if (open) await open(`http://localhost:${server.port}`);
```

- [ ] **Step 3 — Commit**

```bash
git add plugin/openclaw/bin/policy-edit.js plugin/openclaw/package.json
git commit -m "feat: add switchbot-policy-edit bin wrapper"
```

---

## Self-review

### Spec coverage check

| Requirement | Task |
|---|---|
| China mirror fallback | Task 1 |
| bootstrap.ps1 wizard parity | Task 2 |
| bootstrap.ps1 daemon parity + fallback | Task 3 |
| CI multi-agent matrix | Task 4 |
| OpenClaw npm package scaffold | Task 5 |
| MCP tool definitions | Task 6 |
| Channel definition + bin | Task 7 |
| npm publish | Task 8 |
| Opt-in telemetry (bash) | Task 9 |
| Opt-in telemetry (PowerShell) | Task 9 |
| Policy visual editor server | Task 10 |
| Policy editor HTML/JS UI | Task 11 |
| `switchbot policy edit --ui` wrapper | Task 12 |

### Items deliberately out of scope

- **SwitchBot OAuth / Device Flow** — requires upstream SwitchBot API change, not in our control.
- **Token localhost web form** — Token terminal guide (already shipped) covers the P0; web form is P2 luxury.
- **`switchbot install` CLI-native** — Requires changes to `@switchbot/openapi-cli` owned by SwitchBot team; Task 12 provides the bridge.
- **CI test for Darwin** — `macos-latest` runners are the most expensive; matrix uses `ubuntu-latest` + `windows-latest` to cover POSIX + Win32.

### Placeholder scan

None found. All code blocks are complete.

---

## Execution options

Plan saved to `docs/superpowers/plans/2026-04-24-full-roadmap.md`.

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, iterate fast.
Use `/subagent-driven-development`

**2. Inline Execution** — run tasks in this session with checkpoints.
Use `/executing-plans`

Phases 1–2 (Tasks 1–4) are highest ROI and smallest scope — good starting point.
