#!/usr/bin/env python3
"""
Unregister an MCP server from a target configuration JSON file.
"""

import argparse
import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Unregister an MCP server from configuration JSON.")
    parser.add_argument("--config", required=True, help="Path to MCP configuration file")
    parser.add_argument("--name", default="ecc-lite-brain", help="MCP server name (default: ecc-lite-brain)")
    args = parser.parse_args()

    config_path = os.path.abspath(os.path.expanduser(args.config))
    name = args.name.strip()

    if not os.path.exists(config_path):
        # File does not exist: exit silently
        return 0

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            content = f.read()
        if not content.strip():
            return 0
        data = json.loads(content)
        if not isinstance(data, dict):
            return 0
    except Exception as e:
        sys.stderr.write(f"  [!] Failed to read MCP configuration {config_path}: {e}\n")
        return 1

    servers = data.get("mcpServers")
    if isinstance(servers, dict) and name in servers:
        del servers[name]
        try:
            out_text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
            json.loads(out_text)  # validate serialization
            with open(config_path, "w", encoding="utf-8") as f:
                f.write(out_text)
            print(f"  [OK] {name} successfully removed from {config_path}")
            return 0
        except Exception as e:
            sys.stderr.write(f"  [!] Failed to update {config_path}: {e}\n")
            return 1
    else:
        print(f"  [i] {name} was not present in {config_path}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
