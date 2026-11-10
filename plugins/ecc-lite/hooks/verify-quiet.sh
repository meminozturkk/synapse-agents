#!/usr/bin/env bash
# ==============================================================================
# ECC-Lite Dual-Mode Multi-Stack Quiet Verifier (Stop Hook)
# When work completes, runs quiet checks based only on changed file types (.cs, .ts, .tsx, .dart).
# Produces 0 tokens on success, returns concise error summary on failure.
# ==============================================================================
set -u

resolve_python() {
  local cmd
  for cmd in python3 python "py -3"; do
    if $cmd -c "import sys; assert sys.version_info[0] >= 3" >/dev/null 2>&1; then
      echo "$cmd"
      return 0
    fi
  done
  return 1
}

PY_BIN="$(resolve_python || true)"

INPUT="$(cat 2>/dev/null || true)"

if [[ "${1:-}" == "--antigravity" ]] || printf '%s' "$INPUT" | grep -q '"fullyIdle"'; then
  MODE="antigravity"
else
  MODE="claude"
fi

stop_ok() {
  if [ "$MODE" = "antigravity" ]; then
    printf '{"decision": "stop"}\n'
  fi
  exit 0
}

report_error() {
  local stack_name="$1"
  local raw_err="$2"
  # Sanitize for JSON and single-line safety
  local clean_err
  clean_err="$(printf '%s' "$raw_err" | tr '\r\n\t' '   ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/  */ /g' | cut -c1-600)"
  if [ "$MODE" = "antigravity" ]; then
    printf '{"decision": "continue", "reason": "VERIFICATION ERROR (%s): %s"}\n' "$stack_name" "$clean_err"
    exit 0
  else
    # Claude Code: exit 2 blocks the stop and feeds stderr back to Claude so it can fix the error
    printf 'VERIFICATION ERROR (%s): %s\n' "$stack_name" "$clean_err" >&2
    exit 2
  fi
}

if [ "$MODE" = "antigravity" ]; then
  # 1. Skip check if background subagents are still running or termination reason is not NO_TOOL_CALL
  if printf '%s' "$INPUT" | grep -qE '"fullyIdle":[[:space:]]*false'; then
    stop_ok
  fi
  if printf '%s' "$INPUT" | grep -q '"terminationReason"' && ! printf '%s' "$INPUT" | grep -qE '"terminationReason":[[:space:]]*"NO_TOOL_CALL"'; then
    stop_ok
  fi

  # 2. Extract workspace directory and navigate to it
  WS_DIR=""
  if [ -n "$PY_BIN" ]; then
    WS_DIR="$(printf '%s' "$INPUT" | $PY_BIN -c 'import json,sys; d=json.loads(sys.stdin.read() or "{}"); w=d.get("workspacePaths") or []; print(w[0] if w else "")' 2>/dev/null || true)"
  fi
  if [ -z "$WS_DIR" ]; then
    WS_DIR="$(printf '%s' "$INPUT" | tr '\n\r' '  ' | sed -n 's/.*"workspacePaths"[[:space:]]*:[[:space:]]*\[[[:space:]]*"\([^"]*\)".*/\1/p' || true)"
  fi

  if [ -n "$WS_DIR" ] && [ -d "$WS_DIR" ]; then
    cd "$WS_DIR" || stop_ok
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    : # Current directory is already inside a git repository
  else
    stop_ok
  fi
else
  # Claude Code: already continuing because of a Stop hook -> do not loop forever
  if printf '%s' "$INPUT" | grep -qE '"stop_hook_active":[[:space:]]*true'; then
    stop_ok
  fi

  # Run checks inside the project Claude Code is working in
  CLAUDE_CWD=""
  if [ -n "$PY_BIN" ]; then
    CLAUDE_CWD="$(printf '%s' "$INPUT" | $PY_BIN -c 'import json,sys; d=json.loads(sys.stdin.read() or "{}"); c=d.get("cwd") if isinstance(d, dict) else ""; print(c if isinstance(c, str) else "")' 2>/dev/null || true)"
  fi
  if [ -z "$CLAUDE_CWD" ]; then
    CLAUDE_CWD="$(printf '%s' "$INPUT" | tr '\n\r' '  ' | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' || true)"
  fi

  if [ -n "$CLAUDE_CWD" ] && [ -d "$CLAUDE_CWD" ]; then
    cd "$CLAUDE_CWD" || stop_ok
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    : # Current directory is already inside a git repository
  fi
fi

# Silently exit if not a git repository or no changes exist
if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  stop_ok
fi

CHANGED="$(git status --porcelain 2>/dev/null || true)"
if [ -z "$CHANGED" ]; then
  stop_ok
fi

# 1. Backend (.NET / C#) Verification
if printf '%s\n' "$CHANGED" | grep -qE '\.(cs|csproj)$'; then
  if command -v dotnet >/dev/null 2>&1; then
    OUT="$(dotnet build --no-restore -v q 2>&1)" || {
      ERR="$(printf '%s\n' "$OUT" | grep -E "error CS|error MSB" | head -n 5)"
      [ -z "$ERR" ] && ERR="$(printf '%s\n' "$OUT" | tail -n 5)"
      report_error ".NET Build" "$ERR"
    }
  fi
fi

# 2. Frontend (React / Angular / TypeScript) Verification
if printf '%s\n' "$CHANGED" | grep -qE '\.(ts|tsx|html)$' && [ -f "tsconfig.json" ]; then
  if command -v npx >/dev/null 2>&1 && [ -d "node_modules/typescript" ]; then
    OUT="$(npx --no-install tsc --noEmit --pretty false 2>&1)" || {
      ERR="$(printf '%s\n' "$OUT" | grep -E "error TS" | head -n 5)"
      [ -z "$ERR" ] && ERR="$(printf '%s\n' "$OUT" | head -n 5)"
      report_error "TypeScript Check" "$ERR"
    }
  fi
fi

# 3. Mobile (Flutter / Dart) Verification
if printf '%s\n' "$CHANGED" | grep -qE '\.dart$' && [ -f "pubspec.yaml" ]; then
  if command -v dart >/dev/null 2>&1; then
    OUT="$(dart analyze --fatal-infos=false 2>&1)" || {
      ERR="$(printf '%s\n' "$OUT" | grep -E "error -" | head -n 5)"
      [ -z "$ERR" ] && ERR="$(printf '%s\n' "$OUT" | tail -n 5)"
      report_error "Dart Analyze" "$ERR"
    }
  fi
fi

stop_ok
