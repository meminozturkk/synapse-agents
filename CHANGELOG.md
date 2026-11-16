# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-11-16

### Added
- `ecc-lite` plugin: 0-token `PreToolUse` (`secret-guard`) and `Stop` (`verify-quiet`) hooks in Bash and Python, plus zero-dependency `ecc-lite-brain` MCP server with 2-stage progressive knowledge search.
- `orchestration` plugin: Hands-Off Chief Architect rules, `CLAUDE-ROUTING.md` cost-routing rules for Claude Code, and `explorer`, `planner`, `coder`, `reviewer` subagent definitions.
- Cross-platform installers and uninstallers (`install.sh`, `uninstall.sh`, `install.ps1`, `uninstall.ps1`) and registration/sync utilities (`scripts/*.py`).
- `PLATFORM_SKIP` support in `scripts/sync_agents.py` to omit `planner.md` on Claude Code.
- Automated `unittest` test suite under `tests/` covering `brain_server.py`, `secret_guard.py`, `verify_quiet.py`, `register_claude.py`, and `sync_agents.py`.
- Cross-platform GitHub Actions CI workflow (`.github/workflows/ci.yml`) running on Ubuntu, macOS, and Windows.
- `CONTRIBUTING.md`, `CHANGELOG.md`, and `THIRD_PARTY_NOTICES.md`.
