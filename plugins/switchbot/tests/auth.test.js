import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import { makeRunAuth } from '../bin/auth.js';

function makeOkCliCheck(version = '3.3.0') {
  return async () => ({ ok: true, version });
}
function makeFailCliCheck(msg = 'not found') {
  return async () => ({ ok: false, message: msg });
}
function makeOkCredCheck(source = 'keychain') {
  return async () => ({ ok: true, source });
}
function makeFailCredCheck() {
  return async () => ({ ok: false, message: 'no creds' });
}
function makeSpawn(exitCode = 0) {
  const calls = [];
  const spawn = (cmd, args) => {
    calls.push({ cmd, args });
    return Promise.resolve(exitCode);
  };
  return { spawn, calls };
}

describe('runAuth', () => {
  it('exits 0 immediately when credentials already present', async () => {
    const { spawn, calls } = makeSpawn(0);
    const runAuth = makeRunAuth({
      checkCli: makeOkCliCheck(),
      checkCredentials: makeOkCredCheck('config'),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.equal(code, 0);
    assert.equal(calls.length, 0);
  });

  it('exits non-zero when CLI check fails', async () => {
    const { spawn } = makeSpawn(0);
    const runAuth = makeRunAuth({
      checkCli: makeFailCliCheck('CLI not found'),
      checkCredentials: makeFailCredCheck(),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.notEqual(code, 0);
  });

  it('calls auth login then doctor when no credentials', async () => {
    const { spawn, calls } = makeSpawn(0);
    const runAuth = makeRunAuth({
      checkCli: makeOkCliCheck(),
      checkCredentials: makeFailCredCheck(),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.equal(code, 0);
    assert.equal(calls.length, 2);
    assert.deepEqual(calls[0], { cmd: 'switchbot', args: ['auth', 'login'] });
    assert.deepEqual(calls[1], { cmd: 'switchbot', args: ['doctor'] });
  });

  it('exits with login exit code when auth login fails', async () => {
    const { spawn, calls } = makeSpawn(1);
    const runAuth = makeRunAuth({
      checkCli: makeOkCliCheck(),
      checkCredentials: makeFailCredCheck(),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.equal(code, 1);
    assert.equal(calls.length, 1);
    assert.deepEqual(calls[0], { cmd: 'switchbot', args: ['auth', 'login'] });
  });

  it('exits with doctor exit code when verification fails', async () => {
    let callCount = 0;
    const spawn = (cmd, args) => {
      callCount++;
      return Promise.resolve(callCount === 1 ? 0 : 2);
    };
    const runAuth = makeRunAuth({
      checkCli: makeOkCliCheck(),
      checkCredentials: makeFailCredCheck(),
      runInherit: spawn,
    });
    const code = await runAuth();
    assert.equal(code, 2);
  });
});
