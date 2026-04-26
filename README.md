# SwitchBot Skill

Control your SwitchBot smart home (lights, locks, curtains, sensors, plugs, IR
appliances) from an AI agent — safely, with an explicit policy envelope and
an audit log of every action.

This repo ships:

- **An OpenClaw plugin** (`plugin/openclaw/`) published as
  [`@cly-org/switchbot-openclaw-skill`][npm] — 6 MCP tools, one-command
  install.
- **A skill** (`SKILL.md`) that teaches any LLM-backed agent how to drive
  the [`@switchbot/openapi-cli`][cli] safely — command surface, safety
  tiers, bootstrap sequence, common pitfalls.
- **A starter policy** (`examples/policy.example.yaml`) + JSON Schema for
  aliases, quiet hours, confirmation rules, and rule-engine automations.

The skill **does not duplicate CLI docs**. The CLI is authoritative; the
skill teaches the agent how to read it.

[npm]: https://www.npmjs.com/package/@cly-org/switchbot-openclaw-skill
[cli]: https://www.npmjs.com/package/@switchbot/openapi-cli

---

## Install

### A. Via OpenClaw / ClawHub (recommended)

```bash
openclaw plugins install @cly-org/switchbot-openclaw-skill
switchbot config set-token       # paste token + secret from the SwitchBot app
```

OpenClaw auto-detects the bundle manifest, launches the stdio MCP server,
and exposes 6 tools: `devices_list`, `devices_status`, `devices_describe`,
`devices_command`, `scenes_list`, `scenes_run`. Read tools absorb the CLI's
known cache bug by forcing `--no-cache`; mutations write to
`~/.switchbot/audit.log`.

Verification, uninstall, and plugin-specific troubleshooting:
[`docs/openclaw-plugin-install.md`](./docs/openclaw-plugin-install.md).

Using Claude Desktop, Cursor, Zed, Windsurf, Continue.dev, or Cline
instead of OpenClaw? The plugin is a standard MCP stdio server — see
[`docs/mcp-clients.md`](./docs/mcp-clients.md) for per-host config.

### B. File-based install (agents without OpenClaw)

```bash
git clone https://github.com/chenliuyun/switchbot-skill.git
cd switchbot-skill

./scripts/install.sh --agent claude-global --install-cli --init-policy
# PowerShell: pwsh ./scripts/install.ps1 -Agent claude-global -InstallCli -InitPolicy
```

Supported `--agent` targets: `claude-global`, `claude-project`, `copilot`,
`cursor`, `cursor-legacy`, `gemini-global`, `gemini-project`,
`codex-global`, `codex-project`. Workspace-scoped agents also need
`--workspace-path <dir>`. Per-agent notes in
[`docs/agents/`](./docs/agents/).

---

## Prerequisites (both paths)

```bash
node --version              # >= 18
switchbot --version         # >= 3.3.0   (older versions silently hit documented footguns)
switchbot doctor            # all checks ✓; summary "N ok, 0 warn, 0 fail"
```

Get your token + secret from the SwitchBot mobile app:
**Profile → Preferences → tap App Version 10× → Developer Options**.
Treat them like a password — `switchbot config set-token` writes them
to `~/.switchbot/config.json` with `0600` permissions. Multiple accounts?
Use `--profile <name>`.

If `switchbot --version` is below 3.3.0, run
`npm install -g @switchbot/openapi-cli@latest`. The skill refuses to run
against older CLIs — see [`troubleshooting.md`](./troubleshooting.md).

---

## First run (15 minutes)

### 1. Verify the CLI works without the agent

```bash
switchbot devices list
```

A table of your devices confirms the CLI is end-to-end working **before**
you involve the agent.

### 2. Edit `policy.yaml`

Path A and `--init-policy` already wrote
`~/.config/openclaw/switchbot/policy.yaml` (schema v0.2). Set the
`aliases:` block so the agent understands your room names:

```yaml
aliases:
  "living room light": "01-202407090924-26354212"
  "bedroom AC":        "02-202502111234-85411230"
```

Device IDs come from `switchbot devices list --format=tsv`. Then:

```bash
switchbot policy validate
```

If validation fails, the CLI points at the exact line and suggests a fix
(lowercase deviceId, missing `end:` on a quiet-hours block, a
`destructive` action inside `never_confirm`, etc.).

### 3. Ask your agent

> List my SwitchBot devices and tell me which ones are currently on.

