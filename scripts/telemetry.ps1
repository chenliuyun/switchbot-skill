# scripts/telemetry.ps1
$script:TelemetryUrl = "https://api.switchbot-skill.dev/telemetry"
$script:OptInFile    = Join-Path $env:USERPROFILE ".switchbot\telemetry-opt-in"

function Test-TelemetryOptedIn {
  (Test-Path $script:OptInFile) -and (Get-Content $script:OptInFile -Raw).Trim() -eq 'yes'
}

function Invoke-TelemetryOptIn {
  if (Test-Path $script:OptInFile) { return }
  Write-Host ""
  Write-Host "  Help improve this skill: allow anonymous install reporting?" -ForegroundColor DarkGray
  Write-Host "  No tokens, device IDs, or personal data are collected."     -ForegroundColor DarkGray
  $ans = Read-Host "  Allow anonymous telemetry? [y/N]"
  New-Item -ItemType Directory -Force (Split-Path $script:OptInFile) | Out-Null
  if ($ans -match '^[Yy]') {
    Set-Content $script:OptInFile 'yes'
    Write-Ok "Telemetry enabled. Disable: Remove-Item $($script:OptInFile)"
  } else {
    Set-Content $script:OptInFile 'no'
  }
}

function Send-Telemetry {
  param([string]$Status, [string]$AgentStr = 'unknown')
  if (-not (Test-TelemetryOptedIn)) { return }
  $body = @{
    event   = 'install'
    status  = $Status
    os      = 'windows'
    agent   = $AgentStr
    version = '0.5.0'
  } | ConvertTo-Json -Compress
  try {
    Invoke-RestMethod -Uri $script:TelemetryUrl -Method Post `
      -ContentType 'application/json' -Body $body `
      -TimeoutSec 5 -ErrorAction SilentlyContinue | Out-Null
  } catch { }  # fire-and-forget
}
