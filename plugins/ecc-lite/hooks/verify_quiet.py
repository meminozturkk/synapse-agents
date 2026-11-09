#!/usr/bin/env python3
"""
ECC-Lite Dual-Mode Multi-Stack Quiet Verifier (Stop Hook)
When work completes, runs quiet checks based only on changed file types (.cs, .ts, .tsx, .dart).
Produces 0 tokens on success, returns concise error summary on failure.
Zero external dependencies (Python 3 standard library only).
"""
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

if hasattr(sys.stdin, "reconfigure"):
    sys.stdin.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def stop_ok(mode: str) -> None:
    if mode == "antigravity":
        sys.stdout.write(json.dumps({"decision": "stop"}) + "\n")
        sys.stdout.flush()
    sys.exit(0)


def stop_fail(stack_name: str, raw_err: str, mode: str) -> None:
    clean_err = " ".join(raw_err.split())[:600]
    if not clean_err:
        clean_err = "Unknown verification error"
    if mode == "antigravity":
        msg = {
            "decision": "continue",
            "reason": f"VERIFICATION ERROR ({stack_name}): {clean_err}",
        }
        sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
        sys.stdout.flush()
        sys.exit(0)
    else:
        # Claude Code: exit 2 blocks the stop and feeds stderr back to Claude so it can fix the error
        sys.stderr.write(f"VERIFICATION ERROR ({stack_name}): {clean_err}\n")
        sys.stderr.flush()
        sys.exit(2)


# Function alias for backward compatibility / readability
report_error = stop_fail


def get_changed_files(porcelain_output: str) -> list[str]:
    files = []
    for raw_line in porcelain_output.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            path_part = parts[1]
            if "->" in path_part:
                path_part = path_part.split("->")[-1].strip()
            if path_part.startswith('"') and path_part.endswith('"'):
                path_part = path_part[1:-1]
            files.append(path_part)
        else:
            files.append(parts[0])
    return files


def main() -> None:
    try:
        raw_input = sys.stdin.read()
    except Exception:
        raw_input = ""

    mode = (
        "antigravity"
        if ("--antigravity" in sys.argv or '"fullyIdle"' in raw_input)
        else "claude"
    )

    if mode == "antigravity":
        try:
            data = json.loads(raw_input) if raw_input.strip() else {}
        except Exception:
            data = {}

        if isinstance(data, dict):
            # 1. Skip check if background subagents are still running
            if data.get("fullyIdle") is False:
                stop_ok(mode)

            # or termination reason is not NO_TOOL_CALL
            term_reason = data.get("terminationReason")
            if term_reason and term_reason != "NO_TOOL_CALL":
                stop_ok(mode)

            # 2. Extract workspace directory and navigate to it
            ws_paths = data.get("workspacePaths") or []
            if ws_paths and isinstance(ws_paths, list) and ws_paths[0]:
                ws_dir = Path(ws_paths[0])
                if ws_dir.is_dir():
                    try:
                        os.chdir(ws_dir)
                    except Exception:
                        stop_ok(mode)
                else:
                    stop_ok(mode)
            else:
                stop_ok(mode)
    else:
        try:
            data = json.loads(raw_input) if raw_input.strip() else {}
        except Exception:
            data = {}

        if isinstance(data, dict):
            # Claude Code: already continuing because of a Stop hook -> do not loop forever
            if data.get("stop_hook_active") is True:
                stop_ok(mode)

            # Run checks inside the project Claude Code is working in
            cwd = data.get("cwd")
            if isinstance(cwd, str) and cwd and Path(cwd).is_dir():
                try:
                    os.chdir(cwd)
                except Exception:
                    stop_ok(mode)

    # Silently exit if git is not available or not inside a git repository
    if not shutil.which("git"):
        stop_ok(mode)

    git_check = subprocess.run(
        "git rev-parse --is-inside-work-tree",
        shell=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if git_check.returncode != 0 or git_check.stdout.strip() != "true":
        stop_ok(mode)

    # Check git status
    status_res = subprocess.run(
        "git status --porcelain",
        shell=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if status_res.returncode != 0:
        stop_ok(mode)

    changed = status_res.stdout.strip()
    if not changed:
        stop_ok(mode)

    changed_files = get_changed_files(changed)

    # 1. Backend (.NET / C#) Verification
    has_dotnet = any(re.search(r"\.(cs|csproj)$", f, re.IGNORECASE) for f in changed_files)
    if has_dotnet and shutil.which("dotnet"):
        res = subprocess.run(
            "dotnet build --no-restore -v q --nologo",
            shell=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if res.returncode != 0:
            out = (res.stdout or "") + "\n" + (res.stderr or "")
            err_lines = [l for l in out.splitlines() if "error CS" in l or "error MSB" in l][:5]
            if not err_lines:
                err_lines = [l for l in out.splitlines() if l.strip()][-5:]
            stop_fail(".NET Build", " ".join(err_lines), mode)

    # 2. Frontend (React / Angular / TypeScript) Verification
    has_ts = (
        any(re.search(r"\.(ts|tsx|html)$", f, re.IGNORECASE) for f in changed_files)
        and Path("tsconfig.json").is_file()
    )
    if has_ts and shutil.which("npx") and (Path("node_modules/typescript").is_dir() or Path("node_modules").is_dir()):
        res = subprocess.run(
            "npx tsc --noEmit --pretty false",
            shell=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if res.returncode != 0:
            out = (res.stdout or "") + "\n" + (res.stderr or "")
            err_lines = [l for l in out.splitlines() if "error TS" in l][:5]
            if not err_lines:
                err_lines = [l for l in out.splitlines() if l.strip()][:5]
            stop_fail("TypeScript Check", " ".join(err_lines), mode)

    # 3. Mobile (Flutter / Dart) Verification
    has_dart = any(re.search(r"\.dart$", f, re.IGNORECASE) for f in changed_files) and Path("pubspec.yaml").is_file()
    if has_dart and shutil.which("dart"):
        res = subprocess.run(
            "dart analyze --fatal-infos",
            shell=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if res.returncode != 0:
            out = (res.stdout or "") + "\n" + (res.stderr or "")
            err_lines = [l for l in out.splitlines() if "error -" in l][:5]
            if not err_lines:
                err_lines = [l for l in out.splitlines() if l.strip()][-5:]
            stop_fail("Dart Analyze", " ".join(err_lines), mode)

    stop_ok(mode)


if __name__ == "__main__":
    main()
