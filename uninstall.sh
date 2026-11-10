#!/usr/bin/env bash
# ==============================================================================
# Synapse Agents Uninstaller
# Safe Uninstallation & Symlink Cleanup for Antigravity, Claude Code & Cursor
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

GEMINI_PLUGINS_DIR="${HOME}/.gemini/config/plugins"
MCP_CONFIG_FILE="${HOME}/.gemini/config/mcp_config.json"
CLAUDE_BASE_DIR="${HOME}/.claude"
CLAUDE_AGENTS_DIR="${CLAUDE_BASE_DIR}/agents"
CLAUDE_SKILLS_DIR="${CLAUDE_BASE_DIR}/skills"
BACKUP_BASE_DIR="${CLAUDE_BASE_DIR}/backups"
DOT_AGENTS_DIR="${HOME}/.agents"

# Cursor Global Directories & Configurations
CURSOR_BASE_DIR="${HOME}/.cursor"
CURSOR_MCP_FILE="${CURSOR_BASE_DIR}/mcp.json"
CURSOR_RULES_DIR="${CURSOR_BASE_DIR}/rules"
CURSOR_SKILLS_DIR="${CURSOR_BASE_DIR}/skills"
CURSOR_AGENTS_DIR="${CURSOR_BASE_DIR}/agents"

REMOVE_PLUGINS=false
UNINSTALL_ANTIGRAVITY=true
UNINSTALL_CLAUDE=true
UNINSTALL_CURSOR_GLOBAL=true
CURSOR_PROJECT_PATH=""
EXPLICIT_MODE=false

# Resolve functional Python 3 command (resilient against Windows Store stubs)
resolve_python() {
    local cmd
    for cmd in "python3" "python" "py -3"; do
        if $cmd -c "import sys; assert sys.version_info[0] >= 3" >/dev/null 2>&1; then
            echo "$cmd"
            return 0
        fi
    done
    return 1
}

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all                   Remove symlinks, MCP registrations, and delete ~/.gemini/config/plugins/{ecc-lite,orchestration}"
    echo "  --antigravity-only      Remove Antigravity MCP registration only"
    echo "  --claude-only           Remove Claude Code symlinks only"
    echo "  --cursor-only           Remove Cursor Global symlinks and MCP registration only"
    echo "  --cursor-project <path> Remove Cursor rules and MCP registration from a specific project directory"
    echo "  -h, --help              Show this help message and exit"
    echo ""
    echo "Default: Safely removes global symlinks and MCP server registrations while preserving plugin files and learned instincts."
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            REMOVE_PLUGINS=true
            shift
            ;;
        --antigravity-only)
            EXPLICIT_MODE=true
            UNINSTALL_ANTIGRAVITY=true
            UNINSTALL_CLAUDE=false
            UNINSTALL_CURSOR_GLOBAL=false
            shift
            ;;
        --claude-only)
            EXPLICIT_MODE=true
            UNINSTALL_ANTIGRAVITY=false
            UNINSTALL_CLAUDE=true
            UNINSTALL_CURSOR_GLOBAL=false
            shift
            ;;
        --cursor-only)
            EXPLICIT_MODE=true
            UNINSTALL_ANTIGRAVITY=false
            UNINSTALL_CLAUDE=false
            UNINSTALL_CURSOR_GLOBAL=true
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
    # If only --cursor-project is given without other modes, only uninstall project Cursor
    UNINSTALL_ANTIGRAVITY=false
    UNINSTALL_CLAUDE=false
    UNINSTALL_CURSOR_GLOBAL=false
fi

# Resolve functional Python 3 interpreter
PYTHON_CMD="$(resolve_python || true)"
if [[ -z "$PYTHON_CMD" ]]; then
    echo -e "${RED}[!] Error: Python 3 is required but could not be found (checked: python3, python, py -3).${NC}"
    echo -e "${YELLOW}Please install Python 3 or ensure it is added to your PATH.${NC}"
    exit 1
fi

