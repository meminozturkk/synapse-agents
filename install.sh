#!/usr/bin/env bash
# ==============================================================================
# Synapse Agents Installer
# Multi-Platform Idempotent Installation for Antigravity, Claude Code & Cursor
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

# Target Directories & Configurations
GEMINI_PLUGINS_DIR="${HOME}/.gemini/config/plugins"
MCP_CONFIG_FILE="${HOME}/.gemini/config/mcp_config.json"
CLAUDE_BASE_DIR="${HOME}/.claude"
CLAUDE_AGENTS_DIR="${CLAUDE_BASE_DIR}/agents"
CLAUDE_SKILLS_DIR="${CLAUDE_BASE_DIR}/skills"
BACKUP_DIR="${CLAUDE_BASE_DIR}/backups/pre-install-${TIMESTAMP}"
DOT_AGENTS_DIR="${HOME}/.agents"

# Cursor Global Directories & Configurations
CURSOR_BASE_DIR="${HOME}/.cursor"
CURSOR_MCP_FILE="${CURSOR_BASE_DIR}/mcp.json"
CURSOR_RULES_DIR="${CURSOR_BASE_DIR}/rules"
CURSOR_SKILLS_DIR="${CURSOR_BASE_DIR}/skills"
CURSOR_AGENTS_DIR="${CURSOR_BASE_DIR}/agents"

# Modes
INSTALL_ANTIGRAVITY=true
INSTALL_CLAUDE=true
INSTALL_CURSOR_GLOBAL=true
CURSOR_PROJECT_PATH=""
EXPLICIT_MODE=false

# Parse Flags
usage() {
    echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --antigravity-only      Install plugins and MCP configuration for Antigravity only"
    echo "  --claude-only           Install core plugins and configure Claude Code symlinks only"
    echo "  --cursor-only           Install core plugins and configure Cursor Global only"
    echo "  --cursor-project <path> Configure Cursor rules and MCP for a specific project directory"
    echo "  -h, --help              Show this help message and exit"
    echo ""
    echo "Default: Installs Antigravity plugins/MCP, Claude Code symlinks, and Cursor Global configuration."
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --antigravity-only)
            EXPLICIT_MODE=true
            INSTALL_ANTIGRAVITY=true
            INSTALL_CLAUDE=false
            INSTALL_CURSOR_GLOBAL=false
            shift
            ;;
        --claude-only)
            EXPLICIT_MODE=true
            INSTALL_ANTIGRAVITY=false
            INSTALL_CLAUDE=true
            INSTALL_CURSOR_GLOBAL=false
            shift
            ;;
        --cursor-only)
            EXPLICIT_MODE=true
            INSTALL_ANTIGRAVITY=false
            INSTALL_CLAUDE=false
            INSTALL_CURSOR_GLOBAL=true
            shift
            ;;
        --cursor-project)
            if [[ -z "${2:-}" || "$2" == --* ]]; then
                echo -e "${RED}[!] Error: --cursor-project requires a valid directory path.${NC}"
                exit 1
            fi
            CURSOR_PROJECT_PATH="$2"
            shift 2
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

if [[ "$EXPLICIT_MODE" == false && -n "$CURSOR_PROJECT_PATH" ]]; then
    # If only --cursor-project is given without other modes, only install project Cursor
    INSTALL_ANTIGRAVITY=false
    INSTALL_CLAUDE=false
    INSTALL_CURSOR_GLOBAL=false
fi

if [[ -n "$CURSOR_PROJECT_PATH" ]]; then
    if [[ ! -d "$CURSOR_PROJECT_PATH" ]]; then
        echo -e "${RED}[!] Error: Specified project path does not exist or is not a directory: ${CURSOR_PROJECT_PATH}${NC}"
        exit 1
    fi
fi

echo -e "${CYAN}${BOLD}"
echo "=========================================================="
echo "    🚀 Synapse Agents System Installer                   "
echo "       (ECC-Lite v2.0 + Orchestration v2.1.0)            "
echo "=========================================================="
echo -e "${NC}"

# ------------------------------------------------------------------------------
# 1. Backup Existing Configurations
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Step 1: Checking and backing up existing installation...${NC}"
mkdir -p "${CLAUDE_BASE_DIR}/backups"

NEED_BACKUP=false
if [[ -d "${GEMINI_PLUGINS_DIR}/ecc-lite" || -d "${GEMINI_PLUGINS_DIR}/orchestration" || -d "${DOT_AGENTS_DIR}" || -f "$CURSOR_MCP_FILE" ]]; then
    NEED_BACKUP=true
