# bootstrap.ps1 — one-command SwitchBot skill installer (PowerShell)
#
# Usage (no git required):
#   irm https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/bootstrap.ps1 | iex
#
# Or, from a cloned repo:
#   pwsh ./scripts/bootstrap.ps1 [flags]
#
# Flags:
#   -Auto / -Yes        Non-interactive; accept all defaults
#   -DryRun             Print what would happen; write nothing
#   -SkipToken          Skip credential setup (already configured)
#   -SkipVerify         Skip doctor + devices list verification
#   -NoCli              Skip npm install of @switchbot/openapi-cli
#   -Agent <target>     Force a specific agent target (bypass auto-detect)
#   -Force              Overwrite existing skill installations

param(
  [switch]$Auto,
  [switch]$Yes,
  [switch]$DryRun,
  [switch]$SkipToken,
  [switch]$SkipVerify,
  [switch]$NoCli,
  [string]$Agent = "",
  [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Require PowerShell 7+ (arrays, ??, and other features used below)
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Error "PowerShell 7+ (pwsh) is required.`nInstall from https://github.com/PowerShell/PowerShell/releases"
  exit 1
}

$TARBALL_URL = "https://github.com/chenliuyun/switchbot-skill/archive/refs/heads/main.zip"
$NonInteractive = $Auto -or $Yes

# --- helpers ---
function Write-Step  { param($Msg) Write-Host "`n$Msg" -ForegroundColor White }
function Write-Ok    { param($Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn  { param($Msg) Write-Host "  [!]  $Msg" -ForegroundColor Yellow }
function Write-Dry   { param($Msg) Write-Host "  (dry-run) $Msg" -ForegroundColor DarkGray }
function Write-Fail  { param($Msg) Write-Error "  [X]  $Msg" }

# --- telemetry (optional, dot-sourced if available) ---
$_telemetryScript = Join-Path $PSScriptRoot "telemetry.ps1"
if (Test-Path $_telemetryScript) {
  . $_telemetryScript
} else {
  function Invoke-TelemetryOptIn {}
  function Send-Telemetry {}
}

$InstalledPaths = [System.Collections.Generic.List[string]]::new()

function Invoke-Rollback {
  if ($InstalledPaths.Count -gt 0) {
    Write-Warn "Rolling back..."
    foreach ($p in $InstalledPaths) {
      if (Test-Path $p) {
        Remove-Item -Recurse -Force $p
        Write-Warn "  removed: $p"
      }
    }
  }
}

# ─────────────────────────────────────────────
# Main — wrapped for rollback on failure
# ─────────────────────────────────────────────
try {

Write-Step "[1/7] Checking prerequisites..."

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Fail "Node.js is required but not found.`n  Install from https://nodejs.org (v18+) and re-run."
}

$nodeVersion = (node --version 2>$null) -replace 'v(\d+)\..*','$1'
if ([int]$nodeVersion -lt 18) {
  Write-Fail "Node.js v18+ required. Found: $(node --version). Upgrade at https://nodejs.org"
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Fail "npm is required but not found. It ships with Node.js — reinstall Node from https://nodejs.org"
}

Write-Ok "Node $(node --version), npm $(npm --version)"

# ─────────────────────────────────────────────
# [2/6] Install SwitchBot CLI
# ─────────────────────────────────────────────
Write-Step "[2/7] Installing SwitchBot CLI..."

if ($NoCli) {
  Write-Warn "Skipping CLI install (-NoCli)."
} elseif (Get-Command switchbot -ErrorAction SilentlyContinue) {
  $currentVer = (switchbot --version 2>$null) ?? "unknown"
  Write-Ok "CLI already installed: $currentVer"
} elseif ($DryRun) {
  Write-Dry "npm install -g @switchbot/openapi-cli"
} else {
  Write-Host "  Installing @switchbot/openapi-cli..."
  npm install -g @switchbot/openapi-cli
  Write-Ok "CLI installed: $(switchbot --version 2>$null)"
}

# ─────────────────────────────────────────────
# [3/6] Download skill files
# ─────────────────────────────────────────────
Write-Step "[3/7] Downloading skill files..."

$SkillDir = ""

function Invoke-DownloadSkill {
  param([string]$TempZip, [string]$TempDir)

  $primary = "https://github.com/chenliuyun/switchbot-skill/archive/refs/heads/main.zip"
  $mirror  = "https://ghproxy.com/https://github.com/chenliuyun/switchbot-skill/archive/refs/heads/main.zip"

  Write-Host "  Downloading from GitHub..."
  try {
    Invoke-WebRequest -Uri $primary -OutFile $TempZip -UseBasicParsing -TimeoutSec 15
    Write-Ok "Downloaded (GitHub)"
    return
  } catch {
    Write-Warn "GitHub unreachable, trying mirror (ghproxy.com)..."
  }

  try {
    Invoke-WebRequest -Uri $mirror -OutFile $TempZip -UseBasicParsing -TimeoutSec 20
    Write-Ok "Downloaded (mirror)"
  } catch {
    throw "Download failed from both GitHub and mirror.`nClone manually: git clone https://github.com/chenliuyun/switchbot-skill.git"
  }
}

# If running from a cloned repo, use it directly
$ScriptDir = $PSScriptRoot
if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir "..\SKILL.md"))) {
  $SkillDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path
  Write-Ok "Using local repo at $SkillDir"
} elseif ($DryRun) {
  Write-Dry "Invoke-WebRequest $TARBALL_URL | Expand-Archive (to temp dir)"
  $SkillDir = Join-Path $env:TEMP "switchbot-skill-dry-run"
} else {
  $TempZip = Join-Path $env:TEMP "switchbot-skill.zip"
  $TempDir = Join-Path $env:TEMP "switchbot-skill-bootstrap"

  Invoke-DownloadSkill -TempZip $TempZip -TempDir $TempDir

  if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
  Expand-Archive -Path $TempZip -DestinationPath $TempDir
  Remove-Item $TempZip

  # GitHub zip contains a single top-level directory: switchbot-skill-main
  $inner = Get-ChildItem $TempDir -Directory | Select-Object -First 1
  $SkillDir = $inner.FullName

  Write-Ok "Downloaded to $SkillDir"
}

