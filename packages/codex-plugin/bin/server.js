#!/usr/bin/env node
// Self-resolving MCP entry point. Uses import.meta.dirname so the path to
// src/server.js is correct regardless of the project CWD Codex uses when
// launching the process — ${pluginDir} is never substituted by Codex.
import { createMcpServer } from '../src/server.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

const server = createMcpServer();
const transport = new StdioServerTransport();
await server.connect(transport);
