# setup-daemon.ps1 — register the SwitchBot rules engine as a Windows Scheduled Task
#
# Called automatically by bootstrap.ps1; can also be run standalone:
#   pwsh scripts/setup-daemon.ps1 [-Uninstall] [-DryRun]
#
# Registers a Scheduled Task that starts at user logon (no UAC elevation needed)
# and restarts automatically if the rules engine exits.

param(
  [switch]$Uninstall,
  [switch]$DryRun,
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Error "PowerShell 7+ (pwsh) is required."
  exit 1
}

function Write-Ok   { param($Msg) if (-not $Quiet) { Write-Host "  [OK] $Msg" -ForegroundColor Green } }
function Write-Warn { param($Msg) Write-Host "  [!]  $Msg" -ForegroundColor Yellow }
function Write-Dry  { param($Msg) Write-Host "  (dry-run) $Msg" -ForegroundColor DarkGray }

$TaskName    = "SwitchBot Rules Engine"
$LogDir      = Join-Path $env:USERPROFILE ".switchbot"
$LogFile     = Join-Path $LogDir "rules.log"
$SwitchBotBin = (Get-Command switchbot -ErrorAction SilentlyContinue)?.Source ?? "switchbot"

# ── Uninstall ─────────────────────────────────────────────────────────────────

if ($Uninstall) {
  $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($existing) {
    if ($DryRun) {
      Write-Dry "Unregister-ScheduledTask -TaskName '$TaskName'"
    } else {
      Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
      Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
      Write-Ok "Scheduled Task '$TaskName' removed."
    }
  } else {
    Write-Warn "Task '$TaskName' not found — nothing to remove."
  }
  return
}

# ── Check for existing task ───────────────────────────────────────────────────

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
  Write-Ok "Scheduled Task '$TaskName' already exists."
  return
}

# ── Register ──────────────────────────────────────────────────────────────────

if ($DryRun) {
  Write-Dry "Register-ScheduledTask '$TaskName' (switchbot rules run --audit-log, AtLogon)"
  return
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# Wrap in a hidden pwsh window so no console flashes at login
$Action = New-ScheduledTaskAction `
  -Execute "pwsh.exe" `
  -Argument "-WindowStyle Hidden -NonInteractive -Command `"& '$SwitchBotBin' rules run --audit-log 2>&1 | Tee-Object -Append -FilePath '$LogFile'`""

$Trigger = New-ScheduledTaskTrigger -AtLogon

$Settings = New-ScheduledTaskSettingsSet `
  -RestartCount 5 `
  -RestartInterval (New-TimeSpan -Minutes 1) `
  -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -MultipleInstances IgnoreNew

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $Action `
  -Trigger $Trigger `
  -Settings $Settings `
  -Description "SwitchBot automation rules engine — started at user logon" `
  -RunLevel Limited | Out-Null

Write-Ok "Scheduled Task '$TaskName' registered."
Write-Ok "Starts at next login. To start now:"
Write-Ok "  Start-ScheduledTask -TaskName '$TaskName'"
Write-Ok "Logs: $LogFile"
