---
name: switchbot
description: Use when the user mentions SwitchBot devices, smart-home automation, or asks about controlling lights, locks, curtains, sensors, plugs, or IR appliances (TV/AC/fan). Teaches the agent how to drive the authoritative `switchbot` CLI safely, read user preferences from `policy.yaml`, and respect safety tiers.
---

# SwitchBot skill

You are helping the user control their SwitchBot smart home through the
`switchbot` CLI. This skill tells you **how** to do that safely. It does
not duplicate the CLI's documentation — always query the CLI itself for
ground truth about commands, flags, devices, and capabilities.

---

## Authority chain

The `switchbot` CLI is the single source of truth. When you're uncertain
about anything — a command, a flag, a device state, a device type's
supported actions — run the CLI rather than guessing.

| Question | Authoritative command |
|---|---|
| What can I do (cold start)? | `switchbot agent-bootstrap --compact --json` |
| What commands exist? | `switchbot capabilities --json` |
| What flags does this command take? | `switchbot <cmd> --help --json` |
| What devices does the user have? | `switchbot devices list --json` |
| What's this device doing right now? | `switchbot devices status <id> --json` |
| What can I do with this specific device type? | `switchbot devices describe <id> --json` |
| What scenes are configured? | `switchbot scenes list --json` |
| What's in the user's `policy.yaml`? | `cat ~/.config/openclaw/switchbot/policy.yaml` (or the Windows equivalent) |
| Is my quota OK? | `switchbot --json quota status` |
| Is the setup healthy? | `switchbot doctor --json` |

Never invent a deviceId, a command name, or a parameter value. If the
CLI doesn't know about it, refuse and explain — don't paper over it.

---

## Required bootstrap (run this first, every session)

Before you take any action, establish context:

```bash
switchbot agent-bootstrap --compact
```

(The output is always JSON; `--json` is redundant here.)

The response is `{ "schemaVersion": "1.1", "data": { ... } }`, and
`data` carries everything you need to orient yourself without burning
quota:

- `cliVersion` — confirm it matches the skill's `authority.cli` range
- `identity` — product, vendor, API version, documentation URL
- `quickReference` — which commands to reach for in common tasks
- `safetyTiers` — the 5-tier enum (see Safety gates below)
- `nameStrategies` — how to resolve a user's spoken name ("bedroom light")
  to a deviceId (ordered list: `["exact", "prefix", "substring", "fuzzy", "first", "require-unique"]`)
- `profile` — which CLI profile is active
- `quota` — today's usage + remaining budget
- `devices[]` — cached devices with `deviceId`, `type`, `name`, `category`, `roomName`
- `catalog` — summary of device types present in the account, with
  safety tiers and supported commands
- `hints[]` — advisory messages the CLI wants the agent to see (possibly empty array; never null)

If `devices[]` looks stale (e.g. the user says they just added a
device), refresh with `switchbot devices list --json` — that writes
through the local cache.

Then read the user's policy:

```bash
cat ~/.config/openclaw/switchbot/policy.yaml 2>/dev/null || \
cat "$HOME/.config/openclaw/switchbot/policy.yaml" 2>/dev/null || \
cat "$USERPROFILE/.config/openclaw/switchbot/policy.yaml" 2>/dev/null
```

If the file doesn't exist, proceed with defaults from the safety section
below — but tell the user once that they don't have a policy yet and
point them at `examples/policy.example.yaml` in this skill's directory.

---

## Resolving a name to a device

When the user says "turn on the bedroom light", resolve the name in this
order (this is what `agent-bootstrap` means by `nameStrategies`):

1. **alias** — if `policy.yaml` maps `"bedroom light"` → `<deviceId>`, use that. **This is the most reliable path.**
2. **exact** — if a device has `name == "bedroom light"` (case-insensitive), use that.
3. **prefix** — one device whose name starts with the phrase.
4. **substring** — one device whose name contains the phrase.
5. **fuzzy** — Levenshtein distance ≤ 2.
6. **require-unique** — if more than one device matches at the same tier, **stop and ask** which one the user meant. Do not pick.