fi
if [[ -n "$CURSOR_PROJECT_PATH" && -f "${CURSOR_PROJECT_PATH}/.cursor/mcp.json" ]]; then
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
    if [[ -f "$CURSOR_MCP_FILE" ]]; then
        cp "$CURSOR_MCP_FILE" "${BACKUP_DIR}/cursor_mcp.json" 2>/dev/null || true
    fi
    if [[ -n "$CURSOR_PROJECT_PATH" && -f "${CURSOR_PROJECT_PATH}/.cursor/mcp.json" ]]; then
        cp "${CURSOR_PROJECT_PATH}/.cursor/mcp.json" "${BACKUP_DIR}/project_cursor_mcp.json" 2>/dev/null || true
    fi
    echo -e "  ${GREEN}✓ Backup completed.${NC}"
else
    echo -e "  ${GREEN}✓ No existing installation found that requires backup.${NC}"
fi

# ------------------------------------------------------------------------------
# 2. Core Plugins Sync (~/.gemini/config/plugins/) & Antigravity MCP Setup
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[*] Step 2: Syncing core plugins to ~/.gemini/config/plugins/...${NC}"
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
if [[ "$INSTALL_ANTIGRAVITY" == true ]]; then
    echo -e "  ${BLUE}→ Updating Antigravity MCP configuration (${MCP_CONFIG_FILE})...${NC}"
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
    if [[ -d "${GEMINI_PLUGINS_DIR}/ecc-lite/skills" ]]; then
        for s_path in "${GEMINI_PLUGINS_DIR}/ecc-lite/skills"/*; do
            if [[ -d "$s_path" ]]; then
                s_name="$(basename "$s_path")"
                ln -sfn "$s_path" "${CLAUDE_SKILLS_DIR}/${s_name}"
            fi
        done
    fi
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

# ------------------------------------------------------------------------------
# 4. Cursor Global Configuration
# ------------------------------------------------------------------------------
if [[ "$INSTALL_CURSOR_GLOBAL" == true ]]; then
    echo ""
    echo -e "${BLUE}[*] Step 4: Configuring Cursor Global compatibility...${NC}"

    # 4A. Update ~/.cursor/mcp.json
    echo -e "  ${BLUE}→ Updating Cursor Global MCP configuration (${CURSOR_MCP_FILE})...${NC}"
    mkdir -p "$CURSOR_BASE_DIR"
    python3 - "$CURSOR_MCP_FILE" "${GEMINI_PLUGINS_DIR}/ecc-lite/mcp/brain_server.py" << 'EOF'
import json
import os
import sys

config_path = os.path.expanduser(sys.argv[1])
brain_server = os.path.expanduser(sys.argv[2])

data = {}
if os.path.exists(config_path):
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"    [!] Warning: Existing mcp.json could not be parsed: {e}. Reinitializing.")
        data = {}

if not isinstance(data, dict):
    data = {}

if "mcpServers" not in data or not isinstance(data["mcpServers"], dict):
    data["mcpServers"] = {}

data["mcpServers"]["ecc-lite-brain"] = {
    "command": "python3",
    "args": [brain_server]
}

os.makedirs(os.path.dirname(config_path), exist_ok=True)
with open(config_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"    ✓ ecc-lite-brain registered successfully in {config_path}")
EOF

    # 4B. Cursor Global Rules (.mdc symlinks)
    mkdir -p "$CURSOR_RULES_DIR"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/rules/coding-principles.md" "${CURSOR_RULES_DIR}/coding-principles.mdc"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/rules/backend-dotnet.md" "${CURSOR_RULES_DIR}/backend-dotnet.mdc"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/rules/frontend-web.md" "${CURSOR_RULES_DIR}/frontend-web.mdc"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/rules/mobile-flutter.md" "${CURSOR_RULES_DIR}/mobile-flutter.mdc"
    ln -sfn "${GEMINI_PLUGINS_DIR}/orchestration/rules/AGENTS.md" "${CURSOR_RULES_DIR}/agents-orchestration.mdc"
    echo -e "  ${GREEN}✓ Linked ~/.cursor/rules/*.mdc (5 rules)${NC}"

    # 4C. Cursor Global Skills symlinks
    mkdir -p "$CURSOR_SKILLS_DIR"
    if [[ -d "${GEMINI_PLUGINS_DIR}/ecc-lite/skills" ]]; then
        for s_path in "${GEMINI_PLUGINS_DIR}/ecc-lite/skills"/*; do
            if [[ -d "$s_path" ]]; then
                s_name="$(basename "$s_path")"
                ln -sfn "$s_path" "${CURSOR_SKILLS_DIR}/${s_name}"
            fi
        done
    fi
    if [[ -d "${GEMINI_PLUGINS_DIR}/orchestration/skills" ]]; then
        for s_path in "${GEMINI_PLUGINS_DIR}/orchestration/skills"/*; do
            if [[ -d "$s_path" ]]; then
                s_name="$(basename "$s_path")"
                ln -sfn "$s_path" "${CURSOR_SKILLS_DIR}/${s_name}"
            fi
        done
    fi
    echo -e "  ${GREEN}✓ Linked all skills to ~/.cursor/skills/ (11 skills)${NC}"

    # 4D. Cursor Global Agents symlinks
    mkdir -p "$CURSOR_AGENTS_DIR"
    for agent in explorer planner coder reviewer; do
        target_agent="${GEMINI_PLUGINS_DIR}/orchestration/agents/${agent}.md"
        if [[ -f "$target_agent" ]]; then
            ln -sfn "$target_agent" "${CURSOR_AGENTS_DIR}/${agent}.md"
            echo -e "  ${GREEN}✓ Linked ~/.cursor/agents/${agent}.md${NC}"
        fi
    done
fi

# ------------------------------------------------------------------------------
# 5. Cursor Project Configuration (Optional: --cursor-project <path>)
# ------------------------------------------------------------------------------
if [[ -n "$CURSOR_PROJECT_PATH" ]]; then
    ABS_PROJECT_PATH="$(cd "$CURSOR_PROJECT_PATH" && pwd)"
    PROJECT_CURSOR_DIR="${ABS_PROJECT_PATH}/.cursor"
    PROJECT_RULES_DIR="${PROJECT_CURSOR_DIR}/rules"
    PROJECT_MCP_FILE="${PROJECT_CURSOR_DIR}/mcp.json"

    echo ""
    echo -e "${BLUE}[*] Step 5: Configuring Cursor Project in ${ABS_PROJECT_PATH}...${NC}"

    # Rules
    mkdir -p "$PROJECT_RULES_DIR"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/rules/coding-principles.md" "${PROJECT_RULES_DIR}/coding-principles.mdc"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/rules/backend-dotnet.md" "${PROJECT_RULES_DIR}/backend-dotnet.mdc"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/rules/frontend-web.md" "${PROJECT_RULES_DIR}/frontend-web.mdc"
    ln -sfn "${GEMINI_PLUGINS_DIR}/ecc-lite/rules/mobile-flutter.md" "${PROJECT_RULES_DIR}/mobile-flutter.mdc"
    ln -sfn "${GEMINI_PLUGINS_DIR}/orchestration/rules/AGENTS.md" "${PROJECT_RULES_DIR}/agents-orchestration.mdc"
    echo -e "  ${GREEN}✓ Linked ${PROJECT_RULES_DIR}/*.mdc (5 rules)${NC}"

    # MCP
    echo -e "  ${BLUE}→ Updating Project MCP configuration (${PROJECT_MCP_FILE})...${NC}"
    mkdir -p "$PROJECT_CURSOR_DIR"
    python3 - "$PROJECT_MCP_FILE" "${GEMINI_PLUGINS_DIR}/ecc-lite/mcp/brain_server.py" << 'EOF'
import json
import os
import sys

config_path = os.path.expanduser(sys.argv[1])
brain_server = os.path.expanduser(sys.argv[2])

data = {}
if os.path.exists(config_path):
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"    [!] Warning: Existing mcp.json could not be parsed: {e}. Reinitializing.")
        data = {}

if not isinstance(data, dict):
    data = {}

if "mcpServers" not in data or not isinstance(data["mcpServers"], dict):
    data["mcpServers"] = {}

data["mcpServers"]["ecc-lite-brain"] = {
    "command": "python3",
    "args": [brain_server]
}

os.makedirs(os.path.dirname(config_path), exist_ok=True)
with open(config_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"    ✓ ecc-lite-brain registered successfully in {config_path}")
EOF
fi

echo ""
echo -e "${GREEN}${BOLD}=========================================================="
echo "    ✨ Installation completed successfully!               "
echo -e "==========================================================${NC}"
echo -e "Active Configuration:"
echo -e "  • Core Plugins       : ${GEMINI_PLUGINS_DIR}"
[[ "$INSTALL_ANTIGRAVITY" == true ]] && echo -e "  • Antigravity MCP    : ecc-lite-brain active in ${MCP_CONFIG_FILE}"
[[ "$INSTALL_CLAUDE" == true ]] && echo -e "  • Claude Code Agents : explorer, planner, coder, reviewer"
[[ "$INSTALL_CURSOR_GLOBAL" == true ]] && echo -e "  • Cursor Global      : 5 rules (.mdc), 11 skills, 4 agents, MCP active"
[[ -n "$CURSOR_PROJECT_PATH" ]] && echo -e "  • Cursor Project     : rules (.mdc) & MCP active in ${ABS_PROJECT_PATH}"
echo -e "  • User Instincts     : ${TARGET_INSTINCTS} (preserved)"
echo ""
