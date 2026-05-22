# SwitchBot Codex Bootstrap

Paste one of the prompts below into Codex chat. Codex will run the setup
commands automatically. The only step that requires human interaction is
`switchbot auth login` — this opens a browser window for OAuth.

---

## Option A — GitHub Clone (available now)

Copy and paste into Codex:

```
请帮我安装 SwitchBot Codex 插件，按顺序执行以下命令：
1. npm install -g @switchbot/openapi-cli@latest
2. git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
3. codex plugin marketplace add ~/switchbot-skill
4. codex plugin add switchbot@switchbot-skill

全部成功后，提示我在终端运行 `switchbot auth login` 完成浏览器授权。
```

---

## Option B — npm (after publishing `@cly-org/switchbot-codex-plugin`)

Copy and paste into Codex:

```
请帮我安装 SwitchBot Codex 插件：
1. npm install -g @cly-org/switchbot-codex-plugin
2. switchbot-codex-install

完成后提示我运行 `switchbot auth login`。
```

---

After auth completes, ask Codex:

> List my SwitchBot devices and tell me which ones are currently on.
