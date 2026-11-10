<#
==============================================================================
Synapse Agents Installer for Windows
Multi-Platform Idempotent Installation for Antigravity, Claude Code & Cursor
==============================================================================
#>

[CmdletBinding()]
param(
    [Alias("antigravity-only")]
    [switch]$AntigravityOnly,

    [Alias("claude-only")]
    [switch]$ClaudeOnly,

    [Alias("cursor-only")]
    [switch]$CursorOnly,

    [Alias("cursor-project")]
    [string]$CursorProject = "",

    [Alias("h", "?")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Usage {
    Write-Host "Usage: .\install.ps1 [OPTIONS]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -AntigravityOnly, --antigravity-only      Install plugins and MCP configuration for Antigravity only"
    Write-Host "  -ClaudeOnly, --claude-only               Install core plugins and configure Claude Code symlinks only"
    Write-Host "  -CursorOnly, --cursor-only               Install core plugins and configure Cursor Global only"
    Write-Host "  -CursorProject <path>, --cursor-project   Configure Cursor rules and MCP for a specific project directory"
    Write-Host "  -Help, -h, --help                         Show this help message and exit"
    Write-Host ""
    Write-Host "Default: Installs Antigravity plugins/MCP, Claude Code symlinks, and Cursor Global configuration."
}

if ($Help) {
    Show-Usage
    exit 0
}

# ------------------------------------------------------------------------------
# Mode Resolution
# ------------------------------------------------------------------------------
$InstallAntigravity = $true
$InstallClaude = $true
$InstallCursorGlobal = $true
$ExplicitMode = $false

if ($AntigravityOnly -or $ClaudeOnly -or $CursorOnly) {
    $ExplicitMode = $true
    $InstallAntigravity = [bool]$AntigravityOnly
    $InstallClaude = [bool]$ClaudeOnly
    $InstallCursorGlobal = [bool]$CursorOnly
}

if (-not $ExplicitMode -and -not [string]::IsNullOrWhiteSpace($CursorProject)) {
    # If only -CursorProject is given without other modes, only install project Cursor
    $InstallAntigravity = $false
    $InstallClaude = $false
    $InstallCursorGlobal = $false
}

if (-not [string]::IsNullOrWhiteSpace($CursorProject)) {
    if (-not (Test-Path -LiteralPath $CursorProject -PathType Container)) {
        Write-Error "[!] Error: Specified project path does not exist or is not a directory: $CursorProject"
        exit 1
    }
}

# ------------------------------------------------------------------------------
# Script & Target Paths
# ------------------------------------------------------------------------------
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if (-not $ScriptDir) {
    $ScriptDir = (Get-Location).Path
}

$Timestamp = (Get-Date -Format "yyyyMMdd-HHmmss")

$GeminiPluginsDir = Join-Path $HOME ".gemini\config\plugins"
$McpConfigFile = Join-Path $HOME ".gemini\config\mcp_config.json"
$ClaudeBaseDir = Join-Path $HOME ".claude"
$ClaudeAgentsDir = Join-Path $ClaudeBaseDir "agents"
$ClaudeSkillsDir = Join-Path $ClaudeBaseDir "skills"
$BackupDir = Join-Path $ClaudeBaseDir "backups\pre-install-$Timestamp"
$DotAgentsDir = Join-Path $HOME ".agents"

$CursorBaseDir = Join-Path $HOME ".cursor"
$CursorMcpFile = Join-Path $CursorBaseDir "mcp.json"
$CursorRulesDir = Join-Path $CursorBaseDir "rules"
$CursorSkillsDir = Join-Path $CursorBaseDir "skills"
$CursorAgentsDir = Join-Path $CursorBaseDir "agents"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------
function Resolve-PythonCommand {
    $candidates = @("python", "python3")
    foreach ($cand in $candidates) {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue
        if ($cmd) {
            try {
                $verOutput = (& $cand --version 2>&1) | Out-String
                if ($LASTEXITCODE -eq 0 -and $verOutput -match "Python 3\.") {
                    $exePath = (& $cand -c "import sys; print(sys.executable)" 2>&1) | Out-String
                    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($exePath)) {
                        $cleanPath = $exePath.Trim().Split("`r`n")[0].Trim()
                        if (Test-Path -LiteralPath $cleanPath) {
                            return ($cleanPath -replace '\\', '/')
                        }
                    }
                    return ($cmd.Source -replace '\\', '/')
                }
            } catch {
                # Continue searching
            }
        }
    }

    $pyCmd = Get-Command "py" -ErrorAction SilentlyContinue
    if ($pyCmd) {
        try {
            $verOutput = (& py -3 --version 2>&1) | Out-String
            if ($LASTEXITCODE -eq 0 -and $verOutput -match "Python 3\.") {
                $exePath = (& py -3 -c "import sys; print(sys.executable)" 2>&1) | Out-String
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($exePath)) {
                    $cleanPath = $exePath.Trim().Split("`r`n")[0].Trim()
                    if (Test-Path -LiteralPath $cleanPath) {
                        return ($cleanPath -replace '\\', '/')
                    }
                }
            }
        } catch {
            # Continue searching
        }
    }

    Write-Error "[!] Error: Python 3.x was not found. Please install Python 3 (https://www.python.org/) and ensure it is added to your PATH."
    exit 1
}

