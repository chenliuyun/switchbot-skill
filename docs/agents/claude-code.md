# Using this skill with Claude Code

**Status: native.** Claude Code reads `SKILL.md` directly via the Skill tool — the YAML front-matter (`name`, `description`) is the format Anthropic's CLI expects. No adaptation required.

## Install

```bash
# 1. Install the CLI (the skill drives this; it must be on PATH)
npm install -g @switchbot/openapi-cli

# 2. Configure credentials once
switchbot config set-token <token> <secret>

# 3. Create and validate a policy (v2.8.0+)
switchbot policy new
$EDITOR ~/.config/openclaw/switchbot/policy.yaml   # fill in aliases
switchbot policy validate
```

## Install the skill

Pick one:

### Global (works in every Claude Code session)

```bash
mkdir -p ~/.claude/skills
ln -s "$PWD" ~/.claude/skills/switchbot           # macOS / Linux / Git Bash
# or: cp -r . ~/.claude/skills/switchbot          # if symlinks are restricted
```

On Windows PowerShell:

```powershell
New-Item -ItemType SymbolicLink `
  -Path "$env:USERPROFILE\.claude\skills\switchbot" `
  -Target $PWD
```

### Project-local (only when you're in a specific workspace)

```bash
mkdir -p .claude/skills
ln -s <path-to-this-repo> .claude/skills/switchbot
```

## How Claude Code loads it

When the user mentions SwitchBot devices, smart-home automation, or any of the triggers in the skill's `description` field, Claude Code calls the `Skill` tool to load `SKILL.md`. The skill body then tells the model to:

1. Run `switchbot agent-bootstrap --compact` for session context.
2. Read the user's `policy.yaml` for aliases + confirmations.
3. Prefer the CLI's `--json` mode and respect safety tiers.

## Verification

```text
You: turn off the bedroom light
Claude: [invokes Skill: switchbot]
Claude: [runs `switchbot agent-bootstrap --compact` then `switchbot devices command <id> turnOff`]
```

If Claude Code doesn't pick up the skill, check that:

- `manifest.json` and `SKILL.md` both live directly under `~/.claude/skills/switchbot/` (not a sub-folder).
- `@switchbot/openapi-cli` is ≥ 2.8.0 on `PATH` — the skill's `authority.cli` is pinned.
- Restart the Claude Code session once after installing; skills are discovered at session start.
