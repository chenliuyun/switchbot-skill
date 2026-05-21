import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import { makeCheckCli } from '../setup/check-cli.js';

describe('checkCli', () => {
  it('returns ok:true when CLI is >= 3.3.0', async () => {
    const fakeExec = async () => ({ stdout: '3.3.0\n' });
    const checkCli = makeCheckCli(fakeExec);
    const result = await checkCli();
    assert.deepEqual(result, { ok: true, version: '3.3.0' });
  });

  it('returns ok:false when CLI is below minimum', async () => {
    const fakeExec = async () => ({ stdout: '3.2.9\n' });
    const checkCli = makeCheckCli(fakeExec);
    const result = await checkCli();
    assert.equal(result.ok, false);
    assert.match(result.message, /3\.2\.9/);
    assert.match(result.message, /3\.3\.0/);
  });

  it('returns ok:false when CLI is missing (ENOENT)', async () => {
    const err = Object.assign(new Error('not found'), { code: 'ENOENT' });
    const fakeExec = async () => { throw err; };
    const checkCli = makeCheckCli(fakeExec);
    const result = await checkCli();
    assert.equal(result.ok, false);
    assert.match(result.message, /not found/i);
  });

  it('returns ok:false when version string is unparseable', async () => {
    const fakeExec = async () => ({ stdout: 'development\n' });
    const checkCli = makeCheckCli(fakeExec);
    const result = await checkCli();
    assert.equal(result.ok, false);
    assert.match(result.message, /Upgrade/);
  });

  it('returns ok:true when CLI is above minimum (e.g. 5.0.0)', async () => {
    const fakeExec = async () => ({ stdout: '5.0.0\n' });
    const checkCli = makeCheckCli(fakeExec);
    const result = await checkCli();
    assert.deepEqual(result, { ok: true, version: '5.0.0' });
  });

  it('returns ok:false on non-ENOENT exec error', async () => {
    const fakeExec = async () => { throw new Error('permission denied'); };
    const checkCli = makeCheckCli(fakeExec);
    const result = await checkCli();
    assert.equal(result.ok, false);
    assert.match(result.message, /permission denied/);
  });
});

import { makeCheckCredentials } from '../setup/check-credentials.js';

describe('checkCredentials', () => {
  it('returns ok:true with source:config when config show has token+secret', async () => {
    const fakeExec = async (cmd, args) => {
      if (args.includes('show')) {
        return { stdout: JSON.stringify({ data: { token: 'tok123', secret: 'sec456' } }) };
      }
      throw new Error('unexpected');
    };
    const checkCredentials = makeCheckCredentials(fakeExec);
    const result = await checkCredentials();
    assert.deepEqual(result, { ok: true, source: 'config' });
  });

  it('falls back to keychain when config show has no credentials', async () => {
    const fakeExec = async (cmd, args) => {
      if (args.includes('show')) return { stdout: JSON.stringify({ data: {} }) };
      if (args.includes('get'))  return { stdout: JSON.stringify({ data: { present: true } }) };
      throw new Error('unexpected');
    };
    const checkCredentials = makeCheckCredentials(fakeExec);
    const result = await checkCredentials();
    assert.deepEqual(result, { ok: true, source: 'keychain' });
  });

  it('returns ok:false when neither config nor keychain has credentials', async () => {
    const fakeExec = async (cmd, args) => {
      if (args.includes('show')) return { stdout: JSON.stringify({ data: {} }) };
      if (args.includes('get'))  return { stdout: JSON.stringify({ data: { present: false } }) };
      throw new Error('unexpected');
    };
    const checkCredentials = makeCheckCredentials(fakeExec);
    const result = await checkCredentials();
    assert.equal(result.ok, false);
    assert.match(result.message, /switchbot auth login/);
  });

  it('falls back to keychain when config show throws', async () => {
    const fakeExec = async (cmd, args) => {
      if (args.includes('show')) throw new Error('config error');
      if (args.includes('get'))  return { stdout: JSON.stringify({ data: { present: true } }) };
      throw new Error('unexpected');
    };
    const checkCredentials = makeCheckCredentials(fakeExec);
    const result = await checkCredentials();
    assert.deepEqual(result, { ok: true, source: 'keychain' });
  });
});
