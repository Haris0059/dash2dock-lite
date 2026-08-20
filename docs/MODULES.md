# Module reference

Per-file map of the extension. For layout, layer rules and lifecycle see
[ARCHITECTURE.md](ARCHITECTURE.md).

Line numbers drift as the code changes. A stale anchor still lands you in the right
function — grep the symbol name if it has moved.

## Where do I look for X?

| I want to change / fix… | Start at |
|---|---|
| the dock hiding for the wrong window types | `src/dock/autohide.js:17` — the `handledWindowTypes` list |
| the dock not un-hiding, or hiding too eagerly | `src/dock/autohide.js:304` `_checkHide()`, debounced at `:133` |
| the dock reserving the wrong screen space (struts) | `src/dock/animator.js:1020-1060` |
| clicks landing on the desktop instead of the dock (or vice versa) | `src/dock/dock.js:430-484` — `addChrome`/`trackChrome` and the GNOME 50 gate |
| the mouse-to-reveal trigger strip | `src/dock/dock.js:127` — the `dwell` widget |
| icons bouncing when they shouldn't | `src/dock/animator.js:1096` `bounceIcon()`, flag set at `:1149,1176` |
| icon scaling / the magnification curve | `src/dock/animator.js:107` `animate(dt)` |
| the running-app dots | `src/icons/dot.js:11`, placed by `src/dock/dockItems.js:85` |
| the clock or calendar icon faces | `src/icons/clock.js:125`, `src/icons/calendar.js:8` |
| trash icon state, or Empty Trash | `src/services/services.js:193` `setupTrashIcon()`; action script `apps/empty-trash.sh` |
| mounted volumes appearing/disappearing | `src/services/services.js:678` `checkMounts()` → `:257` `setupMountIcon()` |
| the downloads folder icon and its list | `src/services/services.js:232` `setupFolderIcons()`; recents via `apps/recents.js` |
| the right-click / folder popup menu | `src/dock/dockItemMenu.js:21` `DockItemList` |
| conflicts with Blur-My-Shell or other extensions | `src/services/integrations.js:5` |
| which monitor the dock lands on | `extension.js:329` `_queryDisplay()`; prefs side `src/services/monitors.js:7` |
| adding a settings key | `src/prefs/keys.js:11` **and** `schemas/*.gschema.xml`, then `make build` |
| what happens when a setting changes | `extension.js:446` `_enableSettings()` — the big switch |
| generated CSS (borders, radius, colors) | `src/render/style.js:8`, called from `extension.js:996` `_updateStyle()` |
| shader effects (tint, monochrome) | `src/render/effects/*_effect.js`; applied at `src/dock/dock.js:16-17` |
| timing, debouncing, deferred work | `src/util/timer.js:5`; the three instances at `extension.js:175-187` |

## Entry points

### `extension.js`
The extension object. Owns the timers, the settings switch, the dock set, and the
enable/disable lifecycle.

| | |
|---|---|
| Imports | `src/dock/dock.js`, `src/services/{services,integrations}.js`, `src/render/style.js`, `src/util/{utils,timer,diagnostics}.js`, `src/prefs/keys.js` |
| Imported by | gnome-shell, by name |

**Key symbols** — `Dash2DockLiteExt` `:54` · `enable()` `:167` · `disable()` `:245` ·
`createTheDocks()` `:67` · `_enableSettings()` `:446` (the settings switch) ·
`_addEvents()` `:676` · `_queryDisplay()` `:329` · `animate()` `:286` ·
`_updateStyle()` `:996` · `_updateLayout()` `:1153`

### `prefs.js`
The Adw preferences window. Loads the five `.ui` pages, wires them to the schema, and
manages theme presets.

| | |
|---|---|
| Imports | `src/prefs/keys.js`, `src/services/monitors.js`, `src/util/utils.js` |
| Imported by | `gnome-extensions prefs`, by name |

**Key symbols** — `Preferences` `:21` · icon search path `:26` · `.ui` loading `:168-173` ·
`preloadPresets()` `:237` (scans `themes/`) · QR image `:186`

## `src/dock/`

### `src/dock/dock.js`
The dock actor. Reparents the shell's real dash into itself, manages chrome
registration and input regions, and owns one `Animator` and one `AutoHide`.

