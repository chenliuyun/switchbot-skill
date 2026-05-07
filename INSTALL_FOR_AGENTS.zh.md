# SwitchBot Skill — AI Agent 安装指南（中文版）

本文档面向 AI Agent 操作者（如 Claude Code、Cursor 等），说明如何代表用户完成 SwitchBot skill 的安装。

**原则**：不要在对话中收集用户的 Token 或 Secret。凭证由用户在终端交互式输入，不经过 AI 对话。

---

## 第一步：运行 Bootstrap（无需 git）

bootstrap 脚本会自动探测已安装的 agent 并完成配置，无需询问用户选择哪种 agent。

**macOS / Linux / WSL：**

```bash
curl -fsSL https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/bootstrap.sh | bash
```

**Windows（PowerShell 7+）：**

```powershell
irm https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/bootstrap.ps1 | iex
```

自动探测规则：

| 探测到的目录 | 安装目标 |
|---|---|
| `~/.claude/` | `claude-global` |
| `~/.gemini/` | `gemini-global` |
| `~/.codex/` | `codex-global` |
| `~/.cursor/` | 提示需要 workspace-path，跳过 |
| `~/.config/github-copilot/` | 提示需要 workspace-path，跳过 |
| 均未检测到 | 默认安装 `claude-global` |

常用可选参数：

```bash
--yes             # 非交互模式（跳过所有问答）
--dry-run         # 只打印将要执行的操作，不实际写入
--skip-token      # 已配置 Token 时跳过凭证步骤
--agent <target>  # 强制指定安装目标
```

---

## 第二步：如果 Bootstrap 不可用（git clone 备选方案）

```bash
git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
cd ~/switchbot-skill
```

然后继续执行第三步。

---

## 第三步：手动安装（Bootstrap 成功则跳过）

如果需要手动选择 agent 目标，运行对应脚本：

```bash
# macOS / Linux
./scripts/install.sh --agent claude-global --install-cli --init-policy

# Windows
pwsh ./scripts/install.ps1 -Agent claude-global -InstallCli -InitPolicy
```

支持的 agent 目标：`claude-global`、`claude-project`、`copilot`、`cursor`、`cursor-legacy`、`gemini-global`、`gemini-project`、`codex-global`、`codex-project`、`openclaw-staging`

---

## 第四步：配置凭证（Bootstrap 已自动引导，可跳过）

让用户在终端自行运行：

```bash
switchbot config set-token
```

如果用户不知道如何获取 Token：

```
1. 打开 SwitchBot App（手机）
2. 点击「我」→「设置」→「偏好设置」
3. 连续快速点击「App 版本」10 次
4. 进入「开发者选项」→ 开启「云服务」
5. 复制 Token 和 Secret
```

---

## 第五步：验证

```bash
switchbot --version
switchbot doctor
switchbot devices list
```

验证标准：
- `switchbot doctor` 输出以 `0 fail` 结束
- `switchbot devices list` 返回用户的设备列表

---

## 第六步：验证 Agent 安装

重启目标 AI 工具（Claude Code、Cursor 等），然后测试：

> 列出我所有的 SwitchBot 设备，告诉我哪些正在运行

期望行为：
1. Agent 加载已安装的 skill 或指令文件
2. Agent 通过 MCP Channel（`switchbot mcp serve`）获取工具列表
3. Agent 读取 `~/.config/openclaw/switchbot/policy.yaml`
4. Agent 使用 `--json` 解析输出
5. Agent 不编造 deviceId，不索取凭证

---

## 第七步：可选 — 注册规则引擎守护进程

如果用户需要自动化规则（"当运动传感器检测到有人时开灯"）持久运行：

```bash
bash scripts/setup-daemon.sh
```

Windows：

```powershell
pwsh scripts/setup-daemon.ps1
```

这将在 macOS 上注册 LaunchAgent、Linux 上注册 systemd 用户服务、Windows 上创建计划任务。

---

## 升级

```bash
bash scripts/upgrade.sh --agent claude-global
```

---

## 国内网络问题

如果 GitHub 访问超时，使用 ghproxy 镜像：

```bash
curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/bootstrap.sh | bash
```
