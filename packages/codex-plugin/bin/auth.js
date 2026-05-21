#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkCli as defaultCheckCli } from '../setup/check-cli.js';
import { checkCredentials as defaultCheckCredentials } from '../setup/check-credentials.js';

// Patch .mcp.json with the absolute path to bin/server.js so Codex can launch
// the MCP server regardless of which project is open. ${pluginDir} is NOT
// substituted by Codex — it gets treated as a literal directory name.
export async function patchMcpJson(binDir) {
  const pluginRoot = join(binDir, '..');
  const serverPath = join(pluginRoot, 'bin', 'server.js');
  const mcpJsonPath = join(pluginRoot, '.mcp.json');
  const content = JSON.stringify(
    {
      mcpServers: {
        switchbot: {
          command: 'node',
          args: [serverPath],
          description: 'SwitchBot smart-home MCP server (6 tools, policy-gated, self-contained)',
        },
      },
    },
    null,
    2,
  ) + '\n';
  await writeFile(mcpJsonPath, content);
}

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

// CLI entry point — only runs when invoked directly, not when imported by tests.
const isMain = process.argv[1]?.replace(/\\/g, '/').endsWith('bin/auth.js');
if (isMain) {
  const binDir = dirname(fileURLToPath(import.meta.url));
  await patchMcpJson(binDir).catch((err) => {
    process.stderr.write(`[switchbot-codex] Warning: could not patch .mcp.json: ${err.message}\n`);
  });

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