# ─────────────────────────────────────────────
# [4/6] Detect agents and install skill
# ─────────────────────────────────────────────
Write-Step "[4/7] Installing skill into detected agents..."

$PolicyPath = Join-Path ($env:USERPROFILE ?? $env:HOME) ".config\openclaw\switchbot\policy.yaml"
$PolicyNewlyCreated = $false
$PolicyPreExisted = Test-Path $PolicyPath

$DetectedAgents = [System.Collections.Generic.List[string]]::new()

function Get-DetectedAgents {
  if ($Agent) {
    $DetectedAgents.Add($Agent)
    return
  }

  $home = $env:USERPROFILE ?? $env:HOME
  if (Test-Path (Join-Path $home ".claude"))                       { $DetectedAgents.Add("claude-global") }
  if (Test-Path (Join-Path $home ".gemini"))                       { $DetectedAgents.Add("gemini-global") }
  if (Test-Path (Join-Path $home ".codex"))                        { $DetectedAgents.Add("codex-global") }

  # cursor and Copilot both need -WorkspacePath; skip with a hint
  if (Test-Path (Join-Path $home ".cursor")) {
    Write-Warn "Cursor detected — skipping (requires -WorkspacePath; run install.ps1 manually)"
  }
  $copilotDir = Join-Path $home ".config\github-copilot"
  if (Test-Path $copilotDir) {
    Write-Warn "GitHub Copilot detected — skipping (requires -WorkspacePath; run install.ps1 manually)"
  }

  if ($DetectedAgents.Count -eq 0) {
    Write-Warn "No agent directories detected. Defaulting to claude-global."
    $DetectedAgents.Add("claude-global")
  }
}

Get-DetectedAgents

function Get-DestinationPath {
  param([string]$AgentTarget)
  $home = $env:USERPROFILE ?? $env:HOME
  switch ($AgentTarget) {
    "claude-global"  { return Join-Path $home ".claude\skills\switchbot" }
    "gemini-global"  { return Join-Path $home ".gemini\GEMINI.md" }
    "codex-global"   { return Join-Path $home ".codex\AGENTS.md" }
    default          { return "" }
  }
}

