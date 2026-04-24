# Using this skill with Cursor

Cursor's "Rules" system — either legacy `.cursorrules` (single file, project root) or the modern `.cursor/rules/*.mdc` (per-workspace, scoped) — feeds prose instructions into the model's system prompt. `SKILL.md`'s body is a drop-in fit.

## Prerequisites

```bash
npm install -g @switchbot/openapi-cli
switchbot config set-token <token> <secret>
switchbot policy new && switchbot policy validate
```

The skill drives the CLI — Cursor needs the `switchbot` binary on PATH.

## Option A: modern workspace rule (recommended)

Cursor picks up `.cursor/rules/*.mdc` files automatically per workspace.

```bash
mkdir -p .cursor/rules
cp SKILL.md .cursor/rules/switchbot.mdc
```

Then edit `.cursor/rules/switchbot.mdc` and replace the top YAML front-matter with Cursor's `.mdc` header:

```diff
- ---
- name: switchbot
- description: Use when the user mentions SwitchBot devices, smart-home automation, or asks about controlling lights, locks, curtains, sensors, plugs, or IR appliances (TV/AC/fan). Teaches the agent how to drive the authoritative `switchbot` CLI safely, read user preferences from `policy.yaml`, and respect safety tiers.
- ---
+ ---
+ description: Drive SwitchBot smart-home devices via the switchbot CLI. Trigger on smart-home / device-control questions.
+ globs:
+   - "**/*"
+ alwaysApply: false
+ ---
```

`alwaysApply: false` + the description field means the rule is loaded on demand when the user's query looks smart-home-related. If you want it always on (single-purpose workspace), set `alwaysApply: true` and delete `globs`.

## Option B: legacy `.cursorrules`

Single-file, project root. Cursor always loads it into the system prompt.

```bash
cp SKILL.md .cursorrules
```

Then strip the top YAML front-matter (Cursor ignores it but it's noise). Good for a one-off workspace dedicated to home automation.

## Global (across all Cursor projects)

Cursor doesn't have a well-documented global rules location today. The pragmatic path is to clone the skill once and symlink `.cursor/rules/switchbot.mdc` in each project you want it in:

```bash
# once
git clone <repo-url> ~/.config/switchbot-skill

# per project
mkdir -p .cursor/rules
ln -s ~/.config/switchbot-skill/docs/agents/_cursor-rule.mdc .cursor/rules/switchbot.mdc
```

(Create `_cursor-rule.mdc` yourself from Option A if you want this pattern.)

## Verification

In a Cursor chat with the rule loaded:

```text
You: turn on the hallway lamp
Cursor: [suggests `switchbot devices command <id> turnOn` with the aliased deviceId]
```

If Cursor invents a deviceId or ignores `policy.yaml`, the rule probably didn't load — open Settings → Rules, confirm `switchbot.mdc` is present and enabled, and that the query matches the `description` trigger.
