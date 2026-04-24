[CmdletBinding()]
param(
  [string]$OpenClawUrl = 'http://localhost:18789',
  [string]$OpenClawModel = $env:OPENCLAW_MODEL,
  [string]$OpenClawToken = $env:OPENCLAW_TOKEN,
  [string]$Topic = $env:SWITCHBOT_MQTT_TOPIC
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OPENCLAW_URL -and -not $PSBoundParameters.ContainsKey('OpenClawUrl')) {
  $OpenClawUrl = $env:OPENCLAW_URL
}

if (-not (Get-Command switchbot -ErrorAction SilentlyContinue)) {
  throw 'switchbot CLI is not on PATH. Install @switchbot/openapi-cli 3.0.0+ first.'
}

$args = @('status-sync', 'run', '--openclaw-url', $OpenClawUrl)

if ($OpenClawToken) {
  $args += @('--openclaw-token', $OpenClawToken)
}

if ($OpenClawModel) {
  $args += @('--openclaw-model', $OpenClawModel)
}

if ($Topic) {
  $args += @('--topic', $Topic)
}

& switchbot @args
