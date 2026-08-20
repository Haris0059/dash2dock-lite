---
name: project-navigation
description: "Writes and maintains internal navigation documentation for this repository — the architecture map, per-module reference, and 'where do I look for X?' index in docs/. Use when documenting the codebase layout, onboarding to an unfamiliar area, or refreshing docs/ARCHITECTURE.md and docs/MODULES.md after files move."
allowed-tools: Read Write Glob Grep Bash
metadata:
  derived-from: api-documentation
  scope: dash2dock-lite (fork)
  version: "1.0"
---

# Project Navigation Documentation

## When to Use This Skill

Use this skill when you need to:
- Write or refresh `docs/ARCHITECTURE.md` and `docs/MODULES.md`
- Document what a module does, who calls it, and where its entry points are
- Record how a subsystem is wired so the next session doesn't re-derive it by grepping
- Maintain the dead-code register and the "where do I look for X?" index

**DO NOT** use this skill for user-facing documentation (`README.md`), release notes
(`CHANGELOG.md`), fork-workflow rules (`docs/FORK.md`), or API reference for external
consumers. This extension has no public API — the audience is whoever edits the code next.

---

## Core Principle

EVERY ENTRY MUST ANSWER "WHICH FILE DO I OPEN?" WITH A `path:line` A READER CAN CLICK —
A DESCRIPTION THAT DOES NOT LAND THE READER ON A LINE HAS FAILED.

The failure mode of internal docs is prose that restates the directory listing. If a
paragraph would not save someone a grep, delete it.

---

## Phase 1: Brief

Gather these before writing. Read the code — do not infer from filenames.

| Input | How to establish it | Notes |
|---|---|---|
| **Entry points** | What does the loader call? | `extension.js` (`enable`/`disable`), `prefs.js` |
| **Module inventory** | `find . -name '*.js'` minus `tests/`, `tools/` | Every file gets an entry or is declared dead |
| **Dependency edges** | `grep -rn "from '\.\.\?/" ` | Feeds both the layer rules and the reachability check |
| **Reachability** | Walk imports transitively from each entry point | Unreached ≠ dead — check §Path-string trap |
| **Lifecycle** | Trace `enable()` to first paint, and `disable()` teardown | The single most useful thing in the doc |
| **Path-string resolution** | `grep -rn "build_filenamev\|new_for_path\|\.path\}"` | Files loaded by string, not import |
| **Ownership** | `git log upstream/main -- <file>` | Fork-local vs upstream-owned, and how hot |

**GATE: Confirm the module inventory and the dead list before writing.**

### The path-string trap

A file with no importer is not necessarily dead. This codebase loads three kinds of
resource by constructed path:

- shaders — `GLib.build_filenamev([extensionDir, …, '<name>.glsl'])`
- out-of-process resources — `${extension.path}/apps/…` (a spawned gjs script, a shell
  script, `.desktop` files)
- prefs assets — `${this.path}/ui`, `${this.path}/themes` (directory scans, so members
  are never named in code)

Always grep for the *basename* before calling anything dead.

---

## Phase 2: Structure

### `docs/ARCHITECTURE.md` — the map

1. **Overview** — what the extension is, in three sentences
2. **Layout** — annotated tree; every root entry states *why* it is at the root
3. **Layers** — the groups under `src/` and the allowed dependency direction
4. **Lifecycle** — `enable()` → constructed objects → first paint; then `disable()`
5. **Resolution mechanisms** — the three path-string kinds above, each with `file:line`
6. **Build and packaging** — what ships, what is stripped, what is dead

### `docs/MODULES.md` — the reference

1. **Where do I look for X?** — the index, first, because it is what gets used
2. **Module reference** — one entry per file, grouped by layer
3. **Dead-code register** — what is unreachable, and why it was kept or removed

**GATE: Confirm structure before writing.**

---

## Phase 3: Write

### Module entry template

```
### `src/<layer>/<name>.js`

One sentence: what it is responsible for.

| | |
|---|---|
| Layer | dock / services / render / icons / util / prefs |
| Imports | the relative deps, as paths |
| Imported by | who pulls it in — or "entry point" / "**nothing (see dead register)**" |
| Ownership | upstream / fork-local, and last upstream touch |

**Key symbols**
- `ClassOrFunction` — `src/<layer>/<name>.js:NN` — what it does
```

### "Where do I look for X?" index

Phrase rows as the symptom or task a reader arrives with, never as the module name —
someone chasing a bug knows "the dock eats my clicks", not "input region tracking".

```
| I want to change / fix… | Start at |
|---|---|
| the dock hiding for the wrong windows | `src/dock/autohide.js:NN` |
| icons bouncing when they shouldn't | `src/dock/animator.js:NN` |
```

### Writing rules

- Every claim carries a `path:line`. Line numbers drift — that is acceptable; a
  slightly stale anchor still lands the reader in the right function.
- State the dependency direction as a rule, then note every violation explicitly. An
  undocumented cycle is worse than a documented one.
- Record *why* something is where it is when it looks wrong (a root-level directory
  that "should" be under `src/`), or the next session will helpfully break it.
- Prefer a table to a paragraph. This document is scanned, not read.
- Do not restate what `README.md` or `docs/FORK.md` already says — link instead.

---

## Phase 4: Polish

### Dead-code register

Unreachable code is navigational information: the next reader needs to know not to
study it. For each item record **why it was kept**, because on a carried fork deleting
an upstream-owned file creates a permanent modify/delete conflict.

```
| File | Status | Kept because |
|---|---|---|
| `src/icons/overlay.js` | no importer | upstream edited it 2025-12; deleting it conflicts forever |
```

### Quality checklist

```
- [ ] Every .js file outside tests/ and tools/ has an entry or is in the dead register
- [ ] Every entry has at least one `path:line` anchor
- [ ] Lifecycle traces enable() AND disable() — teardown bugs are the common ones
- [ ] All three path-string mechanisms are documented with their call sites
- [ ] The "where do I look for X?" index is phrased as symptoms, not module names
- [ ] Dead register says why each item was kept, not just that it is dead
- [ ] No file is called dead without a basename grep proving no path-string use
- [ ] Root-level exceptions each state their reason
```

---

## Anti-Patterns

- **Restating the tree** — "`src/dock/` contains the dock code" earns nothing. Say what
  the layer may depend on and what calls into it.
- **No line anchors** — a module description without `path:line` sends the reader back
  to grep, which is the problem the document exists to solve.
- **Calling a file dead on import evidence alone** — see the path-string trap. This
  codebase spawns `apps/recents.js` by string; it looks unimported and is not.
- **Documenting intent instead of behaviour** — describe what the code does now. If it
  is wrong, say it is wrong and where.
- **Silent staleness** — when files move, the docs move with them in the same commit,
  or they become actively misleading.

---

## Recovery

- **A module resists a one-sentence summary:** that is a finding, not a writing problem.
  Record the multiple responsibilities as a list and note it as a refactor candidate.
- **Line numbers already drifted:** anchor on the symbol name in the text and keep the
  number as a hint; re-run a grep for the symbol when refreshing.
- **A dependency cycle blocks clean layering:** document the actual edges and mark the
  cycle explicitly rather than drawing a layer diagram that lies.
- **Too much to document at once:** the "where do I look for X?" index first, then the
  layers a current task touches. Partial and accurate beats complete and stale.
