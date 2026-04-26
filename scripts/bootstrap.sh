#!/usr/bin/env bash
# bootstrap.sh — one-command SwitchBot skill installer
#
# Usage (no git required):
#   curl -fsSL https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/bootstrap.sh | bash
#
# Or, from a cloned repo:
#   bash scripts/bootstrap.sh [flags]
#
# Flags:
#   --yes / --auto      Non-interactive; accept all defaults
#   --dry-run           Print what would happen; write nothing
#   --skip-token        Skip credential setup (already configured)
#   --skip-verify       Skip doctor + devices list verification
#   --no-cli            Skip npm install of @switchbot/openapi-cli
#   --agent <target>    Force a specific agent target (bypass auto-detect)
#   --force             Overwrite existing skill installations

set -euo pipefail

TARBALL_URL="https://github.com/chenliuyun/switchbot-skill/archive/refs/heads/main.tar.gz"
MIRROR_URL="https://ghproxy.com/https://github.com/chenliuyun/switchbot-skill/archive/refs/heads/main.tar.gz"
REPO="chenliuyun/switchbot-skill"

# --- flags ---
AUTO=false
DRY_RUN=false
SKIP_TOKEN=false
SKIP_VERIFY=false
NO_CLI=false
FORCE_AGENT=""
FORCE_FLAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|--auto)   AUTO=true; shift ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --skip-token)   SKIP_TOKEN=true; shift ;;
    --skip-verify)  SKIP_VERIFY=true; shift ;;
    --no-cli)       NO_CLI=true; shift ;;
    --agent)        FORCE_AGENT="$2"; shift 2 ;;
    --force)        FORCE_FLAG="--force"; shift ;;
    --help|-h)
      grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown flag: $1  (try --help)" >&2
      exit 1
      ;;
  esac
done

# --- colours (disabled when not a TTY) ---
if [[ -t 1 ]]; then
  BOLD='\033[1m'; DIM='\033[2m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'
else
  BOLD=''; DIM=''; GREEN=''; YELLOW=''; RED=''; RESET=''
fi

step()  { echo -e "${BOLD}$1${RESET}"; }
ok()    { echo -e "  ${GREEN}✓${RESET} $1"; }
warn()  { echo -e "  ${YELLOW}!${RESET} $1"; }
die()   { echo -e "  ${RED}✗${RESET} $1" >&2; exit 1; }
dryrun(){ echo -e "  ${DIM}(dry-run) $1${RESET}"; }

# --- telemetry (optional, sourced if available) ---
_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [[ -n "$_SELF_DIR" && -f "$_SELF_DIR/telemetry.sh" ]]; then
  # shellcheck source=scripts/telemetry.sh
  source "$_SELF_DIR/telemetry.sh"
else
  prompt_telemetry_opt_in() { :; }
  report_telemetry() { :; }
fi

# --- rollback ---
INSTALLED_PATHS=()

