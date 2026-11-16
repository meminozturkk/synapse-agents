"""Tests for scripts/register_claude.py and scripts/sync_agents.py."""

import argparse
import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import register_claude  # noqa: E402
import sync_agents  # noqa: E402


class RegisterClaudeTests(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.root = Path(self.tmpdir.name)
        self.hooks_dir = self.root / "ecc-lite" / "hooks"
        self.hooks_dir.mkdir(parents=True)
        (self.hooks_dir / "secret_guard.py").write_text("#!/usr/bin/env python3\n", encoding="utf-8")
        (self.hooks_dir / "verify_quiet.py").write_text("#!/usr/bin/env python3\n", encoding="utf-8")
        self.server = self.root / "ecc-lite" / "mcp" / "brain_server.py"
        self.server.parent.mkdir(parents=True)
        self.server.write_text("#!/usr/bin/env python3\n", encoding="utf-8")
        self.agents_md = self.root / "CLAUDE-ROUTING.md"
        self.agents_md.write_text("# Routing\n", encoding="utf-8")

        self.settings_path = self.root / ".claude" / "settings.json"
        self.claude_json_path = self.root / ".claude.json"
        self.claude_md_path = self.root / ".claude" / "CLAUDE.md"
        self.backup_dir = self.root / "backups"

    def _make_args(self):
        return argparse.Namespace(
            hooks_dir=str(self.hooks_dir),
            server=str(self.server),
            runtime="py",
            python="python3",
            settings=str(self.settings_path),
            claude_json=str(self.claude_json_path),
            claude_md=str(self.claude_md_path),
            agents_md=str(self.agents_md),
            backup_dir=str(self.backup_dir),
        )

    def test_install_merges_idempotently_and_uninstall_preserves_user_entries(self):
        self.settings_path.parent.mkdir(parents=True)
        self.settings_path.write_text(
            json.dumps(
                {
                    "hooks": {
                        "PreToolUse": [
                            {"matcher": "Bash", "hooks": [{"type": "command", "command": "user-guard.sh"}]}
                        ]
                    }
                }
            ),
            encoding="utf-8",
        )
        self.claude_json_path.write_text(
            json.dumps({"mcpServers": {"user-mcp": {"command": "node", "args": ["srv.js"]}}}),
            encoding="utf-8",
        )
        self.claude_md_path.write_text("# My Personal Rules\nKeep it simple.\n", encoding="utf-8")

        args = self._make_args()
        self.assertEqual(register_claude.install(args), 0)
        self.assertEqual(register_claude.install(args), 0)  # idempotent re-run

        settings = json.loads(self.settings_path.read_text(encoding="utf-8"))
        self.assertEqual(len(settings["hooks"]["PreToolUse"]), 2)
        self.assertEqual(len(settings["hooks"]["Stop"]), 1)

        claude_json = json.loads(self.claude_json_path.read_text(encoding="utf-8"))
        self.assertIn("user-mcp", claude_json["mcpServers"])
        self.assertIn("ecc-lite-brain", claude_json["mcpServers"])

        claude_md = self.claude_md_path.read_text(encoding="utf-8")
        self.assertEqual(claude_md.count(register_claude.AGENTS_BLOCK_BEGIN), 1)
        self.assertIn("# My Personal Rules", claude_md)

        self.assertEqual(register_claude.uninstall(args), 0)
        settings_after = json.loads(self.settings_path.read_text(encoding="utf-8"))
        self.assertEqual(len(settings_after["hooks"]["PreToolUse"]), 1)
        self.assertNotIn("Stop", settings_after["hooks"])

        claude_json_after = json.loads(self.claude_json_path.read_text(encoding="utf-8"))
        self.assertIn("user-mcp", claude_json_after["mcpServers"])
        self.assertNotIn("ecc-lite-brain", claude_json_after["mcpServers"])

        claude_md_after = self.claude_md_path.read_text(encoding="utf-8")
        self.assertNotIn(register_claude.AGENTS_BLOCK_BEGIN, claude_md_after)
        self.assertIn("# My Personal Rules", claude_md_after)

    def test_invalid_json_raises_without_overwriting(self):
        self.settings_path.parent.mkdir(parents=True)
        self.settings_path.write_text("{broken json", encoding="utf-8")
        with self.assertRaises(register_claude.ConfigError):
            register_claude.install(self._make_args())
        self.assertEqual(self.settings_path.read_text(encoding="utf-8"), "{broken json")


class SyncAgentsTests(unittest.TestCase):
    def test_claude_sync_skips_planner_and_transforms_tools_and_models(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = root / "src"
            dst_claude = root / "claude_agents"
            dst_cursor = root / "cursor_agents"
            src.mkdir()
            dst_claude.mkdir()

            (src / "explorer.md").write_text(
                "---\nname: explorer\nmodel: flash\ntools:\n  - view_file\n  - grep_search\n---\n"
                "Operating mode: Gemini 3.8 Flash (Medium Effort). Use `grep_search`.\n",
                encoding="utf-8",
            )
            (src / "planner.md").write_text(
                "---\nname: planner\nmodel: flash\n---\nOperating mode: Gemini 3.8 Flash (High Effort).\n",
                encoding="utf-8",
            )
            # Pre-existing planner.md from an older install should be removed for Claude.
            (dst_claude / "planner.md").write_text("stale", encoding="utf-8")

            self.assertEqual(sync_agents.sync_agents(str(src), str(dst_claude), "claude"), 0)
            self.assertFalse((dst_claude / "planner.md").exists())
            explorer_claude = (dst_claude / "explorer.md").read_text(encoding="utf-8")
            self.assertIn("model: haiku", explorer_claude)
            self.assertIn("- Read", explorer_claude)
            self.assertIn("- Grep", explorer_claude)
            self.assertIn("Claude Haiku 5.5", explorer_claude)
            self.assertIn("`Grep`", explorer_claude)

            self.assertEqual(sync_agents.sync_agents(str(src), str(dst_cursor), "cursor"), 0)
            self.assertTrue((dst_cursor / "planner.md").is_file())


if __name__ == "__main__":
    unittest.main()
