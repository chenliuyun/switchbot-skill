// setup/check-credentials.js — 检查 SwitchBot 凭证是否已配置
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execFile);

async function tryConfigShow() {
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

async function tryKeychainGet() {
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

export async function checkCredentials() {
  if (await tryConfigShow()) return { ok: true };
  if (await tryKeychainGet()) return { ok: true };

  return {
    ok: false,
    message:
      'SwitchBot 账号尚未配置。请在终端运行以下命令完成配置，然后重新打开 SwitchBot channel：\n\n  switchbot auth login\n\n或手动配置：switchbot config set-token\n\n（token 和 secret 可在 SwitchBot App → 个人中心 → 开发者选项 中获取）',
  };
}
