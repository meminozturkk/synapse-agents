#!/usr/bin/env bash
# ==============================================================================
# ecc-lite-orchestrator Uninstaller
# Safe Uninstallation & Symlink Cleanup for Antigravity & Claude Code
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

GEMINI_PLUGINS_DIR="${HOME}/.gemini/config/plugins"
MCP_CONFIG_FILE="${HOME}/.gemini/config/mcp_config.json"
CLAUDE_BASE_DIR="${HOME}/.claude"
CLAUDE_AGENTS_DIR="${CLAUDE_BASE_DIR}/agents"
CLAUDE_SKILLS_DIR="${CLAUDE_BASE_DIR}/skills"
BACKUP_BASE_DIR="${CLAUDE_BASE_DIR}/backups"
DOT_AGENTS_DIR="${HOME}/.agents"

REMOVE_PLUGINS=false

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all         Remove symlinks, MCP registration, and delete ~/.gemini/config/plugins/{ecc-lite,orchestration}"
    echo "  -h, --help    Show this help message and exit"
    echo ""
    echo "Default: Safely removes symlinks and MCP server registration while preserving plugin files and learned instincts."
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            REMOVE_PLUGINS=true
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
echo "    🧹 ecc-lite-orchestrator System Uninstaller          "
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
    # Remove dir if empty
    rmdir "$DOT_AGENTS_DIR" 2>/dev/null || true
fi

# Remove ~/.claude/agents links
if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
    for agent in explorer planner coder reviewer; do
        link_path="${CLAUDE_AGENTS_DIR}/${agent}.md"
        if [[ -L "$link_path" ]]; then
            rm -f "$link_path"
            echo -e "  ${GREEN}✓ Removed link:${NC} ${link_path}"
        fi
    done
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
fi

# Check ~/.claude/rules symlink
if [[ -L "${CLAUDE_BASE_DIR}/rules" ]]; then
    target="$(readlink "${CLAUDE_BASE_DIR}/rules" || true)"
    if [[ "$target" == *".agents/rules"* || "$target" == *"/ecc-lite/"* ]]; then
        rm -f "${CLAUDE_BASE_DIR}/rules"
        echo -e "  ${GREEN}✓ Removed link:${NC} ${CLAUDE_BASE_DIR}/rules"
    fi
fi

# ------------------------------------------------------------------------------
# 3. Remove ecc-lite-brain from mcp_config.json
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[*] Step 3: Removing ecc-lite-brain from MCP configuration...${NC}"
if [[ -f "$MCP_CONFIG_FILE" ]]; then
    python3 - <<EOF
import json
import os

config_path = os.path.expanduser("${MCP_CONFIG_FILE}")
if os.path.exists(config_path):
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if "mcpServers" in data and "ecc-lite-brain" in data["mcpServers"]:
            del data["mcpServers"]["ecc-lite-brain"]
            with open(config_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
            print("  ✓ ecc-lite-brain successfully removed from mcp_config.json")
        else:
            print("  ℹ ecc-lite-brain was not present in mcp_config.json")
    except Exception as e:
        print(f"  [!] Failed to update mcp_config.json: {e}")
EOF
else
    echo -e "  ${YELLOW}ℹ No mcp_config.json found.${NC}"
fi

# ------------------------------------------------------------------------------
# 4. Remove Plugins Directory (If --all was requested)
# ------------------------------------------------------------------------------
if [[ "$REMOVE_PLUGINS" == true ]]; then
    echo ""
    echo -e "${YELLOW}[*] Step 4 (--all): Removing plugin directories from ~/.gemini/config/plugins/...${NC}"
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
echo "==========================================================${NC}"
echo -e "Summary:"
echo -e "  • Claude Code & ~/.agents symlinks removed"
echo -e "  • MCP Server ecc-lite-brain deregistered"
if [[ -f "${BACKUP_BASE_DIR}/instincts.md.bak" ]]; then
    echo -e "  • User Instincts preserved at: ${BACKUP_BASE_DIR}/instincts.md.bak"
fi
echo ""
