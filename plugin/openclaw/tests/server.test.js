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

  it('has required tool names', async () => {
    const tools = await server.listTools();
    const names = tools.map(t => t.name);
    assert.ok(names.includes('devices_list'));
    assert.ok(names.includes('devices_status'));
    assert.ok(names.includes('devices_command'));
    assert.ok(names.includes('scenes_list'));
    assert.ok(names.includes('scenes_run'));
  });
});
