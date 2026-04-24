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

  [ValidateSet('symlink', 'copy')]
  [string]$Mode = 'symlink',

  [switch]$InstallCli,
  [switch]$InitPolicy,
  [switch]$Force,
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Usage {
  @"
SwitchBot skill installer

Usage:
  pwsh ./scripts/install.ps1 -Agent claude-global [-InstallCli] [-InitPolicy]
  pwsh ./scripts/install.ps1 -Agent copilot -WorkspacePath C:\path\to\workspace

Agents:
  claude-global   Install the full skill under ~/.claude/skills/switchbot
  claude-project  Install the full skill under <workspace>/.claude/skills/switchbot
  copilot         Write <workspace>/.github/copilot-instructions.md
  cursor          Write <workspace>/.cursor/rules/switchbot.mdc
  cursor-legacy   Write <workspace>/.cursorrules
  gemini-global   Write ~/.gemini/GEMINI.md
  gemini-project  Write <workspace>/GEMINI.md
  codex-global    Write ~/.codex/AGENTS.md
  codex-project   Write <workspace>/AGENTS.md
  openclaw-staging Stage a future plugin layout under <workspace>/.openclaw/staging/plugins/switchbot

Notes:
  - This script automates today's file-based installs. It does not publish the
    future OpenClaw / ClawHub plugin.
  - -InstallCli runs: npm install -g @switchbot/openapi-cli
  - -InitPolicy creates ~/.config/openclaw/switchbot/policy.yaml if it does not exist.
"@
}

if ($Help) {
  Show-Usage
  exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$skillPath = Join-Path $repoRoot 'SKILL.md'
$policyPath = Join-Path $HOME '.config/openclaw/switchbot/policy.yaml'

function Get-SkillBody {
  $content = Get-Content -Raw -LiteralPath $skillPath
  if ($content -match '(?s)^---\r?\n.*?\r?\n---\r?\n') {
    return ($content -replace '(?s)^---\r?\n.*?\r?\n---\r?\n', '')
  }

  return $content
}

function Get-CursorRuleContent {
  $header = @"
---
description: Drive SwitchBot smart-home devices via the switchbot CLI. Trigger on smart-home or device-control questions.
globs:
  - "**/*"
alwaysApply: false
---

"@

  return $header + (Get-SkillBody)
}

function Ensure-ParentDirectory {
  param([string]$Path)

  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
}

function Require-WorkspacePath {
  if (-not $WorkspacePath) {
    throw 'This agent target requires -WorkspacePath.'
  }

  $resolved = Resolve-Path -LiteralPath $WorkspacePath -ErrorAction Stop
  return $resolved.Path
}

function Remove-ExistingPath {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  if (-not $Force) {
    throw "Path already exists: $Path. Re-run with -Force to replace it."
  }

  Remove-Item -LiteralPath $Path -Recurse -Force
}

function Write-Utf8File {
  param(
    [string]$Path,
    [string]$Content
  )

  Ensure-ParentDirectory -Path $Path
  Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
}

function Copy-SkillTree {
  param([string]$Destination)

  Remove-ExistingPath -Path $Destination
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null

  Get-ChildItem -LiteralPath $repoRoot -Force |
    Where-Object { $_.Name -ne '.git' } |
    ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Link-OrCopySkillTree {
  param([string]$Destination)

  Remove-ExistingPath -Path $Destination
  Ensure-ParentDirectory -Path $Destination

  if ($Mode -eq 'copy') {
    Copy-SkillTree -Destination $Destination
    return
  }

  try {
    New-Item -ItemType SymbolicLink -Path $Destination -Target $repoRoot -Force | Out-Null
  }
  catch {
    Write-Warning 'Symbolic link creation failed; falling back to copy mode.'
    Copy-SkillTree -Destination $Destination
  }
}

function Install-OptionalCli {
  if (-not $InstallCli) {
    return
  }

  npm install -g @switchbot/openapi-cli
}

function Initialize-OptionalPolicy {
  if (-not $InitPolicy) {
    return
  }

  if (-not (Get-Command switchbot -ErrorAction SilentlyContinue)) {
    throw 'switchbot CLI is not available. Re-run with -InstallCli or install it first.'
  }

  if (-not (Test-Path -LiteralPath $policyPath)) {
    switchbot policy new --version 0.2
  }

  switchbot policy validate
}

Install-OptionalCli
Initialize-OptionalPolicy

$skillBody = Get-SkillBody

switch ($Agent) {
  'claude-global' {
    $destination = Join-Path $HOME '.claude/skills/switchbot'
    Link-OrCopySkillTree -Destination $destination
    Write-Host "Installed Claude Code skill at $destination"
  }
  'claude-project' {
    $workspaceRoot = Require-WorkspacePath
    $destination = Join-Path $workspaceRoot '.claude/skills/switchbot'
    Link-OrCopySkillTree -Destination $destination
    Write-Host "Installed project-local Claude Code skill at $destination"
  }
  'copilot' {
    $workspaceRoot = Require-WorkspacePath
    $destination = Join-Path $workspaceRoot '.github/copilot-instructions.md'
    Write-Utf8File -Path $destination -Content $skillBody
    Write-Host "Installed Copilot instructions at $destination"
  }
  'cursor' {
    $workspaceRoot = Require-WorkspacePath
    $destination = Join-Path $workspaceRoot '.cursor/rules/switchbot.mdc'
    Write-Utf8File -Path $destination -Content (Get-CursorRuleContent)
    Write-Host "Installed Cursor rule at $destination"
  }
  'cursor-legacy' {
    $workspaceRoot = Require-WorkspacePath
    $destination = Join-Path $workspaceRoot '.cursorrules'
    Write-Utf8File -Path $destination -Content $skillBody
    Write-Host "Installed legacy Cursor rules at $destination"
  }
  'gemini-global' {
    $destination = Join-Path $HOME '.gemini/GEMINI.md'
    Write-Utf8File -Path $destination -Content $skillBody
    Write-Host "Installed Gemini global instructions at $destination"
  }
  'gemini-project' {
    $workspaceRoot = Require-WorkspacePath
    $destination = Join-Path $workspaceRoot 'GEMINI.md'
    Write-Utf8File -Path $destination -Content $skillBody
    Write-Host "Installed Gemini project instructions at $destination"
  }
  'codex-global' {
    $destination = Join-Path $HOME '.codex/AGENTS.md'
    Write-Utf8File -Path $destination -Content $skillBody
    Write-Host "Installed Codex global instructions at $destination"
  }
  'codex-project' {
    $workspaceRoot = Require-WorkspacePath
    $destination = Join-Path $workspaceRoot 'AGENTS.md'
    Write-Utf8File -Path $destination -Content $skillBody
    Write-Host "Installed Codex project instructions at $destination"
  }
  'openclaw-staging' {
    $workspaceRoot = Require-WorkspacePath
    $destination = Join-Path $workspaceRoot '.openclaw/staging/plugins/switchbot'
    Link-OrCopySkillTree -Destination $destination
    Write-Host "Staged OpenClaw plugin preview at $destination"
  }
}

if (-not (Get-Command switchbot -ErrorAction SilentlyContinue)) {
  Write-Warning 'switchbot CLI is not on PATH yet. Run again with -InstallCli or install @switchbot/openapi-cli manually.'
}

Write-Host 'Next step: run switchbot config set-token to configure credentials if you have not already.'