foreach ($ag in $DetectedAgents) {
  $dest = Get-DestinationPath $ag
  $preExisted = $dest -and (Test-Path $dest)

  if ($preExisted -and -not $Force) {
    Write-Ok "Already installed: $ag ($dest) — skipping (use -Force to reinstall)"
    continue
  }

  $installerScript = Join-Path $SkillDir "scripts\install.ps1"

  if ($DryRun) {
    Write-Dry "install.ps1 -Agent $ag -InitPolicy$(if ($Force) {' -Force'})"
    continue
  }

  $installArgs = @("-Agent", $ag, "-InitPolicy")
  if ($Force) { $installArgs += "-Force" }

  & pwsh -File $installerScript @installArgs

  # Only track freshly created paths; don't rollback pre-existing user files
  if (-not $preExisted -and $dest) { $InstalledPaths.Add($dest) }
  Write-Ok "Installed: $ag"
}

if (-not $PolicyPreExisted -and (Test-Path $PolicyPath)) {
  $PolicyNewlyCreated = $true
}

# ─────────────────────────────────────────────
# [5/7] Token setup
# ─────────────────────────────────────────────
Write-Step "[5/7] Getting your SwitchBot token..."

function Test-TokenIsSet {
  if (-not (Get-Command switchbot -ErrorAction SilentlyContinue)) { return $false }
  try {
    $out = switchbot auth keychain describe --json 2>$null
    return $out -match '"token"'
  } catch { return $false }
}

if ($SkipToken) {
  Write-Warn "Skipping token setup (-SkipToken)."
} elseif ($DryRun) {
  Write-Dry "switchbot config set-token  (interactive)"
} elseif (Test-TokenIsSet) {
  Write-Ok "Credentials already configured — skipping."
} elseif ($NonInteractive) {
  Write-Warn "Non-interactive mode: skipping token setup. Run 'switchbot config set-token' manually."
} else {
  Write-Host ""
  Write-Host "  ──────────────────────────────────────────────"
  Write-Host "  Get your SwitchBot token from the mobile app:"
  Write-Host "  ──────────────────────────────────────────────"
  Write-Host "   1. Open the SwitchBot app on your phone"
  Write-Host "   2. Tap Profile (bottom right) -> Preferences"
  Write-Host "   3. Tap 'App Version' rapidly 10 times"
  Write-Host "   4. Tap 'Developer Options' -> enable Cloud Services"
  Write-Host "   5. Copy the Token and Secret shown there"
  Write-Host "  ──────────────────────────────────────────────"
  Write-Host ""
  Read-Host "  Press Enter when ready to paste your credentials"
  Write-Host ""
  switchbot config set-token
  Write-Ok "Credentials saved."
}

# ─────────────────────────────────────────────
# [6/6] Verify setup
# ─────────────────────────────────────────────
Write-Step "[6/7] Verifying setup..."