# Helper to remove ecc-lite-brain from any mcp config file
remove_mcp_server() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        $PYTHON_CMD - "$config_file" << 'EOF'
import json
import os
import sys

config_path = os.path.expanduser(sys.argv[1])
if os.path.exists(config_path):
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and "mcpServers" in data and "ecc-lite-brain" in data["mcpServers"]:
            del data["mcpServers"]["ecc-lite-brain"]
            with open(config_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
            print(f"  ✓ ecc-lite-brain successfully removed from {config_path}")
        else:
            print(f"  ℹ ecc-lite-brain was not present in {config_path}")
    except Exception as e:
        print(f"  [!] Failed to update {config_path}: {e}")
EOF
    else
        echo -e "  ${YELLOW}ℹ No configuration found at: ${config_file}${NC}"
    fi
}

echo -e "${CYAN}${BOLD}"
echo "=========================================================="
echo "    🧹 Synapse Agents System Uninstaller                 "
echo "       (ECC-Lite v2.0 + Orchestration v2.1.0)            "
echo "=========================================================="
echo -e "${NC}"

# ------------------------------------------------------------------------------
# 1. Preserve Knowledge Base (instincts.md)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Step 1: Safeguarding learned instincts...${NC}"
TARGET_INSTINCTS="${GEMINI_PLUGINS_DIR}/ecc-lite/kb/instincts.md"
if [[ -f "$TARGET_INSTINCTS" ]]; then
    mkdir -p "$BACKUP_BASE_DIR"
    cp "$TARGET_INSTINCTS" "${BACKUP_BASE_DIR}/instincts.md.bak"
    cp "$TARGET_INSTINCTS" "${BACKUP_BASE_DIR}/instincts.md.bak-${TIMESTAMP}"
    echo -e "  ${GREEN}✓ Instincts backed up safely to:${NC} ${BACKUP_BASE_DIR}/instincts.md.bak"
else
    echo -e "  ${YELLOW}ℹ No instincts.md found to back up.${NC}"
fi

