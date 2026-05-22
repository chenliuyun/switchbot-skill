# SwitchBot Codex Plugin

Codex plugin for SwitchBot smart-home control through the authoritative
`switchbot` CLI MCP server.

## What it installs

- A Codex skill at `skills/switchbot/SKILL.md`
- An MCP server definition that runs `switchbot mcp serve --tools all`
- An `onInstall` hook that checks the CLI and credentials
- A bootstrap binary: `switchbot-codex-install`

## Requirements

- Node.js `>=18`
- `@switchbot/openapi-cli >=3.7.1`
- Codex with plugin marketplace support

## Install

### Recommended

```bash
npm install -g @cly-org/switchbot-codex-plugin
switchbot-codex-install
```

`switchbot-codex-install` installs or upgrades the CLI if needed, registers the
plugin with Codex, adds it, then verifies credentials. If credentials are
missing it launches `switchbot auth login` directly, so successful setup does
not depend on Codex `plugin_hooks` being enabled.

### Direct Codex install

If you install the plugin from Codex itself, enable plugin hooks for automatic
first-run auth:

```toml
[features]
plugin_hooks = true
```

Without hooks, install still succeeds, but you must run `switchbot auth login`
manually before using the plugin.

## Verify

Run:

```bash
switchbot doctor
switchbot devices list
```

Then restart Codex and ask:

> List my SwitchBot devices and tell me which ones are currently on.
