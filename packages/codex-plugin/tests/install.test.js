import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { makeInstall } from '../bin/install.js';

function makeOkCliCheck(version = '3.3.0') {
  return async () => ({ ok: true, version });
}
function makeFailCliCheck() {
  return async () => ({ ok: false, message: 'CLI not found' });
}
function makeSpawn(exitCode = 0) {
  const calls = [];
  const spawn = (cmd, args) => {
    calls.push({ cmd, args });
    return Promise.resolve(exitCode);
  };
  return { spawn, calls };
}

const TEST_ROOT = '/fake/switchbot-codex-plugin';

describe('makeInstall', () => {
  it('skips npm install when CLI is already present', async () => {
    const { spawn, calls } = makeSpawn(0);
    const install = makeInstall({
      checkCli: makeOkCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 0);
    assert.equal(calls.length, 2);
    assert.deepEqual(calls[0], { cmd: 'codex', args: ['plugin', 'marketplace', 'add', TEST_ROOT] });
    assert.deepEqual(calls[1], { cmd: 'codex', args: ['plugin', 'add', 'switchbot@switchbot-codex-plugin'] });
  });

  it('runs npm install first when CLI is missing, then registers and adds plugin', async () => {
    const { spawn, calls } = makeSpawn(0);
    const install = makeInstall({
      checkCli: makeFailCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 0);
    assert.equal(calls.length, 3);
    assert.deepEqual(calls[0], { cmd: 'npm', args: ['install', '-g', '@switchbot/openapi-cli@latest'] });
    assert.deepEqual(calls[1], { cmd: 'codex', args: ['plugin', 'marketplace', 'add', TEST_ROOT] });
    assert.deepEqual(calls[2], { cmd: 'codex', args: ['plugin', 'add', 'switchbot@switchbot-codex-plugin'] });
  });

  it('exits with npm install exit code and stops when CLI install fails', async () => {
    const { spawn, calls } = makeSpawn(1);
    const install = makeInstall({
      checkCli: makeFailCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 1);
    assert.equal(calls.length, 1);
    assert.deepEqual(calls[0], { cmd: 'npm', args: ['install', '-g', '@switchbot/openapi-cli@latest'] });
  });

  it('exits with marketplace add exit code and stops when registration fails', async () => {
    let callCount = 0;
    const spawn = (cmd, args) => {
      callCount++;
      return Promise.resolve(callCount === 1 ? 2 : 0);
    };
    const install = makeInstall({
      checkCli: makeOkCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 2);
    assert.equal(callCount, 1);
  });

  it('propagates plugin add exit code', async () => {
    let callCount = 0;
    const spawn = (cmd, args) => {
      callCount++;
      return Promise.resolve(callCount === 2 ? 3 : 0);
    };
    const install = makeInstall({
      checkCli: makeOkCliCheck(),
      runInherit: spawn,
      packageRoot: TEST_ROOT,
    });
    const code = await install();
    assert.equal(code, 3);
    assert.equal(callCount, 2);
  });
});
