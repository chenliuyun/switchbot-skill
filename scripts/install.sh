#!/usr/bin/env bash

set -euo pipefail

agent="claude-global"
workspace_path=""
mode="symlink"
install_cli="false"
init_policy="false"
force="false"

show_usage() {
  cat <<'EOF'
SwitchBot skill installer

Usage:
  ./scripts/install.sh --agent claude-global [--install-cli] [--init-policy]
  ./scripts/install.sh --agent copilot --workspace-path /path/to/workspace

Agents:
  claude-global   Install the full skill under ~/.claude/skills/switchbot
  claude-project  Install the full skill under <workspace>/.claude/skills/switchbot
  copilot         Write <workspace>/.github/copilot-instructions.md
  cursor          Write <workspace>/.cursor/rules/switchbot.mdc
  cursor-legacy   Write <workspace>/.cursorrules
  gemini-global   Write ~/.gemini/GEMINI.md
  gemini-project  Write <workspace>/GEMINI.md
  codex-global    Write ~/.codex/AGENTS.md
  codex-project   Write <workspace>/AGENTS.md
  openclaw-staging Stage a future plugin layout under <workspace>/.openclaw/staging/plugins/switchbot

Notes:
  - This script automates today's file-based installs. It does not publish the
    future OpenClaw / ClawHub plugin.
  - --install-cli runs: npm install -g @switchbot/openapi-cli
  - --init-policy creates ~/.config/openclaw/switchbot/policy.yaml if it does not exist.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      agent="$2"
      shift 2
      ;;
    --workspace-path)
      workspace_path="$2"
      shift 2
      ;;
    --mode)
      mode="$2"
      shift 2
      ;;
    --install-cli)
      install_cli="true"
      shift
      ;;
    --init-policy)
      init_policy="true"
      shift
      ;;
    --force)
      force="true"
      shift
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      show_usage >&2
      exit 1
      ;;
  esac
done

case "$agent" in
  claude-global|claude-project|copilot|cursor|cursor-legacy|gemini-global|gemini-project|codex-global|codex-project|openclaw-staging)
    ;;
  *)
    echo "Unsupported agent target: $agent" >&2
    exit 1
    ;;
esac

case "$mode" in
  symlink|copy)
    ;;
  *)
    echo "Unsupported mode: $mode" >&2
    exit 1
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_file="$repo_root/SKILL.md"
policy_path="$HOME/.config/openclaw/switchbot/policy.yaml"

require_workspace_path() {
  if [[ -z "$workspace_path" ]]; then
    echo "This agent target requires --workspace-path." >&2
    exit 1
  fi

  if [[ ! -d "$workspace_path" ]]; then
    echo "Workspace path does not exist: $workspace_path" >&2
    exit 1
  fi
}

strip_frontmatter() {
  awk '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { in_frontmatter = 0; next }
    !in_frontmatter { print }
  ' "$skill_file"
}

write_file() {
  local destination="$1"
  mkdir -p "$(dirname "$destination")"
  cat > "$destination"
}

remove_existing_path() {
  local destination="$1"

  if [[ ! -e "$destination" && ! -L "$destination" ]]; then
    return
  fi

  if [[ "$force" != "true" ]]; then
    echo "Path already exists: $destination. Re-run with --force to replace it." >&2
    exit 1
  fi

  rm -rf "$destination"
}

copy_skill_tree() {
  local destination="$1"

  remove_existing_path "$destination"
  mkdir -p "$destination"
  find "$repo_root" -mindepth 1 -maxdepth 1 ! -name .git -exec cp -R {} "$destination/" \;
}

link_or_copy_skill_tree() {
  local destination="$1"

  remove_existing_path "$destination"
  mkdir -p "$(dirname "$destination")"

  if [[ "$mode" == "copy" ]]; then
    copy_skill_tree "$destination"
    return
  fi

  if ln -s "$repo_root" "$destination" 2>/dev/null; then
    return
  fi

  echo "Symlink creation failed; falling back to copy mode." >&2
  copy_skill_tree "$destination"
}

if [[ "$install_cli" == "true" ]]; then
  npm install -g @switchbot/openapi-cli
fi

if [[ "$init_policy" == "true" ]]; then
  if ! command -v switchbot >/dev/null 2>&1; then
    echo "switchbot CLI is not available. Re-run with --install-cli or install it first." >&2
    exit 1
  fi

  if [[ ! -f "$policy_path" ]]; then
    switchbot policy new --version 0.2
  fi

  switchbot policy validate
fi

cursor_rule_content() {
  cat <<'EOF'
---
description: Drive SwitchBot smart-home devices via the switchbot CLI. Trigger on smart-home or device-control questions.
globs:
  - "**/*"
alwaysApply: false
---

EOF
  strip_frontmatter
}

case "$agent" in
  claude-global)
    destination="$HOME/.claude/skills/switchbot"
    link_or_copy_skill_tree "$destination"
    echo "Installed Claude Code skill at $destination"
    ;;
  claude-project)
    require_workspace_path
    destination="$workspace_path/.claude/skills/switchbot"
    link_or_copy_skill_tree "$destination"
    echo "Installed project-local Claude Code skill at $destination"
    ;;
  copilot)
    require_workspace_path
    destination="$workspace_path/.github/copilot-instructions.md"
    strip_frontmatter | write_file "$destination"
    echo "Installed Copilot instructions at $destination"
    ;;
  cursor)
    require_workspace_path
    destination="$workspace_path/.cursor/rules/switchbot.mdc"
    cursor_rule_content | write_file "$destination"
    echo "Installed Cursor rule at $destination"
    ;;
  cursor-legacy)
    require_workspace_path
    destination="$workspace_path/.cursorrules"
    strip_frontmatter | write_file "$destination"
    echo "Installed legacy Cursor rules at $destination"
    ;;
  gemini-global)
    destination="$HOME/.gemini/GEMINI.md"
    strip_frontmatter | write_file "$destination"
    echo "Installed Gemini global instructions at $destination"
    ;;
  gemini-project)
    require_workspace_path
    destination="$workspace_path/GEMINI.md"
    strip_frontmatter | write_file "$destination"
    echo "Installed Gemini project instructions at $destination"
    ;;
  codex-global)
    destination="$HOME/.codex/AGENTS.md"
    strip_frontmatter | write_file "$destination"
    echo "Installed Codex global instructions at $destination"
    ;;
  codex-project)
    require_workspace_path
    destination="$workspace_path/AGENTS.md"
    strip_frontmatter | write_file "$destination"
    echo "Installed Codex project instructions at $destination"
    ;;
  openclaw-staging)
    require_workspace_path
    destination="$workspace_path/.openclaw/staging/plugins/switchbot"
    link_or_copy_skill_tree "$destination"
    echo "Staged OpenClaw plugin preview at $destination"
    ;;
esac

if ! command -v switchbot >/dev/null 2>&1; then
  echo "switchbot CLI is not on PATH yet. Re-run with --install-cli or install @switchbot/openapi-cli manually." >&2
fi

echo "Next step: run switchbot config set-token to configure credentials if you have not already."