# ------------------------------------------------------------------------------
# 2. Clean Up Claude Code & ~/.agents Symlinks
# ------------------------------------------------------------------------------
if [[ "$UNINSTALL_CLAUDE" == true ]]; then
    echo ""
    echo -e "${BLUE}[*] Step 2: Removing Claude Code & ~/.agents symlinks...${NC}"

    # Remove ~/.agents links if they point to ecc-lite
    if [[ -d "$DOT_AGENTS_DIR" ]]; then
        for item in hooks kb mcp rules skills; do
            link_path="${DOT_AGENTS_DIR}/${item}"
            if [[ -L "$link_path" ]]; then
                rm -f "$link_path"
                echo -e "  ${GREEN}✓ Removed link:${NC} ${link_path}"
            fi
        done
        rmdir "$DOT_AGENTS_DIR" 2>/dev/null || true
    fi

    # Remove ~/.claude/agents files/links
    if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
        for agent in explorer planner coder reviewer; do
            agent_file="${CLAUDE_AGENTS_DIR}/${agent}.md"
            if [[ -L "$agent_file" || -f "$agent_file" ]]; then
                rm -f "$agent_file"
                echo -e "  ${GREEN}✓ Removed agent file:${NC} ${agent_file}"
            fi
        done
        rmdir "$CLAUDE_AGENTS_DIR" 2>/dev/null || true
    fi

    # Remove ~/.claude/skills links pointing to ecc-lite or orchestration
    if [[ -d "$CLAUDE_SKILLS_DIR" ]]; then
        for skill_link in "${CLAUDE_SKILLS_DIR}"/*; do
            if [[ -L "$skill_link" ]]; then
                target="$(readlink "$skill_link" || true)"
                if [[ "$target" == *"/ecc-lite/"* || "$target" == *"/orchestration/"* ]]; then
                    rm -f "$skill_link"
                    echo -e "  ${GREEN}✓ Removed skill link:${NC} $(basename "$skill_link")"
                fi
            fi
        done
        rmdir "$CLAUDE_SKILLS_DIR" 2>/dev/null || true
    fi

    # Check ~/.claude/rules symlink
    if [[ -L "${CLAUDE_BASE_DIR}/rules" ]]; then
        target="$(readlink "${CLAUDE_BASE_DIR}/rules" || true)"
        if [[ "$target" == *".agents/rules"* || "$target" == *"/ecc-lite/"* ]]; then
            rm -f "${CLAUDE_BASE_DIR}/rules"
            echo -e "  ${GREEN}✓ Removed link:${NC} ${CLAUDE_BASE_DIR}/rules"
        fi
    fi

    # Remove Synapse hooks from ~/.claude/settings.json and ecc-lite-brain from ~/.claude.json
    echo -e "  ${BLUE}→ Removing Claude Code hooks and ecc-lite-brain MCP registration...${NC}"
    $PYTHON_CMD "${SCRIPT_DIR}/scripts/register_claude.py" uninstall \
        --backup-dir "${BACKUP_BASE_DIR}/pre-uninstall-${TIMESTAMP}" || \
        echo -e "  ${YELLOW}[!] Could not update Claude Code configuration; see message above.${NC}"
fi

# ------------------------------------------------------------------------------
# 3. Clean Up Cursor Global Symlinks & Skills/Agents
# ------------------------------------------------------------------------------
if [[ "$UNINSTALL_CURSOR_GLOBAL" == true ]]; then
    echo ""
    echo -e "${BLUE}[*] Step 3: Removing Cursor Global symlinks...${NC}"

    # Rules
    if [[ -d "$CURSOR_RULES_DIR" ]]; then
        for rule in coding-principles backend-dotnet frontend-web mobile-flutter agents-orchestration; do
            link_path="${CURSOR_RULES_DIR}/${rule}.mdc"
            if [[ -L "$link_path" ]]; then
                rm -f "$link_path"
                echo -e "  ${GREEN}✓ Removed Cursor rule link:${NC} ${link_path}"
            fi
        done
        rmdir "$CURSOR_RULES_DIR" 2>/dev/null || true
    fi

    # Agents
    if [[ -d "$CURSOR_AGENTS_DIR" ]]; then
        for agent in explorer planner coder reviewer; do
            agent_file="${CURSOR_AGENTS_DIR}/${agent}.md"
            if [[ -L "$agent_file" || -f "$agent_file" ]]; then
                rm -f "$agent_file"
                echo -e "  ${GREEN}✓ Removed Cursor agent file:${NC} ${agent_file}"
            fi
        done
        rmdir "$CURSOR_AGENTS_DIR" 2>/dev/null || true
    fi

    # Skills
    if [[ -d "$CURSOR_SKILLS_DIR" ]]; then
        for skill_link in "${CURSOR_SKILLS_DIR}"/*; do
            if [[ -L "$skill_link" ]]; then
                target="$(readlink "$skill_link" || true)"
                if [[ "$target" == *"/ecc-lite/"* || "$target" == *"/orchestration/"* ]]; then
                    rm -f "$skill_link"
                    echo -e "  ${GREEN}✓ Removed Cursor skill link:${NC} $(basename "$skill_link")"
                fi
            fi
        done
        rmdir "$CURSOR_SKILLS_DIR" 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# 4. Clean Up Cursor Project Configuration (Optional: --cursor-project <path>)
# ------------------------------------------------------------------------------
if [[ -n "$CURSOR_PROJECT_PATH" ]]; then
    if [[ -d "$CURSOR_PROJECT_PATH" ]]; then
        ABS_PROJECT_PATH="$(cd "$CURSOR_PROJECT_PATH" && pwd)"
        PROJECT_CURSOR_DIR="${ABS_PROJECT_PATH}/.cursor"
        PROJECT_RULES_DIR="${PROJECT_CURSOR_DIR}/rules"
        PROJECT_MCP_FILE="${PROJECT_CURSOR_DIR}/mcp.json"

        echo ""
        echo -e "${BLUE}[*] Step 4: Removing Cursor Project configuration in ${ABS_PROJECT_PATH}...${NC}"

        if [[ -d "$PROJECT_RULES_DIR" ]]; then
            for rule in coding-principles backend-dotnet frontend-web mobile-flutter agents-orchestration; do
                link_path="${PROJECT_RULES_DIR}/${rule}.mdc"
                if [[ -L "$link_path" ]]; then
                    rm -f "$link_path"
                    echo -e "  ${GREEN}✓ Removed project rule link:${NC} ${link_path}"
                fi
            done
            rmdir "$PROJECT_RULES_DIR" 2>/dev/null || true
        fi

        echo -e "  ${BLUE}→ Removing ecc-lite-brain from Project MCP configuration...${NC}"
        remove_mcp_server "$PROJECT_MCP_FILE"
        rmdir "$PROJECT_CURSOR_DIR" 2>/dev/null || true
    else
        echo -e "  ${YELLOW}ℹ Project directory not found: ${CURSOR_PROJECT_PATH}${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Deregister ecc-lite-brain from MCP Configurations
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[*] Step 5: Deregistering ecc-lite-brain from MCP configurations...${NC}"

if [[ "$UNINSTALL_ANTIGRAVITY" == true ]]; then
    echo -e "  ${BLUE}→ Updating Antigravity MCP configuration...${NC}"
    remove_mcp_server "$MCP_CONFIG_FILE"
fi

if [[ "$UNINSTALL_CURSOR_GLOBAL" == true ]]; then
    echo -e "  ${BLUE}→ Updating Cursor Global MCP configuration...${NC}"
    remove_mcp_server "$CURSOR_MCP_FILE"
fi

# ------------------------------------------------------------------------------
# 6. Remove Plugins Directory (If --all was requested)
# ------------------------------------------------------------------------------
if [[ "$REMOVE_PLUGINS" == true ]]; then
    echo ""
    echo -e "${YELLOW}[*] Step 6 (--all): Removing plugin directories from ~/.gemini/config/plugins/...${NC}"
    if [[ -d "${GEMINI_PLUGINS_DIR}/ecc-lite" ]]; then
        rm -rf "${GEMINI_PLUGINS_DIR}/ecc-lite"
        echo -e "  ${GREEN}✓ Removed ${GEMINI_PLUGINS_DIR}/ecc-lite${NC}"
    fi
    if [[ -d "${GEMINI_PLUGINS_DIR}/orchestration" ]]; then
        rm -rf "${GEMINI_PLUGINS_DIR}/orchestration"
        echo -e "  ${GREEN}✓ Removed ${GEMINI_PLUGINS_DIR}/orchestration${NC}"
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}=========================================================="
echo "    ✨ Uninstallation completed successfully!             "
echo -e "==========================================================${NC}"
echo -e "Summary:"
[[ "$UNINSTALL_CLAUDE" == true ]] && echo -e "  • Claude Code & ~/.agents symlinks removed"
[[ "$UNINSTALL_CLAUDE" == true ]] && echo -e "  • Claude Code hooks and ecc-lite-brain MCP registration removed"
[[ "$UNINSTALL_CURSOR_GLOBAL" == true ]] && echo -e "  • Cursor Global symlinks and MCP registration removed"
[[ -n "$CURSOR_PROJECT_PATH" ]] && echo -e "  • Cursor Project configuration removed from ${CURSOR_PROJECT_PATH}"
[[ "$UNINSTALL_ANTIGRAVITY" == true ]] && echo -e "  • Antigravity MCP server ecc-lite-brain deregistered"
if [[ "$REMOVE_PLUGINS" == true ]]; then
    echo -e "  • Plugin directories removed from ~/.gemini/config/plugins"
fi
if [[ -f "${BACKUP_BASE_DIR}/instincts.md.bak" ]]; then
    echo -e "  • User Instincts preserved at: ${BACKUP_BASE_DIR}/instincts.md.bak"
fi
echo ""
