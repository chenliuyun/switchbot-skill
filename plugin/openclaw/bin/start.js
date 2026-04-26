#!/usr/bin/env node
// plugin/openclaw/bin/start.js
//
// Default entry point for the @cly-org/switchbot-openclaw-skill plugin.
// With no arguments (or unrecognized ones), starts the stdio MCP server
// — this is how OpenClaw and other MCP hosts launch the plugin.
//
// Subcommands:
//   setup       Interactive bootstrap: verify CLI installed + >=3.3.0,
//               run `switchbot doctor` to confirm auth.
//   --version   Print the plugin version.
//   --help      Print this help.
//
// MCP mode MUST NOT write to stdout (it's the JSON-RPC channel), so
// every branch that emits text exits before startStdioServer() runs.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const cmd = process.argv[2];

if (cmd === 'setup') {
  const { runSetup } = await import('./setup-flow.js');
  await runSetup();
} else if (cmd === '--version' || cmd === '-v') {
  const here = dirname(fileURLToPath(import.meta.url));
  const pkg = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8'));
  console.log(pkg.version);
} else if (cmd === '--help' || cmd === '-h' || cmd === 'help') {
  console.log(`switchbot-openclaw — MCP plugin for SwitchBot smart-home control

Usage:
  switchbot-openclaw             Start the stdio MCP server (default; used by MCP hosts).
  switchbot-openclaw setup       Interactive CLI install + token bootstrap.
  switchbot-openclaw --version   Print the plugin version.
  switchbot-openclaw --help      Show this help.

See https://github.com/chenliuyun/switchbot-skill for full docs.`);
} else {
  const { startStdioServer } = await import('../index.js');
  await startStdioServer();
}
