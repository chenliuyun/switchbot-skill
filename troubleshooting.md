# Troubleshooting

If something goes wrong during the Quickstart or while using the skill,
find the closest heading below and follow the steps. Every section ends
with a "still stuck?" line that tells you what to include when filing an
issue.

---

## `switchbot --version` is below 3.3.0

**Cause:** the skill requires `@switchbot/openapi-cli@>=3.3.0` because
earlier 3.x versions silently return the wrong envelope shape
(downstream parsers read `undefined` instead of `.data`), have a known
cache bug on batch/long-lived reads, and accept malformed policy files.
The four pitfalls documented in `SKILL.md` §5–§9 all assume 3.3.0
behavior.

**Fix:**

```bash
npm install -g @switchbot/openapi-cli@latest
switchbot --version   # should print 3.3.0 or newer
```

The `scripts/bootstrap.sh` / `scripts/bootstrap.ps1` installers refuse
to proceed below this floor; they will print the upgrade command and
exit 1 before touching anything else.

If you cannot upgrade (e.g. a pinned corporate build), pin the skill to
version `0.5.0` (the last release whose `authority.cli` accepted
`>=3.0.0`) and do not use the §5–§9 guidance.

---

## `switchbot --version` says "command not found"

**Cause:** your global npm bin directory isn't on `PATH`.

**Fix:**

```bash
# Find out where npm installs globals:
npm config get prefix
```

On macOS/Linux the binary lives at `<prefix>/bin/switchbot`. Make sure
that `<prefix>/bin` is on your `PATH`. A common fix for zsh users:

```bash
echo 'export PATH="$(npm config get prefix)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

On Windows the binary lives at `%APPDATA%\npm\switchbot.cmd`. Add
`%APPDATA%\npm` to your user `PATH` through **Settings → System → About
→ Advanced system settings → Environment Variables**.

**Still stuck?** Include `npm config get prefix`, the result of `which
switchbot` (or `where switchbot` on Windows), and your shell + OS.

---

## `switchbot doctor` fails

### `credentials: fail`

`~/.switchbot/config.json` is missing, malformed, or has a bad token.

```bash
switchbot config set-token
```

Paste the token + secret from the SwitchBot app (Profile → Preferences →
tap App Version 10× → Developer Options). If you recently rotated the
token in the app, the old one stops working immediately.

### `api-reachability` (implicit)

The CLI does not run a separate `api-reachability` check by default —
failures usually surface as `credentials: fail` (auth) or a timeout
during the next real call. If `switchbot doctor` passes but
`switchbot devices list` hangs or errors with a network code:

1. Are you online? `curl -sI https://api.switch-bot.com` should return
   HTTP/1.1 or HTTP/2.
2. Are you behind a corporate proxy? Set `HTTPS_PROXY` and rerun.
3. Is SwitchBot's cloud up? Try the SwitchBot app — if the app can't
   reach the cloud, the CLI won't either.

### `cache: warn` — "cache is stale" or "no devices cached"

Normal on first run. Trigger a refresh:

```bash
switchbot devices list --json > /dev/null
switchbot doctor --section cache
```

### `quota: warn` — above 80% of daily budget

The SwitchBot cloud allows 10 000 API calls per account per UTC day.
The counter resets at 00:00 UTC. If you hit this:

1. Stop any loops (shell scripts polling status).
2. Check `switchbot --json quota status` to confirm when the reset is.
3. Consider using `switchbot events mqtt-tail` (push) instead of polling
   status (pull) — MQTT doesn't count against quota.

### `mqtt: fail` under `--probe`

The MQTT probe is only run with `--probe`. A fail means the CLI could
not connect to the SwitchBot MQTT broker in 5 seconds. Causes in order
of likelihood:

1. Your credentials don't have MQTT enabled (older SwitchBot accounts).
   Re-enable developer options in the SwitchBot app.
2. Firewall is blocking outbound MQTTS (port 8883). Open it.
3. DNS: try `nslookup mqtt.switch-bot.com`.

