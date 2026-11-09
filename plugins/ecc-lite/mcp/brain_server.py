#!/usr/bin/env python3
"""
ECC-Lite Zero-Context Memory & Instincts MCP Server v2.1
Hem 'mcp' (FastMCP) paketiyle hem de paket kurulu olmadığında %100 Python
standart kütüphanesiyle (JSON-RPC 2.0 stdio fallback) çalışır.
2 aşamalı progresif arama (search_knowledge_index -> get_knowledge_detail) destekler.
Yerel (CWD/.agents/kb) ve Genel (plugin/kb veya ~/.agents/kb) bilgi bankalarını dinamik olarak tarar.
"""
import json
import re
import sys
from datetime import datetime
from pathlib import Path

# Plugin kb dizini veya fallback ~/.agents/kb
_PLUGIN_KB = Path(__file__).resolve().parent.parent / "kb"
GLOBAL_KB = _PLUGIN_KB if _PLUGIN_KB.exists() else (Path.home() / ".agents" / "kb")


def _get_kb_dirs():
    dirs = []
    try:
        local_kb = Path.cwd() / ".agents" / "kb"
        if local_kb.exists() and local_kb.resolve() != GLOBAL_KB.resolve():
            dirs.append(local_kb)
    except Exception:
        pass
    if GLOBAL_KB.exists():
        dirs.append(GLOBAL_KB)
    return dirs


def _get_file_blocks(md_file: Path):
    """Returns list of (block_idx_1_based, block_text)"""
    try:
        content = md_file.read_text(encoding="utf-8")
    except Exception:
        return []
    raw_blocks = re.split(r"\n(?=#{1,3}\s|\-\s\*\*\[)", content)
    blocks = []
    idx = 1
    for b in raw_blocks:
        b_clean = b.strip()
        if not b_clean:
            continue
        blocks.append((idx, b_clean))
        idx += 1
    return blocks


def _search_kb(query: str) -> str:
    """Proje mimarisi, DB şeması, iş kuralları ve geçmiş kararları (instincts) içinde akıllı arama yapar."""
    kb_dirs = _get_kb_dirs()
    if not kb_dirs:
        return "Henüz kayıtlı bilgi yok (.agents/kb dizini boş)."

    tokens = [t.lower() for t in re.split(r"\s+", query.strip()) if len(t) >= 2]
    if not tokens:
        return "Lütfen en az 2 karakterli bir arama terimi girin."

    matches = []
    seen_files = set()
    for d in kb_dirs:
        for md_file in sorted(d.glob("*.md")):
            file_key = md_file.name
            if file_key in seen_files:
                continue
            seen_files.add(file_key)
            try:
                content = md_file.read_text(encoding="utf-8")
            except Exception:
                continue

            blocks = re.split(r"\n(?=#{1,3}\s|\-\s\*\*\[)", content)
            matched_blocks = []
            for block in blocks:
                block_lower = block.lower()
                score = sum(1 for tok in tokens if tok in block_lower)
                if score > 0:
                    matched_blocks.append((score, block.strip()))

            if matched_blocks:
                matched_blocks.sort(key=lambda x: x[0], reverse=True)
                top_snippets = "\n\n".join(b for _, b in matched_blocks[:5])
                scope_tag = "Yerel" if d != GLOBAL_KB else "Global"
                matches.append(f"### [{md_file.name} ({scope_tag})]\n{top_snippets[:1800]}")

    return "\n\n".join(matches) if matches else f"'{query}' için eşleşen kayıt bulunamadı."


def _search_kb_index(query: str) -> str:
    """Kompakt bilgi bankası indeks araması yapar. Her satır max ~110 karakter döner."""
    kb_dirs = _get_kb_dirs()
    if not kb_dirs:
        return "Henüz kayıtlı bilgi yok (.agents/kb dizini boş)."

    tokens = [t.lower() for t in re.split(r"\s+", query.strip()) if len(t) >= 2]
    if not tokens:
        return "Lütfen en az 2 karakterli bir arama terimi girin."

    matched = []
    seen_files = set()
    for d in kb_dirs:
        for md_file in sorted(d.glob("*.md")):
            file_key = md_file.name
            if file_key in seen_files:
                continue
            seen_files.add(file_key)
            scope_tag = "Yerel" if d != GLOBAL_KB else "Global"
            blocks = _get_file_blocks(md_file)
            for idx, b_text in blocks:
                b_lower = b_text.lower()
                score = sum(1 for tok in tokens if tok in b_lower)
                if score > 0:
                    first_line = b_text.splitlines()[0].strip()
                    clean_line = re.sub(r"\s+", " ", first_line)
                    if clean_line.startswith("- "):
                        clean_line = clean_line[2:].strip()
                    block_id = f"{md_file.name}#{idx}"
                    prefix = f"[ID: {block_id} | {scope_tag}] "
                    max_content_len = max(20, 110 - len(prefix))
                    if len(clean_line) > max_content_len:
                        clean_line = clean_line[: max_content_len - 3] + "..."
                    entry_line = f"{prefix}{clean_line}"
                    matched.append((score, entry_line))

    if not matched:
        return f"'{query}' için indeks kaydı bulunamadı."

    matched.sort(key=lambda x: x[0], reverse=True)
    return "\n".join(line for _, line in matched[:20])


