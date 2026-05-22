# SwitchBot Codex Bootstrap

Paste one of the prompts below into Codex chat. Codex will run the setup
commands automatically. The only human action required is clicking **Authorize**
in the browser — `switchbot auth login` runs automatically via the plugin's
install hook.

---

## Option A — GitHub Clone (available now)

Copy and paste into Codex:

```
Please set up the SwitchBot Codex plugin by running these commands in order:
1. npm install -g @switchbot/openapi-cli@latest
2. git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
3. codex plugin marketplace add ~/switchbot-skill
4. codex plugin add switchbot@switchbot-skill

After all commands succeed, the plugin will automatically open a browser for
OAuth authorization — just click Allow in the browser.
```

---

## Option B — npm (after publishing `@cly-org/switchbot-codex-plugin`)

Copy and paste into Codex:

```
Please set up the SwitchBot Codex plugin:
1. npm install -g @cly-org/switchbot-codex-plugin
2. switchbot-codex-install

After completion, the plugin will automatically open a browser for OAuth
authorization — just click Allow in the browser.
```

---

After auth completes, ask Codex:

> List my SwitchBot devices and tell me which ones are currently on.