**Still stuck?** Include the full `switchbot doctor --json` output
(your token is redacted automatically).

---

## Agent ignores the skill

Symptom: you asked Claude Code about SwitchBot but it didn't invoke the
skill, or asked you for your token, or tried to invent device IDs.

### Is the skill installed?

```bash
ls ~/.claude/skills/switchbot/SKILL.md
```

If the file is missing, the skill isn't installed. Revisit step 6 of the
Quickstart (symlink or copy into `~/.claude/skills/switchbot/`).

### Is the frontmatter intact?

`SKILL.md` must start with `---` YAML frontmatter containing `name` and
`description` fields. If you edited the file and broke the frontmatter,
Claude Code silently won't load it.

```bash
head -5 ~/.claude/skills/switchbot/SKILL.md
```

Expected:

```yaml
---
name: switchbot
description: Use when the user mentions SwitchBot devices...
---
```

### Did you restart Claude Code?

Skills are loaded at session start. If you just installed the skill in
an existing session, the new session needs to start.

### Agent asked for your token

This should **never** happen. The skill explicitly tells the agent to
ask the user to run `switchbot config set` themselves. If the agent
asks you for credentials:

1. Refuse. Don't type them.
2. File an issue with the exact prompt the agent used — this may be a
   prompt injection or a skill loading failure.

**Still stuck?** Include the agent's exact words and
`ls -la ~/.claude/skills/switchbot/`.

---

## Agent picks the wrong device

Symptom: you said "turn on the bedroom light" and it turned on the
kitchen one.

**Cause:** two or more devices have similar names (e.g. "Bedroom Light"
and "Bedroom Light 2"), and the agent guessed.

**Fix:** add an explicit alias to `policy.yaml`:

```yaml
aliases:
  "bedroom light": "01-202407090924-26354212"
```

Get the deviceId from `switchbot devices list --format=tsv`. After
editing, the next session will pick it up — no restart needed, but the
current session won't re-read the file mid-conversation.

---

## `events mqtt-tail` disconnects repeatedly

Symptom: you start `switchbot events mqtt-tail --json` and it prints
"reconnecting" every few seconds.

### Check credentials

MQTT uses the same token/secret as the REST API. If `doctor` fails on
`mqtt` (with `--probe`), start there.

### Are you running it twice?

The SwitchBot MQTT broker allows **one** client session per credential
at a time. Starting a second `mqtt-tail` kicks off the first and they
fight until one wins. Check:

```bash
ps aux | grep mqtt-tail       # macOS/Linux
Get-Process | ? { $_.ProcessName -like '*switchbot*' }    # Windows PowerShell
```

Kill the duplicate.

### Unstable network

MQTT over TLS is sensitive to NAT timeouts. If you're on a flaky VPN,
try temporarily disabling it, or move to a wired connection.

**Still stuck?** Run with `DEBUG=switchbot:mqtt` and include the first
50 lines of output.

---

## `policy.yaml` changes don't take effect

Symptom: you edited `policy.yaml` but the agent still uses the old
behaviour.

### Right path?

The skill looks for the file at:

- Linux/macOS: `~/.config/openclaw/switchbot/policy.yaml`
- Windows: `%USERPROFILE%\.config\openclaw\switchbot\policy.yaml`

Not `~/openclaw/...`, not `~/.switchbot/policy.yaml`. If in doubt:

```bash
ls ~/.config/openclaw/switchbot/policy.yaml   # should exist
```

### Valid YAML and valid schema?

With the supported CLI floor (3.3.0+):

```bash
switchbot policy validate
```

Exit 0 means the file parses AND conforms to the v0.2 schema. Any other
exit code prints a compiler-style error with the offending line and a
fix hint (e.g. lowercase deviceId, destructive action in `never_confirm`,
quiet-hours missing an `end:`).

Older 2.x CLIs are outside the supported range for this repo. Update the CLI
first rather than trying to validate against an older command surface.

