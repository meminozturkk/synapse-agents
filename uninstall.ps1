<#
==============================================================================
Synapse Agents Uninstaller for Windows
Safe Uninstallation & Link Cleanup for Antigravity, Claude Code & Cursor
==============================================================================
#>

[CmdletBinding()]
param(
    [Alias("all")]
    [switch]$All,

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
    Write-Host "Usage: .\uninstall.ps1 [OPTIONS]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -All, --all                               Remove symlinks, MCP registrations, and delete ~/.gemini/config/plugins/{ecc-lite,orchestration}"
    Write-Host "  -AntigravityOnly, --antigravity-only      Remove Antigravity MCP registration only"
    Write-Host "  -ClaudeOnly, --claude-only               Remove Claude Code symlinks only"
    Write-Host "  -CursorOnly, --cursor-only               Remove Cursor Global symlinks and MCP registration only"
    Write-Host "  -CursorProject <path>, --cursor-project   Remove Cursor rules and MCP registration from a specific project directory"
    Write-Host "  -Help, -h, --help                         Show this help message and exit"
    Write-Host ""
    Write-Host "Default: Safely removes global symlinks and MCP server registrations while preserving plugin files and learned instincts."
}

if ($Help) {
    Show-Usage
    exit 0
}

# ------------------------------------------------------------------------------
# Mode Resolution
# ------------------------------------------------------------------------------
$RemovePlugins = [bool]$All
$UninstallAntigravity = $true
$UninstallClaude = $true
$UninstallCursorGlobal = $true
$ExplicitMode = $false

if ($AntigravityOnly -or $ClaudeOnly -or $CursorOnly) {
    $ExplicitMode = $true
    $UninstallAntigravity = [bool]$AntigravityOnly
    $UninstallClaude = [bool]$ClaudeOnly
    $UninstallCursorGlobal = [bool]$CursorOnly
}

if (-not $ExplicitMode -and -not [string]::IsNullOrWhiteSpace($CursorProject)) {
    # If only -CursorProject is given without other modes, only uninstall project Cursor
    $UninstallAntigravity = $false
    $UninstallClaude = $false
    $UninstallCursorGlobal = $false
}

# ------------------------------------------------------------------------------
# Target Paths
# ------------------------------------------------------------------------------
$Timestamp = (Get-Date -Format "yyyyMMdd-HHmmss")

$GeminiPluginsDir = Join-Path $HOME ".gemini\config\plugins"
$McpConfigFile = Join-Path $HOME ".gemini\config\mcp_config.json"
$ClaudeBaseDir = Join-Path $HOME ".claude"
$ClaudeAgentsDir = Join-Path $ClaudeBaseDir "agents"
$ClaudeSkillsDir = Join-Path $ClaudeBaseDir "skills"
$BackupBaseDir = Join-Path $ClaudeBaseDir "backups"
$DotAgentsDir = Join-Path $HOME ".agents"

$CursorBaseDir = Join-Path $HOME ".cursor"
$CursorMcpFile = Join-Path $CursorBaseDir "mcp.json"
$CursorRulesDir = Join-Path $CursorBaseDir "rules"
$CursorSkillsDir = Join-Path $CursorBaseDir "skills"
$CursorAgentsDir = Join-Path $CursorBaseDir "agents"

