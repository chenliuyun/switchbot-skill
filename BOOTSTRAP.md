# SwitchBot Codex Bootstrap

Paste the prompt below into Codex chat. Codex will clone the repo and run
the setup script automatically. The only human action required is clicking
**Allow** in the browser OAuth screen.

---

## Option A — GitHub Clone (available now)

Copy and paste into Codex:

```
Clone the SwitchBot skill repo if needed, then run its setup script:
  git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill 2>/dev/null || git -C ~/switchbot-skill pull origin main
  node ~/switchbot-skill/scripts/codex-setup.js
```

The script handles everything: CLI install, plugin registration, legacy
config fallback, and browser login. After the browser **Allow** click,
restart Codex and try:

> List my SwitchBot devices and tell me which ones are currently on.

---

## Option B — npm (after publishing `@cly-org/switchbot-codex-plugin`)

Copy and paste into Codex:

```
Please set up the SwitchBot Codex plugin:
1. npm install -g @cly-org/switchbot-codex-plugin
2. switchbot-codex-install
```

The install script handles CLI install, plugin registration, and browser login.
After the browser **Allow** click, restart Codex and try:

> List my SwitchBot devices and tell me which ones are currently on.
