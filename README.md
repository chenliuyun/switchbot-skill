# SwitchBot Skill

Control SwitchBot smart-home devices (lights, locks, curtains, sensors,
plugs, IR appliances) from an AI agent — safely, with a policy envelope
and an audit log of every action.

This repo ships:

- **A Codex plugin** (`packages/codex-plugin/`) — one-command install via
  the repo-local marketplace, self-contained MCP server, policy-gated safety layer.
- **An OpenClaw plugin** (`packages/openclaw-skill/`) published as
  [`@cly-org/switchbot-openclaw-skill`][npm] — same 6 MCP tools, one-command install.
- **A skill** (`SKILL.md`) that teaches any LLM-backed agent how to drive
  the [`@switchbot/openapi-cli`][cli] safely — command surface, safety
  tiers, bootstrap sequence, common pitfalls.
- **A starter policy** (`examples/policy.example.yaml`) for aliases,
  quiet hours, and confirmation rules.

[npm]: https://www.npmjs.com/package/@cly-org/switchbot-openclaw-skill
[cli]: https://www.npmjs.com/package/@switchbot/openapi-cli

---

## Prerequisites

```bash
node --version        # >= 18
npm install -g @switchbot/openapi-cli@latest
switchbot --version   # must be >= 3.3.0
switchbot auth login  # browser login — stores token in OS keychain
switchbot doctor      # all checks pass before you touch an agent
```

Get your token + secret from the SwitchBot mobile app:
**Profile → Preferences → tap App Version 10× → Developer Options**.

---

## Install

### A. Codex (recommended)

**Step 1 — Register the marketplace (one-time, per machine)**

```bash
codex plugin marketplace add /path/to/switchbot-skill
```

Replace `/path/to/switchbot-skill` with the path where you cloned this repo.
On Windows:

```powershell
codex plugin marketplace add D:\workspace\claudecode\switchbot-skill
```

**Step 2 — Install the plugin**

```bash
codex plugin add switchbot@switchbot-skill
```

The onInstall hook checks your CLI version and credentials automatically.
If credentials are missing it opens a browser login.

**Step 3 — Open any project in Codex**

The `switchbot` MCP server starts automatically. Try:

> List my SwitchBot devices and tell me which ones are currently on.

To upgrade after pulling new commits, remove and re-add the plugin:

```bash
codex plugin remove switchbot@switchbot-skill
codex plugin add switchbot@switchbot-skill
```

---

### B. OpenClaw / ClawHub

```bash
openclaw plugins install @cly-org/switchbot-openclaw-skill
switchbot-openclaw setup
```

OpenClaw auto-detects the bundle manifest, launches the stdio MCP server,
and exposes 6 tools. `switchbot-openclaw setup` verifies the CLI is
installed, at `>=3.3.0`, and authenticated.

Per-host config for Claude Desktop, Cursor, Zed, Windsurf, Continue.dev,
or Cline: [`docs/mcp-clients.md`](./docs/mcp-clients.md).

Verification, uninstall, and troubleshooting:
[`docs/openclaw-plugin-install.md`](./docs/openclaw-plugin-install.md).

---

### C. File-based install (agents without Codex or OpenClaw)

```bash
git clone https://github.com/chenliuyun/switchbot-skill.git
cd switchbot-skill

./scripts/install.sh --agent claude-global --install-cli --init-policy
# PowerShell: pwsh ./scripts/install.ps1 -Agent claude-global -InstallCli -InitPolicy
```

Supported `--agent` targets: `claude-global`, `claude-project`, `copilot`,
`cursor`, `cursor-legacy`, `gemini-global`, `gemini-project`,
`codex-global`, `codex-project`. Workspace-scoped agents also need
`--workspace-path <dir>`. Per-agent notes in [`docs/agents/`](./docs/agents/).

---

## MCP Tools

All three install paths expose the same 6 tools:

| Tool | Safety tier | Description |
|---|---|---|
| `devices_list` | read | List all devices |
| `devices_status` | read | Get device status |
| `devices_describe` | read | Get device type and capabilities |
| `devices_command` | mutation / destructive | Send a command to a device |
| `scenes_list` | read | List all scenes |
| `scenes_run` | mutation | Run a scene |

`devices_command` with a lock command (`lockOff`) is **destructive** —
the agent must pass `confirmed: true` after explicit user consent.
Mutation tools automatically append to `~/.switchbot/audit.log`.

---

## First Run (5 minutes)

### 1. Verify the CLI works without the agent

```bash
switchbot devices list
```

A table of your devices confirms the CLI is end-to-end working before
you involve the agent.

### 2. Set up aliases in policy.yaml (optional but recommended)

`--init-policy` (path C) creates `~/.config/openclaw/switchbot/policy.yaml`.
Set the `aliases:` block so the agent understands your room names:

```yaml
aliases:
  "living room light": "01-202407090924-26354212"
  "bedroom AC":        "02-202502111234-85411230"
```

Device IDs come from `switchbot devices list`. Then validate:

```bash
switchbot policy validate
```

### 3. Ask your agent

> List my SwitchBot devices and tell me which ones are currently on.

If the agent asks for your token or invents device IDs, see
[`troubleshooting.md`](./troubleshooting.md#agent-ignores-the-skill).

---

## Safety Model

| Tier | Examples | Default behavior |
|---|---|---|
| `read` | list, status queries | Run freely |
| `mutation` | turn on/off, set brightness | Run; append to `audit.log` |
| `destructive` | lock commands (`lockOff`) | Refuse without `confirmed: true` |

The Codex plugin enforces these tiers in code (not just prompt instructions)
via a two-layer pipeline: Layer 1 checks `policy.yaml` (quiet hours,
allowed devices, blocked commands); Layer 2 gates destructive commands behind
explicit confirmation. Full rules in [SKILL.md](./SKILL.md).

---

## Upgrade & Uninstall

**Codex:**

```bash
codex plugin remove switchbot@switchbot-skill
codex plugin add switchbot@switchbot-skill
```

**File-based:**

```bash
./scripts/upgrade.sh --agent claude-global     # pull + refresh
./scripts/uninstall.sh --agent claude-global   # remove agent file
# add --remove-cli / --remove-policy / --remove-credentials to wipe more
```

PowerShell: `./scripts/upgrade.ps1` / `./scripts/uninstall.ps1` with `-Agent <name>`.

---

## Layout

```
.
├── README.md
├── SKILL.md                        # Agent-facing: safety rules and bootstrap
├── manifest.json                   # Skill manifest + compatibility metadata
├── packages/
│   ├── codex-plugin/               # Codex plugin v0.8.0 (self-contained MCP)
│   │   ├── bin/server.js           # MCP server entry point
│   │   ├── src/                    # server, tools, policy, executor
│   │   ├── setup/                  # CLI + credential checks
│   │   ├── .mcp.json               # Patched at install time with absolute path
│   │   └── .codex-plugin/          # plugin.json + hooks.json
│   └── openclaw-skill/             # Published @cly-org/switchbot-openclaw-skill
├── .agents/plugins/marketplace.json  # Repo-local Codex plugin marketplace
├── examples/
│   ├── policy.example.yaml
│   └── policy.schema.json
├── scripts/                        # install / upgrade / uninstall (.sh + .ps1)
├── docs/
│   ├── openclaw-plugin-install.md
│   └── agents/                     # Per-agent install recipes
└── troubleshooting.md
```

---

## Versioning & Support

Follows [SemVer][semver]. `manifest.json → authority.cli` pins the minimum
CLI version; the agent refuses to run against older CLIs rather than guess
at missing features.

Issues: <https://github.com/chenliuyun/switchbot-skill/issues>

[semver]: https://semver.org/

---

## License

MIT — see [LICENSE](./LICENSE).
