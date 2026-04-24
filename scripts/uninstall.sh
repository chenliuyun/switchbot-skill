#!/usr/bin/env bash

set -euo pipefail

agent="claude-global"
workspace_path=""
remove_cli="false"
remove_policy="false"
remove_credentials="false"
force="false"

show_usage() {
  cat <<'EOF'
SwitchBot skill uninstaller

Usage:
  ./scripts/uninstall.sh --agent claude-global
  ./scripts/uninstall.sh --agent copilot --workspace-path /path/to/workspace

Options:
  --remove-cli          Uninstall @switchbot/openapi-cli globally
  --remove-policy       Remove ~/.config/openclaw/switchbot and ~/.switchbot/audit.log
  --remove-credentials  Remove ~/.switchbot credentials directory
  --force               Remove non-Claude agent files even if they do not look script-managed
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
    --remove-cli)
      remove_cli="true"
      shift
      ;;
    --remove-policy)
      remove_policy="true"
      shift
      ;;
    --remove-credentials)
      remove_credentials="true"
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

remove_path_if_exists() {
  local destination="$1"
  if [[ -e "$destination" || -L "$destination" ]]; then
    rm -rf "$destination"
  fi
}

remove_managed_file() {
  local destination="$1"

  if [[ ! -f "$destination" ]]; then
    return
  fi

  if [[ "$force" == "true" ]]; then
    rm -f "$destination"
    return
  fi

  if grep -q '# SwitchBot skill' "$destination"; then
    rm -f "$destination"
    return
  fi

  echo "Skipped $destination because it does not look script-managed. Re-run with --force to remove it anyway." >&2
}

case "$agent" in
  claude-global)
    remove_path_if_exists "$HOME/.claude/skills/switchbot"
    ;;
  claude-project)
    require_workspace_path
    remove_path_if_exists "$workspace_path/.claude/skills/switchbot"
    ;;
  copilot)
    require_workspace_path
    remove_managed_file "$workspace_path/.github/copilot-instructions.md"
    ;;
  cursor)
    require_workspace_path
    remove_managed_file "$workspace_path/.cursor/rules/switchbot.mdc"
    ;;
  cursor-legacy)
    require_workspace_path
    remove_managed_file "$workspace_path/.cursorrules"
    ;;
  gemini-global)
    remove_managed_file "$HOME/.gemini/GEMINI.md"
    ;;
  gemini-project)
    require_workspace_path
    remove_managed_file "$workspace_path/GEMINI.md"
    ;;
  codex-global)
    remove_managed_file "$HOME/.codex/AGENTS.md"
    ;;
  codex-project)
    require_workspace_path
    remove_managed_file "$workspace_path/AGENTS.md"
    ;;
  openclaw-staging)
    require_workspace_path
    remove_path_if_exists "$workspace_path/.openclaw/staging/plugins/switchbot"
    ;;
esac

if [[ "$remove_policy" == "true" ]]; then
  remove_path_if_exists "$HOME/.config/openclaw/switchbot"
  remove_path_if_exists "$HOME/.switchbot/audit.log"
fi

if [[ "$remove_credentials" == "true" ]]; then
  remove_path_if_exists "$HOME/.switchbot"
fi

if [[ "$remove_cli" == "true" ]]; then
  npm uninstall -g @switchbot/openapi-cli
fi

echo "Uninstall complete."