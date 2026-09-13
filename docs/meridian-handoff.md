# Meridian: where the redesign stands

Written 2026-09-12, at the end of the session that finished it. Read this,
then `docs/handoff.md`, which now carries the redesign in its own section and
is the file the rest of the project is read from.

## The short version

The redesign is **done and committed**, thirteen commits on `meridian`,
**nothing pushed and nothing merged** -- the merge is the user's decision.
`make lint` clean, `make test` green (306 QML cases, every shell suite, the
lock screen loaded in Plasma's real greeter). **Nothing in it has ever been on
a screen**: every picture was rendered offscreen.

- Worktree `~/Projects/remappr-shell-meridian`, branch `meridian`, cut from
  `main` at `1a0b10c`. The main tree is untouched.
- 159 files, about 12,800 lines added.
- The user runs the shell by hand (`rmpr start` / `rmpr stop`); the unit is
  deliberately not enabled. Never suggest enabling it.
- No Claude attribution in commits.

## The task it answered

Implement the user's Claude Design mockup "Meridian Shell" as the shell's
look, with the same functionality the mockup has, in **Material Design
colours**, with **light and dark following the system**. Design source:
claude.ai/design project `eb385bb1-c8ae-4a81-b40b-c8403e30f5c4`, file
"Meridian Shell.dc.html", read with DesignSync (`get_file`). A local unescaped
copy is handy for grepping; the settings markup is around lines 227-605 and
the lock screen around 1438-1520.

## The commits

| commit | phase |
| --- | --- |
| `2ba2c82` | 1. Material colours, light and dark, following Plasma |
| `1e2bc4a` | 2. the panel: full, floating or islands, on every edge |
| `27cb96f` | 3. quick settings, the calendar, the notification centre |
| `19ffc64` | 4. the built-in start menu in three layouts, and search |
| `877c60b` | 5. the sidebar, the key sheet, the session screen, the OSD, toasts |
| `8323eac` | 6. the settings window, and five new pages |
| `85f465c` | 7. the lock screen |
| `f80456e` | 8. the rounded screen border and the desktop clock, opt-in |
| `8ef209a` | 9. Plasma's colour schemes from the same Material palette |
| `a781f25` | 10. `docs/handoff.md` updated |
| `f094923` | fix: a panel drawn on the defaults for one frame, then taken away |
| `a77f4b8` | docs: the missing panel, answered |
| `1eae99a` | fix: a shell started by `make run` counted as not running |

## What was found, and what it changed

Everything here was measured, not assumed, and each one changed what got
built:

1. **The greeter's settings are not the drawn package's.** kscreenlocker
   builds its `config` object from the **desktop** package's
   `lockscreen/config.xml`, whatever package it is drawing, so a key added to
   ours never appears. Its values live in kscreenlockerrc under
   **`[Greeter][LnF][General]`** -- the kcfg's own group nested inside the
   greeter's -- found by giving a throwaway HOME a config and asking the real
   greeter what it got. So Plasma's three lock settings stay Plasma's, and
   this shell's own live in `~/.config/<slug>/lockscreen.conf`, read by
   `Options.qml` (QtCore `Settings`, property `location`, not `fileName`).
2. **A lock screen package must be a verbatim copy of `theme/lockscreen`.**
   `try` records the hash of the copy it showed and `status` compares it with
   the source, so rendering a template into the package made `enable` refuse
   every build. Generated files go in the source tree instead:
   `Options.qml` is generated from `Options.qml.in` by
   `scripts/gen-branding.sh`, beside `Branding.qml`, and gitignored.
3. **Plasma 6.7.5 has no automatic light/dark theme switching.** Its day/night
   belongs to the wallpaper; there is no AutomaticLookAndFeel anywhere in the
   workspace here. So no light and dark look-and-feel packages were built --
   there is no switch to feed them -- and the schema no longer promises
   switching at sunset. What the shell does is follow the active colour
   scheme's darkness, live.
4. **`font.pixelSize` must be an integer.** A `12.5` refuses the whole file at
   load ("Invalid property assignment: int expected") and takes every page
   that imports it with it. qmllint passes it; the first offscreen render
   caught it.
5. **A Loader resizes what it loads.** A switch put straight into one is
   stretched across the control slot and reads as a bar. Wrap anything with a
   size of its own; let sliders and text fields fill it.
6. **quickshell does not act on `Qt.quit()`** -- it logs "no receivers
   connected" and keeps running. A script reading a value out of QML stops it
   with a timeout and reads a *file*: `timeout N quickshell ... | grep` waits
   out the whole timeout and then fails on it under `pipefail`.
7. **`lint-slug.sh` only sees tracked files.** A test with the project name
   hardcoded passed for as long as it was untracked and failed the build the
   moment it was committed.
8. **A preview of the settings window reads the installed schema.** `Schema`
   and `Paths` name `Branding.dataDir`; `preview.sh` repoints both at the
   worktree, and points `Branding.ctlBin` at a wrapper that runs this
   worktree's scripts, or a page that shells out runs the installed CLI.
9. **The panel appeared for one frame and vanished** (`f094923`). The defaults
   name this shell as what draws the panel, so a profile that hands the panel
   to Plasma got a panel at startup and lost it a frame later -- the log says
   "panel: up on DP-2" one line above "profile loaded".
   `ConfigStore.profileLoaded` gates it, and it means **applied**, not read:
   the first version set the flag at the top of the handler and an offscreen
   probe caught it promising a merged config one statement early.
10. **Every "is the shell running?" check missed `make run`** (`1eae99a`).
    They matched the installed config directory, and a working-tree run names
    the source tree instead, so `rmpr status` said "no" with a panel on
    screen and `renderer set` refused because it believed nothing would draw.
    `shell_running` / `shell_running_from` in `brand.sh` answer for both;
    `_shell_processes` exists so the suite can fake the process list.

## The user's own machine, at the end of the session

The panel was missing under `make run`, and it was not the redesign: the
profile said `panel.renderer: plasma` while plasmashell was on
`caelestia.desktop`, so nothing drew a panel. **The user ran `rmpr renderer
set quickshell`, and with `rmpr start` the panel is there.** Both fixes above
came out of chasing it.

## What is left

- **Everything needs eyes.** Nothing on this branch has been on a screen. See
  items 23 to 25 under "What to check first" in `docs/handoff.md`.
- **The lock screen needs `rmpr lockscreen try` again**: it is a different
  build from the one tried on 2026-09-11, so `status` says "changed since it
  was tried" and `enable` will refuse until it has unlocked once.
- **The merge is the user's.**

## Working on it

- `make brand` after adding files, `make docs` after schema or manifest
  changes, `make lint`, `make test` -- all in the worktree. Never pipe
  `make lint`.
- `scripts/gen-palette.sh` after changing `Scheme.qml`: it regenerates
  `theme/colors/palette.json` from the shell's own scheme and then the colour
  schemes. It needs quickshell and takes 15 seconds; it is not part of
  `make brand`.
- Offscreen previews, all untracked, under `dev/preview/`:
  - `preview.sh <target.qml> <out.png> [W] [H] [light|dark] [delayMs]`.
    Targets: `gallery`, `glyphs`, `panel`, `panel-side`, `appearance`,
    `popout` (`PREVIEW_WIDGET`, `PREVIEW_PAGE`, `PREVIEW_CONFIG`,
    `PREVIEW_RUNTIME`, `PREVIEW_NOTES`, `PREVIEW_STYLE`, `PREVIEW_PADDING`),
    `searchcard` (`PREVIEW_QUERY`), `overlays` (`PREVIEW_OVERLAY`:
    sidebar|keys|session|osd|osd-text|toasts), `settings` (`PREVIEW_PAGE`:
    a schema section id), `desktop`.
  - `lock.sh <out.png> [idle|prompt] [delayMs] [config-json]` runs Plasma's
    real greeter offscreen under a stand-in authenticator. The offscreen
    screen is 800x800, so the layout is drawn at its smaller scale.
  - `preview.sh` rewrites layer-shell windows into Items: `PanelWindow` has no
    offscreen backend.
- A QML property named `on` + a capital is read as a signal handler;
  `lint-qml.sh` refuses them. `scale`, `state`, `left` and `enabled` are
  QQuickItem's and shadowing them is an error or a warning.
