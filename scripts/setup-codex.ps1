<#
.SYNOPSIS
  One-shot Codex install for the SwitchBot skill.

.DESCRIPTION
  What this script does (automated):
    1. Install @switchbot/openapi-cli globally via npm
    2. Enable plugin_hooks = true in ~/.codex/config.toml
    3. Write AGENTS.md to ~/.codex/  (file-based skill install)
    4. Launch switchbot auth login  <- browser opens; you log in once
    5. Run switchbot doctor to verify everything is working

  The only manual step is signing in to SwitchBot in the browser (step 4).

.PARAMETER NoAuth
  Skip the browser login step (use if already authenticated).

.EXAMPLE
  pwsh ./scripts/setup-codex.ps1
  pwsh ./scripts/setup-codex.ps1 -NoAuth
#>

[CmdletBinding()]
param(
  [switch]$NoAuth
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot    = Split-Path -Parent $PSScriptRoot
$codexConfig = Join-Path $HOME '.codex\config.toml'
$codexDir    = Split-Path -Parent $codexConfig

function Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok   { param($msg) Write-Host "v  $msg"   -ForegroundColor Green }
function Warn { param($msg) Write-Warning $msg }
function Die  { param($msg) Write-Error "ERROR: $msg"; exit 1 }

# ── 1. Install CLI ─────────────────────────────────────────────────────────────
Step "Installing @switchbot/openapi-cli"
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Die "npm not found. Install Node.js >= 18 first: https://nodejs.org"
}
npm install -g @switchbot/openapi-cli@latest
$cliVer = (& switchbot --version 2>$null) -join ''
Ok "CLI ready: $cliVer"

# ── 2. Enable plugin_hooks in ~/.codex/config.toml ────────────────────────────
Step "Enabling plugin_hooks in $codexConfig"
if (-not (Test-Path $codexDir)) {
  New-Item -ItemType Directory $codexDir -Force | Out-Null
}

if (-not (Test-Path $codexConfig)) {
  Set-Content $codexConfig "[features]`nplugin_hooks = true`n" -Encoding utf8
  Ok "Created config.toml with plugin_hooks = true"
} else {
  $raw = Get-Content $codexConfig -Raw
  if ($raw -match '(?m)^plugin_hooks\s*=\s*true') {
    Ok "plugin_hooks already enabled"
  } elseif ($raw -match '(?m)^plugin_hooks\s*=') {
    $raw = $raw -replace '(?m)^plugin_hooks\s*=.*', 'plugin_hooks = true'
    Set-Content $codexConfig $raw -Encoding utf8
    Ok "Updated plugin_hooks = true"
  } elseif ($raw -match '(?m)^\[features\]') {
    $raw = $raw -replace '(?m)(^\[features\])', "`$1`nplugin_hooks = true"
    Set-Content $codexConfig $raw -Encoding utf8
    Ok "Added plugin_hooks = true under existing [features]"
  } else {
    Add-Content $codexConfig "`n[features]`nplugin_hooks = true" -Encoding utf8
    Ok "Appended [features] section with plugin_hooks = true"
  }
}

# ── 3. Install skill instructions for Codex ───────────────────────────────────
Step "Installing SwitchBot skill instructions for Codex"
& "$repoRoot\scripts\install.ps1" -Agent codex-global -Force
Ok "AGENTS.md written to ~/.codex/"

# ── 4. Authenticate ────────────────────────────────────────────────────────────
if ($NoAuth) {
  Ok "Skipping auth (-NoAuth)"
} else {
  Step "SwitchBot login"
  Write-Host "A browser window will open — sign in with your SwitchBot account."
  Write-Host "The CLI stores credentials in the OS keychain; you only do this once.`n"
  Write-Host "Headless environment? Run instead:"
  Write-Host "  switchbot auth login --no-open`n"
  & switchbot auth login
}

# ── 5. Verify ──────────────────────────────────────────────────────────────────
Step "Verifying setup"
& switchbot --version
try {
  & switchbot doctor
  Write-Host ''
  Ok "Setup complete. Try it:"
  Write-Host "  switchbot devices list"
} catch {
  Warn "switchbot doctor reported issues — follow the fix commands above, then re-run with -NoAuth."
  exit 1
}
