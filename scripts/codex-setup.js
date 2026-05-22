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

function run(cmd, args) {
  return spawnSync(cmd, args, { stdio: 'inherit', shell: true }).status ?? 1;
}
function ok(cmd, args) {
  return spawnSync(cmd, args, { shell: true }).status === 0;
}
function stripFrontMatter(text) {
  if (!text.startsWith('---')) return text;
  const end = text.indexOf('\n---', 3);
  return end === -1 ? text : text.slice(end + 4).trimStart();
}

// 1. Install CLI if missing
if (!ok('switchbot', ['--version'])) {
  console.log('[setup] Installing @switchbot/openapi-cli...');
  if (run('npm', ['install', '-g', '@switchbot/openapi-cli@latest']) !== 0) {
    console.error('[setup] CLI install failed. Run manually: npm install -g @switchbot/openapi-cli@latest');
    process.exit(1);
  }
}
console.log('[setup] CLI ready.');

// 2. Marketplace registration (works on all Codex versions)
run('codex', ['plugin', 'marketplace', 'add', REPO_DIR]);

// 3. Plugin add (modern Codex only)
const pluginName = `switchbot@${basename(REPO_DIR)}`;
const pluginOk = run('codex', ['plugin', 'add', pluginName]) === 0;

if (!pluginOk) {
  // Fallback for older Codex: patch config.toml + write AGENTS.md
  console.log('[setup] "codex plugin add" not supported — applying legacy config...');
  mkdirSync(CODEX_DIR, { recursive: true });

  let config = existsSync(CONFIG_PATH) ? readFileSync(CONFIG_PATH, 'utf8') : '';
  if (!config.includes('plugin_hooks')) {
    config += '\n[features]\nplugin_hooks = true\n';
  }
  if (!config.includes('name = "switchbot"')) {
    config += '\n[[mcp_servers]]\nname = "switchbot"\ncommand = "switchbot"\nargs = ["mcp", "serve", "--tools", "all"]\n';
  }
  writeFileSync(CONFIG_PATH, config);

  const skillPath = join(REPO_DIR, 'SKILL.md');
  if (existsSync(skillPath)) {
    writeFileSync(AGENTS_PATH, stripFrontMatter(readFileSync(skillPath, 'utf8')));
  }

  console.log('[setup] config.toml and AGENTS.md updated.');
  console.log('[setup] Starting browser login...');
  run('switchbot', ['auth', 'login']);
}

console.log('[setup] Done. Restart Codex, then ask: "List my SwitchBot devices."');