| | |
|---|---|
| Imports | `dockItems.js`, `dockItemMenu.js`, `autohide.js`, `animator.js`, `../render/effects/{tint,monochrome}_effect.js`, `../util/utils.js` |
| Imported by | `extension.js`, and every sibling in `src/dock/` (for `DockPosition`) |

**Key symbols** — `DockPosition` `:33` · `DockAlignment` `:40` · `Dock` `:52` ·
`dwell` trigger strip `:127` · pointer events `:208-231` · `slideIn/slideOut` `:337,344` ·
chrome + input region `:430-484` · dash reparenting `:372-376` ·
`_beginAnimation()` `:1331` · `_endAnimation()` `:1364`

The `Config.PACKAGE_VERSION[0] == '4'` gate at `:433` is load-bearing on GNOME 50 —
see [FORK.md](FORK.md) before touching it or the `Config` import.

### `src/dock/animator.js`
The per-frame animation pass: icon scaling, position, dots and badges, and the strut
rectangle that reserves screen space.

| | |
|---|---|
| Imports | `../icons/dot.js`, `dock.js`, `../render/vector.js`, `dockItems.js`, `../render/effects/easing.js`, `../util/utils.js` |
| Imported by | `src/dock/dock.js` |

**Key symbols** — `Animator` `:37` · `enable()` `:38` · `disable()` `:47` ·
`_precreateResources()` `:58` · `animate(dt)` `:107` (the hot path) ·
strut computation `:1020-1060` · `bounceIcon()` `:1096`

### `src/dock/autohide.js`
Decides when the dock hides. Dodge logic tests window overlap against a fixed list of
window types.

**Key symbols** — `handledWindowTypes` `:17` · `AutoHide` `:28` ·
`_debounceCheckHide()` `:133` · dodge gate `:231` · `_checkHide()` `:304`

### `src/dock/dockItems.js`
The St widgets composing a dock entry: the icon, its container, the dots and badge
overlays, and the dock background.

**Key symbols** — `DockItemDotsOverlay` `:85` · `DockItemBadgeOverlay` `:144` ·
`DockIcon` `:175` · `DockItemContainer` `:243` · `DockBackground` `:330`

Note `DockItemOverlay` `:68` (unexported base) is unrelated to `src/icons/overlay.js`.

### `src/dock/dockItemMenu.js`
The popup list shown for folder icons (downloads, recents, mounts).

**Key symbols** — `DockItemList` `:21`

## `src/services/`

### `src/services/services.js`
All outside-world state: trash, downloads, recent files, mounted volumes, and app
notification badges. Synthesises `.desktop` files into `/tmp` so the shell can treat
folders as launchable apps.

| | |
|---|---|
| Imports | `../icons/clock.js`, `../icons/calendar.js`, `../util/utils.js` |
| Imported by | `extension.js` |

**Key symbols** — `Services` `:40` · `setupTrashIcon()` `:193` ·
trash action → `apps/empty-trash.sh` `:200` · `setupFolderIcons()` `:232` ·
`setupMountIcon()` `:257` · `checkMounts()` `:678` ·
recents subprocess → `apps/recents.js` `:520`

`setupMountIcon()` early-returns on a null default location (`:266`) — deliberate, see
[FORK.md](FORK.md).

### `src/services/integrations.js`
Compatibility shims for other extensions, principally Blur-My-Shell.

**Key symbols** — `Integrations` `:5` · Blur-My-Shell effect handoff `:257-259`

### `src/services/monitors.js`
Monitor enumeration for the preferences UI. **Reachable only from `prefs.js`** —
nothing on the shell side imports it.

**Key symbols** — `MonitorsConfig` `:7`

## `src/render/`

### `src/render/drawing.js`
Cairo primitives shared by every icon painter.
**Key symbols** — `Drawing` `:134`

### `src/render/vector.js`
2D vector/geometry helper. No imports at all.
**Key symbols** — `Vector` `:1`

### `src/render/style.js`
Generates a stylesheet at runtime and loads it into St.
**Key symbols** — `Style` `:8` · writes via `tempPath()` `:47`

