import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { buildCliArgs } from '../cli.js';

describe('buildCliArgs', () => {
  it('devices_list passes --no-cache', () => {
    const args = buildCliArgs({ tool: 'devices_list', params: {} });
    assert.ok(args.includes('--no-cache'), 'read tool must use --no-cache');
    assert.deepEqual(args, ['devices', 'list', '--no-cache', '--json']);
  });

  it('devices_status passes --no-cache and forwards deviceId', () => {
    const args = buildCliArgs({ tool: 'devices_status', params: { deviceId: 'ABC' } });
    assert.ok(args.includes('--no-cache'));
    assert.deepEqual(args, ['devices', 'status', 'ABC', '--no-cache', '--json']);
  });

  it('devices_describe passes --no-cache', () => {
    const args = buildCliArgs({ tool: 'devices_describe', params: { deviceId: 'ABC' } });
    assert.ok(args.includes('--no-cache'));
    assert.deepEqual(args, ['devices', 'describe', 'ABC', '--no-cache', '--json']);
  });

  it('devices_command does NOT pass --no-cache', () => {
    const args = buildCliArgs({
      tool: 'devices_command',
      params: { deviceId: 'ABC', command: 'turnOn' },
    });
    assert.ok(!args.includes('--no-cache'), 'mutation must not use --no-cache');
    assert.deepEqual(args, ['--audit-log', 'devices', 'command', 'ABC', 'turnOn', '--json']);
  });

  it('devices_command forwards --params when provided', () => {
    const args = buildCliArgs({
      tool: 'devices_command',
      params: { deviceId: 'ABC', command: 'setBrightness', params: { value: 70 } },
    });
    assert.ok(!args.includes('--no-cache'));
    const paramsIdx = args.indexOf('--params');
    assert.notEqual(paramsIdx, -1, '--params flag missing');
    assert.equal(args[paramsIdx + 1], JSON.stringify({ value: 70 }));
  });

  it('scenes_list passes --no-cache', () => {
    const args = buildCliArgs({ tool: 'scenes_list', params: {} });
    assert.ok(args.includes('--no-cache'));
    assert.deepEqual(args, ['scenes', 'list', '--no-cache', '--json']);
  });

  it('scenes_run does NOT pass --no-cache', () => {
    const args = buildCliArgs({ tool: 'scenes_run', params: { sceneId: 'SCENE1' } });
    assert.ok(!args.includes('--no-cache'), 'mutation must not use --no-cache');
    assert.deepEqual(args, ['--audit-log', 'scenes', 'run', 'SCENE1', '--json']);
  });

  it('throws for unknown tool', () => {
    assert.throws(() => buildCliArgs({ tool: 'unknown_tool', params: {} }), /unknown tool/);
  });
});
