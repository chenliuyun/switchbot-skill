import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { TOOL_DEFINITIONS } from '../src/tools.js';

const EXPECTED_TOOLS = [
  'devices_list',
  'devices_status',
  'devices_describe',
  'devices_command',
  'scenes_list',
  'scenes_run',
];

describe('TOOL_DEFINITIONS', () => {
  it('has exactly 6 tools', () => {
    assert.equal(TOOL_DEFINITIONS.length, 6);
  });

  it('contains all expected tool names', () => {
    const names = TOOL_DEFINITIONS.map((t) => t.name);
    for (const expected of EXPECTED_TOOLS) {
      assert.ok(names.includes(expected), `Missing tool: ${expected}`);
    }
  });

  it('every tool has an inputSchema with type:object', () => {
    for (const tool of TOOL_DEFINITIONS) {
      assert.ok(tool.inputSchema, `${tool.name} missing inputSchema`);
      assert.equal(tool.inputSchema.type, 'object', `${tool.name} inputSchema.type != object`);
      assert.ok(Array.isArray(tool.inputSchema.required), `${tool.name} missing required array`);
    }
  });

  it('devices_command has boolean confirmed property', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'devices_command');
    assert.ok(tool, 'devices_command not found');
    assert.ok(
      tool.inputSchema.properties.confirmed,
      'devices_command missing confirmed parameter',
    );
    assert.equal(tool.inputSchema.properties.confirmed.type, 'boolean');
  });

  it('scenes_run has boolean confirmed property', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'scenes_run');
    assert.ok(tool, 'scenes_run not found');
    assert.ok(tool.inputSchema.properties.confirmed, 'scenes_run missing confirmed parameter');
    assert.equal(tool.inputSchema.properties.confirmed.type, 'boolean');
  });

  it('all tools have non-empty description mentioning safety tier', () => {
    for (const tool of TOOL_DEFINITIONS) {
      assert.ok(
        tool.description && tool.description.toLowerCase().includes('safety tier'),
        `${tool.name} description missing 'Safety tier'`,
      );
    }
  });
});