### `src/render/effects/`
`easing.js` is a pure easing-function table (`Linear` `:13`, `Bounce` `:28`, and the
quadratic/cubic family from `:105`). The `*_effect.js` files are `Clutter.ShaderEffect`
subclasses, each loading its `.glsl` sibling by constructed path — **the path is a
string and does not follow file moves**. Only `tint_effect.js` and
`monochrome_effect.js` are live.

## `src/icons/`

Cairo painters for custom icon faces. All four import only `../render/drawing.js` and
have no shell dependency.

| File | Symbol | Used by |
|---|---|---|
| `src/icons/clock.js` | `Clock` `:125` | `src/services/services.js` |
| `src/icons/calendar.js` | `Calendar` `:8` | `src/services/services.js` |
| `src/icons/dot.js` | `Dot` `:11` | `src/dock/animator.js` |
| `src/icons/overlay.js` | `DebugOverlay` `:10` | **nothing** — see dead register |

## `src/util/`

### `src/util/timer.js`
The scheduling primitive. Three instances exist, at 3500ms, 15ms and 750ms.
**Key symbols** — `Timer` `:5`

### `src/util/utils.js`
Leaf helpers: `tempPath()` `:21`, `getPointer()` `:26`, `warpPointer()` `:30`,
`setTimeout`/`setInterval`/`clear*` `:34-52`, `get_distance*` `:56,62`,
`isOverlapRect()` `:66`.

### `src/util/diagnostics.js`
Scripted self-test that warps the pointer around the dock. Entered from
`extension.js` behind a setting.
**Key symbols** — `runTests()` `:255`

## `src/prefs/`

### `src/prefs/keys.js`
The settings-key table — the one module both entry points share. Adding a key means
editing here **and** `schemas/org.gnome.shell.extensions.dash2dock-lite.gschema.xml`,
then `make build`.
**Key symbols** — `schemaId` `:9` · `SettingsKeys()` `:11`

### `src/prefs/prefKeys.js`
Generic key-binding machinery behind `keys.js`.
**Key symbols** — `PrefKeys` `:7`

## Dead-code register

Unreachable, but retained. This is a **carried fork** — deleting a file upstream still
edits turns every future rebase into a modify/delete conflict, permanently. Anything
upstream touched recently stays and is documented here instead.

| File | Status | Kept because |
|---|---|---|
| `src/icons/overlay.js` | no importer | upstream edited it 2025-12 |
| `src/render/effects/blur_effect.{js,glsl}` | no importer; only `tools/transpile.py:57` names it | upstream edited it 2025-12 |
| `src/render/effects/color_effect.{js,glsl}` | no importer, no string reference | upstream edited it 2025-12 |
| `tools/transpile.py`, `tools/imports_{extension,prefs}.js` | serve the dead `g44` target | upstream edited them 2025-12 |
| `tests/*.js` | standalone gjs scratch scripts on the legacy `imports.*` API | dev-useful; excluded from eslint and stripped by `make install` |
| `apps/{trash,downloads,mount}-dash2dock-lite.desktop` | shadowed — generated into `/tmp` at runtime instead | upstream still ships them |
| `screenshots/`, `.github/images/` | referenced only from README via GitHub URLs | documentation assets |

**Removed** in the restructure (dead *and* untouched upstream since 2024):
`ui/legacy/*.ui`, `tests/generate_legacy.py`, `tests/legacy_row_template.ui`,
`apps/app-grid-dash2dock-lite.desktop`, `ERRORS.md` (0 bytes).

### Not dead, despite appearances

- **`apps/recents.js`** has no importer but is spawned as a subprocess —
  `src/services/services.js:520`. Do not remove it.
- **`themes/dark.json`, `themes/light.json`** are never named in code; `prefs.js:237`
  scans the directory.
- **`src/services/monitors.js`** is unreachable from `extension.js` but live from
  `prefs.js`.

## Known defects

- `extension.js` settings switch: `icon-size` was listed twice (once with
  `preferred-monitor` → `_updateLayout()`, once with `shrink-icons` →
  `_updateShrink()`). The second label was dead — JS takes the first match — so
  changing the icon size never triggered `_updateShrink()`. The dead label has been
  removed to keep behaviour identical and let lint pass; **whether `icon-size` should
  in fact call `_updateShrink()` is unverified** and needs testing on a real session.
