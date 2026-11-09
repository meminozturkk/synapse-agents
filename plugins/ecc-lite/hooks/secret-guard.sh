#!/usr/bin/env bash
# ==============================================================================
# ECC-Lite Dual-Mode Secret Guard (PreToolUse Hook)
# Hem Antigravity CLI (JSON stdout) hem Claude Code (exit code 2) ile tam uyumlu
# ==============================================================================
set -u

INPUT="$(cat 2>/dev/null || true)"

# Çağrıldığı CLI'ı otomatik algıla
if [[ "${1:-}" == "--antigravity" ]] || printf '%s' "$INPUT" | grep -q '"toolCall"'; then
  MODE="antigravity"
else
  MODE="claude"
fi

# Self-edit bypass kontrolü:
# SADECE dosya yazma/düzenleme araçlarında VE hedef dosya yolu 'secret-guard.sh' ile bittiğinde izin ver.
# run_command, Bash veya terminal komutları için ASLA bypass verilmez.
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

# JSON içindeki kaçışlı tırnakları (\" -> ") normalize et ki regex her iki durumda da yakalasın
NORMALIZED_INPUT="$(printf '%s' "$INPUT" | sed 's/\\"/"/g')"

# Yüksek doğruluklu secret / anahtar desenleri:
# - Private Key blokları
# - Anthropic (sk-ant-), OpenAI (sk-proj-), Google (AIzaSy), AWS (AKIA...), GitHub (ghp_, github_pat_)
# - Açık parola / secret / connection string atamaları (en az 8 karakterli gerçek değerler)
SECRET_REGEX='(-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-ant-[a-zA-Z0-9_-]{15,}|sk-proj-[a-zA-Z0-9_-]{15,}|AIzaSy[a-zA-Z0-9_-]{30,}|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{30,}|github_pat_[a-zA-Z0-9_]{30,}|(Password|Pwd|SecretKey|ApiKey|ClientSecret)[[:space:]]*[:=][[:space:]]*["'\'']?[^"'\''[:space:];${}<>]{8,})'

if printf '%s' "$NORMALIZED_INPUT" | grep -qE "$SECRET_REGEX"; then
  MSG="BLOCK: Kod içinde hardcoded secret, API anahtarı veya parola tespit edildi! Lütfen ortam değişkeni (.env / User Secrets) kullanın."
  if [ "$MODE" = "antigravity" ]; then
    printf '{"decision": "deny", "reason": "%s"}\n' "$MSG"
    exit 0
  else
    printf '%s\n' "$MSG" >&2
    exit 2
  fi
fi

# Sorun yoksa: Antigravity için minimal allow JSON, Claude Code için 0 byte çıktı (sıfır token maliyeti)
if [ "$MODE" = "antigravity" ]; then
  printf '{"decision": "allow"}\n'
fi
exit 0
