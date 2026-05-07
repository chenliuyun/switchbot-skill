// setup/check-credentials.js — 检查 SwitchBot 凭证是否已配置
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execFile);

export async function checkCredentials() {
  let result;
  try {
    const { stdout } = await exec('switchbot', ['config', 'show', '--json'], { timeout: 8000 });
    result = JSON.parse(stdout);
  } catch {
    result = null;
  }

  const data = result?.data ?? result;
  const hasToken = typeof data?.token === 'string' && data.token.length > 0;
  const hasSecret = typeof data?.secret === 'string' && data.secret.length > 0;

  if (hasToken && hasSecret) return { ok: true };

  return {
    ok: false,
    message:
      'SwitchBot 账号尚未配置。请在终端运行以下命令完成配置，然后重新打开 SwitchBot channel：\n\n  switchbot config set-token\n\n（token 和 secret 可在 SwitchBot App → 个人中心 → 开发者选项 中获取）',
  };
}
