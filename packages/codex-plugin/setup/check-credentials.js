import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

async function tryDoctor(exec) {
  try {
    const { stdout } = await exec('switchbot', ['doctor', '--json'], { timeout: 10000 });
    const data = (JSON.parse(stdout)?.data ?? JSON.parse(stdout));
    return data?.credentials?.configured === true;
  } catch (err) {
    if (err?.code === 'ENOENT') throw err;
    return false;
  }
}

async function tryKeychainDescribe(exec) {
  try {
    await exec('switchbot', ['auth', 'keychain', 'describe', '--json'], { timeout: 8000 });
    return true;
  } catch {
    return false;
  }
}

export function makeCheckCredentials(exec) {
  return async function checkCredentials() {
    try {
      if (await tryDoctor(exec)) return { ok: true, source: 'doctor' };
    } catch {
      // CLI missing — fall through to keychain
    }
    if (await tryKeychainDescribe(exec)) return { ok: true, source: 'keychain' };
    return {
      ok: false,
      message: 'SwitchBot credentials not configured. Run: switchbot auth login',
    };
  };
}

const defaultExec = promisify(execFile);
export const checkCredentials = makeCheckCredentials(defaultExec);
