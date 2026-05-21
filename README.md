# SwitchBot Skill

Control your SwitchBot smart home (lights, locks, curtains, sensors, plugs, IR
appliances) from an AI agent — safely, with an explicit policy envelope and
an audit log of every action.

This repo ships:

- **An OpenClaw plugin** (`packages/openclaw-skill/`) published as
  [`@cly-org/switchbot-openclaw-skill`][npm] — 6 MCP tools, one-command
  install.
- **A Codex plugin wrapper** (`packages/codex-plugin/`) plus a repo-local
  marketplace at `.agents/plugins/marketplace.json`.
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
switchbot-openclaw setup         # guided CLI install + token config
```

OpenClaw auto-detects the bundle manifest, launches the stdio MCP server,
and exposes 6 tools: `devices_list`, `devices_status`, `devices_describe`,
`devices_command`, `scenes_list`, `scenes_run`. Read tools absorb the CLI's
known cache bug by forcing `--no-cache`; mutations write to
`~/.switchbot/audit.log`.

`switchbot-openclaw setup` verifies the underlying
`@switchbot/openapi-cli` is installed, at `>=3.3.0`, and authenticated —
with paste-friendly fix commands at every step. Already set up? The
plugin detects the "not installed" and "no credentials" cases at
runtime too and surfaces the same guidance as an MCP tool error.

Verification, uninstall, and plugin-specific troubleshooting:
[`docs/openclaw-plugin-install.md`](./docs/openclaw-plugin-install.md).

Using Claude Desktop, Cursor, Zed, Windsurf, Continue.dev, or Cline
instead of OpenClaw? The plugin is a standard MCP stdio server — see
[`docs/mcp-clients.md`](./docs/mcp-clients.md) for per-host config.

### B. Via Codex plugin marketplace

This repo ships a Codex plugin at `packages/codex-plugin/` with a repo-local
marketplace at `.agents/plugins/marketplace.json`. The plugin loads `SKILL.md`
guidance and starts the MCP server via
`npx -y @cly-org/switchbot-openclaw-skill@latest`.

#### Step 1 — Prerequisites

```bash
node --version          # >= 18
npm install -g @switchbot/openapi-cli@latest
switchbot --version     # should print >= 3.3.0
```

#### Step 2 — Enable plugin hooks (recommended)

Plugin hooks are **off by default** in the current Codex release. Without this
flag, the `onInstall` hook that triggers browser login will not run — you will
need to run `switchbot auth login` manually in Step 4.

Add to `~/.codex/config.toml`:

```toml
[features]
plugin_hooks = true
```

#### Step 3 — Clone this repo

```bash
git clone https://github.com/chenliuyun/switchbot-skill.git
cd switchbot-skill
```

If the repo is already present, update it first:

```bash
cd switchbot-skill
git pull origin main
```

#### Step 4 — Install the plugin

Point Codex at the repo-local marketplace and install:

```bash
codex plugins install --marketplace .agents/plugins/marketplace.json switchbot
```

If `plugin_hooks = true` was set in Step 2, Codex runs the `onInstall` hook
automatically — a browser window opens to the SwitchBot login page and stores
your credentials in the OS keychain. No token copy-paste needed.

If the hook did not run (feature flag off, headless environment, or manual
preference), authenticate now:

```bash
switchbot auth login           # opens browser
# or in a headless/SSH environment:
switchbot auth login --no-open # prints a URL you open on any machine
```

#### Step 5 — Verify

```bash
switchbot --version       # >= 3.3.0
switchbot doctor          # should end with "0 fail"
switchbot devices list    # returns your device list
```

If `doctor` reports failures, follow the printed fix commands or see
[`troubleshooting.md`](./troubleshooting.md).

#### File-based alternative (no Codex plugin support needed)

If you prefer not to use the plugin marketplace, the installer scripts write
`AGENTS.md` directly to `~/.codex/` or a project workspace:

```bash
./scripts/install.sh --agent codex-global --install-cli --init-policy
# project-local:
./scripts/install.sh --agent codex-project --workspace-path /path/to/workspace

# PowerShell:
pwsh ./scripts/install.ps1 -Agent codex-global -InstallCli -InitPolicy
```

### C. File-based install (agents without OpenClaw or Codex plugins)

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
├── packages/openclaw-skill/        # Published plugin @cly-org/switchbot-openclaw-skill
├── packages/codex-plugin/          # Codex plugin wrapper
├── .agents/plugins/            # Repo-local Codex marketplace
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
