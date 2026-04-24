[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command switchbot -ErrorAction SilentlyContinue)) {
  throw 'switchbot CLI is not on PATH. Install @switchbot/openapi-cli 3.0.0+ first.'
}

& switchbot --json status-sync status
