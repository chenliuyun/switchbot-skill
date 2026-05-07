#!/usr/bin/env node
// plugin/openclaw/bin/start.js
// Bootstrap wrapper：依次完成环境检查，然后 exec switchbot mcp serve 接管进程。
// 只有凭证配置需要人工介入；其余步骤（CLI 安装、policy 脚手架、daemon 启动）全自动完成。
import { checkCli } from '../setup/check-cli.js';
import { checkCredentials } from '../setup/check-credentials.js';
import { checkDaemon } from '../setup/check-daemon.js';
import { execFileSync } from 'node:child_process';

function setupRequired(message) {
  // 以 MCP 协议可识别的格式输出，同时写 stderr 保证日志可读
  process.stderr.write(`[switchbot-channel] 需要配置：${message}\n`);
  // JSON Lines 格式，OpenClaw 读取 stdout 的第一行用于展示
  process.stdout.write(JSON.stringify({ setupRequired: true, message }) + '\n');
  process.exit(1);
}

// [1] CLI 是否已安装？未安装则自动安装
const cliCheck = await checkCli();
if (!cliCheck.ok) setupRequired(cliCheck.message);

// [2] 凭证是否已配置？（必须人工输入，不能自动化）
const credCheck = await checkCredentials();
if (!credCheck.ok) setupRequired(credCheck.message);

// [3] 若 policy 启用了 automation，确保 daemon 运行中
await checkDaemon();

// [4] exec switchbot mcp serve 替换当前进程，暴露完整 24 个 MCP 工具
try {
  execFileSync('switchbot', ['mcp', 'serve'], { stdio: 'inherit' });
} catch (err) {
  process.stderr.write(
    `[switchbot-channel] switchbot mcp serve 退出：${err instanceof Error ? err.message : String(err)}\n`,
  );
  process.exit(1);
}
