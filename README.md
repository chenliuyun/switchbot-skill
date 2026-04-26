# SwitchBot Skill

Control your SwitchBot smart home (lights, locks, curtains, sensors, plugs, IR
appliances) from an AI agent. This repository ships the agent-facing skill and
the supporting files that make it usable in practice:

1. A **skill** (`SKILL.md`) that teaches an AI agent how to use the
  `switchbot` CLI safely — command surface, safety tiers, bootstrap
  sequence, common pitfalls.
2. A **starter policy** (`examples/policy.example.yaml`) that lets you declare
  your preferences (device aliases, quiet hours, which actions always need
  confirmation) so the agent doesn't have to guess.
3. A **policy schema** (`examples/policy.schema.json`) for validation and
  editor autocomplete.

The skill drives the [`@switchbot/openapi-cli`][cli] — the authoritative
source for what commands exist and how they behave. This repo never duplicates
CLI docs; it tells the agent how to read them.

[cli]: https://www.npmjs.com/package/@switchbot/openapi-cli

Paste this into your agent for install:

```text
Retrieve and follow the instructions at:
https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/INSTALL_FOR_AGENTS.md
```

Paste this into your agent for upgrade:

```text
Retrieve and follow the instructions at:
https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/UPGRADE_FOR_AGENTS.md
```

---

## What you get

After the Quickstart below:

- Your agent can list devices, check status, run scenes, execute safe
  commands, and stream real-time events.
- Destructive actions (locks, irreversible changes) require an explicit
  confirmation.
- Every automated action lands in `audit.log` so you can review what the
  agent did and why.
- Your private preferences live in `policy.yaml`, not in the skill — the
  skill stays generic and updatable.

---

## Roadmap (so you know where you stand)

This skill uses **autonomy level** as its delivery dimension —
independent of the CLI's Phase 1-4 numbering. The CLI phase table is
the authoritative source for what the underlying binary can do; see
[`docs/design/roadmap.md`][cli-roadmap] in the CLI repo.

| Level | Status | Meaning | CLI version it needs |
|---|---|---|---|
| **L1 · Manual orchestration** | ✅ Shipped (v0.3) | Skill turns NL into CLI calls; user confirms each mutation; rules the skill authors default to `dry_run: true` until the user arms them. | CLI 3.3.0+ |
| **L2 · Semi-autonomous (propose-then-approve)** | ✅ Shipped (v0.4) | Skill drafts a multi-step plan from intent (`plan suggest`); `plan run --require-approval` prompts the user once per destructive step; non-destructive steps run without interruption. | CLI 3.3.0+ |
| **L3 · Fully autonomous inside the policy envelope** | ✅ Shipped (v0.5) | Skill proactively authors rules via `rules suggest` + `policy add-rule`, shows the diff for one-time user approval, then the rules engine fires them indefinitely without further prompts. | CLI 3.3.0+ |

[cli-roadmap]: https://github.com/OpenWonderLabs/switchbot-openapi-cli/blob/main/docs/design/roadmap.md

You are at **L3**. The skill can author automation rules from intent,
inject them into policy.yaml (with a diff shown to the user for approval),
and guide the dry-run → arm transition. This repo now standardizes on
CLI 3.3.0 or later for all supported installs.

---

## Quickstart (15 minutes)

### 0. Prerequisites

```bash
node --version     # must be >= 18
npm --version      # any recent version
```

Also required:

- A **SwitchBot account** with at least one device paired in the app.
- **Claude Code** installed (the skill loads into `~/.claude/skills/`).
  Other MCP-capable agents work too; see [SKILL.md](./SKILL.md) for the
  generic agent path.

If `node --version` prints something below 18, install Node from
<https://nodejs.org>. On Windows use the LTS installer; on macOS prefer
`brew install node`.

### 1. Install the SwitchBot CLI

```bash
npm install -g @switchbot/openapi-cli
switchbot --version
```

Expected output:

```
3.3.0
```

If `switchbot --version` says "command not found", your global npm bin is
not on `PATH`. Run `npm config get prefix` — the `bin` subdirectory of
that path must be on `PATH`. On Windows this is usually
`%APPDATA%\npm`; on macOS/Linux usually `/usr/local/bin` or
`~/.npm-global/bin`.

### 2. Get your SwitchBot token + secret

