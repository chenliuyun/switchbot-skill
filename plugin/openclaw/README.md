# @switchbot/openclaw-skill

SwitchBot smart-home skill for [OpenClaw](https://openclaw.dev) — exposes 6 MCP tools so AI agents can control SwitchBot devices, run scenes, and send commands.

## Prerequisites

- Node.js 18+
- [`@switchbot/openapi-cli`](https://www.npmjs.com/package/@switchbot/openapi-cli) ≥ 3.3.0 with credentials configured (`switchbot config set-token`)

## Installation

```bash
# Via OpenClaw plugin manager (recommended)
openclaw plugin install @switchbot/openclaw-skill

# Or global npm
npm install -g @switchbot/openclaw-skill
```

## MCP Tools

| Tool | Description |
|---|---|
| `devices_list` | List all devices in the account |
| `devices_status` | Get current status of a device |
| `devices_describe` | List supported commands for a device type |
| `devices_command` | Send a command (turnOn, turnOff, setBrightness, …) |
| `scenes_list` | List all saved scenes |
| `scenes_run` | Execute a scene by ID |

All mutation commands (`devices_command`, `scenes_run`) automatically append to `~/.switchbot/audit.log`.

## Usage

The server communicates over **stdio** (MCP protocol). OpenClaw detects
this tree as a Claude-style bundle and launches the MCP server via the
declarations in:

- `.claude-plugin/plugin.json` — bundle identity
- `.mcp.json` — stdio launcher (`node ${pluginDir}/bin/start.js`)

To start manually (for debugging):

```bash
switchbot-openclaw
```

## Policy editor

A local browser-based editor for `~/.config/openclaw/switchbot/policy.yaml`:

```bash
switchbot-policy-edit
# Opens http://localhost:18799
```

## Configuration

Edit `~/.config/openclaw/switchbot/policy.yaml` to set device aliases, quiet hours, and confirmation rules. See [policy.yaml docs](https://github.com/chenliuyun/switchbot-skill#policy-configuration).

## License

MIT
