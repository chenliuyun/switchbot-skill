#!/usr/bin/env node
// plugin/openclaw/bin/start.js
import { createServer } from '../index.js';

const server = await createServer();
process.on('SIGTERM', () => server.close().then(() => process.exit(0)));
