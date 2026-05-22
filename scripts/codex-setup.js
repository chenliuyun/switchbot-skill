#!/usr/bin/env node
/**
 * One-shot Codex setup for SwitchBot.
 * Works with both modern Codex (plugin add) and older versions (legacy config).
 * Run: node ~/switchbot-skill/scripts/codex-setup.js
 */
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, basename, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_DIR = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const CODEX_DIR = join(homedir(), '.codex');
const CONFIG_PATH = join(CODEX_DIR, 'config.toml');
const AGENTS_PATH = join(CODEX_DIR, 'AGENTS.md');
const MIN_CLI_VERSION = '3.7.1';

function run(cmd, args) {
  return spawnSync(cmd, args, { stdio: 'inherit', shell: true }).status ?? 1;
}
function ok(cmd, args) {
  return spawnSync(cmd, args, { shell: true }).status === 0;
}
function versionAtLeast(have, need) {
  const a = have.split('.').map(n => parseInt(n, 10) || 0);
  const b = need.split('.').map(n => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if ((a[i] ?? 0) > (b[i] ?? 0)) return true;
    if ((a[i] ?? 0) < (b[i] ?? 0)) return false;
  }
  return true;
}
function getCliVersion() {
  const r = spawnSync('switchbot', ['--version'], { shell: true });
  if (r.status !== 0) return null;
  const m = (r.stdout?.toString() ?? '').trim().match(/\d+\.\d+\.\d+/);
  return m ? m[0] : null;
}
function credentialsConfigured() {
  // Try doctor --json first (most reliable)
  const r = spawnSync('switchbot', ['doctor', '--json'], { shell: true, timeout: 10000 });
  if (r.status === 0 && r.stdout) {
    try {
      const parsed = JSON.parse(r.stdout.toString());
      const data = parsed?.data ?? parsed;
      if (data?.credentials?.configured === true) return true;
    } catch {}
  }
  // Fallback: keychain describe exits 0 only when credentials are stored
  return ok('switchbot', ['auth', 'keychain', 'describe', '--json']);
}
function stripFrontMatter(text) {
  if (!text.startsWith('---')) return text;
  const end = text.indexOf('\n---', 3);
  return end === -1 ? text : text.slice(end + 4).trimStart();
}
function applyLegacySetup() {
  console.log('[setup] Applying legacy Codex config...');
  mkdirSync(CODEX_DIR, { recursive: true });

  let config = existsSync(CONFIG_PATH) ? readFileSync(CONFIG_PATH, 'utf8') : '';
  if (!config.includes('name = "switchbot"')) {
    config += '\n[[mcp_servers]]\nname = "switchbot"\ncommand = "switchbot"\nargs = ["mcp", "serve", "--tools", "all"]\n';
  }
  writeFileSync(CONFIG_PATH, config);

  const skillPath = join(REPO_DIR, 'SKILL.md');
  if (existsSync(skillPath)) {
    writeFileSync(AGENTS_PATH, stripFrontMatter(readFileSync(skillPath, 'utf8')));
  }

  console.log('[setup] config.toml and AGENTS.md updated.');
}

// 1. Install CLI if missing or version too old
const currentCliVersion = getCliVersion();
if (!currentCliVersion) {
  console.log('[setup] Installing @switchbot/openapi-cli...');
  if (run('npm', ['install', '-g', '@switchbot/openapi-cli@latest']) !== 0) {
    console.error('[setup] CLI install failed. Run manually: npm install -g @switchbot/openapi-cli@latest');
    process.exit(1);
  }
} else if (!versionAtLeast(currentCliVersion, MIN_CLI_VERSION)) {
  console.log(`[setup] CLI ${currentCliVersion} is below minimum ${MIN_CLI_VERSION} — upgrading...`);
  if (run('npm', ['install', '-g', '@switchbot/openapi-cli@latest']) !== 0) {
    console.error('[setup] CLI upgrade failed. Run manually: npm install -g @switchbot/openapi-cli@latest');
    process.exit(1);
  }
} else {
  console.log(`[setup] CLI ${currentCliVersion} already installed.`);
}

// 2. Marketplace registration
const marketplaceCode = run('codex', ['plugin', 'marketplace', 'add', REPO_DIR]);
const marketplaceOk = marketplaceCode === 0;

// 3. Plugin add (modern Codex only)
const pluginName = `switchbot@${basename(REPO_DIR)}`;
const pluginOk = marketplaceOk && run('codex', ['plugin', 'add', pluginName]) === 0;

if (pluginOk) {
  if (credentialsConfigured()) {
    console.log('[setup] Credentials already configured. Skipping login.');
  } else {
    console.log('[setup] Plugin installed. Completing browser login...');
    run('switchbot', ['auth', 'login']);
  }
} else {
  if (!marketplaceOk) {
    console.log('[setup] "codex plugin marketplace add" failed — falling back to legacy MCP setup.');
  } else {
    console.log('[setup] "codex plugin add" not supported — falling back to legacy MCP setup.');
  }
  applyLegacySetup();

  if (credentialsConfigured()) {
    console.log('[setup] Credentials already configured. Skipping login.');
  } else {
    console.log('[setup] Starting browser login...');
    run('switchbot', ['auth', 'login']);
  }
}

console.log('[setup] Done. Restart Codex, then ask: "List my SwitchBot devices."');
