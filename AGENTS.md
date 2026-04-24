# SwitchBot Skill Repo Protocol For Non-Claude Agents

Use this file when you are not Claude Code and are installing or operating this
repo through Copilot, Cursor, Gemini, Codex, or another agent.

## Read order

1. `INSTALL_FOR_AGENTS.md`
2. `README.md`
3. `SKILL.md`
4. `docs/agents/<target>.md` if the target agent has a dedicated recipe
5. `troubleshooting.md` if installation or verification fails

## Trust boundary

- Do not ask the user to paste SwitchBot token or secret into chat.
- When credentials are needed, have the user run `switchbot config set-token`
  interactively in their own terminal.
- Treat the `switchbot` CLI as the authority for commands, flags, and device
  behavior. Do not invent command names or REST calls.

## Preferred install path

Use the installer scripts in `scripts/` rather than replaying the README by
hand.

- PowerShell: `scripts/install.ps1`
- Bash: `scripts/install.sh`
- PowerShell upgrade: `scripts/upgrade.ps1`
- Bash upgrade: `scripts/upgrade.sh`
- PowerShell uninstall: `scripts/uninstall.ps1`
- Bash uninstall: `scripts/uninstall.sh`

These scripts automate the current file-based install paths for Claude Code,
Copilot, Cursor, Gemini, and Codex, plus an `openclaw-staging` preview target
for the future plugin layout.

## Important limit

This repo does not yet ship a published OpenClaw / ClawHub plugin. Current
installation is a scripted wrapper around today's file-based integration
mechanisms.

## Verification baseline

After installation, verify at minimum:

```bash
switchbot doctor
switchbot devices list
```

Then verify the target agent responds correctly to:

> List my SwitchBot devices and tell me which ones are currently on.

The agent should bootstrap via `switchbot agent-bootstrap --compact` and should
not ask for secrets.
