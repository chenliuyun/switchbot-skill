import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execFile);

async function tryDoctor() {
  try {
    const { stdout } = await exec('switchbot', ['doctor', '--json'], { timeout: 10000 });
    const parsed = JSON.parse(stdout);
    const data = parsed?.data ?? parsed;
    return data?.credentials?.configured === true;
  } catch (err) {
    if (err?.code === 'ENOENT') throw err;
    return false;
  }
}

async function tryKeychainDescribe() {
  try {
    await exec('switchbot', ['auth', 'keychain', 'describe', '--json'], { timeout: 8000 });
    return true;
  } catch {
    return false;
  }
}

export async function checkCredentials() {
  try {
    if (await tryDoctor()) return { ok: true };
  } catch {
    // CLI missing
  }
  if (await tryKeychainDescribe()) return { ok: true };
  return {
    ok: false,
    message:
      'SwitchBot 账号尚未配置。请在终端运行以下命令完成配置：\n\n  switchbot auth login\n\n' +
      '（token 和 secret 可在 SwitchBot App → 个人中心 → 开发者选项 中获取）',
  };
}