def _get_kb_detail(block_ids: str) -> str:
    """Virgülle ayrılmış ID'leri alır ve yalnızca o blokların tam metnini döner."""
    requested_ids = [b.strip() for b in re.split(r"[,;\s]+", block_ids) if b.strip()]
    if not requested_ids:
        return "Lütfen en az bir ID belirtin (ör. 'instincts.md#3')."

    kb_dirs = _get_kb_dirs()
    file_map = {}
    for d in kb_dirs:
        for md_file in sorted(d.glob("*.md")):
            if md_file.name not in file_map:
                scope_tag = "Yerel" if d != GLOBAL_KB else "Global"
                file_map[md_file.name] = (scope_tag, {f"{md_file.name}#{idx}": (idx, b) for idx, b in _get_file_blocks(md_file)})

    results = []
    for req_id in requested_ids:
        found = False
        for fname, (scope, block_dict) in file_map.items():
            if req_id in block_dict:
                idx, text = block_dict[req_id]
                results.append(f"### [ID: {req_id} | {scope}]\n{text}")
                found = True
                break
        if not found:
            results.append(f"### [ID: {req_id}]\n(Kayıt bulunamadı)")

    return "\n\n".join(results)


def _save_instinct_entry(topic: str, rule: str) -> str:
    """Projede öğrenilen kritik bir dersi veya mimari kararı kalıcı hafızaya kaydeder."""
    local_kb = Path.cwd() / ".agents" / "kb"
    target_dir = local_kb if (Path.cwd() / ".agents").exists() else GLOBAL_KB
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / "instincts.md"
    if not target.exists():
        target.write_text("# Project Instincts & Architectural Decisions\n", encoding="utf-8")

    existing = target.read_text(encoding="utf-8")
    normalized_rule = rule.strip()
    if normalized_rule.lower() in existing.lower():
        return f"Bu kural zaten kayıtlı: {topic}"

    stamp = datetime.now().strftime("%Y-%m-%d")
    entry = f"\n- **[{topic.strip()}]** ({stamp}): {normalized_rule}\n"
    with open(target, "a", encoding="utf-8") as f:
        f.write(entry)
    scope = "Yerel (.agents/kb)" if target_dir == local_kb else "Global (~/.agents/kb)"
    return f"Kalıcı hafızaya ({scope}) kaydedildi: [{topic.strip()}]"


def _list_kb_topics() -> str:
    """Kayıtlı bilgi bankası dosyalarını ve başlıklarını listeler."""
    kb_dirs = _get_kb_dirs()
    if not kb_dirs:
        return "Henüz kayıtlı bilgi bankası dosyası yok."
    summary = []
    seen = set()
    for d in kb_dirs:
        for f in sorted(d.glob("*.md")):
            if f.name in seen:
                continue
            seen.add(f.name)
            lines = f.read_text(encoding="utf-8").splitlines()
            headers = [l.strip() for l in lines if l.startswith("#") or l.startswith("- **[")][:10]
            scope = "Yerel" if d != GLOBAL_KB else "Global"
            summary.append(f"- **{f.name}** ({scope}, {len(lines)} satır): " + (", ".join(headers) if headers else "İçerik mevcut"))
    return "\n".join(summary) if summary else "Bilgi bankasında henüz .md dosyası bulunmuyor."


