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

  [string]$Ref = 'main',

  [switch]$SkipCli,
  [switch]$SkipVerify,
  [switch]$SkipGitPull,
  [switch]$AllowDirty,
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Usage {
  @"
SwitchBot skill upgrader

Usage:
  pwsh ./scripts/upgrade.ps1 -Agent claude-global
  pwsh ./scripts/upgrade.ps1 -Agent copilot -WorkspacePath C:\path\to\workspace

What it does:
  1. Verifies the repo is safe to update
  2. Pulls the latest repo content from origin/<ref>
  3. Re-runs the installer for the selected agent target
  4. Updates @switchbot/openapi-cli unless -SkipCli is set
  5. Runs basic health checks unless -SkipVerify is set

Notes:
  - Use -AllowDirty only if you know the local changes are intentional.
  - Use -SkipGitPull only for testing the wrapper without fetching remote updates.
"@
}

if ($Help) {
  Show-Usage
  exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$installScript = Join-Path $PSScriptRoot 'install.ps1'
$policyPath = Join-Path $HOME '.config/openclaw/switchbot/policy.yaml'

function Assert-GitRepo {
  $inside = git -C $repoRoot rev-parse --is-inside-work-tree 2>$null
  if ($LASTEXITCODE -ne 0 -or $inside.Trim() -ne 'true') {
    throw "Not a git repository: $repoRoot"
  }
}

function Assert-CleanWorktree {
  if ($AllowDirty) {
    return
  }

  $status = git -C $repoRoot status --porcelain
  if (-not [string]::IsNullOrWhiteSpace(($status | Out-String))) {
    throw 'Repository has local changes. Commit or stash them first, or re-run with -AllowDirty.'
  }
}

function Update-Repo {
  if ($SkipGitPull) {
    return
  }

  $currentBranch = git -C $repoRoot branch --show-current
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to determine the current git branch.'
  }

  if ($currentBranch.Trim() -ne $Ref) {
    git -C $repoRoot checkout $Ref
    if ($LASTEXITCODE -ne 0) {
      throw "Unable to checkout branch '$Ref'."
    }
  }

  git -C $repoRoot pull --ff-only origin $Ref
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to pull origin/$Ref."
  }
}

function Invoke-Installer {
  $args = @{
    Agent = $Agent
    Mode = $Mode
    Force = $true
  }

  if ($WorkspacePath) {
    $args.WorkspacePath = $WorkspacePath
  }

  if (-not $SkipCli) {
    $args.InstallCli = $true
  }

  & $installScript @args
}

function Invoke-Verification {
  if ($SkipVerify) {
    return
  }

  if (-not (Get-Command switchbot -ErrorAction SilentlyContinue)) {
    throw 'switchbot CLI is not on PATH after upgrade.'
  }

  switchbot --version
  switchbot doctor

  if (Test-Path -LiteralPath $policyPath) {
    switchbot policy validate
  }
}

Assert-GitRepo
Assert-CleanWorktree
Update-Repo
Invoke-Installer
Invoke-Verification

Write-Host 'Upgrade complete. Restart the target agent or reopen the workspace to load the refreshed instructions.'