#!/usr/bin/env bash
# ==============================================================================
# ECC-Lite Dual-Mode Secret Guard (PreToolUse Hook)
# Fully compatible with both Antigravity CLI (JSON stdout) and Claude Code (exit code 2)
# ==============================================================================
set -u

INPUT="$(cat 2>/dev/null || true)"

# Auto-detect calling CLI
if [[ "${1:-}" == "--antigravity" ]] || printf '%s' "$INPUT" | grep -q '"toolCall"'; then
  MODE="antigravity"
else
  MODE="claude"
fi

# Self-edit bypass check:
# ONLY allow when using file write/edit tools AND the target file path ends with 'secret-guard.sh'.
# NEVER bypass for run_command, Bash, or terminal commands.
IS_SELF_EDIT="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read() or "{}")
except Exception:
    sys.exit(1)

tool_call = data.get("toolCall") or {}
tool_name = (tool_call.get("name") or data.get("tool") or data.get("name") or "").lower()
args = tool_call.get("args") or tool_call.get("arguments") or data.get("tool_input") or data.get("input") or {}

write_tools = {"write_file", "edit_file", "write", "edit", "write_to_file", "replace_file_content"}
if tool_name in write_tools:
    target_file = str(args.get("TargetFile") or args.get("target_file") or args.get("path") or args.get("filePath") or args.get("file_path") or "")
    if target_file.endswith("secret-guard.sh"):
        sys.exit(0)

sys.exit(1)
' 2>/dev/null && echo "yes" || echo "no")"

if [ "$IS_SELF_EDIT" = "yes" ]; then
  if [ "$MODE" = "antigravity" ]; then
    printf '{"decision": "allow"}\n'
  fi
  exit 0
fi

# Normalize escaped quotes in JSON (\" -> ") so regex matches in both formats
NORMALIZED_INPUT="$(printf '%s' "$INPUT" | sed 's/\\"/"/g')"

# High-confidence secret / key patterns:
# - Private Key blocks
# - Anthropic (sk-ant-), OpenAI (sk-proj-), Google (AIzaSy), AWS (AKIA...), GitHub (ghp_, github_pat_)
# - Explicit password / secret / connection string assignments (at least 8 chars real values)
SECRET_REGEX='(-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-ant-[a-zA-Z0-9_-]{15,}|sk-proj-[a-zA-Z0-9_-]{15,}|AIzaSy[a-zA-Z0-9_-]{30,}|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{30,}|github_pat_[a-zA-Z0-9_]{30,}|(Password|Pwd|SecretKey|ApiKey|ClientSecret)[[:space:]]*[:=][[:space:]]*["'\'']?[^"'\''[:space:];${}<>]{8,})'

if printf '%s' "$NORMALIZED_INPUT" | grep -qE "$SECRET_REGEX"; then
  MSG="BLOCK: Hardcoded secret, API key, or password detected in code! Please use environment variables (.env / User Secrets)."
  if [ "$MODE" = "antigravity" ]; then
    printf '{"decision": "deny", "reason": "%s"}\n' "$MSG"
    exit 0
  else
    printf '%s\n' "$MSG" >&2
    exit 2
  fi
fi

# If clean: minimal allow JSON for Antigravity, 0 byte output for Claude Code (zero token cost)
if [ "$MODE" = "antigravity" ]; then
  printf '{"decision": "allow"}\n'
fi
exit 0
