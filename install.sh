#!/usr/bin/env bash
# ==============================================================================
# ecc-lite-orchestrator Installer
# Dual-Mode Idempotent Installation for Antigravity & Claude Code
# ==============================================================================

set -euo pipefail

# ANSI color codes for stylish terminal output
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# Target Directories
GEMINI_PLUGINS_DIR="${HOME}/.gemini/config/plugins"
MCP_CONFIG_FILE="${HOME}/.gemini/config/mcp_config.json"
CLAUDE_BASE_DIR="${HOME}/.claude"
CLAUDE_AGENTS_DIR="${CLAUDE_BASE_DIR}/agents"
CLAUDE_SKILLS_DIR="${CLAUDE_BASE_DIR}/skills"
BACKUP_DIR="${CLAUDE_BASE_DIR}/backups/pre-install-${TIMESTAMP}"
DOT_AGENTS_DIR="${HOME}/.agents"

# Modes
INSTALL_ANTIGRAVITY=true
INSTALL_CLAUDE=true

# Parse Flags
usage() {
    echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --antigravity-only    Install plugins and MCP configuration for Antigravity only"
    echo "  --claude-only         Configure symlinks for Claude Code compatibility only"
    echo "  -h, --help            Show this help message and exit"
    echo ""
    echo "Default: Installs both Antigravity plugins and Claude Code symlinks."
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --antigravity-only)
            INSTALL_ANTIGRAVITY=true
            INSTALL_CLAUDE=false
            shift
            ;;
        --claude-only)
            INSTALL_ANTIGRAVITY=false
            INSTALL_CLAUDE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}[!] Unknown option:${NC} $1"
            usage
            ;;
    esac
done

echo -e "${CYAN}${BOLD}"
echo "=========================================================="
echo "    🚀 ecc-lite-orchestrator System Installer            "
echo "=========================================================="
echo -e "${NC}"

# ------------------------------------------------------------------------------
# 1. Backup Existing Configurations
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Step 1: Checking and backing up existing installation...${NC}"
mkdir -p "${CLAUDE_BASE_DIR}/backups"

NEED_BACKUP=false
if [[ -d "${GEMINI_PLUGINS_DIR}/ecc-lite" || -d "${GEMINI_PLUGINS_DIR}/orchestration" || -d "${DOT_AGENTS_DIR}" ]]; then
    NEED_BACKUP=true
fi

if [[ "$NEED_BACKUP" == true ]]; then
    mkdir -p "$BACKUP_DIR"
    echo -e "  ${YELLOW}→ Taking backup to:${NC} ${BACKUP_DIR}"
    
    if [[ -d "${GEMINI_PLUGINS_DIR}/ecc-lite" ]]; then
        cp -R "${GEMINI_PLUGINS_DIR}/ecc-lite" "${BACKUP_DIR}/ecc-lite" 2>/dev/null || true
    fi
    if [[ -d "${GEMINI_PLUGINS_DIR}/orchestration" ]]; then
        cp -R "${GEMINI_PLUGINS_DIR}/orchestration" "${BACKUP_DIR}/orchestration" 2>/dev/null || true
    fi
    if [[ -f "$MCP_CONFIG_FILE" ]]; then
        cp "$MCP_CONFIG_FILE" "${BACKUP_DIR}/mcp_config.json" 2>/dev/null || true
    fi
    echo -e "  ${GREEN}✓ Backup completed.${NC}"
else
    echo -e "  ${GREEN}✓ No existing installation found that requires backup.${NC}"
fi