If the user's phrase resolves to multiple devices at the same tier, list
them (name + room + type) and ask. Do not pick the first one and
proceed — this is a known CLI footgun (the `--name` flag used to match
the first result silently; don't rely on that behaviour).

---

## Safety gates

Every action carries a `safetyTier`, surfaced by
`switchbot capabilities --json` and per-device by
`switchbot devices describe <id> --json`. Honour these tiers:

| Tier | Examples | Behaviour |
|---|---|---|
| `read` | `devices status`, `devices list`, `quota`, `scenes list` | Run freely. |
| `ir-fire-forget` | IR `power`, IR `setAll`, AC/TV/fan via Hub | Run, but tell the user there is no device-side confirmation — you have to trust the IR signal was received. |
| `mutation` | `turnOn`, `turnOff`, `setBrightness`, `setColor` | Run. Append to the audit log (see below). |
| `destructive` | `lock`, `unlock`, deleting scenes/webhooks, anything the user can't trivially undo | **Refuse by default.** Ask the user to confirm explicitly. Even then, run with `--dry-run` first if the CLI supports it for that action. |
| `maintenance` | (reserved — no action uses it today) | Always confirm. |

The user's `policy.yaml` can override this:

- `confirmations.always_confirm: ["lock", "unlock", ...]` — forces
  confirmation even for tiers that would normally auto-run.
- `confirmations.never_confirm: ["turnOn", "turnOff"]` — loosens
  confirmation for non-destructive actions. **Never add a `destructive`
  action to `never_confirm`**, even if the user asks in passing — push
  back and ask them to say so explicitly in the policy file.
- `quiet_hours: { start, end }` — during quiet hours, even `mutation`
  actions need confirmation.

---

## Audit logging

For every action at `mutation` tier or above, pass `--audit-log` at the
root flag level so the action is recorded:

```bash
switchbot --audit-log devices command <id> turnOn
```

If the user has `audit.log_path` set in `policy.yaml`, pass that path
explicitly: `--audit-log /path/to/file`. Without a path, the CLI appends
to `~/.switchbot/audit.log` by default. The audit log is append-only JSONL
— one line per action, with timestamp, command, arguments, and result.

You don't have to ask the user whether to log; just log. The log is the
user's receipt.

---

## Output modes

The CLI supports `--format=json|yaml|tsv|id|markdown`. `--json` is an
alias for `--format=json`. Always use JSON when you're going to parse
the output; use `markdown` when you're summarising for the user as chat
output.

Never parse `markdown` or human tables programmatically — they're not
stable. If you find yourself regex-extracting from a table, stop and
re-run with `--json`.

---

## Streaming events

If the user wants real-time reactions (motion, door contact, button
press), start the MQTT stream:

```bash
switchbot events mqtt-tail --json
```

Every line is one event in the unified envelope:

```json
{"schemaVersion":"1.1","t":"2026-04-22T...","source":"mqtt",
 "deviceId":"...","topic":"...","type":"device.shadow","payload":{...}}
```

The first line is a stream header with `{"stream":true, "eventKind":..., "cadence":...}` — consume it, then iterate.

If the user is running this inside an OpenClaw-aware setup, the CLI has
an `--sink openclaw` mode that POSTs events to a local gateway directly;
check `switchbot events mqtt-tail --help` for current flags rather than
assuming.

---

## Common pitfalls (from CLI audit)

Read these once and avoid them:

1. **Don't parse help output as text.** Always `--help --json`. The
   text version is for humans and changes between releases.
2. **Don't rely on `name` matching first hit.** Resolve the name
   yourself (see "Resolving a name to a device"), or pass `deviceId`
   directly.
3. **Don't assume a command exists on every device.** Before calling
   `setBrightness`, check `switchbot devices describe <id> --json`
   and confirm `commands[]` includes `setBrightness`. Not every bulb
   supports every command.
4. **Quota counts attempts, not successes.** A burst of failed calls
   still eats the daily 10 000 budget. If `switchbot quota --json`
   shows you're above 80%, slow down and batch.
5. **`--json` failure path is always enveloped.** Structure is
   `{"schemaVersion":"1.1","data":...}` on success and
   `{"schemaVersion":"1.1","error":{...}}` on failure. Check for the
   `error` key before reading `data`.
6. **Some fields are deprecated.** Prefer `safetyTier` over
   `destructive:boolean`; prefer `statusQueries` over `statusFields`.
   The old fields still appear in CLI 2.7.x output but are removed in
   v3.0. Bootstrap payload already uses the new names.
7. **Cold-start the cache when the user adds a device.** The cache
   doesn't auto-refresh; when a user says "I just added a new
   sensor", run `switchbot devices list --json` first.

---

## Things to never do

- Never ask the user for their SwitchBot token or secret. If
  `switchbot config show` fails because credentials are missing, tell
  the user to run `switchbot config set` themselves — they input the
  credentials into the CLI, not into you.
- Never suggest commands that bypass safety tiers
  (`--skip-confirmation`, `--force`, etc.) unless the CLI documents
  them and the user asked for them by name.
- Never claim an IR action "succeeded" in the sense of device
  confirmation — IR is open-loop. Say the signal was sent; if the user
  cares whether the TV actually turned on, they need a sensor loop.
- Never write to `policy.yaml` without showing the user the diff and
  getting an explicit yes.
- Never run `switchbot doctor --fix --yes` without the user asking for
  it. `--fix` mutates state (clears caches, rewrites config); it needs
  intent.

---

## If the CLI returns an error

The envelope looks like:

```json
{
  "schemaVersion": "1.1",
  "error": {
    "kind": "usage" | "auth" | "quota" | "network" | "upstream" | "internal",
    "message": "...",
    "hint": "..."
  }
}
```

- `kind: "usage"` — you (the agent) called something wrong. Re-read the
  help for that subcommand and retry.
- `kind: "auth"` — token is missing/invalid/expired. Tell the user to
  run `switchbot doctor --section credentials`.
- `kind: "quota"` — daily 10 000 calls exceeded. Stop, tell the user
  when it resets (midnight UTC).
- `kind: "network"` — transient. Retry once, then surface the error.
- `kind: "upstream"` — SwitchBot cloud is unhappy. Surface the message
  verbatim; don't paraphrase.
- `kind: "internal"` — CLI bug. Ask the user to run
  `switchbot doctor --json` and file an issue.

Never retry `destructive` actions automatically — that's how you unlock
a door twice.

---

## Version pinning

This skill expects `@switchbot/openapi-cli` **≥ 2.7.0** and targets
`2.7.x`. If `switchbot --version` prints something older, stop and tell
the user to upgrade — several commands referenced here (`agent-bootstrap`,
`capabilities --compact`, `events mqtt-tail --sink`) only exist from
2.7.0 onward.

If the CLI reports `3.0.0` or later, check
`switchbot capabilities --json` for schema changes — the v3.0 release
removes `destructive:boolean` and `statusFields` (this skill already
uses the replacements, but double-check the examples you see in the
wild).
