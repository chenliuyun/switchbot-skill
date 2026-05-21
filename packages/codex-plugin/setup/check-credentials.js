import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

async function tryConfigShow(exec) {
  try {
    const { stdout } = await exec('switchbot', ['config', 'show', '--json'], { timeout: 8000 });
    const result = JSON.parse(stdout);
    const data = result?.data ?? result;
    return typeof data?.token === 'string' && data.token.length > 0
        && typeof data?.secret === 'string' && data.secret.length > 0;
  } catch {
    return false;
  }
}

async function tryKeychainGet(exec) {
  try {
    const { stdout } = await exec(
      'switchbot', ['auth', 'keychain', 'get', '--json'], { timeout: 8000 }
    );
    const result = JSON.parse(stdout);
    const data = result?.data ?? result;
    return data?.present === true;
  } catch {
    return false;
  }
}

export function makeCheckCredentials(exec) {
  return async function checkCredentials() {
    if (await tryConfigShow(exec)) return { ok: true, source: 'config' };
    if (await tryKeychainGet(exec))  return { ok: true, source: 'keychain' };
    return {
      ok: false,
      message: 'SwitchBot credentials not configured. Run: switchbot auth login',
    };
  };
}

const defaultExec = promisify(execFile);
export const checkCredentials = makeCheckCredentials(defaultExec);
