---
name: tech-debt
description: "Harvest every shortcut: and ponytail: comment into one debt ledger, so deferrals get tracked instead of forgotten. One-shot report."
---

Every deliberate shortcut is marked with a `shortcut:` (or older `ponytail:`) comment naming
its ceiling and upgrade path. This skill collects them into one ledger so a deferral
can't quietly become permanent debt.

## Scan

Grep the repo for comment markers, skipping `.git` and everything the
`.gitignore` files ignore (dependencies, build output, caches, in any stack):

```bash
git grep --no-index --exclude-standard -nE '(#|//|/[*]) ?(shortcut|ponytail):'
```

If the user names their own marker word (e.g. `TODO`, `FIXME`), grep for that word instead.

Each hit is one ledger row. The comment prefix keeps prose that merely mentions
the convention out of the ledger. Skip hits that are not a deferral, like a note
about a keyboard shortcut.

## Output

One row per marker, grouped by file:

`<file>:<line>, <what was simplified>. ceiling: <the limit named>. upgrade: <the trigger to revisit>.`

The standard convention is `shortcut: <ceiling>, <upgrade path>`, so pull the ceiling
and the trigger straight from the comment. To check the author: `git blame -L<line>,<line>`.

Flag the rot risk: any marker comment that names no upgrade path or
trigger gets a `[no-trigger]` tag — those are the ones that silently rot.

End with:
- `<N> markers, <M> with no trigger.`
- Nothing found: `No shortcut debt. Clean ledger.`

## Boundaries

Reads and reports only, changes nothing. To persist it, write the
ledger to a file (e.g. `TECH-DEBT.md`).
