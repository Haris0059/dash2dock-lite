# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## This is a fork, not a project

A long-lived patch set on top of `icedman/dash2dock-lite`. Read @docs/FORK.md before touching anything — it governs how work is done here and lists every carried patch with its upstream PR.

Key consequences:

- **One commit per fix.** Patches must drop cleanly when upstream merges the equivalent. Never bundle unrelated fixes.
- `main` = `upstream/main` + carried patches, rebased on top. Rebasing and force-pushing `main` is safe; always `git push --force-with-lease origin main`, never bare `--force`.
- `git rerere` is enabled and must not be disabled — the same `dock.js` hunks conflict every rebase cycle.
- Run `./tools/fork-status.sh` to see which patches are `carried` vs `LANDED` upstream.
- **Every commit touching an upstream-owned source file must sit below the `src/` restructure
  commit**, addressing root-level paths — that is what keeps patch-id matching and `rerere`
  working. Author a new fix against root paths and insert it *below* the restructure
  (`git rebase -i`), never on top. Fork-local additions (docs, tooling) may sit above it.
  See `docs/FORK.md`.
- The extension UUID (`dash2dock-lite@icedman.github.com`) is deliberately unchanged so local builds replace the extensions.gnome.org install in place and keep its dconf settings.

**Do not "fix" these back to match the upstream PRs** (both are deliberate, both documented in FORK.md):

1. The `Config` import in `dock.js` stays. PR #356 deletes it, but the fork needs it for the `Config.PACKAGE_VERSION[0] == '4'` gate around `affectsInputRegion` — without it, `Params.parse()` throws on GNOME 50 and the extension fails to initialise.
2. `setupMountIcon()` early-returns on a null `get_default_location()`. PR #359 calls it in a loop over every mount, so an unguarded throw would abort reconciliation for all mounts, not just one.

Before porting a new upstream fix, verify the symptom on the actual machine. Several upstream PRs describe conditions this fork does not run under.

## Layout

Root holds only what the GNOME loader or a runtime path string requires; everything else is
under `src/`.

```
extension.js prefs.js metadata.json stylesheet.css   # loaded by name by gnome-shell
schemas/            glib-compile-schemas target
ui/                 prefs.js:168  `${this.path}/ui`      (.ui pages, icons, images)
themes/             prefs.js:227  `${this.path}/themes`  (preset .json, scanned by dir)
apps/               NOT modules — spawned or read by path:
                    recents.js (gjs subprocess), empty-trash.sh, *.desktop
src/dock/           dock.js animator.js autohide.js dockItems.js dockItemMenu.js
src/services/       services.js integrations.js monitors.js
src/render/         drawing.js vector.js style.js  + effects/ (*.js and *.glsl)
src/icons/          clock.js calendar.js dot.js overlay.js  (Cairo icon painters)
src/util/           timer.js utils.js diagnostics.js
src/prefs/          keys.js prefKeys.js
docs/               FORK.md DESIGN.md HACKING.md CHECKLIST.md ARCHITECTURE.md MODULES.md
tests/ tools/ lint/ screenshots/
```

`apps/` deliberately stays at the root: it is out-of-process resources addressed by path
string, not part of the ESM graph. Only its four Cairo painters moved to `src/icons/`.

See `docs/ARCHITECTURE.md` for the layer rules and `docs/MODULES.md` for the per-module map
and the register of dead-but-retained files.

## Commands

- `make` — build + install + lint (the normal rebuild)
- `make build` — `glib-compile-schemas` into `schemas/`; required before the extension will run
- `make install` — wipes and re-copies into `~/.local/share/gnome-shell/extensions/dash2dock-lite@icedman.github.com/`
- `make test-prefs` — open just the prefs window
- `make test-shell` — nested Wayland shell via `dbus-run-session` (hardcodes UID 1000)
- `make pretty` — `prettier --single-quote --write "**/*.js"`
- `./tools/check-imports.sh` — resolve every relative ESM import; run by `make lint`
- `./tools/fork-status.sh` — fetch upstream, list carried vs landed patches

`package.json` has no scripts and no dependencies; `eslint`/`prettier` come from the global environment.

## Reload and verification

There is no automated test suite. Claude cannot verify a change on its own — the user tests manually.

- Nested session (`make test-shell`) for quick checks.
- Full log out / log in (X11) for anything touching input regions, struts, or monitor geometry — those do not reproduce faithfully in the nested shell.
- Logs: `journalctl /usr/bin/gnome-shell -f -o cat`
- `docs/CHECKLIST.md` is the manual pre-publish visual pass.

## Code style

Match `.prettierrc` and surrounding code: 2-space indent, single quotes, semicolons, trailing commas, 80 cols. Note `prettier` is not currently installed, so `make pretty` fails — match surrounding code by hand.

`.eslintrc.yml` pulls in vendored GNOME configs that specify 4-space indent and other conventions the codebase does not follow, so every formatting rule is switched off there. **Formatting is prettier's business; eslint is only there to catch bugs.** Do not reformat to satisfy eslint, and do not re-enable the disabled style rules.

`make lint` runs eslint plus `tools/check-imports.sh` and should report zero errors. Any error is a real defect — `no-undef`, `no-dupe-*`, `no-unreachable`. Warnings (`no-unused-vars`, `no-shadow`) are a known backlog and do not fail the build.

Imports are GNOME 45+ ESM (`import St from 'gi://St'`, `resource:///org/gnome/shell/...`). `prefs.js` uses the capitalized `resource:///org/gnome/Shell/Extensions/js/...` path.

## Gotchas

- **GNOME version gating** uses `Config.PACKAGE_VERSION[0] == '4'` (see `dock.js`). Any new API that changed in GNOME 50 needs the same treatment.
- `schemas/gschemas.compiled` is committed, but `make publish` strips it from the zip — a plain zip extract yields an extension with no compiled schemas.
- User config lives in `~/.config/d2da/` (`config.json`, `icons.json`, `style.css`, `themes/`) and needs a disable→enable to reload. `extension.js` reads these via relative paths, assuming CWD is `$HOME`.
- Blurred background requires `imagemagick` installed system-wide.
- **Moving a file does not move its path strings.** Three mechanisms resolve by path, not by
  import: shaders (`GLib.build_filenamev([extensionDir, 'src', 'render', 'effects', …])`),
  the `apps/` subprocess and `.desktop` resources (`${extension.path}/apps/…` in
  `src/services/services.js` and `src/dock/dock.js`), and the prefs `ui/`+`themes/` folders
  (`${this.path}/…` in `prefs.js`). `tools/check-imports.sh` catches broken *imports* only.
- Non-file `make` targets must be listed in `.PHONY` — the `lint/` directory silently
  shadowed the `lint` target until it was added.
- The `make g44` GNOME 42–44 transpile build is dead for this fork (`metadata.json` declares 46+). Ignore `tools/transpile.py`'s import map when adding imports.
- `gettext` is wired up but there are no translations — no `po/` or `locale/`.

## Commits

Imperative mood, capitalized, single-line subject, no body — e.g. `Guard addChrome options for GNOME 50`. No Conventional Commits prefixes and no issue refs in the subject; the PR mapping lives in FORK.md's table instead. Inherited upstream commits look different; follow the fork's style, not theirs.

New fixes go straight onto `main` as a single commit. Commit and push only when asked.
