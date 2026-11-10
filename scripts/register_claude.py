#!/usr/bin/env python3
"""
Register (or unregister) Synapse Agents' 0-token hooks and the ecc-lite-brain
MCP server with Claude Code.

  * Hooks      -> ~/.claude/settings.json  ("hooks.PreToolUse" / "hooks.Stop")
  * MCP server -> ~/.claude.json           ("mcpServers", user scope)

Both files are merged, never overwritten: only entries owned by Synapse Agents
(hook commands pointing into an 'ecc-lite/hooks/' directory, and the
'ecc-lite-brain' MCP entry) are added or removed. Re-running is idempotent.
"""

import argparse
import json
import os
import shutil
import sys
import tempfile

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

MCP_NAME = "ecc-lite-brain"
HOOK_DIR_MARKERS = ("ecc-lite/hooks/", ".agents/hooks/")
PRE_TOOL_MATCHER = "Write|Edit|MultiEdit|NotebookEdit|Bash"
HOOK_SCRIPTS = {
    "sh": {"guard": "secret-guard.sh", "verify": "verify-quiet.sh"},
    "py": {"guard": "secret_guard.py", "verify": "verify_quiet.py"},
}


class ConfigError(Exception):
    pass


def load_json(path: str) -> dict:
    """Load a JSON object; a missing or empty file is {}. Refuse to touch invalid JSON."""
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    if not content.strip():
        return {}
    try:
        data = json.loads(content)
    except json.JSONDecodeError as e:
        raise ConfigError(f"{path} is not valid JSON ({e}); fix it by hand, nothing was changed.")
    if not isinstance(data, dict):
        raise ConfigError(f"{path} does not contain a JSON object; nothing was changed.")
    return data