cleanup() {
  local exit_code=$?
  if [[ ${#INSTALLED_PATHS[@]} -gt 0 && $exit_code -ne 0 ]]; then
    echo ""
    warn "Install failed (exit $exit_code). Rolling back..."
    for p in "${INSTALLED_PATHS[@]}"; do
      if [[ -e "$p" || -L "$p" ]]; then
        rm -rf "$p"
        warn "  removed: $p"
      fi
    done
    report_telemetry "failed_at_exit_$exit_code" "unknown" || true
  fi
}
trap cleanup EXIT

# ─────────────────────────────────────────────
# [1/7] Prerequisites
# ─────────────────────────────────────────────
step "[1/7] Checking prerequisites..."

if ! command -v node >/dev/null 2>&1; then
  die "Node.js is required but not found.\n  Install from https://nodejs.org (v18+) and re-run."
fi

node_major=$(node --version 2>/dev/null | sed 's/v\([0-9]*\).*/\1/')
if [[ "${node_major:-0}" -lt 18 ]]; then
  die "Node.js v18+ required. Found: $(node --version). Upgrade at https://nodejs.org"
fi

if ! command -v npm >/dev/null 2>&1; then
  die "npm is required but not found. It ships with Node.js — reinstall Node from https://nodejs.org"
fi

ok "Node $(node --version), npm $(npm --version)"

# ─────────────────────────────────────────────
# [2/7] Install SwitchBot CLI
# ─────────────────────────────────────────────
step "[2/7] Installing SwitchBot CLI..."

REQUIRED_CLI_VERSION="3.3.0"

# Returns 0 if $actual is >= $required (semver-compared via sort -V).
cli_version_meets() {
  local actual="$1" required="$2"
  [[ "$(printf '%s\n%s\n' "$required" "$actual" | sort -V | head -1)" == "$required" ]]
}

check_cli_version() {
  local actual
  actual="$(switchbot --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [[ -z "$actual" ]]; then
    die "'switchbot --version' produced no version. Reinstall the CLI:\n  npm install -g @switchbot/openapi-cli@latest"
  fi
  if ! cli_version_meets "$actual" "$REQUIRED_CLI_VERSION"; then
    die "switchbot $actual is below the required floor $REQUIRED_CLI_VERSION.\n  The skill's envelope/cache/idempotency guidance assumes 3.3.0 behavior.\n  Upgrade:\n    npm install -g @switchbot/openapi-cli@latest"
  fi
  ok "CLI version $actual meets floor $REQUIRED_CLI_VERSION"
}

if [[ "$NO_CLI" == "true" ]]; then
  warn "Skipping CLI install (--no-cli)."
elif command -v switchbot >/dev/null 2>&1; then
  current_ver=$(switchbot --version 2>/dev/null || echo "unknown")
  ok "CLI already installed: $current_ver"
  if [[ "$DRY_RUN" != "true" ]]; then
    check_cli_version
  fi
else
  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "npm install -g @switchbot/openapi-cli"
  else
    echo "  Installing @switchbot/openapi-cli..."
    npm install -g @switchbot/openapi-cli
    ok "CLI installed: $(switchbot --version 2>/dev/null)"
    check_cli_version
  fi
fi

# ─────────────────────────────────────────────
# [3/7] Download skill files
# ─────────────────────────────────────────────
step "[3/7] Downloading skill files..."

SKILL_DIR=""

download_tarball() {
  local dest="$1"
  echo "  Downloading from GitHub..."
  if curl -fsSL --connect-timeout 10 "$TARBALL_URL" | tar xz -C "$dest" --strip-components=1 2>/dev/null; then
    ok "Downloaded (GitHub)"
    return 0
  fi
  warn "GitHub unreachable, trying mirror (ghproxy.com)..."
  if curl -fsSL --connect-timeout 15 "$MIRROR_URL" | tar xz -C "$dest" --strip-components=1; then
    ok "Downloaded (mirror)"
    return 0
  fi
  die "Download failed from both GitHub and mirror.\n  Check network or clone manually:\n  git clone https://github.com/chenliuyun/switchbot-skill.git"
}

# If this script lives inside a cloned repo, use it directly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../SKILL.md" ]]; then
  SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  ok "Using local repo at $SKILL_DIR"
else
  if ! command -v curl >/dev/null 2>&1; then
    die "curl is required to download the skill. Install curl and re-run."
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "curl -fsSL $TARBALL_URL | tar xz (to temp dir)"
    SKILL_DIR="/tmp/switchbot-skill-dry-run"
  else
    SKILL_DIR=$(mktemp -d)
    download_tarball "$SKILL_DIR"
  fi
fi

# ─────────────────────────────────────────────
# [4/7] Detect agents and install skill
# ─────────────────────────────────────────────
step "[4/7] Installing skill into detected agents..."

POLICY_PATH="$HOME/.config/openclaw/switchbot/policy.yaml"
POLICY_NEWLY_CREATED=false
policy_pre_existed=false
[[ -f "$POLICY_PATH" ]] && policy_pre_existed=true

DETECTED_AGENTS=()

detect_agents() {
  if [[ -n "$FORCE_AGENT" ]]; then
    DETECTED_AGENTS=("$FORCE_AGENT")
    return
  fi

  [[ -d "$HOME/.claude" ]]                    && DETECTED_AGENTS+=("claude-global")
  [[ -d "$HOME/.gemini" ]]                    && DETECTED_AGENTS+=("gemini-global")
  [[ -d "$HOME/.codex" ]]                     && DETECTED_AGENTS+=("codex-global")

  # cursor and Copilot both need --workspace-path; skip with a hint
  if [[ -d "$HOME/.cursor" ]]; then
    warn "Cursor detected — skipping (requires --workspace-path; run install.sh manually)"
  fi
  if [[ -d "$HOME/.config/github-copilot" ]]; then
    warn "GitHub Copilot detected — skipping (requires --workspace-path; run install.sh manually)"
  fi

  if [[ ${#DETECTED_AGENTS[@]} -eq 0 ]]; then
    warn "No agent directories detected. Defaulting to claude-global."
    DETECTED_AGENTS=("claude-global")
  fi
}

detect_agents

install_for_agent() {
  local agent="$1"
  local installer="$SKILL_DIR/scripts/install.sh"

  # Determine the destination path for rollback tracking
  local dest pre_existed=false
  case "$agent" in
    claude-global)    dest="$HOME/.claude/skills/switchbot" ;;
    gemini-global)    dest="$HOME/.gemini/GEMINI.md" ;;
    codex-global)     dest="$HOME/.codex/AGENTS.md" ;;
    *)                dest="" ;;
  esac

  if [[ -n "$dest" && ( -e "$dest" || -L "$dest" ) ]]; then
    if [[ -z "${FORCE_FLAG:-}" ]]; then
      ok "Already installed: $agent ($dest) — skipping (use --force to reinstall)"
      return
    fi
    pre_existed=true
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "install.sh --agent $agent --init-policy${FORCE_FLAG:+ $FORCE_FLAG}"
    return
  fi

  bash "$installer" --agent "$agent" --init-policy ${FORCE_FLAG:+$FORCE_FLAG}

  # Only track freshly created paths; don't rollback pre-existing user files
  if [[ "$pre_existed" == "false" && -n "$dest" ]]; then
    INSTALLED_PATHS+=("$dest")
  fi
  ok "Installed: $agent"
}

for agent in "${DETECTED_AGENTS[@]}"; do
  install_for_agent "$agent"
done

# Check if --init-policy created policy.yaml for the first time
if [[ "$policy_pre_existed" == "false" && -f "$POLICY_PATH" ]]; then
  POLICY_NEWLY_CREATED=true
fi

# ─────────────────────────────────────────────
# [5/7] Token setup
# ─────────────────────────────────────────────
step "[5/7] Getting your SwitchBot token..."

token_is_set() {
  command -v switchbot >/dev/null 2>&1 || return 1
  local out
  out=$(switchbot auth keychain describe --json 2>/dev/null || echo '{}')
  # If the keychain backend reports any token stored, skip
  echo "$out" | grep -q '"token"' 2>/dev/null
}

if [[ "$SKIP_TOKEN" == "true" ]]; then
  warn "Skipping token setup (--skip-token)."
elif [[ "$DRY_RUN" == "true" ]]; then
  dryrun "switchbot config set-token  (interactive)"
elif token_is_set; then
  ok "Credentials already configured — skipping."
else
  if [[ "$AUTO" == "true" ]]; then
    warn "Non-interactive mode: skipping token setup. Run 'switchbot config set-token' manually."
  else
    echo ""
    echo -e "  ──────────────────────────────────────────────"
    echo -e "  Get your SwitchBot token from the mobile app:"
    echo -e "  ──────────────────────────────────────────────"
    echo -e "   1. Open the ${BOLD}SwitchBot${RESET} app on your phone"
    echo -e "   2. Tap ${BOLD}Profile${RESET} (bottom right) → ${BOLD}Preferences${RESET}"
    echo -e "   3. Tap ${BOLD}\"App Version\"${RESET} rapidly 10 times"
    echo -e "   4. Tap ${BOLD}Developer Options${RESET} → enable ${BOLD}Cloud Services${RESET}"
    echo -e "   5. Copy the ${BOLD}Token${RESET} and ${BOLD}Secret${RESET} shown there"
    echo -e "  ──────────────────────────────────────────────"
    echo ""
    # read -r with -p requires bash (not sh), but set -euo pipefail requires bash too
    read -r -p $'  Press Enter when ready to paste your credentials \xe2\x96\xb8 '
    echo ""
    switchbot config set-token
    ok "Credentials saved."
  fi
fi

# ─────────────────────────────────────────────
# [6/7] Verify setup
# ─────────────────────────────────────────────
step "[6/7] Verifying setup..."

if [[ "$SKIP_VERIFY" == "true" ]]; then
  warn "Skipping verification (--skip-verify)."
elif [[ "$DRY_RUN" == "true" ]]; then
  dryrun "switchbot doctor && switchbot devices list --json"
elif ! command -v switchbot >/dev/null 2>&1; then
  warn "switchbot CLI not on PATH — skipping verification."
  warn "Run 'switchbot doctor' manually after installation."
else
  if switchbot doctor 2>&1 | grep -q "0 fail"; then
    ok "switchbot doctor passed."
  else
    warn "switchbot doctor reported issues — run 'switchbot doctor' for details."
  fi

  device_count=$(switchbot devices list --json 2>/dev/null \
    | grep -c '"deviceId"' || echo 0)
  if [[ "$device_count" -gt 0 ]]; then
    ok "Found $device_count device(s)."
  else
    warn "No devices returned — check credentials with 'switchbot doctor --section credentials'."
  fi
fi

# ─────────────────────────────────────────────
# [7/7] First-use wizard
# ─────────────────────────────────────────────
step "[7/7] Setting up your preferences..."

run_wizard() {
  local quiet_hours="false"
  local lock_confirm="false"

  echo ""
  echo -e "  Answer 3 quick questions to configure ${BOLD}policy.yaml${RESET}."
  echo -e "  (Press Enter to accept the default shown in brackets.)"
  echo ""

  # Q1: Quiet hours
  local q1_ans
  read -r -p $'  Q1: Block light/plug/AC changes during sleep hours (22:00\xe2\x80\x9307:00)? [Y/n] ' q1_ans
  [[ "${q1_ans:-y}" =~ ^[Yy] ]] && quiet_hours="true"

  # Q2: Lock confirmation
  local q2_ans
  read -r -p "  Q2: Always confirm before locking or unlocking doors? [Y/n] " q2_ans
  [[ "${q2_ans:-y}" =~ ^[Yy] ]] && lock_confirm="true"

  # Q3: Device aliases (requires working CLI)
  local do_aliases="false"
  local q3_ans
  read -r -p "  Q3: Set up friendly names for your devices now? [y/N] " q3_ans
  [[ "${q3_ans:-n}" =~ ^[Yy] ]] && do_aliases="true"

  echo ""

  # Patch policy.yaml using Node (already a verified prerequisite)
  QUIET_HOURS="$quiet_hours" LOCK_CONFIRM="$lock_confirm" node - <<'NODEJS_PATCH'
const fs = require('fs');
const path = process.env.SWITCHBOT_POLICY_PATH;
let c = fs.readFileSync(path, 'utf8');

// Quiet hours: uncomment and set start/end
if (process.env.QUIET_HOURS === 'true') {
  c = c.replace(/^\s*#\s*start:.*$/m, '  start: "22:00"');
  c = c.replace(/^\s*#\s*end:.*$/m, '  end: "07:00"');
}

// Lock/unlock confirmation
if (process.env.LOCK_CONFIRM === 'true') {
  c = c.replace(/^(\s*always_confirm:\s*\[)\]/m, '$1"lock", "unlock"]');
}

fs.writeFileSync(path, c);
console.log('policy.yaml updated.');
NODEJS_PATCH

  # Device aliases
  if [[ "$do_aliases" == "true" ]] && command -v switchbot >/dev/null 2>&1; then
    echo "  Fetching your devices..."
    local devices_json
    devices_json=$(switchbot devices list --json 2>/dev/null || echo '{"data":[]}')

    # Extract deviceId and name pairs with Node
    DEVICES_JSON="$devices_json" node - <<'ALIAS_PATCH'
const fs = require('fs');
const policyPath = process.env.SWITCHBOT_POLICY_PATH;
const data = JSON.parse(process.env.DEVICES_JSON || '{"data":[]}');
const devices = (data.data || []).slice(0, 12);
if (!devices.length) { console.log('  No devices found.'); process.exit(0); }

const readline = require('readline');
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const aliases = {};
let i = 0;

function next() {
  if (i >= devices.length) {
    rl.close();
    if (Object.keys(aliases).length > 0) {
      let c = fs.readFileSync(policyPath, 'utf8');
      const entries = Object.entries(aliases)
        .map(([alias, id]) => '  "' + alias + '": "' + id + '"')
        .join('\n');
      c = c.replace(/^(aliases:\s*\n)((?:\s*#.*\n)*)/m, '\$1' + entries + '\n');
      fs.writeFileSync(policyPath, c);
      console.log('  Aliases saved to policy.yaml.');
    }
    return;
  }
  const d = devices[i++];
  rl.question('  "' + d.deviceName + '" → alias (Enter to skip): ', (ans) => {
    const alias = ans.trim();
    if (alias) aliases[alias] = d.deviceId;
    next();
  });
}
next();
ALIAS_PATCH
  fi

  ok "policy.yaml configured. Edit ~/.config/openclaw/switchbot/policy.yaml any time."
}

if [[ "$AUTO" == "true" || "$DRY_RUN" == "true" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "First-use wizard (would ask 3 preference questions)"
  else
    warn "Non-interactive mode: skipping wizard. Edit $POLICY_PATH to customize."
  fi
elif [[ "$POLICY_NEWLY_CREATED" == "false" ]]; then
  ok "policy.yaml already existed — skipping wizard."
elif ! command -v switchbot >/dev/null 2>&1; then
  warn "Skipping wizard (CLI not available). Configure policy.yaml manually."
else
  SWITCHBOT_POLICY_PATH="$POLICY_PATH" run_wizard
fi

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────
trap - EXIT  # disarm rollback — install succeeded

# ── Optional: register rules engine as a system service ──────────────────────
if [[ "$DRY_RUN" != "true" && "$AUTO" != "true" ]]; then
  echo ""
  local_ans=""
  read -r -p $'  Register the rules engine to start at login? [y/N] ' local_ans
  if [[ "${local_ans:-n}" =~ ^[Yy] ]]; then
    bash "$SKILL_DIR/scripts/setup-daemon.sh"
  else
    echo -e "  ${DIM}Run 'bash scripts/setup-daemon.sh' later to set this up.${RESET}"
  fi
fi

echo ""
echo -e "${GREEN}${BOLD}SwitchBot skill installed.${RESET}"
echo ""
if [[ ${#DETECTED_AGENTS[@]} -gt 0 ]]; then
  echo "  Installed for: ${DETECTED_AGENTS[*]}"
fi
echo ""
echo -e "  ${BOLD}Next:${RESET} Restart your agent, then try:"
echo -e "        ${DIM}\"List my SwitchBot devices\"${RESET}"
echo ""
echo "  Upgrade later:  bash scripts/upgrade.sh"
echo "  Uninstall:      bash scripts/uninstall.sh"

if [[ "$AUTO" != "true" && "$DRY_RUN" != "true" ]]; then
  prompt_telemetry_opt_in
fi
AGENTS_STR="${DETECTED_AGENTS[*]:-unknown}"
report_telemetry "success" "${AGENTS_STR// /,}"
