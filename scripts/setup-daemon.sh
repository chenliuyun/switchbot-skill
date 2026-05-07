#!/usr/bin/env bash
# setup-daemon.sh — register the SwitchBot rules engine as a system service
#
# Called automatically by bootstrap.sh; can also be run standalone:
#   bash scripts/setup-daemon.sh [--uninstall] [--dry-run]
#
# Supported platforms:
#   macOS  → LaunchAgent   ~/Library/LaunchAgents/com.switchbot.rules.plist
#   Linux  → systemd user  ~/.config/systemd/user/switchbot-rules.service
#   WSL2   → prints a warning (Windows Task Scheduler is the right path)

set -euo pipefail

UNINSTALL=false
DRY_RUN=false
QUIET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall) UNINSTALL=true; shift ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --quiet)     QUIET=true; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

ok()   { [[ "$QUIET" != "true" ]] && echo "  ✓ $1" || true; }
warn() { echo "  ! $1"; }
dry()  { echo "  (dry-run) $1"; }

SWITCHBOT_BIN="$(command -v switchbot 2>/dev/null || echo "switchbot")"

# ── Detect platform ──────────────────────────────────────────────────────────

detect_platform() {
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl2"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
  elif [[ "$(uname -s)" == "Linux" ]]; then
    echo "linux"
  else
    echo "unknown"
  fi
}

PLATFORM=$(detect_platform)

# ── macOS LaunchAgent ─────────────────────────────────────────────────────────

setup_macos() {
  local plist_dir="$HOME/Library/LaunchAgents"
  local plist="$plist_dir/com.switchbot.rules.plist"

  if [[ "$UNINSTALL" == "true" ]]; then
    if [[ -f "$plist" ]]; then
      if [[ "$DRY_RUN" != "true" ]]; then
        launchctl unload "$plist" 2>/dev/null || true
        rm -f "$plist"
      else
        dry "launchctl unload $plist && rm $plist"
      fi
      ok "Removed LaunchAgent."
    else
      warn "LaunchAgent not found — nothing to remove."
    fi
    return
  fi

  if [[ -f "$plist" ]]; then
    ok "LaunchAgent already exists at $plist"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    dry "Write $plist and launchctl load it"
    return
  fi

  mkdir -p "$plist_dir"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.switchbot.rules</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SWITCHBOT_BIN</string>
    <string>rules</string>
    <string>run</string>
    <string>--audit-log</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$HOME/.switchbot/rules.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/.switchbot/rules.log</string>
</dict>
</plist>
PLIST

  mkdir -p "$HOME/.switchbot"
  launchctl load "$plist"
  ok "LaunchAgent installed and loaded: $plist"
  ok "Starts automatically at login. Logs: ~/.switchbot/rules.log"
}

# ── Linux systemd user service ────────────────────────────────────────────────

setup_linux() {
  local svc_dir="$HOME/.config/systemd/user"
  local svc="$svc_dir/switchbot-rules.service"

  if [[ "$UNINSTALL" == "true" ]]; then
    if [[ -f "$svc" ]]; then
      if [[ "$DRY_RUN" != "true" ]]; then
        systemctl --user stop switchbot-rules 2>/dev/null || true
        systemctl --user disable switchbot-rules 2>/dev/null || true
        rm -f "$svc"
        systemctl --user daemon-reload
      else
        dry "systemctl --user stop/disable + rm $svc"
      fi
      ok "Removed systemd user service."
    else
      warn "Service file not found — nothing to remove."
    fi
    return
  fi

  if [[ -f "$svc" ]]; then
    ok "systemd user service already exists at $svc"
    return
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl not found — cannot install service. Run the rules engine manually:"
    warn "  switchbot rules run --audit-log &"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    dry "Write $svc and systemctl --user enable --now it"
    return
  fi

  mkdir -p "$svc_dir" "$HOME/.switchbot"
  cat > "$svc" <<SERVICE
[Unit]
Description=SwitchBot Rules Engine
After=network.target

[Service]
ExecStart=$SWITCHBOT_BIN rules run --audit-log
Restart=on-failure
RestartSec=10s
StandardOutput=append:$HOME/.switchbot/rules.log
StandardError=append:$HOME/.switchbot/rules.log

[Install]
WantedBy=default.target
SERVICE

  systemctl --user daemon-reload
  systemctl --user enable --now switchbot-rules
  ok "systemd user service installed: $svc"
  ok "Status: systemctl --user status switchbot-rules"
  ok "Logs:   journalctl --user -u switchbot-rules -f"
}

# ── WSL2 ─────────────────────────────────────────────────────────────────────

setup_wsl2() {
  if [[ "$UNINSTALL" == "true" ]]; then
    warn "Nothing to remove (WSL2 daemon was not installed)."
    return
  fi
  warn "WSL2 detected — background services require Windows Task Scheduler."
  warn "Run the rules engine manually for now:"
  warn "  switchbot rules run --audit-log &"
  warn "Or use the PowerShell script: pwsh scripts/setup-daemon.ps1"
}

# ── Dispatch ─────────────────────────────────────────────────────────────────

case "$PLATFORM" in
  macos)   setup_macos ;;
  linux)   setup_linux ;;
  wsl2)    setup_wsl2 ;;
  *)
    warn "Unsupported platform: $(uname -s). Start the rules engine manually:"
    warn "  switchbot rules run --audit-log &"
    ;;
esac