# Önce resmi FastMCP kütüphanesini dene; yoksa sıfır bağımlılıklı JSON-RPC 2.0 Stdio sunucusunu çalıştır
try:
    from mcp.server.fastmcp import FastMCP  # type: ignore

    mcp = FastMCP("ECC-Lite-Brain")

    @mcp.tool()
    def search_project_knowledge(query: str) -> str:
        """Proje mimarisi, DB şeması, iş kuralları ve geçmiş kararları (instincts) içinde tam metin arama yapar."""
        return _search_kb(query)

    @mcp.tool()
    def search_knowledge_index(query: str) -> str:
        """Kompakt bilgi bankası indeks araması yapar. Az token tüketir ve ID listesi döner."""
        return _search_kb_index(query)

    @mcp.tool()
    def get_knowledge_detail(block_ids: str) -> str:
        """Belirtilen blok ID'lerinin tam içeriğini getirir (virgülle ayrılmış ID listesi, ör. 'instincts.md#3')."""
        return _get_kb_detail(block_ids)

    @mcp.tool()
    def save_instinct(topic: str, rule: str) -> str:
        """Projede öğrenilen kritik bir dersi veya mimari kararı kalıcı hafızaya kaydeder."""
        return _save_instinct_entry(topic, rule)

    @mcp.tool()
    def list_knowledge_topics() -> str:
        """Kayıtlı bilgi bankası dosyalarını ve başlıklarını listeler."""
        return _list_kb_topics()

    if __name__ == "__main__":
        mcp.run()

except ImportError:
    # Zero-Dependency Native JSON-RPC 2.0 MCP Server Fallback
    TOOLS = [
        {
            "name": "search_project_knowledge",
            "description": "Proje mimarisi, DB şeması, iş kuralları ve geçmiş kararları (instincts) içinde tam metin arama yapar.",
            "inputSchema": {
                "type": "object",
                "properties": {"query": {"type": "string", "description": "Aranacak anahtar kelimeler"}},
                "required": ["query"],
            },
        },
        {
            "name": "search_knowledge_index",
            "description": "Kompakt bilgi bankası indeks araması yapar. Az token tüketir ve ID listesi döner.",
            "inputSchema": {
                "type": "object",
                "properties": {"query": {"type": "string", "description": "Aranacak anahtar kelimeler"}},
                "required": ["query"],
            },
        },
        {
            "name": "get_knowledge_detail",
            "description": "Belirtilen blok ID'lerinin tam içeriğini getirir.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "block_ids": {
                        "type": "string",
                        "description": "Virgülle ayrılmış blok ID'leri (ör. 'instincts.md#3, instincts.md#5')",
                    }
                },
                "required": ["block_ids"],
            },
        },
        {
            "name": "save_instinct",
            "description": "Projede öğrenilen kritik bir dersi veya mimari kararı kalıcı hafızaya kaydeder.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "topic": {"type": "string", "description": "Konu başlığı (örn. EF-Core, Auth, Angular)"},
                    "rule": {"type": "string", "description": "Öğrenilen kural veya mimari karar"},
                },
                "required": ["topic", "rule"],
            },
        },
        {
            "name": "list_knowledge_topics",
            "description": "Kayıtlı bilgi bankası dosyalarını ve başlıklarını listeler.",
            "inputSchema": {"type": "object", "properties": {}},
        },
    ]

    def _send(msg: dict) -> None:
        sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
        sys.stdout.flush()

    def _run_stdio() -> None:
        for raw_line in sys.stdin:
            line = raw_line.strip()
            if not line:
                continue
            try:
                req = json.loads(line)
            except Exception:
                continue

            req_id = req.get("id")
            method = req.get("method", "")
            params = req.get("params") or {}

            if method == "initialize":
                _send({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": params.get("protocolVersion", "2024-11-05"),
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "ECC-Lite-Brain", "version": "2.1.0"},
                    },
                })
            elif method == "notifications/initialized":
                continue
            elif method == "ping":
                _send({"jsonrpc": "2.0", "id": req_id, "result": {}})
            elif method == "tools/list":
                _send({"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}})
            elif method == "tools/call":
                name = params.get("name")
                args = params.get("arguments") or {}
                if name == "search_project_knowledge":
                    text = _search_kb(str(args.get("query", "")))
                elif name == "search_knowledge_index":
                    text = _search_kb_index(str(args.get("query", "")))
                elif name == "get_knowledge_detail":
                    text = _get_kb_detail(str(args.get("block_ids", "")))
                elif name == "save_instinct":
                    text = _save_instinct_entry(str(args.get("topic", "Genel")), str(args.get("rule", "")))
                elif name == "list_knowledge_topics":
                    text = _list_kb_topics()
                else:
                    text = f"Bilinmeyen araç: {name}"
                _send({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {"content": [{"type": "text", "text": text}], "isError": False},
                })
            elif req_id is not None:
                _send({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {"code": -32601, "message": f"Method not found: {method}"},
                })

    if __name__ == "__main__":
        _run_stdio()