function Invoke-PythonScript {
    param(
        [Parameter(Mandatory=$true)][string]$Python,
        [Parameter(Mandatory=$true)][string]$Script,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments
    )

    if (-not (Test-Path -LiteralPath $Script)) {
        Write-Error "[!] Error: Python script not found: $Script"
        exit 1
    }

    $exe = $Python
    $preArgs = @()

    if (Test-Path -LiteralPath $Python) {
        $exe = $Python
    } elseif ($Python -match '\s+') {
        $parts = $Python -split '\s+'
        $exe = $parts[0]
        if ($parts.Count -gt 1) {
            $preArgs = $parts[1..($parts.Count - 1)]
        }
    }

    & $exe @preArgs $Script @Arguments

    if ($LASTEXITCODE -ne 0) {
        Write-Error "[!] Error: Python script failed ($Script with exit code $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
}


function Remove-SafeItem {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($item) {
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                if ($item.PSIsContainer) {
                    [System.IO.Directory]::Delete($Path)
                } else {
                    [System.IO.File]::Delete($Path)
                }
            } else {
                if ($item.PSIsContainer) {
                    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
                }
            }
        } elseif ([System.IO.Directory]::Exists($Path)) {
            [System.IO.Directory]::Delete($Path, $true)
        } elseif ([System.IO.File]::Exists($Path)) {
            [System.IO.File]::Delete($Path)
        }
    } catch {
        # Best effort cleanup
    }
}

function New-SafeDirectoryLink {
    param(
        [Parameter(Mandatory=$true)][string]$LinkPath,
        [Parameter(Mandatory=$true)][string]$TargetPath
    )
    $parent = Split-Path -Parent $LinkPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $LinkPath) {
        $item = Get-Item -LiteralPath $LinkPath -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            [System.IO.Directory]::Delete($LinkPath)
        } else {
            Remove-Item -LiteralPath $LinkPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $absTarget = [System.IO.Path]::GetFullPath($TargetPath)

    # 1. Try Junction (NTFS Junctions work on Windows without Administrator or Developer Mode!)
    try {
        New-Item -ItemType Junction -Path $LinkPath -Target $absTarget -Force -ErrorAction Stop | Out-Null
        return
    } catch {
        # Fallback to symbolic link
    }

    # 2. Try SymbolicLink
    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $absTarget -Force -ErrorAction Stop | Out-Null
        return
    } catch {
        # Fallback to copy
    }

    # 3. Fallback: Copy-Item
    Copy-Item -LiteralPath $absTarget -Destination $LinkPath -Recurse -Force
}

