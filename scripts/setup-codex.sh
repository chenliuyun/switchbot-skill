#!/usr/bin/env bash
# scripts/setup-codex.sh
#
# One-shot Codex install for the SwitchBot skill.
#
# What this script does (automated):
#   1. Install @switchbot/openapi-cli globally via npm
#   2. Enable plugin_hooks = true in ~/.codex/config.toml
#   3. Write AGENTS.md to ~/.codex/ (file-based skill install)
#   4. Launch switchbot auth login  ← browser opens; you log in once
#   5. Run switchbot doctor to verify everything is working
#
# The only manual step is signing in to SwitchBot in the browser (step 4).
#
# Usage:
#   bash scripts/setup-codex.sh
#   bash scripts/setup-codex.sh --no-auth   # skip auth (already logged in)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_CONFIG="$HOME/.codex/config.toml"
SKIP_AUTH="false"

for arg in "$@"; do
  case "$arg" in
    --no-auth) SKIP_AUTH="true" ;;
    --help|-h)
      echo "Usage: bash scripts/setup-codex.sh [--no-auth]"
      echo "  --no-auth   Skip the browser login step (use if already authenticated)"
      exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓  %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!  %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. Install CLI ─────────────────────────────────────────────────────────────
step "Installing @switchbot/openapi-cli"
if ! command -v npm >/dev/null 2>&1; then
  die "npm not found. Install Node.js >= 18 first: https://nodejs.org"
fi
npm install -g @switchbot/openapi-cli@latest
CLI_VER="$(switchbot --version 2>/dev/null || true)"
ok "CLI ready: ${CLI_VER:-unknown version}"

# ── 2. Enable plugin_hooks in ~/.codex/config.toml ────────────────────────────
step "Enabling plugin_hooks in $CODEX_CONFIG"
mkdir -p "$(dirname "$CODEX_CONFIG")"

if [[ ! -f "$CODEX_CONFIG" ]]; then
  printf '[features]\nplugin_hooks = true\n' > "$CODEX_CONFIG"
  ok "Created config.toml with plugin_hooks = true"
elif grep -qE '^plugin_hooks[[:space:]]*=[[:space:]]*true' "$CODEX_CONFIG"; then
  ok "plugin_hooks already enabled"
elif grep -qE '^plugin_hooks[[:space:]]*=' "$CODEX_CONFIG"; then
  awk '{gsub(/^plugin_hooks[[:space:]]*=.*/, "plugin_hooks = true")}1' \
    "$CODEX_CONFIG" > "$CODEX_CONFIG.tmp" && mv "$CODEX_CONFIG.tmp" "$CODEX_CONFIG"
  ok "Updated plugin_hooks = true"
elif grep -qE '^\[features\]' "$CODEX_CONFIG"; then
  awk '/^\[features\]/{print; print "plugin_hooks = true"; next}1' \
    "$CODEX_CONFIG" > "$CODEX_CONFIG.tmp" && mv "$CODEX_CONFIG.tmp" "$CODEX_CONFIG"
  ok "Added plugin_hooks = true under existing [features]"
else
  printf '\n[features]\nplugin_hooks = true\n' >> "$CODEX_CONFIG"
  ok "Appended [features] section with plugin_hooks = true"
fi

# ── 3. Install skill instructions for Codex ───────────────────────────────────
step "Installing SwitchBot skill instructions for Codex"
bash "$REPO_ROOT/scripts/install.sh" --agent codex-global --force
ok "AGENTS.md written to ~/.codex/"

# ── 4. Authenticate ────────────────────────────────────────────────────────────
if [[ "$SKIP_AUTH" == "true" ]]; then
  ok "Skipping auth (--no-auth)"
else
  step "SwitchBot login"
  printf 'A browser window will open — sign in with your SwitchBot account.\n'
  printf 'The CLI stores credentials in the OS keychain; you only do this once.\n\n'
  printf 'Headless / SSH environment? Run instead:\n'
  printf '  switchbot auth login --no-open\n\n'
  switchbot auth login
fi

# ── 5. Verify ──────────────────────────────────────────────────────────────────
step "Verifying setup"
switchbot --version
if switchbot doctor; then
  printf '\n'
  ok "Setup complete. Try it:"
  printf '  switchbot devices list\n'
else
  warn "switchbot doctor reported issues — follow the fix commands above, then re-run this script with --no-auth."
  exit 1
fi
