# SwitchBot Skill — 中文安装指南

一份 AI Skill，让 Claude Code、Cursor、Gemini、Codex 等 AI 助手通过自然语言控制你的 SwitchBot 智能家居设备。

---

## 快速开始（约 5 分钟）

### 第一步：一键安装

**macOS / Linux / WSL：**

```bash
curl -fsSL https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/bootstrap.sh | bash
```

**Windows（PowerShell 7+）：**

```powershell
irm https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/bootstrap.ps1 | iex
```

脚本会自动完成：
- 安装 SwitchBot CLI（`@switchbot/openapi-cli`）
- 探测你已安装的 AI 工具（Claude Code / Cursor / Gemini / Codex）并自动配置
- 引导你完成 Token 配置
- 验证连接是否正常
- 生成 `policy.yaml` 策略文件

> 国内网络问题？见下方"故障排除"。

---

### 第二步：获取 SwitchBot Token

这是唯一需要你手动操作的步骤，脚本会在安装时提示你：

```
──────────────────────────────────────────────
  获取 SwitchBot Token（仅需操作一次）
──────────────────────────────────────────────
 1. 打开手机上的 SwitchBot App
 2. 点击底部「我」→「设置」→「偏好设置」
 3. 连续快速点击「App 版本」10 次
 4. 进入「开发者选项」→ 开启「云服务」
 5. 复制显示的 Token 和 Secret
──────────────────────────────────────────────
```

> 注意：千万不要把 Token 粘贴到 AI 对话框里，只能在终端提示符处输入。

---

### 第三步：验证安装

重启 AI 工具（Claude Code / Cursor 等），然后输入：

> 列出我的 SwitchBot 设备，告诉我哪些正在运行

AI 应该能正确列出你的设备。

---

## 控制设备示例

安装成功后，你可以直接用中文或英文告诉 AI：

```
打开客厅的灯
把卧室空调设为 26 度制冷
关闭所有插座
今晚 10 点以后不要动任何灯
当走廊运动传感器检测到有人时，自动开走廊灯
```

---

## 策略配置（policy.yaml）

策略文件位于 `~/.config/openclaw/switchbot/policy.yaml`，控制 AI 的权限边界：

```yaml
version: "0.2"

aliases:
  "客厅灯": "01-202407090924-26354212"   # 给设备起中文别名
  "卧室空调": "02-202502111234-85411230"

confirmations:
  always_confirm: ["lock", "unlock"]     # 这些命令永远需要二次确认

quiet_hours:
  start: "22:00"                         # 静默时段：禁止自动操作灯/插座
  end:   "07:00"

automation:
  enabled: false                         # true 后才启用规则引擎
  rules: []
```

首次安装时，脚本会引导你回答 3 个问题自动生成合理的策略。

---

## 升级

```bash
bash scripts/upgrade.sh
```

或者 Windows：

```powershell
pwsh scripts/upgrade.ps1
```

---

## 卸载

```bash
bash scripts/uninstall.sh
```

---

## 故障排除

### GitHub 访问超时

大陆用户如果 curl 超时，可以通过 ghproxy 镜像安装：

```bash
curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/bootstrap.sh | bash
```

### `switchbot doctor` 报错

```bash
switchbot doctor
```

查看输出中的 `fail` 项，常见原因：

| 错误 | 解决方法 |
|---|---|
| `credentials missing` | 重新运行 `switchbot config set-token` |
| `node version too old` | 升级 Node.js 到 v18+ |
| `policy.yaml invalid` | 运行 `switchbot policy validate` 查看具体错误 |
| `network error` | 检查网络，或等待 SwitchBot 云服务恢复 |

### Token 在哪里

如果找不到 Developer Options：

1. 确保 SwitchBot App 版本 ≥ 7.x
2. 必须在 App 内点击「App 版本」，不是系统设置里的版本号
3. 必须连续快速点击，中间停顿会重置计数

---

## 相关链接

- [英文 README](./README.md)
- [Skill 内容（SKILL.md）](./SKILL.md) — AI 行为规范
- [故障排除（英文）](./troubleshooting.md)
- [policy.yaml 示例](./examples/policy.example.yaml)