def write_json(path: str, data: dict, backup_dir: str = "") -> None:
    """Back up the existing file, then write atomically (temp file + rename)."""
    if os.path.exists(path):
        if backup_dir:
            os.makedirs(backup_dir, exist_ok=True)
            backup_path = os.path.join(backup_dir, os.path.basename(path).lstrip(".") or "config.json")
        else:
            backup_path = path + ".bak"
        shutil.copy2(path, backup_path)

    parent = os.path.dirname(path) or "."
    os.makedirs(parent, exist_ok=True)
    out_text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    fd, tmp_path = tempfile.mkstemp(dir=parent, prefix=".synapse-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(out_text)
        if os.path.exists(path):
            shutil.copymode(path, tmp_path)
        os.replace(tmp_path, path)
    except Exception:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise


def split_python(python_val: str):
    """'python3' -> ('python3', []), 'py -3' -> ('py', ['-3']), a path with spaces stays whole."""
    python_val = python_val.strip().strip("'\"")
    if os.path.exists(python_val) or " " not in python_val:
        return python_val.replace("\\", "/"), []
    parts = python_val.split()
    return parts[0], parts[1:]


def quote(arg: str) -> str:
    return f'"{arg}"' if (" " in arg or not arg) else arg


def hook_command(runtime: str, script_path: str, python_val: str) -> str:
    if runtime == "sh":
        return quote(script_path)
    cmd, extra = split_python(python_val)
    return " ".join([quote(cmd)] + extra + [quote(script_path)])


def is_synapse_hook(hook: dict) -> bool:
    command = str(hook.get("command", "")).replace("\\", "/")
    return any(marker in command for marker in HOOK_DIR_MARKERS) and any(
        name in command for names in HOOK_SCRIPTS.values() for name in names.values()
    )


def strip_synapse_hooks(settings: dict) -> bool:
    """Remove Synapse-owned hooks from settings in place. Returns True if anything changed."""
    hooks = settings.get("hooks")
    if not isinstance(hooks, dict):
        return False
    changed = False
    for event in list(hooks.keys()):
        groups = hooks[event]
        if not isinstance(groups, list):
            continue
        new_groups = []
        for group in groups:
            if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
                new_groups.append(group)
                continue
            kept = [h for h in group["hooks"] if not (isinstance(h, dict) and is_synapse_hook(h))]
            if len(kept) != len(group["hooks"]):
                changed = True
            if kept:
                new_groups.append({**group, "hooks": kept})
        if new_groups:
            hooks[event] = new_groups
        else:
            del hooks[event]
            changed = True
    if not hooks:
        del settings["hooks"]
    return changed


def install(args) -> int:
    hooks_dir = os.path.abspath(os.path.expanduser(args.hooks_dir)).replace("\\", "/")
    server = os.path.abspath(os.path.expanduser(args.server)).replace("\\", "/")
    scripts = HOOK_SCRIPTS[args.runtime]
    for script in scripts.values():
        if not os.path.isfile(os.path.join(hooks_dir, script)):
            raise ConfigError(f"Hook script not found: {hooks_dir}/{script}")
    if not os.path.isfile(server):
        raise ConfigError(f"MCP server not found: {server}")

    # 1. Hooks -> ~/.claude/settings.json
    settings = load_json(args.settings)
    strip_synapse_hooks(settings)
    hooks = settings.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ConfigError(f'"hooks" in {args.settings} is not an object; nothing was changed.')
    guard_cmd = hook_command(args.runtime, f"{hooks_dir}/{scripts['guard']}", args.python)
    verify_cmd = hook_command(args.runtime, f"{hooks_dir}/{scripts['verify']}", args.python)
    hooks.setdefault("PreToolUse", []).append({
        "matcher": PRE_TOOL_MATCHER,
        "hooks": [{"type": "command", "command": guard_cmd, "timeout": 10}],
    })
    hooks.setdefault("Stop", []).append({
        "hooks": [{"type": "command", "command": verify_cmd, "timeout": 120}],
    })
    write_json(args.settings, settings, args.backup_dir)
    print(f"  [OK] secret-guard (PreToolUse) and verify-quiet (Stop) hooks registered in {args.settings}")

    # 2. MCP server -> ~/.claude.json (user scope)
    claude_json = load_json(args.claude_json)
    servers = claude_json.setdefault("mcpServers", {})
    if not isinstance(servers, dict):
        raise ConfigError(f'"mcpServers" in {args.claude_json} is not an object; nothing was changed.')
    cmd, extra = split_python(args.python)
    servers[MCP_NAME] = {"type": "stdio", "command": cmd, "args": extra + [server], "env": {}}
    write_json(args.claude_json, claude_json, args.backup_dir)
    print(f"  [OK] {MCP_NAME} MCP server registered (user scope) in {args.claude_json}")
    return 0


def uninstall(args) -> int:
    if os.path.exists(args.settings):
        settings = load_json(args.settings)
        if strip_synapse_hooks(settings):
            write_json(args.settings, settings, args.backup_dir)
            print(f"  [OK] Synapse hooks removed from {args.settings}")
        else:
            print(f"  [i] No Synapse hooks present in {args.settings}")

    if os.path.exists(args.claude_json):
        claude_json = load_json(args.claude_json)
        servers = claude_json.get("mcpServers")
        if isinstance(servers, dict) and MCP_NAME in servers:
            del servers[MCP_NAME]
            write_json(args.claude_json, claude_json, args.backup_dir)
            print(f"  [OK] {MCP_NAME} removed from {args.claude_json}")
        else:
            print(f"  [i] {MCP_NAME} was not present in {args.claude_json}")
    return 0


def main() -> int:
    home = os.path.expanduser("~")
    parser = argparse.ArgumentParser(description="Register Synapse Agents hooks and MCP server with Claude Code.")
    sub = parser.add_subparsers(dest="action", required=True)

    def add_common(p):
        p.add_argument("--settings", default=os.path.join(home, ".claude", "settings.json"),
                       help="Claude Code user settings file (default: ~/.claude/settings.json)")
        p.add_argument("--claude-json", default=os.path.join(home, ".claude.json"),
                       help="Claude Code user state file holding MCP servers (default: ~/.claude.json)")
        p.add_argument("--backup-dir", default="", help="Directory for backups (default: <file>.bak)")

    p_install = sub.add_parser("install", help="Register hooks and MCP server")
    add_common(p_install)
    p_install.add_argument("--python", required=True, help="Python command or path (e.g. python3, 'py -3')")
    p_install.add_argument("--hooks-dir", required=True, help="Directory containing the ecc-lite hook scripts")
    p_install.add_argument("--server", required=True, help="Path to brain_server.py")
    p_install.add_argument("--runtime", choices=["sh", "py"], default="sh",
                           help="Use bash (.sh) or Python (.py) hook scripts (default: sh)")

    p_uninstall = sub.add_parser("uninstall", help="Remove hooks and MCP server")
    add_common(p_uninstall)

    args = parser.parse_args()
    args.settings = os.path.abspath(os.path.expanduser(args.settings))
    args.claude_json = os.path.abspath(os.path.expanduser(args.claude_json))
    try:
        return install(args) if args.action == "install" else uninstall(args)
    except ConfigError as e:
        sys.stderr.write(f"  [!] {e}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