(The explicit `encoding='utf-8'` mattered in the old Python fallback on
Windows, where Python defaults to the system codepage and can fail on policy files that
contain non-ASCII aliases like device names in Chinese or Japanese.
This checks only that the YAML parses — it does NOT catch schema
violations like a lowercase deviceId or an out-of-range `quiet_hours`.)

### Session needs to restart

The skill reads `policy.yaml` once at session start. Close the current
agent session and start a new one.

---

## Batch or long-lived calls return stale device state

> **Workaround (temporary)** — remove once the upstream cache bug is fixed.

Symptom: a loop or long agent session reads `switchbot devices status
<id> --json` and gets state that doesn't match reality — the lamp is
off in the app but the CLI reports `"power": "on"`.

**Cause:** known CLI cache bug. The cached value isn't invalidated
promptly for some read paths.

**Workaround:** pass `--no-cache` on the read.

```bash
switchbot devices status <id> --json --no-cache
```

Apply this to:

- batch fan-outs (`for id in ...; do switchbot devices status "$id" ...; done`)
- long-lived agent sessions that re-read device state after sitting idle
- any rule or script that compares current state against a previous snapshot

Short one-shot interactive calls are usually fine without the flag.
Do **not** lower `cli.cache_ttl` in `policy.yaml` as a substitute —
that's a durable config change; `--no-cache` is the targeted workaround.

Remove the flag once the cache bug is fixed upstream.

---

## Device shows `offline` but works in the SwitchBot app

Symptom: `switchbot devices status <id> --json` returns `{"online":
false}` but the app shows the device as responsive.

**Cause:** SwitchBot's cloud cache of device online state lags behind
reality. The app uses a different code path (direct poll on tap).

**Workarounds:**

1. Try the command anyway. Offline-reported devices often accept
   commands fine; the cloud retries them.
2. For motion/contact sensors, use `events mqtt-tail` — the push path
   reports state changes even when the polled `online` flag is stale.
3. Physically power-cycle the device's Hub (unplug for 30 s). This
   forces a re-registration with the cloud and usually refreshes the
   online flag.

---

## Quota exceeded (HTTP 429)

Symptom: any CLI call returns `{"error":{"kind":"quota",...}}`.

The SwitchBot cloud limits **10 000 calls per account per UTC day**,
counted per HTTP attempt (including failures). This resets at
**00:00 UTC**.

```bash
switchbot --json quota status
```

gives you the exact reset time.

**What to do:**

1. Stop polling loops immediately.
2. Use `switchbot events mqtt-tail` for state changes — it doesn't count
   against the REST quota.
3. If you absolutely need more calls today, delete a second SwitchBot
   developer token and use a different one with `--profile`. Not a
   permanent solution but gets you through.

---

## Uninstalling

Phase 1 install was manual, so uninstall is too:

```bash
# Remove the skill
rm -rf ~/.claude/skills/switchbot

# (Optional) remove policy + audit log
rm -rf ~/.config/openclaw/switchbot
rm -f ~/.switchbot/audit.log

# (Optional) remove the CLI itself
npm uninstall -g @switchbot/openapi-cli

# (Optional) remove credentials
rm -rf ~/.switchbot
```

The Phase 3 plugin will provide `openclaw switchbot uninstall` that
does this cleanly.

---

## Reporting an issue

When the sections above don't help, open an issue at
<https://github.com/chenliuyun/switchbot-skill/issues>
and include:

- OS + shell (e.g. "macOS 14.4 zsh", "Windows 11 PowerShell 7")
- Node version (`node --version`)
- CLI version (`switchbot --version`)
- Skill version (`cat ~/.claude/skills/switchbot/manifest.json | jq .version`)
- Output of `switchbot doctor --json` (credentials are redacted automatically)
- What you typed at the agent and what it replied
- Any relevant lines from `audit.log`

Do not paste your SwitchBot token or secret — nobody debugging this
needs them.
