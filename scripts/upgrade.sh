#!/usr/bin/env bash

set -euo pipefail

agent="claude-global"
workspace_path=""
mode="symlink"
ref="main"
skip_cli="false"
skip_verify="false"
skip_git_pull="false"
allow_dirty="false"

show_usage() {
  cat <<'EOF'
SwitchBot skill upgrader

Usage:
  ./scripts/upgrade.sh --agent claude-global
  ./scripts/upgrade.sh --agent copilot --workspace-path /path/to/workspace

What it does:
  1. Verifies the repo is safe to update
  2. Pulls the latest repo content from origin/<ref>
  3. Re-runs the installer for the selected agent target
  4. Updates @switchbot/openapi-cli unless --skip-cli is set
  5. Runs basic health checks unless --skip-verify is set

Notes:
  - Use --allow-dirty only if you know the local changes are intentional.
  - Use --skip-git-pull only for testing the wrapper without fetching remote updates.
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
    --ref)
      ref="$2"
      shift 2
      ;;
    --skip-cli)
      skip_cli="true"
      shift
      ;;
    --skip-verify)
      skip_verify="true"
      shift
      ;;
    --skip-git-pull)
      skip_git_pull="true"
      shift
      ;;
    --allow-dirty)
      allow_dirty="true"
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
install_script="$repo_root/scripts/install.sh"
policy_path="$HOME/.config/openclaw/switchbot/policy.yaml"

assert_git_repo() {
  if [[ "$(git -C "$repo_root" rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]]; then
    echo "Not a git repository: $repo_root" >&2
    exit 1
  fi
}

assert_clean_worktree() {
  if [[ "$allow_dirty" == "true" ]]; then
    return
  fi

  if [[ -n "$(git -C "$repo_root" status --porcelain)" ]]; then
    echo "Repository has local changes. Commit or stash them first, or re-run with --allow-dirty." >&2
    exit 1
  fi
}

update_repo() {
  if [[ "$skip_git_pull" == "true" ]]; then
    return
  fi

  current_branch="$(git -C "$repo_root" branch --show-current)"
  if [[ "$current_branch" != "$ref" ]]; then
    git -C "$repo_root" checkout "$ref"
  fi

  git -C "$repo_root" pull --ff-only origin "$ref"
}

invoke_installer() {
  args=(--agent "$agent" --mode "$mode" --force)

  if [[ -n "$workspace_path" ]]; then
    args+=(--workspace-path "$workspace_path")
  fi

  if [[ "$skip_cli" != "true" ]]; then
    args+=(--install-cli)
  fi

  "$install_script" "${args[@]}"
}

invoke_verification() {
  if [[ "$skip_verify" == "true" ]]; then
    return
  fi

  if ! command -v switchbot >/dev/null 2>&1; then
    echo "switchbot CLI is not on PATH after upgrade." >&2
    exit 1
  fi

  switchbot --version
  switchbot doctor

  if [[ -f "$policy_path" ]]; then
    switchbot policy validate
  fi
}

assert_git_repo
assert_clean_worktree
update_repo
invoke_installer
invoke_verification

echo "Upgrade complete. Restart the target agent or reopen the workspace to load the refreshed instructions."