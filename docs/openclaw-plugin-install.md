# OpenClaw Plugin — Install & Verify

Canonical install guide for the SwitchBot plugin when used with
[OpenClaw](https://openclaw.ai). For the lower-level MCP-only path (any
Claude-compatible runtime) see `plugin/openclaw/README.md`.

## Prerequisites

- OpenClaw installed and on `PATH` (`openclaw --version`)
- Node.js **≥ 18**
- `@switchbot/openapi-cli` **≥ 3.3.0** installed globally and authenticated
  (`switchbot config set-token`). The plugin will not work below 3.3.0 — see
  `troubleshooting.md` for why.

Verify all three:

```bash
openclaw --version          # openclaw gateway available
node --version              # v18.x or newer
switchbot --version         # 3.3.0 or newer
switchbot doctor            # credentials + connectivity healthy
```

If any of these fail, fix that first — the plugin cannot paper over a broken
CLI install.

## Install path A — via ClawHub (recommended once published)

```bash
openclaw plugins install @cly-org/switchbot-openclaw-skill
switchbot-openclaw setup
```

OpenClaw resolves the name against ClawHub first, then npm. The plugin
tree ships a Claude-bundle manifest (`.claude-plugin/plugin.json`) + an
MCP stdio declaration (`.mcp.json`), so OpenClaw auto-detects the MCP
server and exposes its 6 tools to the embedded Pi agent.

`switchbot-openclaw setup` is an interactive bootstrap: it verifies
the underlying `@switchbot/openapi-cli` is installed, satisfies the
`>=3.3.0` floor, and is authenticated (via `switchbot doctor`). At each
failing step it prints the exact command to run next. Safe to re-run
at any time — it's idempotent and read-only when everything is already
working.

## Install path B — direct from GitHub (pre-publish or pinned version)

```bash
openclaw plugins install github:chenliuyun/switchbot-skill#v0.6.0
```

Useful when you want a specific tag, or before the npm package has been
published. Works the same way OpenClaw-side: bundle detection + MCP
merge.

## Install path C — local clone (plugin development)

```bash
git clone https://github.com/chenliuyun/switchbot-skill.git
cd switchbot-skill/plugin/openclaw
npm install
openclaw plugins install-local .
```

`install-local` registers the current directory as a plugin without
publishing. Use this when iterating on the MCP handlers in
`plugin/openclaw/index.js`.

## Verify

After install, confirm the plugin is visible and the tools land in your
agent:

```bash
openclaw plugins list            # expect: @cly-org/switchbot-openclaw-skill
openclaw plugins inspect @cly-org/switchbot-openclaw-skill
```

Then open an agent session and ask: "list my switchbot devices". The
agent should call the `switchbot__devices_list` tool (OpenClaw namespaces
bundle MCP tools as `<server>__<tool>`), which invokes the local
`@switchbot/openapi-cli` with `--no-cache --json` and returns the device
array.

### Spot-checks

- **Cache bypass on reads**: run `openclaw plugins inspect` and verify
  the MCP tool payload includes `--no-cache`. The plugin forces this on
  `devices_list`, `devices_status`, `devices_describe`, and `scenes_list`
  to absorb the CLI's documented cache bug.
- **No cache bypass on mutations**: `devices_command` and `scenes_run`
  must NOT include `--no-cache` — that's the write path and doesn't hit
  the cache.
- **Audit log grows on mutations only**: `~/.switchbot/audit.log` gets
  an entry every time you run a mutation tool. Read tools do not append.

## Uninstall

```bash
openclaw plugins uninstall @cly-org/switchbot-openclaw-skill
```

Policy file (`~/.config/openclaw/switchbot/policy.yaml`) and audit log
(`~/.switchbot/audit.log`) survive the uninstall on purpose — they
contain user configuration and history. Remove manually if you want a
full wipe:

```bash
rm -rf ~/.config/openclaw/switchbot
rm -f  ~/.switchbot/audit.log
```

## Troubleshooting

First stop: `troubleshooting.md` in the repo root. Common plugin-specific
failure modes:

- **`openclaw plugins list` doesn't show the plugin** — run
  `openclaw plugins inspect <name>` for a validation error. Usually a
  missing `.claude-plugin/plugin.json` (local clone tree without
  `npm install`) or a stale ClawHub cache (`openclaw plugins refresh`).
- **Agent calls a tool but gets `internal: … spawn ENOENT`** — the
  `switchbot` binary isn't on the PATH the agent sees. Install globally
  with `npm install -g @switchbot/openapi-cli@latest` and restart the
  agent.
- **Agent gets `quota` errors on every call** — you hit the 10 000
  calls/day cloud limit. See `troubleshooting.md` → "Quota exceeded".

## Reporting an issue

Open at <https://github.com/chenliuyun/switchbot-skill/issues> and include:

- `openclaw --version`, `node --version`, `switchbot --version`
- `openclaw plugins inspect @cly-org/switchbot-openclaw-skill`
- The exact agent prompt + reply
- Relevant lines from `~/.switchbot/audit.log`

Never paste your SwitchBot token or secret.
