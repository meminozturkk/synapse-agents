# Cost Routing (Claude Code)

The main session runs on the most expensive model. Think, decide and verify here; push token-heavy work to cheaper executors. Delegate only when the work clearly outweighs the hand-off cost (brief + cold start + reading the result).

| Work | Who |
| :--- | :--- |
| Planning, trade-offs, reviewing results, small edits at a known spot (a few lines, 1-2 files) | Main session, directly |
| Code search, caller mapping, reading more than a couple of files, scanning logs/test output | `explorer` subagent (Haiku) |
| Multi-file or logic-bearing code changes, debugging loops | `coder` subagent (Sonnet) |
| Bulk, well-specified output: test suites, scaffolding, mechanical migrations, huge-file digests, web research | Antigravity via the `antigravity` plugin (`antigravity-delegate`, `/antigravity:delegate`) |
| Independent review of a large diff | `reviewer` subagent (Sonnet) or `/antigravity:review` |

Rules:
- Give every executor exact file paths and the expected output so it does not search again; take back a short digest, not raw content.
- Start every task sent to another CLI agent (`agy -p`, `agy-delegate`, `/antigravity:*`) with `[HEADLESS]`.
- Antigravity writes go on a dedicated branch or worktree; review `git diff`, not the generated files.
- Never trust an executor's own "tests pass": run the verification yourself.
- If an executor fails twice on the same piece, do it yourself or move it to `coder`.
- For multi-layer work or any API/DTO/DB contract change, show the plan and get approval before writing code.

## Headless runs
A prompt that starts with `[HEADLESS]` is a non-interactive delegated run: do the task yourself in this turn and return the result. Do not invoke subagents and do not reply with only a plan.