1. Open the **SwitchBot mobile app**.
2. Go to **Profile** → **Preferences**.
3. Tap **App Version** 10 times to unlock **Developer Options**.
4. Open **Developer Options** and copy the **Token** and **Secret**.

These credentials have full control of every device on your account — treat
them like a password. This repo never asks you to paste them into chat or a
web form.

### 3. Configure the CLI

```bash
switchbot config set-token
```

The command is interactive. It asks for your token and your secret, then
writes them to `~/.switchbot/config.json` with owner-only permissions
(`0600`). If you prefer non-interactive setup:

```bash
switchbot config set-token <TOKEN> <SECRET>
```

(Be aware that putting the token on the command line leaves it in your
shell history. For everyday use, prefer the interactive form.)

If you have multiple SwitchBot accounts, pass `--profile <name>` to keep
them apart:

```bash
switchbot config set-token --profile work
switchbot --profile work devices list
```

Verify your credentials landed correctly:

```bash
switchbot config show
```

Expected: both token and secret are displayed **masked** (first few
characters, then `****`, then last few). Neither should appear in full.
If you see the full secret, stop and file an issue — this is a bug.

### 4. Run the doctor

```bash
switchbot doctor
```

Expected output — most checks should be `✓` (ok). Several rows expand to
inline JSON with diagnostic detail; that's normal, not noise:

```
✓ node            Node 22.21.1
✓ credentials     file: ~/.switchbot/config.json
✓ profiles        no profile dir (default profile only)
✓ catalog         42 types loaded
✓ catalog-schema  {"catalogSchemaVersion":"1.0","bootstrapExpectsVersion":"1.0","match":true, ...}
✓ cache           list: ~/.switchbot/devices.json | status: (none)
✓ quota           {"percentUsed":0,"remaining":9999,"dailyCap":10000, ...}
✓ clock           {"skewMs":-387,"localIso":"...","serverIso":"..."}
✓ mqtt            auto-provisioned from credentials — run 'switchbot events mqtt-tail' to test live connectivity
✓ mcp             {"serverInstantiated":true,"toolCount":11, ...}
✓ audit           {"path":"~/.switchbot/audit.log","enabled":true,"errorsLast24h":0, ...}

11 ok, 0 warn, 0 fail
```

Your numbers will differ — that's fine. What matters is the summary line
shows `0 fail`.

