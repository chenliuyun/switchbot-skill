// setup/check-cli.js — 检查 switchbot CLI 是否已安装；未安装时自动执行 npm install -g
import { execFile, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execFile);

async function cliExists() {
  try {
    await exec('switchbot', ['--version'], { timeout: 8000 });
    return true;
  } catch {
    return false;
  }
}

function npmExists() {
  try {
    execFileSync('npm', ['--version'], { timeout: 8000, stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

export async function checkCli() {
  if (await cliExists()) return { ok: true };

  if (!npmExists()) {
    return {
      ok: false,
      message: 'Node.js / npm 未安装。请先安装 Node.js（https://nodejs.org），然后重新打开 SwitchBot channel。',
    };
  }

  process.stderr.write('[switchbot-channel] CLI 未找到，正在自动安装 @switchbot/openapi-cli…\n');
  try {
    execFileSync('npm', ['install', '-g', '@switchbot/openapi-cli'], {
      stdio: 'inherit',
      timeout: 120_000,
    });
  } catch (err) {
    return {
      ok: false,
      message: `CLI 安装失败：${err instanceof Error ? err.message : String(err)}。请手动运行：npm install -g @switchbot/openapi-cli`,
    };
  }

  if (!(await cliExists())) {
    return {
      ok: false,
      message: 'CLI 安装完成但 switchbot 命令仍不可用，可能需要重新打开终端或重启 OpenClaw。',
    };
  }

  process.stderr.write('[switchbot-channel] CLI 安装完成。\n');
  return { ok: true };
}
