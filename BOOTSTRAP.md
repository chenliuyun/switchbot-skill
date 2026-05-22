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

If step 4 fails because your Codex version does not support "plugin add",
use this fallback instead:
a. Add to ~/.codex/config.toml (create the file if it does not exist):
     [features]
     plugin_hooks = true

     [[mcp_servers]]
     name = "switchbot"
     command = "switchbot"
     args = ["mcp", "serve", "--tools", "all"]
b. Read ~/switchbot-skill/SKILL.md, strip the YAML front matter block (the
   lines from the first --- to the second ---, inclusive), and write the
   remaining content to ~/.codex/AGENTS.md.
c. Run: switchbot auth login

After setup, a browser opens for OAuth authorization — just click Allow.
```

---

## Option B — npm (after publishing `@cly-org/switchbot-codex-plugin`)

Copy and paste into Codex:

```
Please set up the SwitchBot Codex plugin:
1. npm install -g @cly-org/switchbot-codex-plugin
2. switchbot-codex-install

If switchbot-codex-install fails at the "plugin add" step because your Codex
version does not support it, use Option A's fallback steps (a–c) above instead.

After setup, a browser opens for OAuth authorization — just click Allow.
```

---

After auth completes, ask Codex:

> List my SwitchBot devices and tell me which ones are currently on.