If any check is `✗` (fail), see
[`troubleshooting.md`](./troubleshooting.md#switchbot-doctor-fails). A
`!` (warn) is informational and doesn't block the Quickstart.

### 5. Take the first real action

```bash
switchbot devices list
```

You should see a table of every device on your account. This is the
moment the CLI is proven working end-to-end — **before** we involve the
agent.

### 6. Install the skill into Claude Code

Clone this repo somewhere stable, then install the skill:

```bash
# pick any directory you'll keep
git clone https://github.com/chenliuyun/switchbot-skill.git
cd switchbot-skill

# macOS / Linux
mkdir -p ~/.claude/skills
ln -s "$(pwd)" ~/.claude/skills/switchbot

# Windows PowerShell
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\switchbot" -Target (Get-Location).Path
```

A symlink is preferred so `git pull` inside the repo updates the
installed skill in place. If your platform disallows symlinks, `cp -r .`
into the destination works — you'll just have to re-copy on updates.

### 7. Create your `policy.yaml`

Requires `@switchbot/openapi-cli` ≥ 3.3.0:

```bash
switchbot policy new --version 0.2
# → writes ~/.config/openclaw/switchbot/policy.yaml (schema v0.2)
```

Edit the `aliases:` block to use the friendly names you want the agent
to understand:

```yaml
aliases:
  "living room light": "01-202407090924-26354212"  # one of your deviceIds
  "bedroom AC": "02-202502111234-85411230"
```

You can get the `deviceId` column from `switchbot devices list --format=tsv`.

Then verify the file is well-formed:

```bash
switchbot policy validate
# → ✓ ~/.config/openclaw/switchbot/policy.yaml is valid (schema v0.2)
```

If validation fails, the CLI points at the exact line and suggests a fix
(e.g. lowercase deviceId, quiet-hours missing an `end:`, a destructive
action like `lock` inside `never_confirm`).

For this Quickstart you can leave every other section of the policy at its
defaults. The skill explains the remaining sections on demand.

### 8. Ask your agent

Start Claude Code in any directory and try:

> List my SwitchBot devices and tell me which ones are currently on.

The agent should:

1. Notice the `switchbot` skill is available.
2. Run `switchbot agent-bootstrap --compact` to learn your setup.
3. Run `switchbot devices list --json` and `switchbot devices status <id> --json` for each on/off-capable device.
4. Report in plain language.

If any step above doesn't happen — e.g. the agent asks you for the token,
or tries to invent device IDs — see
[`troubleshooting.md`](./troubleshooting.md#agent-ignores-the-skill).

---

## Install / Configure / Execute

Think about this skill in three phases:

1. **Install** — put the skill or instruction files in the right place,
  install the CLI, and verify `switchbot doctor` / `switchbot devices list`.
2. **Configure** — create or edit `policy.yaml` so the agent knows your
  aliases, confirmation rules, quiet hours, and automation preferences.
3. **Execute** — let the agent control devices, run plans, or author rules
  using the CLI and the policy you approved.

After installation, the **recommended next step is configuration**. That is
when you create `~/.config/openclaw/switchbot/policy.yaml`, add aliases, and
decide how strict confirmations should be.

But configuration is **not a hard gate**. If you accept the defaults, you can
go straight from install to execution and start with simple read-only or
low-risk commands. The configuration phase is also triggered later whenever:

- you want friendlier aliases instead of raw device IDs
- you want to change confirmation behavior or quiet hours
- you want to set up or refine automations in `policy.yaml`
- the agent needs policy context to make a safe decision

Short version: install usually flows into configuration next, but execution can
begin immediately with defaults.

---

## Optional: real-time events

To let the agent react to events (motion sensors, door contacts, button
presses, webhook pushes):

```bash
# runs until Ctrl-C; streams every shadow change as one JSON line per event
switchbot events mqtt-tail --json
```

For a more integrated setup (events are forwarded to a local OpenClaw
gateway so your agent sees them as they happen), the CLI has built-in
sinks:

```bash
switchbot events mqtt-tail \
  --sink openclaw \
  --openclaw-url http://localhost:18789 \
  --openclaw-token "$OPENCLAW_TOKEN"
```

Leave this running in a terminal (or wrap it in `tmux` / `screen` /
`launchd` / `systemd` — your call for Phase 1; Phase 3 will supervise
this for you).

---

## What the skill does NOT do

| Out of scope | Notes |
|---|---|
| Template variables in rule `then[]` args (e.g. `{{ device.status }}`) | v0.3 schema feature; not yet in the rules engine. |
| `policy remove-rule` / `policy edit-rule` CLI commands | Users edit policy.yaml directly. The skill shows the diff but doesn't provide a dedicated removal command. |
| LLM-backed trigger/schedule inference | Pure heuristics only — no AI inside the suggest commands. |

---

## Safety model (one-minute version)

The skill classifies every SwitchBot action into one of five tiers, taken
from `switchbot capabilities --json`:

| Tier | Examples | Default behaviour |
|---|---|---|
| `read` | status queries, device list | Run freely. |
| `ir-fire-forget` | TV power, AC mode (IR, no state feedback) | Run; report that verification isn't possible. |
| `mutation` | turn on/off, set brightness | Run and write to `audit.log`. |
| `destructive` | unlock, delete scene | Refuse without explicit user confirmation. |
| `maintenance` | (reserved for factory-reset etc.; no device uses this today) | Always confirm. |

You can override the confirmation policy per action or per device in
`policy.yaml` (see the `confirmations:` section of the example).

Full details and the list of actions per tier live in [SKILL.md](./SKILL.md).

---

## Using this skill with other agents

`SKILL.md` was born in the Claude Code skill format (YAML front-matter + Markdown body), but the body itself is plain prose — any LLM-backed agent that accepts a system prompt or an instruction file can use it. Drop `SKILL.md` into the agent's instruction slot, strip the `---` front-matter if the agent doesn't speak it, and you're done.

## One-Command Install (Until The Plugin Ships)

This repo now includes installer scripts in `scripts/` that automate the
current file-based setup. They do **not** publish the future OpenClaw /
ClawHub plugin; they are the bridge until that plugin exists.

PowerShell:

```powershell
pwsh ./scripts/install.ps1 -Agent claude-global -InstallCli -InitPolicy
pwsh ./scripts/install.ps1 -Agent copilot -WorkspacePath C:\path\to\workspace
```

Bash:

```bash
./scripts/install.sh --agent claude-global --install-cli --init-policy
./scripts/install.sh --agent copilot --workspace-path /path/to/workspace
```

Supported targets:

- `claude-global`
- `claude-project`
- `copilot`
- `cursor`
- `cursor-legacy`
- `gemini-global`
- `gemini-project`
- `codex-global`
- `codex-project`
- `openclaw-staging`

What the scripts do:

- install or link the full skill tree for Claude Code
- generate front-matter-free instruction files for Copilot, Gemini, and Codex
- generate a ready-to-load `.mdc` rule for Cursor
- stage a future plugin preview under `<workspace>/.openclaw/staging/plugins/switchbot`
- include a status-sync channel launcher that wraps the CLI's `switchbot status-sync` commands
- optionally install `@switchbot/openapi-cli`
- optionally create and validate `~/.config/openclaw/switchbot/policy.yaml`

What still stays manual today:

- `switchbot config set-token` remains interactive because it handles secrets
- the OpenClaw / ClawHub plugin itself is still unpublished

## Upgrade

If you already installed this skill and want a real one-command upgrade, use
the upgrade wrapper in `scripts/`. It updates the repo, refreshes the target
agent install, updates the CLI, and runs basic health checks.

### PowerShell Upgrade

Upgrade the repo + CLI, then refresh a global Claude Code install:

```powershell
Set-Location C:\path\to\switchbot-skill
pwsh ./scripts/upgrade.ps1 -Agent claude-global
```

Upgrade the repo + CLI, then refresh a workspace-scoped Copilot install:

```powershell
Set-Location C:\path\to\switchbot-skill
pwsh ./scripts/upgrade.ps1 -Agent copilot -WorkspacePath C:\path\to\workspace
```

Upgrade a Cursor workspace rule:

```powershell
Set-Location C:\path\to\switchbot-skill
pwsh ./scripts/upgrade.ps1 -Agent cursor -WorkspacePath C:\path\to\workspace
```

### Bash Upgrade

Upgrade the repo + CLI, then refresh a global Claude Code install:

```bash
cd /path/to/switchbot-skill
./scripts/upgrade.sh --agent claude-global
```

Upgrade the repo + CLI, then refresh a workspace-scoped Copilot install:

```bash
cd /path/to/switchbot-skill
./scripts/upgrade.sh --agent copilot --workspace-path /path/to/workspace
```

Upgrade a Gemini or Codex global install:

```bash
cd /path/to/switchbot-skill
./scripts/upgrade.sh --agent gemini-global
# or
./scripts/upgrade.sh --agent codex-global
```

Upgrade the staged OpenClaw preview layout:

```bash
cd /path/to/switchbot-skill
./scripts/upgrade.sh --agent openclaw-staging --workspace-path /path/to/workspace
```

The staged preview plugin includes a channel launcher at:

- `<workspace>/.openclaw/staging/plugins/switchbot/scripts/run-status-sync.ps1`
- `<workspace>/.openclaw/staging/plugins/switchbot/scripts/run-status-sync.sh`

That launcher uses the CLI's built-in OpenClaw sink to push MQTT shadow events
into the agent gateway. Export `OPENCLAW_TOKEN` and `OPENCLAW_MODEL` before
starting it.

The preview scripts now delegate lifecycle management to the CLI's formal
`switchbot status-sync run|start|stop|status` commands instead of carrying a
separate PID/log implementation in the skill repo.

For manual lifecycle management outside an agent supervisor, the staged preview
also includes:

- `<workspace>/.openclaw/staging/plugins/switchbot/scripts/start-status-sync.*`
- `<workspace>/.openclaw/staging/plugins/switchbot/scripts/stop-status-sync.*`
- `<workspace>/.openclaw/staging/plugins/switchbot/scripts/status-status-sync.*`

`start-status-sync` runs the bridge in the background, `status-status-sync`
reports PID/log paths, and `stop-status-sync` terminates it.

For a real-machine MQTT -> OpenClaw verification flow with actual credentials,
see [docs/openclaw-status-sync-e2e.md](./docs/openclaw-status-sync-e2e.md).

### CLI only

If you only need to update the CLI and do not need to rewrite the agent files:

```bash
npm update -g @switchbot/openapi-cli
switchbot --version
```

### Agent-driven upgrade

For OpenClaw-like AI agents that can follow repo instructions, paste this and
tell the agent which target to refresh:

```text
Retrieve and follow the instructions at:
https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/INSTALL_FOR_AGENTS.md

Upgrade my existing SwitchBot skill install for <agent-target> and update the CLI too.
```

Examples for `<agent-target>`: `copilot`, `cursor`, `gemini-global`,
`codex-project`, `claude-global`, `openclaw-staging`.

## Uninstall

If you want a one-command uninstall, use the uninstall wrapper in `scripts/`.

### PowerShell Uninstall

Remove a global Claude Code install:

```powershell
Set-Location C:\path\to\switchbot-skill
pwsh ./scripts/uninstall.ps1 -Agent claude-global
```

Remove a workspace-scoped Copilot install:

```powershell
Set-Location C:\path\to\switchbot-skill
pwsh ./scripts/uninstall.ps1 -Agent copilot -WorkspacePath C:\path\to\workspace
```

Remove the staged OpenClaw preview layout:

```powershell
Set-Location C:\path\to\switchbot-skill
pwsh ./scripts/uninstall.ps1 -Agent openclaw-staging -WorkspacePath C:\path\to\workspace
```

### Bash Uninstall

Remove a global Claude Code install:

```bash
cd /path/to/switchbot-skill
./scripts/uninstall.sh --agent claude-global
```

Remove a workspace-scoped Cursor rule:

```bash
cd /path/to/switchbot-skill
./scripts/uninstall.sh --agent cursor --workspace-path /path/to/workspace
```

Remove the staged OpenClaw preview layout:

```bash
cd /path/to/switchbot-skill
./scripts/uninstall.sh --agent openclaw-staging --workspace-path /path/to/workspace
```

### Optional cleanup

Also remove the CLI, policy, audit log, or credentials:

```bash
./scripts/uninstall.sh --agent claude-global --remove-cli --remove-policy --remove-credentials
```

### After upgrading

- restart the target agent or reopen the workspace
- run `switchbot devices list` once to confirm the CLI still talks to your account
- if your policy changed, run `switchbot policy validate`

Recipe per agent:

- **Claude Code** — [docs/agents/claude-code.md](./docs/agents/claude-code.md) *(native; no adaptation needed)*
- **Cursor** — [docs/agents/cursor.md](./docs/agents/cursor.md) *(`.cursor/rules/*.mdc` or `.cursorrules`)*
- **GitHub Copilot** — [docs/agents/copilot.md](./docs/agents/copilot.md) *(`.github/copilot-instructions.md`)*
- **Everything else** (Gemini CLI, Codex, custom LLM apps, MCP clients) — [docs/agents/other.md](./docs/agents/other.md)

All recipes assume the same prerequisite: `@switchbot/openapi-cli` is on `PATH` and `switchbot config set-token` has been run. The skill teaches the agent *how* to use the CLI; it doesn't teach it how to use SwitchBot's REST API directly, and agents should never try.

---

## Layout

```
.
├── README.md                     # You are here
├── SKILL.md                      # Agent-facing: authority, safety, bootstrap
├── manifest.json                 # Skill manifest + compatibility metadata
├── examples/
│   ├── policy.example.yaml       # Copy-and-edit starting point
│   └── policy.schema.json        # JSON Schema v0.2 for editor autocomplete
├── docs/
│   └── agents/                   # Per-agent install recipes (Claude Code, Cursor, Copilot, ...)
├── troubleshooting.md            # 6 common failure modes + exact fixes
├── LICENSE                       # MIT
└── CHANGELOG.md                  # Keep a Changelog format
```

---

## Versioning

This skill follows [Semantic Versioning][semver]. `manifest.json` declares a
minimum CLI version via `authority.cli`; the agent refuses to run against
older CLIs rather than guess at missing features.

Breaking changes to `policy.yaml` bump the minor version of the skill (not
the patch version) and ship with a migration note in `CHANGELOG.md`.

[semver]: https://semver.org/

---

## Contributing & support

- File issues at <https://github.com/chenliuyun/switchbot-skill/issues>.
- Do **not** open PRs against the CLI's documentation to fix skill-specific
  quirks — the CLI is the authoritative source; the skill adapts.

---

## License

MIT — see [LICENSE](./LICENSE).
