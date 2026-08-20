# Architecture

How this extension is laid out and wired. For the per-module reference and the
"where do I look for X?" index, see [MODULES.md](MODULES.md). For how the fork itself
is maintained, see [FORK.md](FORK.md).

Dash2Dock Animated replaces the GNOME Shell overview dash with a persistent, animated
dock. It reparents the real `Main.overview.dash` into its own `Dock` actor rather than
building a dash from scratch, drives per-frame icon scaling from a timer, and adds
folder icons (trash, downloads, mounts) that are synthesised as `.desktop` files at
runtime.

## Layout

Root holds only what the GNOME loader or a runtime path string requires. Everything
else lives under `src/`.

```
extension.js            entry point — gnome-shell loads this by name
prefs.js                entry point — gnome-extensions prefs loads this by name
metadata.json           UUID, shell-version, schema-id
stylesheet.css          auto-loaded by the shell from the extension root
schemas/                glib-compile-schemas target; gschemas.compiled is committed
ui/                     prefs assets — resolved as `${this.path}/ui` (prefs.js:26,168)
themes/                 preset .json — resolved as `${this.path}/themes` (prefs.js:227)
apps/                   NOT ESM modules; addressed by path string (see below)
src/
  dock/                 the dock actor, its animation, hiding, and items
  services/             outside-world state: files, mounts, notifications, other extensions
  render/               drawing primitives, geometry, stylesheet generation, shaders
  icons/                Cairo painters for the custom icon faces
  util/                 timers, path/geometry helpers, diagnostics
  prefs/                settings-key plumbing, shared by extension.js and prefs.js
docs/                   this document and its siblings
tests/ tools/ lint/     dev-only; stripped by `make install`, excluded from eslint
```

### Why `apps/` is not under `src/`

`apps/` holds out-of-process resources, not modules. Nothing imports them:

- `apps/recents.js` is spawned as a separate gjs process — `src/services/services.js:520`
- `apps/empty-trash.sh` is the `Exec=` of a generated desktop action — `src/services/services.js:200`
- `apps/recents-dash2dock-lite.desktop` is read from disk — `src/dock/dock.js:959`

Its four Cairo painters (`clock.js`, `calendar.js`, `dot.js`, `overlay.js`) *were*
modules and moved to `src/icons/`.

## Layers

Dependencies point downward. There is one documented cycle.

```
        extension.js ── prefs.js
             │             │
        ┌────┴─────┬───────┴────┐
      dock/    services/     prefs/
        │          │
        └────┬─────┘
          render/   icons/
             └────┬────┘
                util/
```

| Layer | May depend on | Notes |
|---|---|---|
| `src/dock/` | `render/`, `icons/`, `util/` | The only layer that touches shell internals heavily |
| `src/services/` | `icons/`, `util/` | Owns all Gio file/mount/notification watching |
| `src/render/` | `util/` | `render/effects/` is leaf — depends on nothing local |
| `src/icons/` | `render/` | Cairo painters only; no shell dependency |
| `src/util/` | — | Leaf, except `diagnostics.js` which imports `Main` |
| `src/prefs/` | — | Leaf; the only code shared by both entry points |

**Documented cycle:** every module inside `src/dock/` imports `DockPosition` from
`dock.js`, and `dock.js` imports those same modules back
(`src/dock/dock.js:16-23`). It is a shared enum, not a behavioural dependency —
`DockPosition` is defined at `src/dock/dock.js:33` before any of them is used.

`src/services/monitors.js` is reachable **only from `prefs.js`**. Nothing on the
shell side imports it, despite the name suggesting otherwise.

## Lifecycle

### enable — `extension.js:167`

1. **Three timers** — `extension.js:175-187`. `_timer` (3500ms, persistent polling),
   `_hiTimer` (15ms, the animation clock, retuned by `animation-fps`), `_loTimer`
   (750ms, debounce/deferral). All three are `Timer` from `src/util/timer.js:5`.
