#!/usr/bin/env python3
"""
Platform-adaptive agent sync engine for Synapse Agents.
Translates Gemini Antigravity agent definitions (SSOT) to platform-native
Claude Code and Cursor agent formats.
"""

import argparse
import os
import re
import shutil
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

# Model mappings per agent stem
MODEL_MAP = {
    "explorer": "haiku",
    "planner": "sonnet",
    "coder": "sonnet",
    "reviewer": "sonnet",
}

# Claude Code native tools mapping
CLAUDE_TOOL_MAP = {
    "view_file": "Read",
    "write_to_file": "Write",
    "replace_file_content": "Edit",
    "grep_search": "Grep",
    "find_by_name": "Glob",
    "list_dir": "LS",
    "run_command": "Bash",
}


def safe_remove_target(target_path: str):
    """Safely unlink/remove a path if it exists or is a symlink (broken or valid)."""
    if os.path.islink(target_path):
        try:
            os.unlink(target_path)
        except OSError:
            pass
    elif os.path.isdir(target_path):
        shutil.rmtree(target_path, ignore_errors=True)
    elif os.path.isfile(target_path) or os.path.exists(target_path):
        try:
            os.remove(target_path)
        except OSError:
            pass


def transform_agent_content(content: str, agent_stem: str, platform: str) -> str:
    """Transform agent markdown according to platform rules."""
    has_frontmatter = False
    frontmatter = ""
    body = content

    if content.startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            has_frontmatter = True
            frontmatter = parts[1]
            body = parts[2]

    if has_frontmatter:
        # 1. Model mapping in frontmatter
        if agent_stem in MODEL_MAP:
            target_model = MODEL_MAP[agent_stem]
            frontmatter = re.sub(
                r"^model:\s*.*$",
                f"model: {target_model}",
                frontmatter,
                flags=re.MULTILINE
            )

        # 2. Tool mapping in frontmatter (Claude Code only)
        if platform == "claude":
            lines = frontmatter.splitlines()
            transformed_lines = []
            for line in lines:
                stripped = line.strip()
                if stripped.startswith("- "):
                    tool_candidate = stripped[2:].strip()
                    if tool_candidate in CLAUDE_TOOL_MAP:
                        indent = line[:line.find("- ")]
                        transformed_lines.append(f"{indent}- {CLAUDE_TOOL_MAP[tool_candidate]}")
                        continue
                transformed_lines.append(line)
            frontmatter = "\n".join(transformed_lines)
            if not frontmatter.endswith("\n"):
                frontmatter += "\n"

    # 3. Badge & description transformations across the entire text (both frontmatter & body)
    text = f"---{frontmatter}---{body}" if has_frontmatter else body

    # Deep reasoning / operating mode
    text = text.replace("Gemini 3.8 Flash (High Effort / Deep Reasoning)", "Claude Sonnet 5.5 (Deep Reasoning)")

    # Dispatch roles in coder/planner
    text = text.replace("[Gemini 3.8 Flash - High]", "[Claude Sonnet 5.5]")

    # Persona titles with hyphen
    text = text.replace("Gemini 3.8 Flash - Medium Effort", "Claude Haiku 5.5")
    text = text.replace("Gemini 3.8 Flash - High Effort", "Claude Sonnet 5.5")

    # Badges, descriptions, and rule specifications
    text = text.replace("Gemini 3.8 Flash (Medium Effort)", "Claude Haiku 5.5")
    text = text.replace("Gemini 3.8 Flash (High Effort)", "Claude Sonnet 5.5")

    # Claude Code body tool mention updates (e.g. reviewer.md `grep_search` -> `Grep`)
    if platform == "claude":
        text = text.replace("`grep_search`", "`Grep`")

    return text


def sync_agents(source_dir: str, dest_dir: str, platform: str, dry_run: bool = False) -> int:
    """Synchronize agent definitions from source_dir to dest_dir."""
    if not os.path.isdir(source_dir):
        sys.stderr.write(f"[!] Error: Source directory does not exist: {source_dir}\n")
        return 1

    md_files = [f for f in sorted(os.listdir(source_dir)) if f.endswith(".md")]
    if not md_files:
        sys.stderr.write(f"[!] Warning: No .md files found in {source_dir}\n")
        return 0

    if not dry_run:
        os.makedirs(dest_dir, exist_ok=True)

    synced_count = 0
    for filename in md_files:
        source_path = os.path.join(source_dir, filename)
        if not os.path.isfile(source_path):
            continue

        agent_stem = os.path.splitext(filename)[0].lower()
        dest_path = os.path.join(dest_dir, filename)

        try:
            with open(source_path, "r", encoding="utf-8") as f:
                content = f.read()

            transformed = transform_agent_content(content, agent_stem, platform)

            if dry_run:
                print(f"  [DRY-RUN] Would sync {filename} ({platform}) -> {dest_path}")
            else:
                # Remove any existing symlink or file before writing regular file
                safe_remove_target(dest_path)
                with open(dest_path, "w", encoding="utf-8", newline="\n") as f:
                    f.write(transformed)
                print(f"  ✓ Synced {filename} ({platform}) -> {dest_path}")

            synced_count += 1
        except Exception as e:
            sys.stderr.write(f"[!] Error syncing {filename}: {e}\n")
            return 1

    action = "Would sync" if dry_run else "Successfully synced"
    print(f"  [OK] {action} {synced_count} agent(s) to {dest_dir} (platform: {platform})")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Platform-adaptive agent synchronization engine.")
    parser.add_argument("--source", required=True, help="Source directory containing agent markdown files (SSOT)")
    parser.add_argument("--dest", required=True, help="Destination directory (e.g. ~/.claude/agents or ~/.cursor/agents)")
    parser.add_argument("--platform", required=True, choices=["claude", "cursor"], help="Target platform (claude or cursor)")
    parser.add_argument("--dry-run", action="store_true", help="Perform a trial run without writing files")

    args = parser.parse_args()

    source_dir = os.path.abspath(os.path.expanduser(args.source))
    dest_dir = os.path.abspath(os.path.expanduser(args.dest))
    platform = args.platform.lower()

    return sync_agents(source_dir, dest_dir, platform, dry_run=args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
