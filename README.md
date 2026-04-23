# OpenClaw SwitchBot Skill

Control your SwitchBot smart home (lights, locks, curtains, sensors, plugs, IR
appliances) from an AI agent. This repository ships two things:

1. A **skill** (`SKILL.md`) that teaches an AI agent how to use the
   `switchbot` CLI safely — command surface, safety tiers, bootstrap
   sequence, common pitfalls.
2. A **policy schema** (`examples/policy.example.yaml`) that lets you declare
   your preferences (device aliases, quiet hours, which actions always need
   confirmation) so the agent doesn't have to guess.

The skill drives the [`@switchbot/openapi-cli`][cli] — the authoritative
source for what commands exist and how they behave. This repo never duplicates
CLI docs; it tells the agent how to read them.

[cli]: https://www.npmjs.com/package/@switchbot/openapi-cli

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

| Level | Status | Meaning | CLI phase it needs |
|---|---|---|---|
| **L1 · Manual orchestration** (this release, v0.3) | ✅ Shipped | Skill turns NL into CLI calls; user confirms each mutation; rules the skill authors default to `dry_run: true` until the user arms them. | Phase 1 or later. This release assumes Phase 4. |
| **L2 · Semi-autonomous (propose-then-approve)** | Planned | Skill composes multi-step plans; `--require-approval` gates each step; one Y/N approves or rejects the whole batch. | Track δ on the CLI roadmap. |
| **L3 · Fully autonomous inside the policy envelope** | Planned | Skill writes a rule, the rules engine executes it without further prompts. The skill moves from "driver" to "author". | Phase 4 (shipped); requires skill-side UX for policy diffs + audit review. |

[cli-roadmap]: https://github.com/OpenWonderLabs/switchbot-openapi-cli/blob/main/docs/design/roadmap.md

You are currently at L1. The skill handles the conversational surface;
every mutation is a single confirmed command. L2 and L3 are explicit
future releases, not hidden features — this doc will grow L2/L3 rows as
they ship.

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
2.9.0
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
git clone https://github.com/<your-account>/openclaw-switchbot-skill.git
cd openclaw-switchbot-skill

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

Requires `@switchbot/openapi-cli` ≥ 2.9.0:

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

## What the skill does NOT do (yet)

These are **deliberate L1 omissions**. If you need any of them today,
you'll have to handle it yourself or wait for the level that ships them:

| Not yet | Ships in | Workaround today |
|---|---|---|
| One-command install with rollback | Track β (CLI roadmap) | Follow the Quickstart above |
| Skill-authored multi-step plans with a single confirmation | L2 (this skill) | Run the steps manually and confirm each |
| Skill that writes and arms its own rules without further prompts | L3 (this skill) | The user edits `policy.yaml` and runs `switchbot rules reload` themselves; the skill can author the rule with `dry_run: true` and show the diff |

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
├── manifest.json                 # Claude Code skill + ClawHub plugin metadata
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

- File issues at <https://github.com/OpenWonderLabs/openclaw-switchbot-skill/issues>
  (once the public repo is live).
- Do **not** open PRs against the CLI's documentation to fix skill-specific
  quirks — the CLI is the authoritative source; the skill adapts.

---

## License

MIT — see [LICENSE](./LICENSE).
