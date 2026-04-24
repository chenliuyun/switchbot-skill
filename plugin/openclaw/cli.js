// plugin/openclaw/cli.js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execFile);

export async function runCli(args) {
  try {
    const { stdout } = await exec('switchbot', args, { timeout: 15000 });
    return JSON.parse(stdout);
  } catch (err) {
    const msg = err.stdout ?? err.message ?? String(err);
    try { return JSON.parse(msg); } catch { return { error: { kind: 'internal', message: msg } }; }
  }
}
