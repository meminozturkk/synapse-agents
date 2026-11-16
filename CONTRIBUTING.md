# Contributing to Synapse Agents

Contributions, bug reports, and platform improvements are welcome!

## Principles

- **Zero external runtime dependencies:** Keep all hooks, MCP tools (`plugins/ecc-lite/mcp/brain_server.py`), and installer/sync helpers in `scripts/` strictly on the Python 3 standard library and POSIX shell / PowerShell.
- **Surgical, minimal changes:** Avoid speculative abstractions or unrelated formatting edits. Keep diffs focused on the issue or feature being solved.
- **Non-destructive defaults:** Installer and registration scripts must merge existing user configurations, create backups before editing, and fail safely on invalid JSON.

## Local Verification

Run the syntax checks and zero-dependency test suite before opening a pull request:

```bash
bash -n install.sh uninstall.sh plugins/ecc-lite/hooks/*.sh
python3 -m py_compile plugins/ecc-lite/mcp/brain_server.py plugins/ecc-lite/hooks/*.py scripts/*.py tests/*.py
python3 -m unittest discover -s tests -v
```

## Pull Request Checklist

1. Create a focused branch from `main` (e.g., `fix/...` or `feat/...`).
2. Add or update unit tests in `tests/` for any new hook, MCP, or script behavior.
3. Update `README.md` / `README.tr.md` if installation flags, hooks, or agent mappings change.
4. Confirm all checks above pass cleanly with zero warnings or errors.
