#!/usr/bin/env python3
"""
Register an MCP server into a target configuration JSON file.
Supports Antigravity mcp_config.json, Cursor mcp.json, and project-level mcp.json.
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
    parser = argparse.ArgumentParser(description="Register an MCP server in configuration JSON.")
    parser.add_argument("--config", required=True, help="Path to MCP configuration file")
    parser.add_argument("--python", required=True, help="Python executable command or path")
    parser.add_argument("--server", required=True, help="Path to MCP server script (e.g. brain_server.py)")
    parser.add_argument("--name", default="ecc-lite-brain", help="MCP server name (default: ecc-lite-brain)")
    args = parser.parse_args()

    config_path = os.path.abspath(os.path.expanduser(args.config))
    server_path = os.path.abspath(os.path.expanduser(args.server)).replace("\\", "/")
    python_val = args.python.strip()
    name = args.name.strip()

    # Determine command and extra args (handles 'py -3', python, or full path with spaces)
    if os.path.exists(python_val):
        cmd = python_val.replace("\\", "/")
        extra_args = []
    elif " " in python_val:
        parts = python_val.split()
        cmd = parts[0]
        extra_args = parts[1:]
    else:
        cmd = python_val
        extra_args = []

    server_args = extra_args + [server_path]

    data = {}
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                content = f.read()
            if content.strip():
                data = json.loads(content)
            else:
                data = {}
            if not isinstance(data, dict):
                raise ValueError("Root JSON element is not an object")
        except Exception as e:
            bak_path = f"{config_path}.bak"
            try:
                shutil.copy2(config_path, bak_path)
                sys.stderr.write(
                    f"  [!] Warning: Existing MCP config could not be parsed: {e}. Backed up to {bak_path}. Reinitializing.\n"
                )
            except Exception as copy_err:
                sys.stderr.write(f"  [!] Warning: Failed to backup corrupted MCP config: {copy_err}\n")
            data = {}

    if not isinstance(data, dict):
        data = {}

    if "mcpServers" not in data or not isinstance(data["mcpServers"], dict):
        data["mcpServers"] = {}

    data["mcpServers"][name] = {
        "command": cmd,
        "args": server_args
    }

    try:
        out_text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
        # Validate serialization before writing
        json.loads(out_text)

        os.makedirs(os.path.dirname(config_path), exist_ok=True)
        with open(config_path, "w", encoding="utf-8") as f:
            f.write(out_text)

        print(f"  [OK] {name} registered successfully in {config_path}")
        return 0
    except Exception as e:
        sys.stderr.write(f"  [!] Failed to write MCP configuration to {config_path}: {e}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