function New-SafeFileLink {
    param(
        [Parameter(Mandatory=$true)][string]$LinkPath,
        [Parameter(Mandatory=$true)][string]$TargetPath
    )
    $parent = Split-Path -Parent $LinkPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Remove-SafeItem $LinkPath

    $absTarget = [System.IO.Path]::GetFullPath($TargetPath)

    # 1. Try SymbolicLink (works if Developer Mode or Elevated)
    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $absTarget -Force -ErrorAction Stop | Out-Null
        return
    } catch {
        # Fallback to HardLink
    }

    # 2. Try HardLink (works without admin privileges on same volume)
    try {
        New-Item -ItemType HardLink -Path $LinkPath -Target $absTarget -Force -ErrorAction Stop | Out-Null
        return
    } catch {
        # Fallback to copy
    }

    # 3. Fallback: Copy-Item (works cross-drive or on non-NTFS)
    Copy-Item -LiteralPath $absTarget -Destination $LinkPath -Force
}

function Update-McpConfig {
    param(
        [Parameter(Mandatory=$true)][string]$ConfigFile,
        [Parameter(Mandatory=$true)][string]$PythonExe,
        [Parameter(Mandatory=$true)][string]$BrainServerPath
    )

    $parentDir = Split-Path -Parent $ConfigFile
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $registerScript = Join-Path $ScriptDir "scripts\register_mcp.py"
    Invoke-PythonScript -Python $PythonExe -Script $registerScript -Arguments @(
        "--config", $ConfigFile,
        "--python", $PythonExe,
        "--server", $BrainServerPath
    )
}

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    Synapse Agents System Installer                       " -ForegroundColor Cyan
Write-Host "       (ECC-Lite v2.0 + Orchestration v2.1.0)             " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# Detect Python 3
# ------------------------------------------------------------------------------
$ResolvedPython = Resolve-PythonCommand
Write-Host "[*] Python 3 detected: $ResolvedPython" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 1. Backup Existing Configurations
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[*] Step 1: Checking and backing up existing installation..." -ForegroundColor Cyan
$ClaudeBackupsDir = Join-Path $ClaudeBaseDir "backups"
if (-not (Test-Path -LiteralPath $ClaudeBackupsDir)) {
    New-Item -ItemType Directory -Path $ClaudeBackupsDir -Force | Out-Null
}

$NeedBackup = $false
$EccLiteTarget = Join-Path $GeminiPluginsDir "ecc-lite"
$OrchTarget = Join-Path $GeminiPluginsDir "orchestration"

if ((Test-Path -LiteralPath $EccLiteTarget) -or (Test-Path -LiteralPath $OrchTarget) -or (Test-Path -LiteralPath $DotAgentsDir) -or (Test-Path -LiteralPath $CursorMcpFile)) {
    $NeedBackup = $true
}
if (-not [string]::IsNullOrWhiteSpace($CursorProject)) {
    $ProjMcp = Join-Path $CursorProject ".cursor\mcp.json"
    if (Test-Path -LiteralPath $ProjMcp) {
        $NeedBackup = $true
    }
}

