# SwitchBot Skill — Codex Install

> **Recommended install:** Codex app → Plugins → Add from local path → `packages/codex-plugin/`
> Or via CLI: `codex plugin marketplace add .`
>
> The manual steps below are a **Legacy path** for older Codex versions that do not support the plugin system.

---

<details>
<summary>Legacy: Manual Installation (older Codex without plugin support)</summary>

You are a Codex agent. Read this section completely, then execute every step below.
Do **not** ask the user for SwitchBot tokens or secrets — those come from the browser login in Step 5.

---

## Step 1: Check Node.js

Run: `node --version`

If Node.js is missing or below v18, tell the user to install it from https://nodejs.org and stop.

---

## Step 2: Install the SwitchBot CLI

Run:

```
npm install -g @switchbot/openapi-cli@latest
```

Then confirm: `switchbot --version` must print `3.3.0` or higher.
If it prints a lower version, stop and tell the user to check their npm global prefix.

---

## Step 3: Enable plugin hooks in Codex config

Read `~/.codex/config.toml` (create the file if it does not exist).

Ensure the file contains:

```toml
[features]
plugin_hooks = true
```

Rules:
- If the file does not exist → create it with just those two lines.
- If a `[features]` section exists but `plugin_hooks` is missing → add the key under it.
- If `plugin_hooks` exists but is not `true` → update it to `true`.
- Do not touch any other keys in the file.

---

## Step 4: Write AGENTS.md

Clone or update the skill repo:

```
git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
```

If `~/switchbot-skill` already exists, run `git -C ~/switchbot-skill pull origin main` instead.

Read `~/switchbot-skill/SKILL.md`.
Strip the YAML front matter block (the lines from the first `---` to the second `---`, inclusive).
Write the remaining content to `~/.codex/AGENTS.md`, creating the directory if needed.

---

## Step 5: Authenticate

Tell the user:

> "A browser window will open — sign in with your SwitchBot account.
> Your credentials are stored securely in the OS keychain; you only do this once."

Run: `switchbot auth login`

If the browser cannot open (headless or SSH environment), run:

```
switchbot auth login --no-open
```

and show the printed URL to the user so they can open it on any machine.

---

## Step 6: Verify

Run both:

```
switchbot --version
switchbot doctor
```

`doctor` must end with `0 fail`.
If it reports failures, show the output and tell the user to follow the printed fix commands, then re-run `switchbot doctor` before continuing.

---

## Step 7: Done

Tell the user:

> "SwitchBot skill installed for Codex.
> Restart Codex if it is already open, then try:
> **List my SwitchBot devices and tell me which ones are currently on.**"

</details>
