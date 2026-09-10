# Where the project stands

A snapshot for picking the work up fresh. Written 2026-09-10, after Phase 6b.

## What this is

`remappr-shell` — a configurable desktop shell for **KDE Plasma 6**, at
`~/Projects/remappr-shell`, pushed to `git@github.com:Wolffyx/remapprShell.git`
(private). Licensed GPL-3.0.

**The framing that decides every design question: this is not a Hyprland
alternative.** Plasma already has a notification daemon, an OSD, a lock screen,
a wallpaper engine, an overview and a task switcher. This shell's job is to
draw a good panel, *retheme* Plasma's own components, and *expose* Plasma's
settings — not to replace things that already work. Every replacement is opt-in
and never the default.

**Clean-room.** No code is taken from caelestia-dots-kde. It is referenced only
for lessons — which patterns to avoid.

## Working today

- **Panel** — Quickshell layer-shell, one per monitor, position/thickness from
  config, live reload with no restart.
- **Widgets** — launcher, workspaces (KWin virtual desktops), clock, tray
  (StatusNotifierItem), power (Plasma's logout prompt), show-desktop. Built-ins
  and third-party plugins share one manifest format and one code path.
- **Config** — layered defaults → profile → per-monitor → runtime. Sparse
  deltas. Live reload. Refuses to write over a file that does not parse.
- **Settings window** — schema-driven; every control is generated from a schema,
  including a third-party widget's own settings.
- **Launcher providers** — chosen at runtime, separately for the menu and for
  search: kickoff, krunner, builtin, fuzzel, rofi, custom.
- **Theme** — a Plasma Look-and-Feel package with our own OSD; appearance
  changes are opt-in behind `--appearance`.
- **Reversibility** — every KDE key we write is ledgered with its prior value.
  Restore points are never deleted automatically.
- **Plasma renderer** — `panel.renderer` selects what draws the panel:
  `quickshell`, `plasma`, `caelestia` or `none`. The Plasma panel containment is
  *generated* from `bar.entries`, so both renderers draw the same described
  panel. Two shell packages, one per renderer, so switching cannot overwrite the
  other one's layout. `rmpr renderer set` is plan → snapshot → apply → verify →
  rollback, and `--dry-run` prints the layout without writing anything.
- **Diagnostics** — `rmpr report` writes a local bundle (error + qmllint,
  environment, redacted config, journal tail + widget health). Written on unit
  failure via `OnFailure=` and when a widget is quarantined, through the same
  command. Redaction exists twice — `domain/diagnostics/Redact.qml` for the
  running shell, `scripts/lib/redact.sh` for the reporter that must work when
  the shell is dead — and both are held to `tests/fixtures/redact-cases.json`.
  Nothing is sent anywhere; no AI provider is wired up.
- **CLI** — `rmpr` with preflight, doctor, snapshot, restore, theme, renderer,
  report, edges, shortcuts, launcher, search, settings, preset, profile, update.
- **Tests** — 9 shell suites in throwaway HOMEs, plus a QML suite. All green.

## Not built yet

- **First-run wizard**.
- **AI assist and the notification ring buffer.** The report bundle and its
  redaction are built and tested, which was the precondition; the providers
  (`clipboard`, `claude-code`, `ollama`, `custom`), the consent dialog that
  shows the actual redacted bundle, and the `busctl --user monitor` eavesdrop
  are not. Verification step 6 — whether that eavesdrop is permitted for an
  unprivileged user on this dbus build — has not been run.
- **Active-window / task-list widget** — *blocked*: Quickshell 0.3.1's Wayland
  module exposes only session-lock types, so window state needs a KWin JS
  script feeding it out. Do not attempt it with a C++ KWin effect.

## Known problems

1. ~~**`plasmashellrc` names a shell package that does not exist.**~~ Resolved:
   `~/.local/share/plasma/shells/caelestia.desktop` is present again, and
   `rmpr doctor` now reports the package as fine. What it does report is that
   plasmashell still uses `caelestia.desktop` while `panel.renderer` says
   `quickshell` — `rmpr renderer set quickshell` is the switch that makes the
   two agree, and it is a live change to the desktop, so it has not been run.
2. **Typing into the built-in launcher only works after clicking it.**
   Quickshell 0.3.1 exposes no layer-shell keyboard-focus mode, so `focusable`
   means on-demand and Wayland grants the keyboard only once the surface is
   clicked. The panel forwards its keys to an open popout as a partial fix.
   Opened purely from IPC with no click anywhere, it cannot be typed into.
3. **caelestia is still running alongside**, holding Meta, and krohnkite is
   installed, which can fight edge tiling. Both are reported by `doctor`.

## The incident worth knowing about

An early `snapshot_restore` **deleted real files** from the user's home:
`~/.local/share/plasma/shells/caelestia.desktop/`, `look-and-feel/` and
`color-schemes/`. Three faults combined — the snapshot store lived inside a
directory that restores overwrite, the manifest was re-read from disk each
iteration so a missing file meant "delete everything", and restore deleted
anything not in the snapshot. All three are fixed, and the rules that came out
of it are now enforced rather than intended:

- Restore deletes only paths this project owns. Never KDE's.
- Captured directories are merged, not replaced.
- Snapshots are never deleted by any code path; a guard enforces it.
- **Destructive code is tested against a throwaway HOME, never a real one.**

That last one is the actual lesson. The harness existed *after* the damage; it
would have caught it.

## How to work on it

```bash
make link     # symlink into ~/.config/quickshell/<slug>; edits are live
make run      # foreground, against the working tree
make lint     # slug, layer and QML lints -- do NOT pipe it, see below
make test     # QML suite plus shell suites in throwaway HOMEs
rmpr doctor   # what is wrong with the installation right now
```

Non-obvious things that cost time to discover:

- **`/usr/bin/qmllint` is Qt5's** and exits 255 silently on Qt6 files. Use
  `/usr/lib/qt6/bin/qmllint`; `scripts/lint-qml.sh` resolves it.
- **Never pipe `make lint`** — `make lint | tail` reports tail's exit status, so
  a failing lint looks like a passing one. That is how a hardcoded slug got
  committed.
- **`FileView.watchChanges` reports a change but does not re-read**; call
  `reload()` in `onFileChanged`. It also only follows a path that already
  exists.
- **Required QML properties must be set at construction** — use
  `Loader.setSource(url, props)`, not `onLoaded`.
- **`Keys` attaches to an Item, never to a window.**
- **A comment whose first word is `qmllint` is parsed as a lint directive.**
- **`date +%s`-granularity directory names collide.** Two reports in the same
  second shared a directory and one overwrote the other; snapshots had the same
  latent bug. Both now count up a suffix.
- **Qt 6 refuses local-file `XMLHttpRequest`** unless `QML_XHR_ALLOW_FILE_READ=1`
  is set, and the failure surfaces as a JSON parse error rather than a
  permissions one. `scripts/test.sh` sets it.
- **A KConfig group name can contain a space** (`[PlasmaViews][Panel 811]`), so
  the ledger's group path is split on `/` and nothing else. Splitting on
  whitespace turned one group into two that KDE never reads.
- **A throwaway HOME is not a throwaway session bus.** `changeShell` over DBus
  reaches the real plasmashell no matter what `$HOME` says, so anything that
  touches the session is behind `REMAPPR_SHELL_NO_SESSION`, which the tests set.
- **KWin edge value `9` means `ElectricNone`** — an effect can look configured
  and do nothing.
- The project name lives only in `branding.json`; `scripts/lint-slug.sh` fails
  the build if it appears anywhere else.
- Layers: `core → platform → domain → ui → features`. A layer may import from
  below, never sideways or up; `scripts/lint-layers.sh` enforces it.

## The plan

`~/.claude/plans/in-this-project-i-cryptic-horizon.md` holds the full approved
plan, including the sections not yet built.

## What Phase 6b left for the next session

- The renderer switch is proven in a sandbox (`tests/test-renderer.sh`: 29
  checks, including the byte-identical revert and "never more than one panel"),
  but it has **not been run against the live desktop**. The plan's Phase 6b gate
  wants the round trip performed on the real machine, watching that exactly one
  panel is visible at each step and checking
  `qdbus6 org.kde.plasmashell /StrutManager` plus a maximised window's geometry
  for strut leaks.
- **No `plasma/plasmoids/org.remappr.*`.** Every built-in widget maps to a stock
  applet today, so nothing needed one yet. A widget with no stock equivalent is
  named in the compatibility matrix and left out of the panel.
- **Per-widget settings are not translated into applet settings.** The manifest
  can declare a static `renderers.plasma.config` block and that is written
  verbatim; our own values are deliberately not mapped, because a guessed
  mapping produces a panel that quietly disagrees with its configuration.
