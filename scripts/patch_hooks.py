#!/usr/bin/env python3
"""
Patch hooks.json for Windows compatibility with secret_guard.py and verify_quiet.py.
"""

import argparse
import json
import os
import shutil
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Patch hooks.json for Windows-native Python hooks.")
    parser.add_argument("--hooks-json", required=True, help="Path to hooks.json")
    parser.add_argument("--python", required=True, help="Python executable path or command")
    parser.add_argument("--hooks-dir", required=True, help="Directory containing hook scripts")
    args = parser.parse_args()

    hooks_path = os.path.abspath(os.path.expanduser(args.hooks_json))
    python_exe = args.python.strip().replace("\\", "/")
    hooks_dir = os.path.abspath(os.path.expanduser(args.hooks_dir)).replace("\\", "/")

    secret_cmd = f'"{python_exe}" "{hooks_dir}/secret_guard.py" --antigravity'
    verify_cmd = f'"{python_exe}" "{hooks_dir}/verify_quiet.py" --antigravity'

    data = {}
    if os.path.exists(hooks_path):
        try:
            with open(hooks_path, "r", encoding="utf-8") as f:
                content = f.read()
            if content.strip():
                data = json.loads(content)
            else:
                data = {}
            if not isinstance(data, dict):
                raise ValueError("Root JSON element is not an object")
        except Exception as e:
            bak_path = f"{hooks_path}.bak"
            try:
                shutil.copy2(hooks_path, bak_path)
                sys.stderr.write(
                    f"  [!] Warning: Existing hooks.json could not be parsed: {e}. Backed up to {bak_path}. Reinitializing.\n"
                )
            except Exception as copy_err:
                sys.stderr.write(f"  [!] Warning: Failed to backup corrupted hooks.json: {copy_err}\n")
            data = {}

    if not isinstance(data, dict):
        data = {}

    data["ecc-secret-guard"] = {
        "PreToolUse": [
            {
                "matcher": "write_file|edit_file|run_command",
                "hooks": [
                    {
                        "type": "command",
                        "command": secret_cmd,
                        "timeout": 10
                    }
                ]
            }
        ]
    }

    data["ecc-verify-quiet"] = {
        "Stop": [
            {
                "type": "command",
                "command": verify_cmd,
                "timeout": 30
            }
        ]
    }

    try:
        out_text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
        json.loads(out_text)  # validate serialization

        os.makedirs(os.path.dirname(hooks_path), exist_ok=True)
        with open(hooks_path, "w", encoding="utf-8") as f:
            f.write(out_text)

        print(f"  [OK] Windows hooks configured in {hooks_path}")
        return 0
    except Exception as e:
        sys.stderr.write(f"  [!] Failed to write hooks configuration to {hooks_path}: {e}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