$KnownSkills = @(
    "deep-review",
    "handoff",
    "kb",
    "model-orchestrator",
    "repo-audit",
    "systematic-debugging",
    "tdd",
    "tech-debt",
    "using-git-worktrees",
    "verification-gate",
    "orchestrator"
)

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------
function Get-SafePython {
    $candidates = @("python", "python3")
    foreach ($cand in $candidates) {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue
        if ($cmd) {
            try {
                $verOutput = (& $cand --version 2>&1) | Out-String
                if ($LASTEXITCODE -eq 0 -and $verOutput -match "Python 3\.") {
                    return $cand
                }
            } catch {}
        }
    }
    $pyCmd = Get-Command "py" -ErrorAction SilentlyContinue
    if ($pyCmd) {
        try {
            $verOutput = (& py -3 --version 2>&1) | Out-String
            if ($LASTEXITCODE -eq 0 -and $verOutput -match "Python 3\.") {
                return "py -3"
            }
        } catch {}
    }
    return $null
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


function Remove-SafeReparseOrItem {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [switch]$IsDirectory
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($IsDirectory -and [System.IO.Directory]::Exists($Path)) {
            try { [System.IO.Directory]::Delete($Path) } catch {}
        } elseif (-not $IsDirectory -and [System.IO.File]::Exists($Path)) {
            try { [System.IO.File]::Delete($Path) } catch {}
        } else {
            try {
                if ($IsDirectory) {
                    [System.IO.Directory]::Delete($Path)
                } else {
                    [System.IO.File]::Delete($Path)
                }
            } catch {}
        }
        return
    }

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -ne $item) {
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            # Reparse point (Junction or SymbolicLink): safe removal without recursing into target
            if ($item.PSIsContainer) {
                [System.IO.Directory]::Delete($Path)
            } else {
                [System.IO.File]::Delete($Path)
            }
        } else {
            # Regular directory/file (e.g. from copy fallback)
            if ($item.PSIsContainer) {
                Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Remove-DirectoryIfEmpty {
    param([string]$DirPath)
    if (Test-Path -LiteralPath $DirPath) {
        $children = Get-ChildItem -LiteralPath $DirPath -Force -ErrorAction SilentlyContinue
        if ($null -eq $children -or $children.Count -eq 0) {
            Remove-Item -LiteralPath $DirPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Remove-McpServer {
    param([string]$ConfigFile)
    if (-not (Test-Path -LiteralPath $ConfigFile)) {
        Write-Host "  [i] No configuration found at: $ConfigFile" -ForegroundColor Yellow
        return
    }

    $safePy = Get-SafePython
    if ($safePy) {
        $unregisterScript = Join-Path $ScriptDir "scripts\unregister_mcp.py"
        Invoke-PythonScript -Python $safePy -Script $unregisterScript -Arguments @(
            "--config", $ConfigFile,
            "--name", "ecc-lite-brain"
        )
    } else {
        # Fallback to PowerShell JSON parsing
        try {
            $raw = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8
            $data = $raw | ConvertFrom-Json
            if ($data.mcpServers -and $data.mcpServers."ecc-lite-brain") {
                $data.mcpServers.PSObject.Properties.Remove("ecc-lite-brain")
                $json = $data | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($ConfigFile, $json + "`n", [System.Text.UTF8Encoding]::new($false))
                Write-Host "  [OK] ecc-lite-brain successfully removed from $ConfigFile" -ForegroundColor Green
            } else {
                Write-Host "  [i] ecc-lite-brain was not present in $ConfigFile" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [!] Failed to update $ConfigFile`: $_" -ForegroundColor Red
        }
    }
}

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    Synapse Agents System Uninstaller                     " -ForegroundColor Cyan
Write-Host "       (ECC-Lite v2.0 + Orchestration v2.1.0)             " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. Preserve Knowledge Base (instincts.md)
# ------------------------------------------------------------------------------
Write-Host "[*] Step 1: Safeguarding learned instincts..." -ForegroundColor Cyan
$TargetInstincts = Join-Path $GeminiPluginsDir "ecc-lite\kb\instincts.md"
if (Test-Path -LiteralPath $TargetInstincts) {
    if (-not (Test-Path -LiteralPath $BackupBaseDir)) {
        New-Item -ItemType Directory -Path $BackupBaseDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $TargetInstincts -Destination (Join-Path $BackupBaseDir "instincts.md.bak") -Force
    Copy-Item -LiteralPath $TargetInstincts -Destination (Join-Path $BackupBaseDir "instincts.md.bak-$Timestamp") -Force
    Write-Host "  [OK] Instincts backed up safely to: $(Join-Path $BackupBaseDir 'instincts.md.bak')" -ForegroundColor Green
} else {
    Write-Host "  [i] No instincts.md found to back up." -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# 2. Clean Up Claude Code & ~/.agents Links
# ------------------------------------------------------------------------------
if ($UninstallClaude) {
    Write-Host ""
    Write-Host "[*] Step 2: Removing Claude Code & ~/.agents symlinks..." -ForegroundColor Cyan

    # Remove ~/.agents links
    if (Test-Path -LiteralPath $DotAgentsDir) {
        $items = @("hooks", "kb", "mcp", "rules", "skills")
        foreach ($item in $items) {
            $itemPath = Join-Path $DotAgentsDir $item
            if (Test-Path -LiteralPath $itemPath) {
                Remove-SafeReparseOrItem -Path $itemPath -IsDirectory
                Write-Host "  [OK] Removed link: $itemPath" -ForegroundColor Green
            }
        }
        Remove-DirectoryIfEmpty $DotAgentsDir
    }

    # Remove ~/.claude/agents/*.md files/links
    if (Test-Path -LiteralPath $ClaudeAgentsDir) {
        $agents = @("explorer", "planner", "coder", "reviewer")
        foreach ($agent in $agents) {
            $itemPath = Join-Path $ClaudeAgentsDir "$agent.md"
            if ((Test-Path -LiteralPath $itemPath) -or [System.IO.File]::Exists($itemPath)) {
                Remove-SafeReparseOrItem -Path $itemPath
                Write-Host "  [OK] Removed agent file: $itemPath" -ForegroundColor Green
            }
        }
        Remove-DirectoryIfEmpty $ClaudeAgentsDir
    }

    # Remove ~/.claude/skills links
    if (Test-Path -LiteralPath $ClaudeSkillsDir) {
        Get-ChildItem -LiteralPath $ClaudeSkillsDir -Force | ForEach-Object {
            $shouldRemove = $false
            if ($KnownSkills -contains $_.Name) {
                $shouldRemove = $true
            } else {
                $target = $_.Target
                if ($target -and ($target -like "*ecc-lite*" -or $target -like "*orchestration*")) {
                    $shouldRemove = $true
                }
            }
            if ($shouldRemove) {
                Remove-SafeReparseOrItem -Path $_.FullName -IsDirectory
                Write-Host "  [OK] Removed skill link: $($_.Name)" -ForegroundColor Green
            }
        }
        Remove-DirectoryIfEmpty $ClaudeSkillsDir
    }

    # Check ~/.claude/rules symlink
    $claudeRulesLink = Join-Path $ClaudeBaseDir "rules"
    if (Test-Path -LiteralPath $claudeRulesLink) {
        Remove-SafeReparseOrItem -Path $claudeRulesLink -IsDirectory
        Write-Host "  [OK] Removed link: $claudeRulesLink" -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------------
# 3. Clean Up Cursor Global Links
# ------------------------------------------------------------------------------
if ($UninstallCursorGlobal) {
    Write-Host ""
    Write-Host "[*] Step 3: Removing Cursor Global symlinks..." -ForegroundColor Cyan

    # Cursor Global Rules
    if (Test-Path -LiteralPath $CursorRulesDir) {
        $rules = @("coding-principles", "backend-dotnet", "frontend-web", "mobile-flutter", "agents-orchestration")
        foreach ($rule in $rules) {
            $itemPath = Join-Path $CursorRulesDir "$rule.mdc"
            if (Test-Path -LiteralPath $itemPath) {
                Remove-SafeReparseOrItem -Path $itemPath
                Write-Host "  [OK] Removed Cursor rule link: $itemPath" -ForegroundColor Green
            }
        }
        Remove-DirectoryIfEmpty $CursorRulesDir
    }

    # Cursor Global Agents
    if (Test-Path -LiteralPath $CursorAgentsDir) {
        $agents = @("explorer", "planner", "coder", "reviewer")
        foreach ($agent in $agents) {
            $itemPath = Join-Path $CursorAgentsDir "$agent.md"
            if ((Test-Path -LiteralPath $itemPath) -or [System.IO.File]::Exists($itemPath)) {
                Remove-SafeReparseOrItem -Path $itemPath
                Write-Host "  [OK] Removed Cursor agent file: $itemPath" -ForegroundColor Green
            }
        }
        Remove-DirectoryIfEmpty $CursorAgentsDir
    }

    # Cursor Global Skills
    if (Test-Path -LiteralPath $CursorSkillsDir) {
        Get-ChildItem -LiteralPath $CursorSkillsDir -Force | ForEach-Object {
            $shouldRemove = $false
            if ($KnownSkills -contains $_.Name) {
                $shouldRemove = $true
            } else {
                $target = $_.Target
                if ($target -and ($target -like "*ecc-lite*" -or $target -like "*orchestration*")) {
                    $shouldRemove = $true
                }
            }
            if ($shouldRemove) {
                Remove-SafeReparseOrItem -Path $_.FullName -IsDirectory
                Write-Host "  [OK] Removed Cursor skill link: $($_.Name)" -ForegroundColor Green
            }
        }
        Remove-DirectoryIfEmpty $CursorSkillsDir
    }
}

# ------------------------------------------------------------------------------
# 4. Clean Up Cursor Project Configuration (Optional: -CursorProject <path>)
# ------------------------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($CursorProject)) {
    if (Test-Path -LiteralPath $CursorProject) {
        $AbsProjectPath = (Resolve-Path -LiteralPath $CursorProject).Path
        $ProjectCursorDir = Join-Path $AbsProjectPath ".cursor"
        $ProjectRulesDir = Join-Path $ProjectCursorDir "rules"
        $ProjectMcpFile = Join-Path $ProjectCursorDir "mcp.json"

        Write-Host ""
        Write-Host "[*] Step 4: Removing Cursor Project configuration in $AbsProjectPath..." -ForegroundColor Cyan

        if (Test-Path -LiteralPath $ProjectRulesDir) {
            $rules = @("coding-principles", "backend-dotnet", "frontend-web", "mobile-flutter", "agents-orchestration")
            foreach ($rule in $rules) {
                $itemPath = Join-Path $ProjectRulesDir "$rule.mdc"
                if (Test-Path -LiteralPath $itemPath) {
                    Remove-SafeReparseOrItem -Path $itemPath
                    Write-Host "  [OK] Removed project rule link: $itemPath" -ForegroundColor Green
                }
            }
            Remove-DirectoryIfEmpty $ProjectRulesDir
        }

        Write-Host "  -> Removing ecc-lite-brain from Project MCP configuration..." -ForegroundColor Cyan
        Remove-McpServer -ConfigFile $ProjectMcpFile
        Remove-DirectoryIfEmpty $ProjectCursorDir
    } else {
        Write-Host "  [i] Project directory not found: $CursorProject" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------------------
# 5. Deregister ecc-lite-brain from MCP Configurations
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[*] Step 5: Deregistering ecc-lite-brain from MCP configurations..." -ForegroundColor Cyan

if ($UninstallAntigravity) {
    Write-Host "  -> Updating Antigravity MCP configuration..." -ForegroundColor Cyan
    Remove-McpServer -ConfigFile $McpConfigFile
}

if ($UninstallCursorGlobal) {
    Write-Host "  -> Updating Cursor Global MCP configuration..." -ForegroundColor Cyan
    Remove-McpServer -ConfigFile $CursorMcpFile
}

# ------------------------------------------------------------------------------
# 6. Remove Plugins Directory (If -All was requested)
# ------------------------------------------------------------------------------
if ($RemovePlugins) {
    Write-Host ""
    Write-Host "[*] Step 6 (-All): Removing plugin directories from ~/.gemini/config/plugins/..." -ForegroundColor Yellow
    $eccDir = Join-Path $GeminiPluginsDir "ecc-lite"
    if (Test-Path -LiteralPath $eccDir) {
        Remove-Item -LiteralPath $eccDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Removed $eccDir" -ForegroundColor Green
    }
    $orchDir = Join-Path $GeminiPluginsDir "orchestration"
    if (Test-Path -LiteralPath $orchDir) {
        Remove-Item -LiteralPath $orchDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Removed $orchDir" -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------------
# Completion Summary
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "    [OK] Uninstallation completed successfully!             " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Summary:"
if ($UninstallClaude) {
    Write-Host "  - Claude Code & ~/.agents symlinks removed"
}
if ($UninstallCursorGlobal) {
    Write-Host "  - Cursor Global symlinks and MCP registration removed"
}
if (-not [string]::IsNullOrWhiteSpace($CursorProject)) {
    Write-Host "  - Cursor Project configuration removed from $CursorProject"
}
if ($UninstallAntigravity) {
    Write-Host "  - Antigravity MCP server ecc-lite-brain deregistered"
}
if ($RemovePlugins) {
    Write-Host "  - Plugin directories removed from ~/.gemini/config/plugins"
}
$backupFile = Join-Path $BackupBaseDir "instincts.md.bak"
if (Test-Path -LiteralPath $backupFile) {
    Write-Host "  - User Instincts preserved at: $backupFile"
}
Write-Host ""
