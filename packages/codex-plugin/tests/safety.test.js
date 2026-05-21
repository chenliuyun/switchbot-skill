import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { buildCliArgs, runCli, looksLikeAuthError } from '../src/executor.js';

describe('buildCliArgs', () => {
  it('devices_list → [devices, list, --no-cache, --json]', () => {
    assert.deepEqual(
      buildCliArgs('devices_list', {}),
      ['devices', 'list', '--no-cache', '--json']
    );
  });

  it('devices_status → [devices, status, <id>, --no-cache, --json]', () => {
    assert.deepEqual(
      buildCliArgs('devices_status', { deviceId: 'abc' }),
      ['devices', 'status', 'abc', '--no-cache', '--json']
    );
  });

  it('devices_describe → [devices, describe, <id>, --no-cache, --json]', () => {
    assert.deepEqual(
      buildCliArgs('devices_describe', { deviceId: 'abc' }),
      ['devices', 'describe', 'abc', '--no-cache', '--json']
    );
  });

  it('scenes_list → [scenes, list, --no-cache, --json]', () => {
    assert.deepEqual(
      buildCliArgs('scenes_list', {}),
      ['scenes', 'list', '--no-cache', '--json']
    );
  });

  it('devices_command without auditLog omits --audit-log', () => {
    const args = buildCliArgs('devices_command', { deviceId: 'x', command: 'turnOn' });
    assert.ok(!args.includes('--audit-log'));
    assert.ok(args.includes('devices'));
    assert.ok(args.includes('command'));
    assert.ok(args.includes('x'));
    assert.ok(args.includes('turnOn'));
  });

  it('devices_command with auditLog:true prepends --audit-log', () => {
    const args = buildCliArgs('devices_command', { deviceId: 'x', command: 'turnOn' }, { auditLog: true });
    assert.equal(args[0], '--audit-log');
    assert.ok(args.includes('devices'));
    assert.ok(args.includes('command'));
  });

  it('devices_command with parameter appends --params <value>', () => {
    const args = buildCliArgs('devices_command', { deviceId: 'x', command: 'setBrightness', parameter: '80' });
    const idx = args.indexOf('--params');
    assert.notEqual(idx, -1);
    assert.equal(args[idx + 1], '80');
  });

  it('scenes_run without auditLog omits --audit-log', () => {
    const args = buildCliArgs('scenes_run', { sceneId: 's1' });
    assert.ok(!args.includes('--audit-log'));
    assert.ok(args.includes('scenes'));
    assert.ok(args.includes('run'));
    assert.ok(args.includes('s1'));
  });

  it('scenes_run with auditLog:true prepends --audit-log', () => {
    const args = buildCliArgs('scenes_run', { sceneId: 's1' }, { auditLog: true });
    assert.equal(args[0], '--audit-log');
  });

  it('throws on unknown tool', () => {
    assert.throws(() => buildCliArgs('unknown_tool', {}), /unknown tool/);
  });
});

describe('runCli', () => {
  it('returns parsed JSON on success', async () => {
    const fakeExec = async () => ({ stdout: JSON.stringify({ status: 'ok' }) });
    const result = await runCli(['devices', 'list', '--json'], fakeExec);
    assert.deepEqual(result, { status: 'ok' });
  });

  it('returns setup-required when CLI is missing (ENOENT)', async () => {
    const err = Object.assign(new Error('not found'), { code: 'ENOENT' });
    const fakeExec = async () => { throw err; };
    const result = await runCli(['devices', 'list'], fakeExec);
    assert.equal(result.error.kind, 'setup-required');
    assert.equal(result.error.reason, 'cli-missing');
  });

  it('returns setup-required on auth error text', async () => {
    const err = Object.assign(new Error('token not set'), { stdout: 'token not set' });
    const fakeExec = async () => { throw err; };
    const result = await runCli(['devices', 'list'], fakeExec);
    assert.equal(result.error.kind, 'setup-required');
    assert.equal(result.error.reason, 'auth-missing');
  });
});

describe('looksLikeAuthError', () => {
  it('detects "token not set"', () => assert.ok(looksLikeAuthError('token not set')));
  it('detects "Unauthorized"', () => assert.ok(looksLikeAuthError('Unauthorized')));
  it('detects "401"', () => assert.ok(looksLikeAuthError('HTTP 401')));
  it('returns false for unrelated text', () => assert.ok(!looksLikeAuthError('device not found')));
  it('returns false for empty string', () => assert.ok(!looksLikeAuthError('')));
});