# ------------------------------------------------------------------------------
# 2. Antigravity Plugins & MCP Setup
# ------------------------------------------------------------------------------
if [[ "$INSTALL_ANTIGRAVITY" == true ]]; then
    echo ""
    echo -e "${BLUE}[*] Step 2: Installing plugins to Antigravity (~/.gemini/config/plugins/)...${NC}"
    mkdir -p "$GEMINI_PLUGINS_DIR"

    # Temporary preservation for instincts.md (Rule: NEVER overwrite user instincts!)
    TARGET_INSTINCTS="${GEMINI_PLUGINS_DIR}/ecc-lite/kb/instincts.md"
    TEMP_INSTINCTS=""
    if [[ -f "$TARGET_INSTINCTS" ]]; then
        echo -e "  ${YELLOW}ℹ Existing instincts.md found. Preserving learned reflexes...${NC}"
        TEMP_INSTINCTS="$(mktemp)"
        cp "$TARGET_INSTINCTS" "$TEMP_INSTINCTS"
    fi

    # Sync ecc-lite
    if [[ -d "${SCRIPT_DIR}/plugins/ecc-lite" ]]; then
        mkdir -p "${GEMINI_PLUGINS_DIR}/ecc-lite"
        # Copy directory contents recursively
        cp -R "${SCRIPT_DIR}/plugins/ecc-lite/"* "${GEMINI_PLUGINS_DIR}/ecc-lite/"
        echo -e "  ${GREEN}✓ Synced plugins/ecc-lite${NC}"
    else
        echo -e "  ${RED}✗ Error: ${SCRIPT_DIR}/plugins/ecc-lite not found!${NC}"
        exit 1
    fi

    # Sync orchestration
    if [[ -d "${SCRIPT_DIR}/plugins/orchestration" ]]; then
        mkdir -p "${GEMINI_PLUGINS_DIR}/orchestration"
        cp -R "${SCRIPT_DIR}/plugins/orchestration/"* "${GEMINI_PLUGINS_DIR}/orchestration/"
        echo -e "  ${GREEN}✓ Synced plugins/orchestration${NC}"
    else
        echo -e "  ${RED}✗ Error: ${SCRIPT_DIR}/plugins/orchestration not found!${NC}"
        exit 1
    fi

    # Restore or Initialize instincts.md
    if [[ -n "$TEMP_INSTINCTS" && -f "$TEMP_INSTINCTS" ]]; then
        cp "$TEMP_INSTINCTS" "$TARGET_INSTINCTS"
        rm -f "$TEMP_INSTINCTS"
        echo -e "  ${GREEN}✓ Existing instincts.md successfully restored & preserved.${NC}"
    elif [[ ! -f "$TARGET_INSTINCTS" ]]; then
        EXAMPLE_INSTINCTS="${GEMINI_PLUGINS_DIR}/ecc-lite/kb/instincts.example.md"
        if [[ -f "$EXAMPLE_INSTINCTS" ]]; then
            cp "$EXAMPLE_INSTINCTS" "$TARGET_INSTINCTS"
            echo -e "  ${GREEN}✓ Initialized new instincts.md from instincts.example.md.${NC}"
        fi
    fi

    # Grant execution permissions to hooks and MCP brain server
    echo -e "  ${BLUE}→ Granting execution permissions...${NC}"
    if compgen -G "${GEMINI_PLUGINS_DIR}/ecc-lite/hooks/*.sh" > /dev/null; then
        chmod +x "${GEMINI_PLUGINS_DIR}/ecc-lite/hooks/"*.sh
    fi
    if [[ -f "${GEMINI_PLUGINS_DIR}/ecc-lite/mcp/brain_server.py" ]]; then
        chmod +x "${GEMINI_PLUGINS_DIR}/ecc-lite/mcp/brain_server.py"
    fi
    echo -e "  ${GREEN}✓ Execution permissions verified.${NC}"

    # Configure ~/.gemini/config/mcp_config.json
    echo -e "  ${BLUE}→ Updating MCP configuration (${MCP_CONFIG_FILE})...${NC}"
    mkdir -p "$(dirname "$MCP_CONFIG_FILE")"
    python3 - <<EOF
import json
import os
import sys

config_path = os.path.expanduser("${MCP_CONFIG_FILE}")
brain_server = os.path.expanduser("${GEMINI_PLUGINS_DIR}/ecc-lite/mcp/brain_server.py")

