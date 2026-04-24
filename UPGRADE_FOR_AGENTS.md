# SwitchBot Skill Upgrade Guide for AI Agents

Read this entire file, then follow the steps. Do not ask the user to paste
their SwitchBot token or secret into chat.

Target: about 5-10 minutes to refresh an existing SwitchBot skill install,
update the CLI, and validate the target agent still loads the right context.

## Step 0: If you are not Claude Code

Read [AGENTS.md](./AGENTS.md) first.

If you fetched this file by URL without cloning yet, the companion files live
at:

- `https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/AGENTS.md`
- `https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/INSTALL_FOR_AGENTS.md`
- `https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/README.md`
- `https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/troubleshooting.md`

## Step 1: Ask 2 questions

Ask only what you need:

1. Which existing target should be refreshed: `claude-global`, `copilot`, `cursor`, `gemini-global`, `codex-project`, `openclaw-staging`, or another supported target?
2. If the target is workspace-scoped or `openclaw-staging`, what workspace path should be used?

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

## Step 3: Run the upgrader

Use the matching shell wrapper:

- PowerShell on Windows: `scripts/upgrade.ps1`
- Bash/zsh on macOS/Linux: `scripts/upgrade.sh`

Supported targets:

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

Examples:

```powershell
pwsh ./scripts/upgrade.ps1 -Agent claude-global
pwsh ./scripts/upgrade.ps1 -Agent cursor -WorkspacePath C:\path\to\workspace
pwsh ./scripts/upgrade.ps1 -Agent openclaw-staging -WorkspacePath C:\path\to\workspace
```

```bash
./scripts/upgrade.sh --agent claude-global
./scripts/upgrade.sh --agent cursor --workspace-path /path/to/workspace
./scripts/upgrade.sh --agent openclaw-staging --workspace-path /path/to/workspace
```

What the upgrader does:

- updates the local repo from `origin/main`
- refreshes the selected install target
- updates `@switchbot/openapi-cli`
- runs `switchbot --version` and `switchbot doctor`
- validates `policy.yaml` if it exists

## Step 4: Verify the agent

Tell the user to restart the target agent or reopen the workspace, then try:

> List my SwitchBot devices and tell me which ones are currently on.

Expected behavior:

1. The agent loads the refreshed instructions or skill.
2. The agent runs `switchbot agent-bootstrap --compact` first.
3. The agent does not ask for secrets.
4. The agent does not invent device IDs.

## Step 5: Optional uninstall or rollback

If the user wants to remove the current install target instead of upgrading it,
use `scripts/uninstall.ps1` or `scripts/uninstall.sh`.
