import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { checkPolicy, loadPolicy } from '../src/policy.js';

describe('loadPolicy', () => {
  it('returns null when file does not exist', async () => {
    const result = await loadPolicy('/nonexistent/path/policy.yaml');
    assert.equal(result, null);
  });

  it('parses allowedDevices list', async () => {
    const tmp = join(tmpdir(), `sb-policy-${Date.now()}.yaml`);
    await writeFile(tmp, 'allowedDevices:\n  - device-A\n  - device-B\n');
    try {
      const policy = await loadPolicy(tmp);
      assert.deepEqual(policy.allowedDevices, ['device-A', 'device-B']);
    } finally {
      await rm(tmp, { force: true });
    }
  });

  it('parses blockedCommands list', async () => {
    const tmp = join(tmpdir(), `sb-policy-${Date.now()}.yaml`);
    await writeFile(tmp, 'blockedCommands:\n  - lockOff\n  - setBrightness\n');
    try {
      const policy = await loadPolicy(tmp);
      assert.deepEqual(policy.blockedCommands, ['lockOff', 'setBrightness']);
    } finally {
      await rm(tmp, { force: true });
    }
  });
});

describe('checkPolicy — null policy', () => {
  it('returns blocked:false for any call when policy is null', () => {
    const r = checkPolicy(null, { tool: 'devices_command', deviceId: 'x', command: 'turnOn' });
    assert.deepEqual(r, { blocked: false });
  });
});

describe('checkPolicy — quietHours', () => {
  function makeDate(h, m) {
    const d = new Date();
    d.setHours(h, m, 0, 0);
    return d;
  }

  it('blocks at 23:30 within 22:00–07:00 window', () => {
    const policy = { quietHours: { start: '22:00', end: '07:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(23, 30));
    assert.equal(r.blocked, true);
    assert.equal(r.reason, 'quietHours');
    assert.ok(r.message.includes('22:00'));
  });

  it('blocks at 03:00 within 22:00–07:00 window (crosses midnight)', () => {
    const policy = { quietHours: { start: '22:00', end: '07:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(3, 0));
    assert.equal(r.blocked, true);
  });

  it('does not block at 12:00 within 22:00–07:00 window', () => {
    const policy = { quietHours: { start: '22:00', end: '07:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(12, 0));
    assert.equal(r.blocked, false);
  });

  it('blocks within a same-day window (09:00–18:00) at 14:00', () => {
    const policy = { quietHours: { start: '09:00', end: '18:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(14, 0));
    assert.equal(r.blocked, true);
  });

  it('does not block outside a same-day window at 20:00', () => {
    const policy = { quietHours: { start: '09:00', end: '18:00' } };
    const r = checkPolicy(policy, { tool: 'devices_command' }, makeDate(20, 0));
    assert.equal(r.blocked, false);
  });
});

describe('checkPolicy — allowedDevices', () => {
  it('blocks device not in allowlist', () => {
    const policy = { allowedDevices: ['device-A'] };
    const r = checkPolicy(policy, { tool: 'devices_command', deviceId: 'device-B' });
    assert.equal(r.blocked, true);
    assert.equal(r.reason, 'allowedDevices');
  });

  it('allows device that is in allowlist', () => {
    const policy = { allowedDevices: ['device-A'] };
    const r = checkPolicy(policy, { tool: 'devices_command', deviceId: 'device-A' });
    assert.equal(r.blocked, false);
  });

  it('allows any device when allowedDevices is empty array', () => {
    const policy = { allowedDevices: [] };
    const r = checkPolicy(policy, { tool: 'devices_command', deviceId: 'device-X' });
    assert.equal(r.blocked, false);
  });

  it('skips check when deviceId is undefined', () => {
    const policy = { allowedDevices: ['device-A'] };
    const r = checkPolicy(policy, { tool: 'devices_list' });
    assert.equal(r.blocked, false);
  });
});

describe('checkPolicy — blockedCommands', () => {
  it('blocks command in blockedCommands list', () => {
    const policy = { blockedCommands: ['lockOff'] };
    const r = checkPolicy(policy, { tool: 'devices_command', command: 'lockOff' });
    assert.equal(r.blocked, true);
    assert.equal(r.reason, 'blockedCommands');
  });

  it('allows command not in blockedCommands list', () => {
    const policy = { blockedCommands: ['lockOff'] };
    const r = checkPolicy(policy, { tool: 'devices_command', command: 'turnOn' });
    assert.equal(r.blocked, false);
  });

  it('skips check when command is undefined', () => {
    const policy = { blockedCommands: ['lockOff'] };
    const r = checkPolicy(policy, { tool: 'scenes_run' });
    assert.equal(r.blocked, false);
  });
});