data = {}
if os.path.exists(config_path):
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"    [!] Warning: Existing mcp_config.json could not be parsed: {e}. Reinitializing.")
        data = {}

if "mcpServers" not in data or not isinstance(data["mcpServers"], dict):
    data["mcpServers"] = {}

data["mcpServers"]["ecc-lite-brain"] = {
    "command": "python3",
    "args": [brain_server]
}

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"    ✓ ecc-lite-brain registered successfully in {config_path}")
EOF
fi

# ------------------------------------------------------------------------------
# 3. Claude Code Compatibility Symlinks
# ------------------------------------------------------------------------------
if [[ "$INSTALL_CLAUDE" == true ]]; then
    echo ""
    echo -e "${BLUE}[*] Step 3: Configuring Claude Code compatibility symlinks...${NC}"
    
    # 3A. ~/.agents symlinks
    mkdir -p "$DOT_AGENTS_DIR"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/hooks" "${DOT_AGENTS_DIR}/hooks"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/kb" "${DOT_AGENTS_DIR}/kb"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/mcp" "${DOT_AGENTS_DIR}/mcp"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/rules" "${DOT_AGENTS_DIR}/rules"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/skills" "${DOT_AGENTS_DIR}/skills"
    echo -e "  ${GREEN}✓ Linked ~/.agents/{hooks,kb,mcp,rules,skills}${NC}"

    # 3B. ~/.claude/agents symlinks
    mkdir -p "$CLAUDE_AGENTS_DIR"
    for agent in explorer planner coder reviewer; do
        target_agent="${GEMINI_PLUGINS_DIR}/orchestration/agents/${agent}.md"
        if [[ -f "$target_agent" ]]; then
            ln -sfn "$target_agent" "${CLAUDE_AGENTS_DIR}/${agent}.md"
            echo -e "  ${GREEN}✓ Linked ~/.claude/agents/${agent}.md${NC}"
        fi
    done

    # 3C. ~/.claude/skills symlinks
    mkdir -p "$CLAUDE_SKILLS_DIR"
    # Link all skills from ecc-lite
    if [[ -d "${GEMINI_PLUGINS_DIR}/ecc-lite/skills" ]]; then
        for s_path in "${GEMINI_PLUGINS_DIR}/ecc-lite/skills"/*; do
            if [[ -d "$s_path" ]]; then
                s_name="$(basename "$s_path")"
                ln -sfn "$s_path" "${CLAUDE_SKILLS_DIR}/${s_name}"
            fi
        done
    fi
    # Link all skills from orchestration
    if [[ -d "${GEMINI_PLUGINS_DIR}/orchestration/skills" ]]; then
        for s_path in "${GEMINI_PLUGINS_DIR}/orchestration/skills"/*; do
            if [[ -d "$s_path" ]]; then
                s_name="$(basename "$s_path")"
                ln -sfn "$s_path" "${CLAUDE_SKILLS_DIR}/${s_name}"
            fi
        done
    fi
    echo -e "  ${GREEN}✓ Linked all skills to ~/.claude/skills/${NC}"

    # 3D. ~/.claude/rules symlink
    if [[ ! -e "${CLAUDE_BASE_DIR}/rules" ]]; then
        ln -sfn "${DOT_AGENTS_DIR}/rules" "${CLAUDE_BASE_DIR}/rules"
        echo -e "  ${GREEN}✓ Linked ~/.claude/rules -> ~/.agents/rules${NC}"
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}=========================================================="
echo "    ✨ Installation completed successfully!               "
echo "==========================================================${NC}"
echo -e "Active Configuration:"
echo -e "  • Antigravity Plugins : ${GEMINI_PLUGINS_DIR}"
echo -e "  • MCP Brain Server    : ecc-lite-brain active"
echo -e "  • Claude Code Agents  : explorer, planner, coder, reviewer"
echo -e "  • User Instincts      : ${TARGET_INSTINCTS} (preserved)"
echo ""
