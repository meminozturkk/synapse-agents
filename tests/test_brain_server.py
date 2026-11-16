"""Unit and stdio JSON-RPC tests for plugins/ecc-lite/mcp/brain_server.py."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BRAIN_SERVER_PATH = REPO_ROOT / "plugins" / "ecc-lite" / "mcp" / "brain_server.py"


def load_brain_server():
    spec = importlib.util.spec_from_file_location("brain_server", BRAIN_SERVER_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class BrainServerTests(unittest.TestCase):
    def setUp(self):
        self.brain = load_brain_server()
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.root = Path(self.tmpdir.name)
        self.local_kb = self.root / ".agents" / "kb"
        self.local_kb.mkdir(parents=True)
        self.global_kb = self.root / "global_kb"
        self.global_kb.mkdir(parents=True)
        self.orig_cwd = Path.cwd()
        self.orig_global_kb = self.brain.GLOBAL_KB
        os.chdir(self.root)
        self.brain.GLOBAL_KB = self.global_kb
        self.addCleanup(lambda: os.chdir(self.orig_cwd))
        self.addCleanup(lambda: setattr(self.brain, "GLOBAL_KB", self.orig_global_kb))

    def test_two_stage_progressive_search_and_detail(self):
        (self.local_kb / "architecture.md").write_text(
            "# Auth Layer\nJWT tokens expire in 15 minutes.\n\n"
            "## Database Rules\nAlways use parameterized queries for PostgreSQL.\n",
            encoding="utf-8",
        )

        index_out = self.brain._search_kb_index("PostgreSQL")
        self.assertIn("[ID: architecture.md#2 | Local]", index_out)
        for line in index_out.splitlines():
            self.assertLessEqual(len(line), 110)

        detail_out = self.brain._get_kb_detail("architecture.md#2, architecture.md#999")
        self.assertIn("Always use parameterized queries for PostgreSQL.", detail_out)
        self.assertIn("[ID: architecture.md#999]\n(Record not found)", detail_out)

    def test_save_instinct_writes_and_deduplicates(self):
        first = self.brain._save_instinct_entry("EF-Core", "Use AsNoTracking for read queries.")
        self.assertIn("Saved to persistent memory (Local", first)

        second = self.brain._save_instinct_entry("EF-Core", "use asnotracking for read queries.")
        self.assertIn("already recorded", second)

        instincts_file = self.local_kb / "instincts.md"
        self.assertTrue(instincts_file.is_file())
        content = instincts_file.read_text(encoding="utf-8")
        self.assertEqual(content.count("AsNoTracking"), 1)

    def test_stdio_jsonrpc_fallback_roundtrip(self):
        (self.local_kb / "rules.md").write_text(
            "# Testing\nRun unittest before pushing.\n",
            encoding="utf-8",
        )
        requests = [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05"}},
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {"name": "search_knowledge_index", "arguments": {"query": "unittest"}},
            },
            {"jsonrpc": "2.0", "id": 4, "method": "unknown/method"},
        ]
        stdin_payload = "\n".join(json.dumps(r) for r in requests) + "\n"

        # Force the zero-dependency JSON-RPC fallback even if the optional 'mcp' package is installed.
        runner = (
            "import runpy, sys; "
            "sys.modules['mcp'] = None; "
            "sys.modules['mcp.server'] = None; "
            "sys.modules['mcp.server.fastmcp'] = None; "
            f"runpy.run_path({str(BRAIN_SERVER_PATH)!r}, run_name='__main__')"
        )
        proc = subprocess.run(
            [sys.executable, "-c", runner],
            input=stdin_payload,
            cwd=self.root,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        responses = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
        self.assertEqual([r["id"] for r in responses], [1, 2, 3, 4])
        self.assertEqual(responses[0]["result"]["serverInfo"]["name"], "ECC-Lite-Brain")
        tool_names = {t["name"] for t in responses[1]["result"]["tools"]}
        self.assertIn("search_knowledge_index", tool_names)
        self.assertIn("rules.md#1", responses[2]["result"]["content"][0]["text"])
        self.assertEqual(responses[3]["error"]["code"], -32601)


if __name__ == "__main__":
    unittest.main()