if ($SkipVerify) {
  Write-Warn "Skipping verification (-SkipVerify)."
} elseif ($DryRun) {
  Write-Dry "switchbot doctor && switchbot devices list --json"
} elseif (-not (Get-Command switchbot -ErrorAction SilentlyContinue)) {
  Write-Warn "switchbot CLI not on PATH — skipping verification."
  Write-Warn "Run 'switchbot doctor' manually after installation."
} else {
  $doctorOut = switchbot doctor 2>&1
  if ($doctorOut -match "0 fail") {
    Write-Ok "switchbot doctor passed."
  } else {
    Write-Warn "switchbot doctor reported issues — run 'switchbot doctor' for details."
  }

  try {
    $devicesJson = switchbot devices list --json 2>$null
    $deviceCount = ([regex]::Matches($devicesJson, '"deviceId"')).Count
    if ($deviceCount -gt 0) {
      Write-Ok "Found $deviceCount device(s)."
    } else {
      Write-Warn "No devices returned — check credentials with 'switchbot doctor --section credentials'."
    }
  } catch {
    Write-Warn "Could not list devices — run 'switchbot devices list' manually."
  }
}

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "SwitchBot skill installed." -ForegroundColor Green
Write-Host ""
if ($DetectedAgents.Count -gt 0) {
  Write-Host "  Installed for: $($DetectedAgents -join ', ')"
}
Write-Host ""
Write-Host "  Next: Restart your agent, then try:"
Write-Host "        `"List my SwitchBot devices`""
Write-Host ""
Write-Host "  Upgrade later:  pwsh scripts/upgrade.ps1"
Write-Host "  Uninstall:      pwsh scripts/uninstall.ps1"

if (-not $NonInteractive -and -not $DryRun) { Invoke-TelemetryOptIn }
Send-Telemetry -Status "success" -AgentStr ($DetectedAgents -join ',')

# ─────────────────────────────────────────────
# [7/7] First-use wizard
# ─────────────────────────────────────────────
Write-Step "[7/7] Setting up your preferences..."

function Invoke-Wizard {
  param([string]$WizardPolicyPath)

  Write-Host ""
  Write-Host "  Answer 3 quick questions to configure policy.yaml."
  Write-Host "  (Press Enter to accept the default shown in brackets.)"
  Write-Host ""

  $quietAns  = Read-Host "  Q1: Block light/plug/AC changes during sleep hours (22:00-07:00)? [Y/n]"
  $lockAns   = Read-Host "  Q2: Always confirm before locking or unlocking doors? [Y/n]"
  $aliasAns  = Read-Host "  Q3: Set up friendly names for your devices now? [y/N]"

  $quietHours  = ($quietAns -eq '' -or $quietAns -match '^[Yy]')
  $lockConfirm = ($lockAns  -eq '' -or $lockAns  -match '^[Yy]')
  $doAliases   = $aliasAns -match '^[Yy]'

  $content = Get-Content $WizardPolicyPath -Raw

  if ($quietHours) {
    $content = $content -replace '(?m)^\s*#\s*start:.*$', '  start: "22:00"'
    $content = $content -replace '(?m)^\s*#\s*end:.*$',   '  end: "07:00"'
  }
  if ($lockConfirm) {
    $content = $content -replace '(?m)^(\s*always_confirm:\s*\[)\]', '$1"lock", "unlock"]'
  }
  Set-Content -Path $WizardPolicyPath -Value $content -Encoding UTF8

  if ($doAliases -and (Get-Command switchbot -ErrorAction SilentlyContinue)) {
    Write-Host "  Fetching your devices..."
    try {
      $devicesJson = switchbot devices list --json 2>$null
      $devices = ($devicesJson | ConvertFrom-Json).data
      foreach ($dev in ($devices | Select-Object -First 12)) {
        $alias = Read-Host "  `"$($dev.deviceName)`" -> alias (Enter to skip)"
        if ($alias.Trim()) {
          $content = Get-Content $WizardPolicyPath -Raw
          $entry = "  `"$($alias.Trim())`": `"$($dev.deviceId)`""
          $content = $content -replace '(?m)^(aliases:\s*\r?\n)((?:\s*#.*\r?\n)*)', "`$1$entry`n`$2"
          Set-Content -Path $WizardPolicyPath -Value $content -Encoding UTF8
        }
      }
    } catch {
      Write-Warn "Could not fetch devices for alias setup."
    }
  }

  Write-Ok "policy.yaml configured. Edit $WizardPolicyPath any time."
}

if ($DryRun) {
  Write-Dry "First-use wizard (would ask 3 preference questions)"
} elseif ($NonInteractive) {
  Write-Warn "Non-interactive mode: skipping wizard. Edit $PolicyPath to customize."
} elseif (-not $PolicyNewlyCreated) {
  Write-Ok "policy.yaml already existed — skipping wizard."
} elseif (-not (Get-Command switchbot -ErrorAction SilentlyContinue)) {
  Write-Warn "Skipping wizard (CLI not available)."
} else {
  Invoke-Wizard -WizardPolicyPath $PolicyPath
}

# ── Optional: register rules engine as a system service ──────────────────────
if (-not $DryRun -and -not $NonInteractive) {
  $daemonAns = Read-Host "`n  Register the rules engine to start at login? [y/N]"
  if ($daemonAns -match '^[Yy]') {
    $daemonScript = Join-Path $SkillDir "scripts\setup-daemon.ps1"
    if (Test-Path $daemonScript) {
      & pwsh -File $daemonScript
    } else {
      Write-Warn "setup-daemon.ps1 not found. Run it manually later."
    }
  } else {
    Write-Host "  Run 'pwsh scripts/setup-daemon.ps1' later to set this up." -ForegroundColor DarkGray
  }
}

} catch {
  Send-Telemetry -Status "failed" -AgentStr "unknown"
  Invoke-Rollback
  throw
}
