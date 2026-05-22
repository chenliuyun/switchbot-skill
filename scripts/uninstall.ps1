[CmdletBinding()]
param(
  [ValidateSet(
    'claude-global',
    'claude-project',
    'copilot',
    'cursor',
    'cursor-legacy',
    'gemini-global',
    'gemini-project',
    'codex-global',
    'codex-project',
    'openclaw-staging'
  )]
  [string]$Agent = 'claude-global',

  [string]$WorkspacePath,

  [switch]$RemoveCli,
  [switch]$RemovePolicy,
  [switch]$RemoveCredentials,
  [switch]$Force,
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Usage {
  @"
SwitchBot skill uninstaller

Usage:
  pwsh ./scripts/uninstall.ps1 -Agent claude-global
  pwsh ./scripts/uninstall.ps1 -Agent copilot -WorkspacePath C:\path\to\workspace

Options:
  -RemoveCli          Uninstall @switchbot/openapi-cli globally
  -RemovePolicy       Remove ~/.config/openclaw/switchbot and ~/.switchbot/audit.log
  -RemoveCredentials  Remove ~/.switchbot files (OS keychain login still needs switchbot auth logout)
  -Force              Remove non-Claude agent files even if they do not look script-managed
"@
}

if ($Help) {
  Show-Usage
  exit 0
}

$policyRoot = Join-Path $HOME '.config/openclaw/switchbot'
$auditLogPath = Join-Path $HOME '.switchbot/audit.log'
$credentialsRoot = Join-Path $HOME '.switchbot'

function Require-WorkspacePath {
  if (-not $WorkspacePath) {
    throw 'This agent target requires -WorkspacePath.'
  }

  $resolved = Resolve-Path -LiteralPath $WorkspacePath -ErrorAction Stop
  return $resolved.Path
}

function Remove-PathIfExists {
  param([string]$Path)

  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
}

function Remove-ManagedFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  if ($Force) {
    Remove-Item -LiteralPath $Path -Force
    return
  }

  $content = Get-Content -Raw -LiteralPath $Path
  if ($content -match '# SwitchBot skill') {
    Remove-Item -LiteralPath $Path -Force
    return
  }

  Write-Warning "Skipped $Path because it does not look script-managed. Re-run with -Force to remove it anyway."
}

function Remove-CodexPluginIfPresent {
  $codex = Get-Command codex -ErrorAction SilentlyContinue
  if (-not $codex) {
    Write-Warning 'codex CLI not found, so plugin removal was skipped.'
    return
  }

  $removed = $false
  foreach ($pluginId in @(
    'switchbot@switchbot-skill',
    'switchbot@codex-plugin',
    'switchbot@switchbot-codex-plugin'
  )) {
    try {
      & $codex.Source plugin remove $pluginId *> $null
      if ($LASTEXITCODE -eq 0) {
        Write-Host "Removed Codex plugin: $pluginId"
        $removed = $true
      }
    } catch {
      # Ignore unknown plugin IDs and continue trying the common variants.
    }
  }

  if (-not $removed) {
    Write-Warning 'No known SwitchBot Codex plugin ID was removed. Run `codex plugin list` to verify manually.'
  }
}

switch ($Agent) {
  'claude-global' { Remove-PathIfExists -Path (Join-Path $HOME '.claude/skills/switchbot') }
  'claude-project' {
    $workspaceRoot = Require-WorkspacePath
    Remove-PathIfExists -Path (Join-Path $workspaceRoot '.claude/skills/switchbot')
  }
  'copilot' {
    $workspaceRoot = Require-WorkspacePath
    Remove-ManagedFile -Path (Join-Path $workspaceRoot '.github/copilot-instructions.md')
  }
  'cursor' {
    $workspaceRoot = Require-WorkspacePath
    Remove-ManagedFile -Path (Join-Path $workspaceRoot '.cursor/rules/switchbot.mdc')
  }
  'cursor-legacy' {
    $workspaceRoot = Require-WorkspacePath
    Remove-ManagedFile -Path (Join-Path $workspaceRoot '.cursorrules')
  }
  'gemini-global' { Remove-ManagedFile -Path (Join-Path $HOME '.gemini/GEMINI.md') }
  'gemini-project' {
    $workspaceRoot = Require-WorkspacePath
    Remove-ManagedFile -Path (Join-Path $workspaceRoot 'GEMINI.md')
  }
  'codex-global' {
    Remove-CodexPluginIfPresent
    Remove-ManagedFile -Path (Join-Path $HOME '.codex/AGENTS.md')
  }
  'codex-project' {
    $workspaceRoot = Require-WorkspacePath
    Remove-CodexPluginIfPresent
    Remove-ManagedFile -Path (Join-Path $workspaceRoot 'AGENTS.md')
  }
  'openclaw-staging' {
    $workspaceRoot = Require-WorkspacePath
    Remove-PathIfExists -Path (Join-Path $workspaceRoot '.openclaw/staging/plugins/switchbot')
  }
}

if ($RemovePolicy) {
  Remove-PathIfExists -Path $policyRoot
  Remove-PathIfExists -Path $auditLogPath
}

if ($RemoveCredentials) {
  Remove-PathIfExists -Path $credentialsRoot
}

if ($RemoveCli) {
  npm uninstall -g @switchbot/openapi-cli
}

Write-Host 'Uninstall complete.'
Write-Host ''
Write-Host 'Verify the parts you asked to remove:'
if ($Agent -like 'codex-*') {
  Write-Host '  codex plugin list                                  # expected: no SwitchBot plugin entry'
}
if ($RemovePolicy) {
  Write-Host '  Test-Path $env:USERPROFILE\.config\openclaw\switchbot   # expected: False'
}
if ($RemoveCredentials) {
  Write-Host '  Test-Path $env:USERPROFILE\.switchbot              # expected: False'
  Write-Host '  switchbot auth keychain describe --json'
  Write-Host '    # may still succeed until you also run: switchbot auth logout'
}
if ($RemoveCli) {
  Write-Host '  switchbot --version                                # expected: not recognized'
  Write-Host '  switchbot doctor                                   # expected: not recognized'
}