if ($NeedBackup) {
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    Write-Host "  -> Taking backup to: $BackupDir" -ForegroundColor Yellow

    if (Test-Path -LiteralPath $EccLiteTarget) {
        Copy-Item -LiteralPath $EccLiteTarget -Destination (Join-Path $BackupDir "ecc-lite") -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $OrchTarget) {
        Copy-Item -LiteralPath $OrchTarget -Destination (Join-Path $BackupDir "orchestration") -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $McpConfigFile) {
        Copy-Item -LiteralPath $McpConfigFile -Destination (Join-Path $BackupDir "mcp_config.json") -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $CursorMcpFile) {
        Copy-Item -LiteralPath $CursorMcpFile -Destination (Join-Path $BackupDir "cursor_mcp.json") -Force -ErrorAction SilentlyContinue
    }
    if (-not [string]::IsNullOrWhiteSpace($CursorProject)) {
        $ProjMcp = Join-Path $CursorProject ".cursor\mcp.json"
        if (Test-Path -LiteralPath $ProjMcp) {
            Copy-Item -LiteralPath $ProjMcp -Destination (Join-Path $BackupDir "project_cursor_mcp.json") -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "  [OK] Backup completed." -ForegroundColor Green
} else {
    Write-Host "  [OK] No existing installation found that requires backup." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 2. Core Plugins Sync & Triple-Protected instincts.md & hooks.json
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[*] Step 2: Syncing core plugins to ~/.gemini/config/plugins/..." -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $GeminiPluginsDir)) {
    New-Item -ItemType Directory -Path $GeminiPluginsDir -Force | Out-Null
}

$TargetInstincts = Join-Path $GeminiPluginsDir "ecc-lite\kb\instincts.md"
$TempInstincts = $null
if (Test-Path -LiteralPath $TargetInstincts) {
    Write-Host "  [i] Existing instincts.md found. Preserving learned reflexes..." -ForegroundColor Yellow
    $TempInstincts = [System.IO.Path]::GetTempFileName()
    Copy-Item -LiteralPath $TargetInstincts -Destination $TempInstincts -Force
}

# Sync plugins/ecc-lite
$EccLiteSrc = Join-Path $ScriptDir "plugins\ecc-lite"
$EccLiteDst = Join-Path $GeminiPluginsDir "ecc-lite"
if (Test-Path -LiteralPath $EccLiteSrc) {
    if (-not (Test-Path -LiteralPath $EccLiteDst)) {
        New-Item -ItemType Directory -Path $EccLiteDst -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $EccLiteSrc "*") -Destination $EccLiteDst -Recurse -Force
    Write-Host "  [OK] Synced plugins/ecc-lite" -ForegroundColor Green
} else {
    Write-Error "[!] Error: $EccLiteSrc not found!"
    exit 1
}

# Sync plugins/orchestration
$OrchSrc = Join-Path $ScriptDir "plugins\orchestration"
$OrchDst = Join-Path $GeminiPluginsDir "orchestration"
if (Test-Path -LiteralPath $OrchSrc) {
    if (-not (Test-Path -LiteralPath $OrchDst)) {
        New-Item -ItemType Directory -Path $OrchDst -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $OrchSrc "*") -Destination $OrchDst -Recurse -Force
    Write-Host "  [OK] Synced plugins/orchestration" -ForegroundColor Green
} else {
    Write-Error "[!] Error: $OrchSrc not found!"
    exit 1
}

# Restore or Initialize instincts.md
if ($TempInstincts -and (Test-Path -LiteralPath $TempInstincts)) {
    Copy-Item -LiteralPath $TempInstincts -Destination $TargetInstincts -Force
    Remove-Item -LiteralPath $TempInstincts -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Existing instincts.md successfully restored & preserved." -ForegroundColor Green
} elseif (-not (Test-Path -LiteralPath $TargetInstincts)) {
    $ExampleInstincts = Join-Path $GeminiPluginsDir "ecc-lite\kb\instincts.example.md"
    if (Test-Path -LiteralPath $ExampleInstincts) {
        Copy-Item -LiteralPath $ExampleInstincts -Destination $TargetInstincts -Force
        Write-Host "  [OK] Initialized new instincts.md from instincts.example.md." -ForegroundColor Green
    }
}

# Windows-Native hooks.json Rewrite
Write-Host "  -> Configuring Windows-native hooks.json..." -ForegroundColor Cyan
$HooksFile = Join-Path $GeminiPluginsDir "ecc-lite\hooks.json"
$HooksDir = ($GeminiPluginsDir -replace '\\', '/') + "/ecc-lite/hooks"
$patchHooksScript = Join-Path $ScriptDir "scripts\patch_hooks.py"

Invoke-PythonScript -Python $ResolvedPython -Script $patchHooksScript -Arguments @(
    "--hooks-json", $HooksFile,
    "--python", $ResolvedPython,
    "--hooks-dir", $HooksDir
)

$BrainServer = ($GeminiPluginsDir -replace '\\', '/') + "/ecc-lite/mcp/brain_server.py"

# Antigravity MCP Setup
if ($InstallAntigravity) {
    Write-Host "  -> Updating Antigravity MCP configuration ($McpConfigFile)..." -ForegroundColor Cyan
    Update-McpConfig -ConfigFile $McpConfigFile -PythonExe $ResolvedPython -BrainServerPath $BrainServer
}

# ------------------------------------------------------------------------------
# 3. Claude Code Compatibility Symlinks
# ------------------------------------------------------------------------------
if ($InstallClaude) {
    Write-Host ""
    Write-Host "[*] Step 3: Configuring Claude Code compatibility symlinks..." -ForegroundColor Cyan

    # 3A. ~/.agents symlinks
    $items = @("hooks", "kb", "mcp", "rules", "skills")
    foreach ($item in $items) {
        $target = Join-Path $GeminiPluginsDir "ecc-lite\$item"
        $link = Join-Path $DotAgentsDir $item
        New-SafeDirectoryLink -LinkPath $link -TargetPath $target
    }
    Write-Host "  [OK] Linked ~/.agents/{hooks,kb,mcp,rules,skills}" -ForegroundColor Green

    # 3B. Claude Code Agents (platform-adaptive sync)
    if (-not (Test-Path -LiteralPath $ClaudeAgentsDir)) {
        New-Item -ItemType Directory -Path $ClaudeAgentsDir -Force | Out-Null
    }
    $syncAgentsScript = Join-Path $ScriptDir "scripts\sync_agents.py"
    $orchAgentsDir = Join-Path $GeminiPluginsDir "orchestration\agents"
    Invoke-PythonScript -Python $ResolvedPython -Script $syncAgentsScript -Arguments @(
        "--source", $orchAgentsDir,
        "--dest", $ClaudeAgentsDir,
        "--platform", "claude"
    )

    # 3C. ~/.claude/skills/* links
    $eccSkillsDir = Join-Path $GeminiPluginsDir "ecc-lite\skills"
    if (Test-Path -LiteralPath $eccSkillsDir) {
        Get-ChildItem -LiteralPath $eccSkillsDir -Directory | ForEach-Object {
            $linkSkill = Join-Path $ClaudeSkillsDir $_.Name
            New-SafeDirectoryLink -LinkPath $linkSkill -TargetPath $_.FullName
        }
    }
    $orchSkillsDir = Join-Path $GeminiPluginsDir "orchestration\skills"
    if (Test-Path -LiteralPath $orchSkillsDir) {
        Get-ChildItem -LiteralPath $orchSkillsDir -Directory | ForEach-Object {
            $linkSkill = Join-Path $ClaudeSkillsDir $_.Name
            New-SafeDirectoryLink -LinkPath $linkSkill -TargetPath $_.FullName
        }
    }
    Write-Host "  [OK] Linked all skills to ~/.claude/skills/" -ForegroundColor Green

    # 3D. ~/.claude/rules symlink
    $claudeRulesLink = Join-Path $ClaudeBaseDir "rules"
    $dotAgentsRules = Join-Path $DotAgentsDir "rules"
    if (-not (Test-Path -LiteralPath $claudeRulesLink)) {
        New-SafeDirectoryLink -LinkPath $claudeRulesLink -TargetPath $dotAgentsRules
        Write-Host "  [OK] Linked ~/.claude/rules -> ~/.agents/rules" -ForegroundColor Green
    }

    # 3E. Claude Code hooks (~/.claude/settings.json) & MCP brain (~/.claude.json)
    Write-Host "  -> Registering 0-token hooks and ecc-lite-brain MCP with Claude Code..." -ForegroundColor Cyan
    $registerClaudeScript = Join-Path $ScriptDir "scripts\register_claude.py"
    Invoke-PythonScript -Python $ResolvedPython -Script $registerClaudeScript -Arguments @(
        "install",
        "--python", $ResolvedPython,
        "--hooks-dir", $HooksDir,
        "--server", $BrainServer,
        "--runtime", "py",
        "--backup-dir", $BackupDir
    )
}

# ------------------------------------------------------------------------------
# 4. Cursor Global Configuration
# ------------------------------------------------------------------------------
if ($InstallCursorGlobal) {
    Write-Host ""
    Write-Host "[*] Step 4: Configuring Cursor Global compatibility..." -ForegroundColor Cyan

    # 4A. Update ~/.cursor/mcp.json
    Write-Host "  -> Updating Cursor Global MCP configuration ($CursorMcpFile)..." -ForegroundColor Cyan
    Update-McpConfig -ConfigFile $CursorMcpFile -PythonExe $ResolvedPython -BrainServerPath $BrainServer

    # 4B. Cursor Global Rules (.mdc links)
    $ruleMappings = [ordered]@{
        "coding-principles.mdc" = Join-Path $GeminiPluginsDir "ecc-lite\rules\coding-principles.md"
        "backend-dotnet.mdc"     = Join-Path $GeminiPluginsDir "ecc-lite\rules\backend-dotnet.md"
        "frontend-web.mdc"       = Join-Path $GeminiPluginsDir "ecc-lite\rules\frontend-web.md"
        "mobile-flutter.mdc"     = Join-Path $GeminiPluginsDir "ecc-lite\rules\mobile-flutter.md"
        "agents-orchestration.mdc" = Join-Path $GeminiPluginsDir "orchestration\rules\AGENTS.md"
    }

    foreach ($ruleName in $ruleMappings.Keys) {
        $targetRule = $ruleMappings[$ruleName]
        if (Test-Path -LiteralPath $targetRule) {
            $linkRule = Join-Path $CursorRulesDir $ruleName
            New-SafeFileLink -LinkPath $linkRule -TargetPath $targetRule
        }
    }
    Write-Host "  [OK] Linked ~/.cursor/rules/*.mdc (5 rules)" -ForegroundColor Green

    # 4C. Cursor Global Skills links
    $eccSkillsDir = Join-Path $GeminiPluginsDir "ecc-lite\skills"
    if (Test-Path -LiteralPath $eccSkillsDir) {
        Get-ChildItem -LiteralPath $eccSkillsDir -Directory | ForEach-Object {
            $linkSkill = Join-Path $CursorSkillsDir $_.Name
            New-SafeDirectoryLink -LinkPath $linkSkill -TargetPath $_.FullName
        }
    }
    $orchSkillsDir = Join-Path $GeminiPluginsDir "orchestration\skills"
    if (Test-Path -LiteralPath $orchSkillsDir) {
        Get-ChildItem -LiteralPath $orchSkillsDir -Directory | ForEach-Object {
            $linkSkill = Join-Path $CursorSkillsDir $_.Name
            New-SafeDirectoryLink -LinkPath $linkSkill -TargetPath $_.FullName
        }
    }
    Write-Host "  [OK] Linked all skills to ~/.cursor/skills/ (11 skills)" -ForegroundColor Green

    # 4D. Cursor Global Agents (platform-adaptive sync)
    if (-not (Test-Path -LiteralPath $CursorAgentsDir)) {
        New-Item -ItemType Directory -Path $CursorAgentsDir -Force | Out-Null
    }
    $syncAgentsScript = Join-Path $ScriptDir "scripts\sync_agents.py"
    $orchAgentsDir = Join-Path $GeminiPluginsDir "orchestration\agents"
    Invoke-PythonScript -Python $ResolvedPython -Script $syncAgentsScript -Arguments @(
        "--source", $orchAgentsDir,
        "--dest", $CursorAgentsDir,
        "--platform", "cursor"
    )

    # 4E. Cursor Global Hooks (~/.cursor/hooks.json)
    Write-Host "  -> Registering 0-token hooks in Cursor Global ($CursorBaseDir\hooks.json)..." -ForegroundColor Cyan
    $registerCursorScript = Join-Path $ScriptDir "scripts\register_cursor_hooks.py"
    $cursorHooksFile = Join-Path $CursorBaseDir "hooks.json"
    Invoke-PythonScript -Python $ResolvedPython -Script $registerCursorScript -Arguments @(
        "--action", "install",
        "--hooks-file", $cursorHooksFile,
        "--hooks-dir", $HooksDir,
        "--python", $ResolvedPython,
        "--platform", "windows"
    )
}

# ------------------------------------------------------------------------------
# 5. Cursor Project Configuration (Optional: -CursorProject <path>)
# ------------------------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($CursorProject)) {
    $AbsProjectPath = (Resolve-Path -LiteralPath $CursorProject).Path
    $ProjectCursorDir = Join-Path $AbsProjectPath ".cursor"
    $ProjectRulesDir = Join-Path $ProjectCursorDir "rules"
    $ProjectMcpFile = Join-Path $ProjectCursorDir "mcp.json"

    Write-Host ""
    Write-Host "[*] Step 5: Configuring Cursor Project in $AbsProjectPath..." -ForegroundColor Cyan

    $ruleMappings = [ordered]@{
        "coding-principles.mdc" = Join-Path $GeminiPluginsDir "ecc-lite\rules\coding-principles.md"
        "backend-dotnet.mdc"     = Join-Path $GeminiPluginsDir "ecc-lite\rules\backend-dotnet.md"
        "frontend-web.mdc"       = Join-Path $GeminiPluginsDir "ecc-lite\rules\frontend-web.md"
        "mobile-flutter.mdc"     = Join-Path $GeminiPluginsDir "ecc-lite\rules\mobile-flutter.md"
        "agents-orchestration.mdc" = Join-Path $GeminiPluginsDir "orchestration\rules\AGENTS.md"
    }

    foreach ($ruleName in $ruleMappings.Keys) {
        $targetRule = $ruleMappings[$ruleName]
        if (Test-Path -LiteralPath $targetRule) {
            $linkRule = Join-Path $ProjectRulesDir $ruleName
            New-SafeFileLink -LinkPath $linkRule -TargetPath $targetRule
        }
    }
    Write-Host "  [OK] Linked $ProjectRulesDir\*.mdc (5 rules)" -ForegroundColor Green

    Write-Host "  -> Updating Project MCP configuration ($ProjectMcpFile)..." -ForegroundColor Cyan
    Update-McpConfig -ConfigFile $ProjectMcpFile -PythonExe $ResolvedPython -BrainServerPath $BrainServer

    # Hooks
    Write-Host "  -> Registering 0-token hooks in Project Cursor ($ProjectCursorDir\hooks.json)..." -ForegroundColor Cyan
    $registerCursorScript = Join-Path $ScriptDir "scripts\register_cursor_hooks.py"
    $projectHooksFile = Join-Path $ProjectCursorDir "hooks.json"
    Invoke-PythonScript -Python $ResolvedPython -Script $registerCursorScript -Arguments @(
        "--action", "install",
        "--hooks-file", $projectHooksFile,
        "--hooks-dir", $HooksDir,
        "--python", $ResolvedPython,
        "--platform", "windows"
    )
}

# ------------------------------------------------------------------------------
# Completion Summary
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "    [OK] Installation completed successfully!               " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Active Configuration:"
Write-Host "  - Core Plugins       : $GeminiPluginsDir"
if ($InstallAntigravity) {
    Write-Host "  - Antigravity MCP    : ecc-lite-brain active in $McpConfigFile"
}
if ($InstallClaude) {
    Write-Host "  - Claude Code Agents : explorer, planner, coder, reviewer"
    Write-Host "  - Claude Code Hooks  : secret-guard (PreToolUse), verify-quiet (Stop) in $ClaudeBaseDir\settings.json"
    Write-Host "  - Claude Code MCP    : ecc-lite-brain active in $HOME\.claude.json (user scope)"
}
if ($InstallCursorGlobal) {
    Write-Host "  - Cursor Global      : 5 rules (.mdc), 11 skills, 4 agents, hooks & MCP active"
}
if (-not [string]::IsNullOrWhiteSpace($CursorProject)) {
    Write-Host "  - Cursor Project     : rules (.mdc), hooks & MCP active in $AbsProjectPath"
}
Write-Host "  - User Instincts     : $TargetInstincts (preserved)"
Write-Host ""
