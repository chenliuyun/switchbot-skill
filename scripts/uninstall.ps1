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
  -RemoveCredentials  Remove ~/.switchbot credentials directory
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
  'codex-global' { Remove-ManagedFile -Path (Join-Path $HOME '.codex/AGENTS.md') }
  'codex-project' {
    $workspaceRoot = Require-WorkspacePath
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