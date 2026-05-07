# Using the SwitchBot plugin with MCP clients

The plugin `@cly-org/switchbot-openclaw-skill` is a standard MCP stdio
server. Any host that speaks Model Context Protocol can launch it and
expose its 6 tools (`devices_list`, `devices_status`, `devices_describe`,
`devices_command`, `scenes_list`, `scenes_run`) to its agent.

This doc covers six mainstream hosts. For **OpenClaw**, use the simpler
one-liner in [`openclaw-plugin-install.md`](./openclaw-plugin-install.md)
instead — OpenClaw auto-detects the bundle manifest.

## Prerequisites

Install the plugin globally and authenticate the underlying CLI:

```bash
npm install -g @cly-org/switchbot-openclaw-skill
npm install -g @switchbot/openapi-cli@latest     # if not already installed
switchbot config set-token                        # paste token + secret
switchbot --version                               # must be >= 3.3.0
switchbot doctor                                  # all checks ✓
```

Then confirm the plugin's bin is on `PATH`:

```bash
# macOS / Linux
which switchbot-openclaw

# Windows
where switchbot-openclaw
```

`switchbot-openclaw` is the stdio MCP server — every config below spawns
that binary. If the above returns nothing, your global npm bin directory
isn't on `PATH`. Run `npm config get prefix` and add `<prefix>/bin`
(macOS / Linux) or `<prefix>` (Windows) to `PATH`.

## Claude Desktop

Config file:

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "switchbot": {
      "command": "switchbot-openclaw"
    }
  }
}
```

Fully quit Claude Desktop and reopen — reload-in-place doesn't pick up
new servers. On success, the MCP indicator (slider icon) appears in the
bottom-right of the conversation input. Linux is not officially
supported by Claude Desktop.

## Cursor

Config file:

- Project-scoped: `.cursor/mcp.json` in your workspace root
- User-global: `~/.cursor/mcp.json`

```json
{
  "mcpServers": {
    "switchbot": {
      "type": "stdio",
      "command": "switchbot-openclaw"
    }
  }
}
```

Project config takes precedence over global when both exist. Open
Cursor Settings → Features → Model Context Protocol to confirm the
server shows up; toggle it on if Cursor started before the config
existed.

## Zed

Config file (note the key is `context_servers`, not `mcpServers`):

- **macOS / Linux**: `~/.config/zed/settings.json`
- **Windows**: `%APPDATA%\Zed\settings.json`

```json
{
  "context_servers": {
    "switchbot": {
      "command": "switchbot-openclaw"
    }
  }
}
```

Restart Zed after adding a new server. The Agent Panel's settings view
shows a green dot when the server is active; a red dot means the spawn
failed — check `switchbot-openclaw` is on `PATH`.

## Windsurf

Config file (all OS):

`~/.codeium/windsurf/mcp_config.json`

```json
{
  "mcpServers": {
    "switchbot": {
      "command": "switchbot-openclaw"
    }
  }
}
```

Windsurf auto-detects changes to `mcp_config.json`. Open **Cascade →
MCPs** (icon in the top-right of the Cascade panel) or
**Windsurf Settings → Cascade → MCP Servers** to confirm the server is
registered and refresh if needed.

## Continue.dev

Place a YAML file under your workspace root at
`.continue/mcpServers/switchbot.yaml`:

```yaml
name: Switchbot OpenClaw
version: 0.0.1
schema: v1
mcpServers:
  - name: switchbot
    type: stdio
    command: switchbot-openclaw
```

The `mcpServers` key here is an **array** — unlike the other hosts,
which use an object keyed by server name. Reload Continue after adding
the file (VSCode: Ctrl/Cmd+Shift+P → "Continue: Reload"; JetBrains:
restart the IDE).

## Cline

Open Cline's MCP settings via the MCP Servers icon in the Cline panel
→ **Configure** tab → **Configure MCP Servers**. That opens
`cline_mcp_settings.json` in your editor:

```json
{
  "mcpServers": {
    "switchbot": {
      "command": "switchbot-openclaw",
      "disabled": false
    }
  }
}
```

Optional: add `"alwaysAllow": ["devices_list", "devices_status", "devices_describe", "scenes_list"]`
to auto-approve read-only tools so Cline doesn't prompt on every
read. Keep `devices_command` and `scenes_run` out of `alwaysAllow`
— those are mutations and should always be reviewed.

Cline picks up config changes automatically; no VSCode restart needed.

## Verification (applies to all)

In a fresh chat with the agent, say:

> List my SwitchBot devices and tell me which ones are currently on.

Expected behavior:

1. Agent discovers the `switchbot` MCP server and invokes the
   `devices_list` tool.
2. Reports the device list in plain language.
3. For "which are on", agent calls `devices_status` per on/off-capable
   device.
4. Read calls do **not** append to `~/.switchbot/audit.log`.

Now ask for a mutation (e.g. "turn off the kitchen light"):

1. Destructive or unfamiliar actions should trigger the host's approval
   flow.
2. A successful mutation **does** append a line to `~/.switchbot/audit.log`.

The same spot-checks apply as the OpenClaw path — see
[`openclaw-plugin-install.md`](./openclaw-plugin-install.md#spot-checks)
for the full list.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `spawn switchbot-openclaw ENOENT` in logs | Global npm bin not on the host's `PATH` | Run `npm config get prefix`, add that directory to `PATH`, restart the host. |
| Host shows no switchbot tools after edit | Config change needs a full restart | Claude Desktop / Zed / Cursor: fully quit and reopen. Windsurf / Cline: refresh from the MCP panel. |
| Agent calls a tool and gets `internal error … switchbot config not found` | CLI not authenticated | Run `switchbot config set-token`, verify with `switchbot doctor`. |
| Every call returns `quota exceeded` | Hit the SwitchBot cloud quota (10 000 / day) | See [`../troubleshooting.md`](../troubleshooting.md#quota-exceeded). |
| Cursor / Cline config edited but server not listed | Project config overridden by a broken global (or vice versa) | Check both `.cursor/mcp.json` and `~/.cursor/mcp.json`; for Cline, open settings through the UI to confirm which file is being read. |

For CLI-level issues (credentials, quota, network, policy validation)
see [`../troubleshooting.md`](../troubleshooting.md).

## Where else does the plugin work

Any MCP-compatible host. If your host isn't listed here but supports
stdio MCP servers, the pattern is always the same:

- outer key: `mcpServers` (or `context_servers` in Zed)
- server entry: `command: "switchbot-openclaw"`

Open an issue at
<https://github.com/chenliuyun/switchbot-skill/issues> if your host
needs a different shape and we'll add it.
