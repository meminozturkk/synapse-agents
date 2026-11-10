#!/usr/bin/env python3
"""
Register or unregister Synapse Agents' 0-token hooks in Cursor hooks.json.

Supports Cursor hooks configuration (~/.cursor/hooks.json or <project>/.cursor/hooks.json).
Crucial Rule: NEVER overwrite existing user-defined hooks (e.g. post-dev-review.ps1).
Only manage Synapse-owned hooks:
  - preToolUse : secret-guard.sh (Unix) or secret_guard.py (Windows)
  - stop       : verify-quiet.sh (Unix) or verify_quiet.py (Windows)
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


def is_synapse_secret_guard(command: str) -> bool:
    cmd_lower = str(command).lower().replace("\\", "/")
    return "secret-guard" in cmd_lower or "secret_guard" in cmd_lower


def is_synapse_verify_quiet(command: str) -> bool:
    cmd_lower = str(command).lower().replace("\\", "/")
    return "verify-quiet" in cmd_lower or "verify_quiet" in cmd_lower


def is_synapse_hook(command: str) -> bool:
    return is_synapse_secret_guard(command) or is_synapse_verify_quiet(command)


def load_hooks_json(path: str) -> dict:
    if not os.path.exists(path):
        return {"version": 1, "hooks": {}}

    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        if not content.strip():
            return {"version": 1, "hooks": {}}
        data = json.loads(content)
        if not isinstance(data, dict):
            raise ValueError("Root JSON element is not an object")
    except Exception as e:
        bak_path = f"{path}.bak"
        try:
            shutil.copy2(path, bak_path)
            sys.stderr.write(
                f"  [!] Warning: Existing hooks file could not be parsed: {e}. Backed up to {bak_path}. Reinitializing.\n"
            )
        except Exception as copy_err:
            sys.stderr.write(f"  [!] Warning: Failed to backup corrupted hooks file: {copy_err}\n")
        return {"version": 1, "hooks": {}}

    if "version" not in data:
        data["version"] = 1
    if "hooks" not in data or not isinstance(data["hooks"], dict):
        data["hooks"] = {}

    return data


def write_hooks_json(path: str, data: dict) -> None:
    abs_path = os.path.abspath(os.path.expanduser(path))
    parent = os.path.dirname(abs_path) or "."
    os.makedirs(parent, exist_ok=True)
    out_text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    fd, tmp_path = tempfile.mkstemp(dir=parent, prefix=".synapse-hooks-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(out_text)
        if os.path.exists(abs_path):
            try:
                shutil.copymode(abs_path, tmp_path)
            except Exception:
                pass
        os.replace(tmp_path, abs_path)
    except Exception:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass
        raise


def install(args) -> int:
    hooks_file = os.path.abspath(os.path.expanduser(args.hooks_file))
    if not args.hooks_dir:
        sys.stderr.write("  [!] Error: --hooks-dir is required for install action.\n")
        return 1

    hooks_dir = os.path.abspath(os.path.expanduser(args.hooks_dir)).replace("\\", "/")
    platform_name = (args.platform or ("windows" if sys.platform == "win32" else "unix")).lower()

    if platform_name == "windows":
        python_cmd = (args.python or sys.executable or "python").strip().replace("\\", "/")
        pre_cmd = f'"{python_cmd}" "{hooks_dir}/secret_guard.py"'
        stop_cmd = f'"{python_cmd}" "{hooks_dir}/verify_quiet.py"'
    else:
        pre_cmd = f'"{hooks_dir}/secret-guard.sh"'
        stop_cmd = f'"{hooks_dir}/verify-quiet.sh"'

    data = load_hooks_json(hooks_file)
    hooks = data.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        hooks = {}
        data["hooks"] = hooks

    # 1. Update or add preToolUse (secret-guard)
    pre_list = hooks.setdefault("preToolUse", [])
    if not isinstance(pre_list, list):
        pre_list = []
        hooks["preToolUse"] = pre_list

    synapse_pre_indices = [
        i for i, h in enumerate(pre_list)
        if isinstance(h, dict) and is_synapse_secret_guard(str(h.get("command", "")))
    ]
    if synapse_pre_indices:
        pre_list[synapse_pre_indices[0]] = {"command": pre_cmd}
        for idx in reversed(synapse_pre_indices[1:]):
            del pre_list[idx]
    else:
        pre_list.append({"command": pre_cmd})

    # 2. Update or add stop (verify-quiet)
    stop_list = hooks.setdefault("stop", [])
    if not isinstance(stop_list, list):
        stop_list = []
        hooks["stop"] = stop_list

    synapse_stop_indices = [
        i for i, h in enumerate(stop_list)
        if isinstance(h, dict) and is_synapse_verify_quiet(str(h.get("command", "")))
    ]
    if synapse_stop_indices:
        stop_list[synapse_stop_indices[0]] = {"command": stop_cmd}
        for idx in reversed(synapse_stop_indices[1:]):
            del stop_list[idx]
    else:
        stop_list.append({"command": stop_cmd})

    write_hooks_json(hooks_file, data)
    print(f"  [OK] Cursor hooks successfully installed in {hooks_file}")
    return 0


def uninstall(args) -> int:
    hooks_file = os.path.abspath(os.path.expanduser(args.hooks_file))
    if not os.path.exists(hooks_file):
        print(f"  [i] No hooks file found at: {hooks_file}")
        return 0

    data = load_hooks_json(hooks_file)
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        print(f"  [i] No hooks dictionary found in {hooks_file}")
        return 0

    changed = False
    for event in list(hooks.keys()):
        event_list = hooks[event]
        if not isinstance(event_list, list):
            continue
        filtered = [
            h for h in event_list
            if not (isinstance(h, dict) and is_synapse_hook(str(h.get("command", ""))))
        ]
        if len(filtered) != len(event_list):
            changed = True
        if filtered:
            hooks[event] = filtered
        else:
            del hooks[event]
            changed = True

    if changed:
        write_hooks_json(hooks_file, data)
        print(f"  [OK] Synapse hooks successfully uninstalled from {hooks_file}")
    else:
        print(f"  [i] No Synapse hooks found in {hooks_file}")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Register or unregister Synapse hooks with Cursor.")
    parser.add_argument("--action", required=True, choices=["install", "uninstall"], help="Action to perform")
    parser.add_argument("--hooks-file", required=True, help="Path to Cursor hooks.json file")
    parser.add_argument("--hooks-dir", default="", help="Path to directory containing hook scripts")
    parser.add_argument("--python", default="", help="Python executable command or path")
    parser.add_argument("--platform", choices=["windows", "unix"], default=None, help="Target platform")

    args = parser.parse_args()

    if args.action == "install":
        return install(args)
    elif args.action == "uninstall":
        return uninstall(args)
    return 1


if __name__ == "__main__":
    sys.exit(main())
