#!/usr/bin/env python3
"""
ECC-Lite Dual-Mode Secret Guard (PreToolUse Hook)
Fully compatible with both Antigravity CLI (JSON stdout) and Claude Code (exit code 2).
Zero external dependencies (Python 3 standard library only).
"""
import json
import re
import sys

if hasattr(sys.stdin, "reconfigure"):
    sys.stdin.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BLOCK_MESSAGE = (
    "BLOCK: Hardcoded secret, API key, or password detected in code! "
    "Use environment variables (.env / appsettings / Platform.environment) instead."
)

WRITE_TOOLS = {
    "write_file",
    "edit_file",
    "write_to_file",
    "replace_file_content",
    "multi_replace_file_content",
    "write",
    "edit",
    "multiedit",
}

SECRET_PATTERNS = [
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    r"sk-ant-[a-zA-Z0-9_-]{15,}",
    r"sk-proj-[a-zA-Z0-9_-]{15,}",
    r"AIza[a-zA-Z0-9_-]{30,}",
    r"AKIA[0-9A-Z]{16}",
    r"ghp_[a-zA-Z0-9]{30,}",
    r"github_pat_[a-zA-Z0-9_]{30,}",
    r"(?i:(?:password|pwd|secretkey|secret_key|secret|apikey|api_key|clientsecret|client_secret|token|jwt_secret))\s*[:=]\s*[\"']?[^\"'\s;\${}<>]{8,}",
]
SECRET_REGEX = re.compile("|".join(f"(?:{p})" for p in SECRET_PATTERNS))


def is_self_edit_attempt(raw_data: str) -> bool:
    """
    Self-edit bypass check:
    ONLY allow when using file write/edit tools AND the target file path ends with
    'secret-guard.sh' or 'secret_guard.py'.
    NEVER bypass for run_command, Bash, or terminal commands.
    """
    try:
        data = json.loads(raw_data) if raw_data.strip() else {}
    except Exception:
        return False

    if not isinstance(data, dict):
        return False

    tool_call = data.get("toolCall") if isinstance(data.get("toolCall"), dict) else {}
    tool_name = str(
        tool_call.get("name") or data.get("tool") or data.get("name") or ""
    ).strip().lower()

    if tool_name not in WRITE_TOOLS:
        return False

    args = (
        tool_call.get("args")
        or tool_call.get("arguments")
        or data.get("tool_input")
        or data.get("input")
        or {}
    )
    if not isinstance(args, dict):
        return False

    target_file = str(
        args.get("TargetFile")
        or args.get("target_file")
        or args.get("path")
        or args.get("Path")
        or args.get("filePath")
        or args.get("file_path")
        or ""
    ).strip()

    return target_file.endswith("secret-guard.sh") or target_file.endswith("secret_guard.py")


def main() -> None:
    try:
        raw_input = sys.stdin.read()
    except Exception:
        raw_input = ""

    is_antigravity = ("--antigravity" in sys.argv) or ('"toolCall"' in raw_input)
    mode = "antigravity" if is_antigravity else "claude"

    # 1. Self-edit bypass
    if is_self_edit_attempt(raw_input):
        if mode == "antigravity":
            sys.stdout.write(json.dumps({"decision": "allow"}) + "\n")
            sys.stdout.flush()
        sys.exit(0)

    # 2. Normalize escaped quotes in JSON (\" -> ") so regex matches in both formats
    normalized_input = raw_input.replace(r'\"', '"')

    # 3. Secret detection
    if SECRET_REGEX.search(normalized_input):
        if mode == "antigravity":
            sys.stdout.write(
                json.dumps({"decision": "deny", "reason": BLOCK_MESSAGE}, ensure_ascii=False) + "\n"
            )
            sys.stdout.flush()
            sys.exit(0)
        else:
            sys.stderr.write(BLOCK_MESSAGE + "\n")
            sys.stderr.flush()
            sys.exit(2)

    # 4. Clean pass
    if mode == "antigravity":
        sys.stdout.write(json.dumps({"decision": "allow"}) + "\n")
        sys.stdout.flush()
    sys.exit(0)


if __name__ == "__main__":
    main()