The agent should run `switchbot agent-bootstrap --compact` to learn your
setup, enumerate devices via `devices list --json` + `devices status`,
and report in plain language. If it asks for your token or invents
device IDs, see
[`troubleshooting.md`](./troubleshooting.md#agent-ignores-the-skill).

---

## Safety model

Every action is classified into one of five tiers, taken from
`switchbot capabilities --json`:

| Tier | Examples | Default |
|---|---|---|
| `read` | device list, status queries | Run freely. |
| `ir-fire-forget` | TV power, AC mode (IR, no state feedback) | Run; flag that verification isn't possible. |
| `mutation` | turn on/off, set brightness | Run; append to `audit.log`. |
| `destructive` | unlock, delete scene | **Refuse** without explicit user confirmation. |
| `maintenance` | factory-reset etc. (unused today) | Always confirm. |

Override per-action or per-device in the `confirmations:` section of
`policy.yaml`. Full rules in [SKILL.md](./SKILL.md).

---

## Real-time events (optional)

Stream SwitchBot shadow updates (motion, contact, buttons) so the agent
can react as they happen:

```bash
# standalone tail
switchbot events mqtt-tail --json

# forward into an OpenClaw gateway
switchbot events mqtt-tail \
  --sink openclaw \
  --openclaw-url http://localhost:18789 \
  --openclaw-token "$OPENCLAW_TOKEN"
```

Real-hardware MQTT → OpenClaw walkthrough:
[`docs/openclaw-status-sync-e2e.md`](./docs/openclaw-status-sync-e2e.md).

---

## Roadmap

**You are at L3** — fully autonomous inside the policy envelope. The
skill drafts rules from intent via `rules suggest`, injects them with
`policy add-rule` (showing a one-time diff for approval), then the rules
engine fires them indefinitely. L1 (manual, one command per mutation)
and L2 (propose-then-approve plans) remain available. All three require
CLI ≥ 3.3.0.

The CLI's own phase numbering is separate — see the [authoritative
roadmap][cli-roadmap] in the CLI repo.

[cli-roadmap]: https://github.com/OpenWonderLabs/switchbot-openapi-cli/blob/main/docs/design/roadmap.md

---

## Upgrade & uninstall

```bash
# upgrade: pulls the latest repo, refreshes the agent install, updates the CLI
./scripts/upgrade.sh --agent claude-global

# uninstall: removes the agent file; add --remove-cli / --remove-policy /
# --remove-credentials to also wipe the CLI, policy, or secrets.
./scripts/uninstall.sh --agent claude-global
```

PowerShell equivalents: `./scripts/upgrade.ps1` / `./scripts/uninstall.ps1`
with `-Agent <name>`. Workspace-scoped targets also need
`--workspace-path <dir>`.

Agent-driven upgrade (let the agent update itself):

```text
Retrieve and follow the instructions at:
https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/UPGRADE_FOR_AGENTS.md

Upgrade my SwitchBot skill for <agent-target> and update the CLI too.
```

---

## What the skill does NOT do

| Out of scope | Notes |
|---|---|
| Template variables in rule `then[]` args (`{{ device.status }}`) | Schema v0.3 feature; not yet in the rules engine. |
| `policy remove-rule` / `policy edit-rule` | Users edit `policy.yaml` directly. |
| LLM-backed trigger/schedule inference | `rules suggest` is pure heuristics, no AI inside. |

---

## Layout

```
.
├── README.md                   # You are here
├── SKILL.md                    # Agent-facing: authority, safety, bootstrap
├── manifest.json               # Skill manifest + compatibility metadata
├── plugin/openclaw/            # Published plugin @cly-org/switchbot-openclaw-skill
├── examples/
│   ├── policy.example.yaml     # Starting point
│   └── policy.schema.json      # JSON Schema v0.2 for editor autocomplete
├── scripts/                    # install / upgrade / uninstall (.sh + .ps1)
├── docs/
│   ├── openclaw-plugin-install.md
│   ├── openclaw-status-sync-e2e.md
│   └── agents/                 # Per-agent install recipes
├── troubleshooting.md
├── LICENSE                     # MIT
└── CHANGELOG.md
```

---

## Versioning & support

Follows [SemVer][semver]. `manifest.json → authority.cli` pins the
minimum CLI version; the agent refuses to run against older CLIs rather
than guess at missing features. Breaking `policy.yaml` changes bump the
minor version with a migration note in `CHANGELOG.md`.

Issues: <https://github.com/chenliuyun/switchbot-skill/issues>.
Please don't open CLI-docs PRs to paper over skill quirks — the CLI is
authoritative; the skill adapts.

[semver]: https://semver.org/

---

## License

MIT — see [LICENSE](./LICENSE).
