# SwitchBot Codex Bootstrap

Paste one of the prompts below into Codex chat. Codex will run the setup
commands automatically. The only human action required is clicking **Authorize**
in the browser — `switchbot auth login` runs automatically via the plugin's
install hook.

---

## Option A — GitHub Clone (available now)

Copy and paste into Codex:

```
请帮我安装 SwitchBot Codex 插件，按顺序执行以下命令：
1. npm install -g @switchbot/openapi-cli@latest
2. git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
3. codex plugin marketplace add ~/switchbot-skill
4. codex plugin add switchbot@switchbot-skill

安装完成后，插件会自动打开浏览器进行 OAuth 授权，请在浏览器里点击「允许」即可。
```

---

## Option B — npm (after publishing `@cly-org/switchbot-codex-plugin`)

Copy and paste into Codex:

```
请帮我安装 SwitchBot Codex 插件：
1. npm install -g @cly-org/switchbot-codex-plugin
2. switchbot-codex-install

安装完成后，插件会自动打开浏览器进行 OAuth 授权，请在浏览器里点击「允许」即可。
```

---

After auth completes, ask Codex:

> List my SwitchBot devices and tell me which ones are currently on.
