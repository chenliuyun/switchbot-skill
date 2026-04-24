# SwitchBot Skill Installation Guide for AI Agents

Read this entire file, then follow the steps. Do not ask the user to paste
their SwitchBot token or secret into chat. Have them run the interactive CLI
prompt locally when credentials are needed.

Target: about 10-15 minutes to a working installation for Claude Code,
Copilot, Cursor, Gemini, or Codex using this repo's installer scripts.

## Step 0: If you are not Claude Code

Read [AGENTS.md](./AGENTS.md) first. It is the non-Claude operating protocol
for this repo: read order, trust boundary, install targets, and what stays
manual.

If you fetched this file by URL without cloning yet, the companion files live
at:

- `https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/AGENTS.md`
- `https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/README.md`
- `https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/SKILL.md`
- `https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/troubleshooting.md`

## Step 1: Ask 3 questions

Ask the user only what you need to choose the install target:

1. Which agent are we installing for: Claude Code, Copilot, Cursor, Gemini, or Codex?
2. Should this be global or only for one workspace?
3. If workspace-local, what path should be used?

Do not ask for the SwitchBot token or secret in chat.

## Step 2: Clone or update the repo

If the repo is not present yet:

```bash
git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
cd ~/switchbot-skill
```

If it already exists:

```bash
cd ~/switchbot-skill
git pull origin main
```

If you are already inside the repo, keep using the current checkout.

## Step 3: Run the installer

Choose the script for the user's shell:

- PowerShell on Windows: `scripts/install.ps1`
- Bash/zsh on macOS/Linux: `scripts/install.sh`

Supported installer targets:

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

Recommended mappings:

- Claude Code global install -> `claude-global`
- Claude Code workspace-local install -> `claude-project`
- GitHub Copilot -> `copilot`
- Cursor modern rules -> `cursor`
- Cursor legacy `.cursorrules` -> `cursor-legacy`
- Gemini CLI / app -> `gemini-global` or `gemini-project`
- Codex -> `codex-global` or `codex-project`
- OpenClaw future-plugin preview -> `openclaw-staging`

Examples:

```powershell
pwsh ./scripts/install.ps1 -Agent claude-global -InstallCli -InitPolicy
pwsh ./scripts/install.ps1 -Agent copilot -WorkspacePath C:\path\to\workspace -InstallCli -InitPolicy
```

```bash
./scripts/install.sh --agent claude-global --install-cli --init-policy
./scripts/install.sh --agent copilot --workspace-path /path/to/workspace --install-cli --init-policy
```

What the installer does:

- installs or links the full skill tree for Claude Code
- writes front-matter-free instruction files for Copilot, Gemini, and Codex
- writes a ready-to-load `.mdc` rule for Cursor
- stages a future plugin preview under `<workspace>/.openclaw/staging/plugins/switchbot`
- optionally installs `@switchbot/openapi-cli`
- optionally creates and validates `~/.config/openclaw/switchbot/policy.yaml`

## Step 4: Credentials

Have the user run this themselves in a terminal:

```bash
switchbot config set-token
```

This prompt is interactive. The user should paste their token and secret into
the terminal prompt, not into chat.

If they do not know where to get the token/secret, tell them:

1. Open the SwitchBot app.
2. Go to Profile -> Preferences.
3. Tap App Version 10 times.
4. Open Developer Options and copy Token + Secret.

## Step 5: Verify the CLI

Run:

```bash
switchbot --version
switchbot doctor
switchbot devices list
```

Success criteria:

- `switchbot --version` prints a version number
- `switchbot doctor` ends with `0 fail`
- `switchbot devices list` returns the user's devices

If `doctor` fails, read `troubleshooting.md` and fix the failing check before
moving on.

## Step 6: Verify the agent install

Tell the user to start or restart the target agent or workspace, then try:

> List my SwitchBot devices and tell me which ones are currently on.

Expected behavior:

1. The agent loads the installed instructions or skill.
2. The agent runs `switchbot agent-bootstrap --compact` first.
3. The agent reads `~/.config/openclaw/switchbot/policy.yaml` if it exists.
4. The agent uses `--json` output for parsing.
5. The agent does not invent device IDs or ask for secrets.

## Step 7: Optional OpenClaw-aware event flow

If the user wants live events into an OpenClaw-aware setup, the CLI can forward
MQTT events to a local gateway:

```bash
switchbot events mqtt-tail --sink openclaw --openclaw-url http://localhost:18789 --openclaw-token "$OPENCLAW_TOKEN"
```

This is optional. It is not the same thing as a published OpenClaw plugin.

## Upgrade

To upgrade later, prefer the dedicated upgrader rather than replaying the
install steps by hand.

PowerShell examples:

```powershell
pwsh ./scripts/upgrade.ps1 -Agent claude-global
pwsh ./scripts/upgrade.ps1 -Agent copilot -WorkspacePath C:\path\to\workspace
```

Bash examples:

```bash
./scripts/upgrade.sh --agent claude-global
./scripts/upgrade.sh --agent copilot --workspace-path /path/to/workspace
```

What the upgrader does:

- updates the local repo from `origin/main`
- re-runs the installer for the selected target
- updates `@switchbot/openapi-cli` unless explicitly skipped
- runs `switchbot --version` and `switchbot doctor`
- validates `policy.yaml` if it exists

If you only need the latest repo content without reinstalling the target files,
the manual fallback is still:

```bash
cd ~/switchbot-skill
git pull origin main
```

If you only need to update the CLI:

```bash
npm install -g @switchbot/openapi-cli
```