2. **Style** — `extension.js:194`, generates and loads a stylesheet at runtime
   (`src/render/style.js:8`).
3. **Settings** — `_enableSettings()` at `extension.js:446`, backed by
   `src/prefs/keys.js:11`; then `_loadConfig()` reads `~/.config/d2da/`.
4. **Hide the real dash** — `_showMainOverviewDash(false)` at `extension.js:207`,
   after stashing `Main.overview.dash._box` as `__box`.
5. **Integrations** — `extension.js:213`, patches around Blur-My-Shell and friends
   (`src/services/integrations.js:5`).
6. **Services** — `extension.js:219`, `setupFolderIcons()` synthesises the trash,
   downloads and mount `.desktop` files (`src/services/services.js:232`).
7. **Style/shrink/resolution/FPS passes**, then `_addEvents()` (`extension.js:676`)
   and `_queryDisplay()` (`extension.js:329`) which builds the per-monitor dock set.
8. **Deferred start** — `startUp()` runs 250ms later via `_loTimer`
   (`extension.js:239`) so dynamic imports have settled.

Each `Dock` (`src/dock/dock.js:52`) owns an `Animator`
(`src/dock/animator.js:37`) and an `AutoHide` (`src/dock/autohide.js:28`). The
animation loop is `Animator.animate(dt)` at `src/dock/animator.js:107`, driven by
`_hiTimer`.

### disable — `extension.js:245`

Order matters and is deliberate: timers shut down **first** (`extension.js:246-249`)
so no frame lands mid-teardown, then events, then settings, then the three
`_update*(true)` calls that pass `disable=true` to undo layout/shrink/autohide, then
docks are destroyed, then integrations and services, then the stylesheet is unloaded.

The most common bug class here is a listener or timer that outlives `disable()` and
fires against a destroyed actor. `src/dock/dock.js` uses `connectObject` so most
signal cleanup is automatic.

## Path-string resolution

Three mechanisms resolve files by constructed path, so **they do not follow a
`git mv`**. `tools/check-imports.sh` validates ESM imports only — it cannot see these.

| Kind | Built at | Resolves to |
|---|---|---|
| Shaders | `src/render/effects/*_effect.js:9-18` | `${extensionDir}/src/render/effects/<name>.glsl` |
| Subprocess + desktop files | `src/services/services.js:200,520`, `src/dock/dock.js:959` | `${extension.path}/apps/…` |
| Prefs assets | `prefs.js:26,168,227` | `${this.path}/ui`, `${this.path}/themes` |

The prefs assets are **directory scans** — `preloadPresets()` at `prefs.js:237`
enumerates `themes/` and loads whatever it finds, so `dark.json` and `light.json` are
never named in code.

Separately, the trash/downloads/mount `.desktop` files are **generated into `/tmp` at
runtime** (`src/services/services.js:195-226`, `:641`) and consumed from there
(`src/dock/dock.js:976,1007`). The copies tracked in `apps/` are shadowed — see the
dead register in [MODULES.md](MODULES.md).

## Build and packaging

- `make build` — compiles schemas. Required before the extension will run.
- `make install` — wipes and re-copies into
  `~/.local/share/gnome-shell/extensions/dash2dock-lite@icedman.github.com/`,
  then strips `tests/`, `tools/`, `screenshots/`, `Makefile`, `build/`.
- `make lint` — eslint plus `tools/check-imports.sh`. Must report zero errors.
- `make publish` — builds the zip. Copies the two entry points, `src/`, `schemas/`,
  `ui/`, `apps/`, `themes/`, and strips `gschemas.compiled`, so a plain extract yields
  an extension with **no compiled schemas**.

**Dead build path:** the `g44` target and its GNOME 42–44 transpiler
(`tools/transpile.py`, `tools/imports_*.js`) target shell versions this fork no longer
declares (`metadata.json` says 46+). The target still references the pre-restructure
`./effects` and `./preferences` directories and will fail if invoked. It is left
untouched rather than half-repaired because upstream still maintains it.
