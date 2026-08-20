# Fork notes

This is a fork of [icedman/dash2dock-lite](https://github.com/icedman/dash2dock-lite),
maintained as a **long-lived patch set on top of upstream**, not as a separate project.

Upstream is alive but ships in bursts (roughly around GNOME releases), and open PRs
can sit for months. This fork carries the fixes that matter on a real machine so they
can be used before they land upstream — and drops them again once they do.

The extension UUID is deliberately unchanged (`dash2dock-lite@icedman.github.com`)
so a local build replaces the extensions.gnome.org install in place and keeps its
dconf settings.

## Layout

There is no mirror branch. The remote-tracking ref `upstream/main` *is* the mirror.

- `main` — upstream/main plus the carried patches, rebased on top
- one commit per fix, so a patch drops cleanly once upstream merges the equivalent

Nobody consumes this branch downstream, so rebasing (and force-pushing `main`) is
safe, and it buys the thing that makes a carried fork maintainable: `git rebase`
matches patch-ids and **silently drops patches upstream has already taken**.

### The restructure commit must stay at the tip

`Reorganize extension sources under src/` is a fork-local commit that will never go
upstream. The invariant is that **every commit touching upstream's source files sits
below it**, still addressing root-level paths — which is exactly what keeps patch-id
matching and `rerere` working:

- carried patches touch `dock.js`, `animator.js`, … , so their patch-ids still match
  the equivalent commit upstream and still get dropped automatically
- `rerere` resolutions are keyed on path + hunk, so the recurring `dock.js` conflicts
  replay as before
- the restructure itself replays as a pure rename set; git's rename detection carries
  upstream's edits into `src/` for you

Commits that only *add* fork-local files (docs, tooling, skills) may sit above it —
they touch nothing upstream owns and so cannot conflict.

**Adding a new fix:** author it against the *root* paths and insert it **below** the
restructure commit, so it stays upstream-portable:

```sh
git rebase -i <restructure-commit>^   # mark the restructure commit 'edit', or reorder
```

A fix committed on top of the restructure is written against `src/` paths and can no
longer be submitted upstream unmodified, nor patch-id matched when upstream takes it.

## Routine

```sh
./tools/fork-status.sh          # fetch upstream, list carried vs landed patches
```

When it reports upstream has moved:

```sh
git rebase upstream/main
make                            # rebuild + reinstall
# log out / log in (X11) to reload the shell, then exercise the dock
git push --force-with-lease origin main
```

`rerere` is enabled (`rerere.enabled`, `rerere.autoupdate`), so a conflict resolved
once is replayed automatically on later rebases. Don't disable it — the same few
hunks in `dock.js` conflict every cycle.

After a rebase, re-run `fork-status.sh`. Anything that flipped to `LANDED` is now
upstream and should have disappeared from the patch set; if a patch you expected to
drop is still `carried`, upstream merged a *different* version of that fix and the
two need reconciling by hand.

## Carried patches

Each maps to an upstream PR unless noted. See the triage notes for why the rejected
PRs were rejected — that reasoning is expensive to re-derive.

| commit | upstream | fix |
|---|---|---|
| `bf07487` + `ad59132` | #342 / #349 | X11 click dead-zone along dock edge |
| `696c45c` | #348 | dodge ignoring modal and utility windows (`in` vs `.includes`) |
| `9564b8f` | #339 | null-dash crash on monitor disconnect |
| `4d00118` | #353 | stale trash icon and Empty Trash action |
| `f016c9b` | #344 | dock blocking clicks in fullscreen |
| `1166433` | #347 | spurious icon bounce on app list changes |
| `f4dc852` | #361 | minimized window flashing on icon click |
| `f0c857a` | #355 | strut rect on offset monitors |
| `c10e816` | #356 | track visible dock actors for input region |
| `21fd474` | *local* | guard `addChrome` options for GNOME 50 |
| `c40c21b` | #359 + #360 | mount icon identity and unmount cleanup |

### Fork-local commits with no upstream counterpart

| commit | what |
|---|---|
| — | `src/` source layout, docs under `docs/`, `tools/check-imports.sh` |
| — | donation prompts and funding config removed |
| — | `screenshots/` and dead legacy UI artifacts removed |

These never drop out on rebase. See the invariant above.

**The donation removal is the fork's most conflict-prone patch.** It touches
`metadata.json` (62 upstream commits, last 2026-05-23), `prefs.js` (84, 2025-12-19),
`ui/general.ui` (41, 2025-12-03) and `README.md` (46, 2026-01-30) — all files upstream
edits routinely. Expect to re-resolve it most rebases; `rerere` will replay the
resolution once you have done it once.

What was removed: the `donations` block in `metadata.json`, `.github/FUNDING.yml`, the
`open-buy-coffee` action and QR loader in `prefs.js`, the "Buy me a coffee" menu item
in `ui/menu.ui`, the thank-you/QR banner group in `ui/general.ui`, the
`ui/images/qr_icedman.png` asset, and the badge in `README.md`.

**Attribution was deliberately kept** and must stay — GPL-3.0 requires it and the tree
is overwhelmingly icedman's work: `LICENSE`, `original-authors` and `url` in
`metadata.json`, the project-page/bug-report/license links in the prefs menu, and the
README credits. Removing funding links is not the same as removing authorship.

### Deliberate departures from the upstream diffs

Do not "fix" these back to match the PRs:

- **Keep the `Config` import in `dock.js`.** #356 deletes it; we still need it, because
  our `affectsInputRegion: false` is gated on `Config.PACKAGE_VERSION[0] == '4'`.
  Without that gate the extension fails to initialise on GNOME 50 — `Params.parse()`
  throws on unknown keys.
- **`setupMountIcon()` early-returns on a null `get_default_location()`.** #359 moves
  that call into a loop over every mount, so an unguarded throw would abort
  reconciliation for all of them rather than one event.

## Before porting anything new

Check it against the machine it will actually run on rather than trusting the PR
description — several upstream PRs describe symptoms that only occur in
configurations this fork does not run (Wayland, autohide combinations, multi-monitor
layouts without an offset).

## If upstream goes quiet for a full release cycle

Revisit whether to publish this as a separate extension. That means a new UUID and a
new schema id, and preserving attribution for icedman and for every contributor whose
PR is carried above — the tree is overwhelmingly their work, and GPL-3.0 requires those
notices be kept. The `donations` block is already gone (see the fork-local table).
