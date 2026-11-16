"""Tests for 0-token PreToolUse and Stop hooks (secret_guard.py & verify_quiet.py)."""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SECRET_GUARD_PATH = REPO_ROOT / "plugins" / "ecc-lite" / "hooks" / "secret_guard.py"
VERIFY_QUIET_PATH = REPO_ROOT / "plugins" / "ecc-lite" / "hooks" / "verify_quiet.py"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class SecretGuardTests(unittest.TestCase):
    def run_guard(self, payload: dict, extra_args=None):
        cmd = [sys.executable, str(SECRET_GUARD_PATH)] + (extra_args or [])
        return subprocess.run(
            cmd,
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

    def test_blocks_secret_in_claude_mode(self):
        payload = {
            "tool_name": "Write",
            "tool_input": {"file_path": "app.py", "content": 'API_KEY = "sk-ant-api03-abcdefghijklmnop"'},
        }
        res = self.run_guard(payload)
        self.assertEqual(res.returncode, 2)
        self.assertIn("BLOCK:", res.stderr)
        self.assertEqual(res.stdout, "")

    def test_blocks_secret_in_antigravity_mode(self):
        payload = {
            "toolCall": {
                "name": "write_to_file",
                "arguments": {"TargetFile": "config.ts", "CodeContent": 'const aws = "AKIAIOSFODNN7EXAMPLE"'},
            }
        }
        res = self.run_guard(payload, ["--antigravity"])
        self.assertEqual(res.returncode, 0)
        out = json.loads(res.stdout.strip())
        self.assertEqual(out["decision"], "deny")
        self.assertIn("BLOCK:", out["reason"])

    def test_allows_clean_write_in_both_modes(self):
        claude_res = self.run_guard(
            {"tool_name": "Edit", "tool_input": {"file_path": "app.py", "new_string": "x = os.getenv('API_KEY')"}}
        )
        self.assertEqual(claude_res.returncode, 0)
        self.assertEqual(claude_res.stdout, "")

        ag_res = self.run_guard(
            {"toolCall": {"name": "edit_file", "arguments": {"path": "app.py", "Replacement": "x = 1"}}},
            ["--antigravity"],
        )
        self.assertEqual(ag_res.returncode, 0)
        self.assertEqual(json.loads(ag_res.stdout.strip())["decision"], "allow")

    def test_self_edit_bypass_allows_write_tool_but_blocks_bash(self):
        write_payload = {
            "tool_name": "Edit",
            "tool_input": {"file_path": "plugins/ecc-lite/hooks/secret_guard.py", "new_string": "sk-ant-1234567890123456"},
        }
        write_res = self.run_guard(write_payload)
        self.assertEqual(write_res.returncode, 0)

        bash_payload = {
            "tool_name": "Bash",
            "tool_input": {"command": "echo sk-ant-1234567890123456 > secret_guard.py"},
        }
        bash_res = self.run_guard(bash_payload)
        self.assertEqual(bash_res.returncode, 2)


class VerifyQuietTests(unittest.TestCase):
    def run_verify(self, payload: dict, cwd: Path, extra_args=None):
        cmd = [sys.executable, str(VERIFY_QUIET_PATH)] + (extra_args or [])
        return subprocess.run(
            cmd,
            input=json.dumps(payload),
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

    def test_stop_hook_active_prevents_loop(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = self.run_verify({"stop_hook_active": True, "cwd": tmp}, Path(tmp))
            self.assertEqual(res.returncode, 0)
            self.assertEqual(res.stdout, "")
            self.assertEqual(res.stderr, "")

    def test_non_git_directory_exits_quietly(self):
        with tempfile.TemporaryDirectory() as tmp:
            claude_res = self.run_verify({"cwd": tmp}, Path(tmp))
            self.assertEqual(claude_res.returncode, 0)
            self.assertEqual(claude_res.stdout, "")

            ag_res = self.run_verify({"fullyIdle": True, "workspacePaths": [tmp]}, Path(tmp), ["--antigravity"])
            self.assertEqual(ag_res.returncode, 0)
            self.assertEqual(json.loads(ag_res.stdout.strip())["decision"], "stop")

    def test_get_changed_files_parses_porcelain_paths(self):
        verify_quiet = load_module("verify_quiet", VERIFY_QUIET_PATH)
        porcelain = (
            " M src/App.cs\n"
            "R  old_name.ts -> new_name.ts\n"
            '?? "dir with space/file.dart"\n'
        )
        self.assertEqual(
            verify_quiet.get_changed_files(porcelain),
            ["src/App.cs", "new_name.ts", "dir with space/file.dart"],
        )


if __name__ == "__main__":
    unittest.main()
