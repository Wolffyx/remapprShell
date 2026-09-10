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
- **First-run wizard** — four questions (panel position and thickness, layout
  preset, launcher provider, renderer), applied only on Finish. Shown when
  `$STATE_DIR/wizard-done` is absent; re-runnable with `rmpr wizard`. A preset
  replaces the profile, so it is applied first and the other answers written on
  top of it.
- **Theme layer** — Look-and-Feel package (OSD, splash), two generated colour
  schemes, an Alt+Tab window-switcher package and a colours-only desktop theme.
  All installed by `theme apply`, none selected without `--appearance`, all
  removed by `theme revert` with the user's own files in those directories left
  alone. One palette (`theme/colors/palette.json`) feeds the colour schemes and
  the desktop theme, so nothing can disagree about the accent colour.
- **On-screen display** — opt-in, off by default. `plasmashell` emits
  `osdProgress` and `osdText` on `org.kde.osdService` as plain DBus signals, so
  ours listens and draws rather than taking anything over. `rmpr theme osd
  ours|plasma` swaps the QML our L&F package supplies for a silent one, because
  with that package active there is no other way to avoid seeing two. Verified
  end to end against the real bus.
- **Diagnostics** — `rmpr report` writes a local bundle (error + qmllint,
  environment, redacted config, journal tail + widget health). Written on unit
  failure via `OnFailure=` and when a widget is quarantined, through the same
  command. Redaction exists twice — `domain/diagnostics/Redact.qml` for the
  running shell, `scripts/lib/redact.sh` for the reporter that must work when
  the shell is dead — and both are held to `tests/fixtures/redact-cases.json`.
  Nothing is sent anywhere; no AI provider is wired up.
- **CLI** — `rmpr` with preflight, doctor, snapshot, restore, theme, renderer,
  report, wizard, edges, shortcuts, launcher, search, settings, preset, profile, update.
- **Generated docs** — `docs/config.md` comes from the schema and the widget
  manifests; `make lint` fails when it is stale. A schema section carrying both
  `page` and `keys` renders as the page in the settings window while its keys
  still reach the reference, which is how `panel.renderer` is documented as the
  config key it is without becoming a text field in the GUI.
- **Tests** — 9 shell suites in throwaway HOMEs, plus a QML suite. All green.

## Not built yet

- **AI assist and the notification ring buffer.** The report bundle and its
  redaction are built and tested, which was the precondition; the providers
  (`clipboard`, `claude-code`, `ollama`, `custom`), the consent dialog that
  shows the actual redacted bundle, and the `busctl --user monitor` eavesdrop
  are not. Verification step 6 has now been run: `busctl --user monitor
  org.freedesktop.Notifications` starts and monitors without error as an
  unprivileged user on this dbus build, so Tier 1 is viable and the
  Plasma-notification-history fallback is not needed. The eavesdrop stays
  opt-in and off unless AI assist or notification history is enabled.
- **The lock screen.** Deliberately not shipped. The Look-and-Feel package can
  override `lockscreen/LockScreen.qml`, and a broken one means being unable to
  unlock — the worst failure this project could ship, and the only one that
  cannot be tested from inside the session it would break. Do it only with a
  second TTY open and a tested way back (`loginctl unlock-session` from
  Ctrl+Alt+F2, or `rmpr theme revert`), and gate it behind its own flag rather
  than folding it into `theme apply`.
- **Opt-in notifications.** Plasma owns `org.freedesktop.Notifications` and a
  second owner cannot have it, so this is a genuine takeover rather than the
  listen-and-draw the OSD turned out to be. Not attempted. The eavesdrop needed
  for a notification history is verified to work (above).
- **Open-window list** — built, and no longer blocked. KWin implements
  `org_kde_plasma_window_management` and not `zwlr_foreign_toplevel_manager_v1`,
  so Quickshell's `ToplevelManager` sees nothing here and
  `Quickshell.WindowManager` is virtual desktops rather than windows. The route
  is: a KWin JS script reads `workspace`, filters on KWin's own `skipTaskbar`,
  and pushes JSON to `bin/windowsd.py.in` — a small bus-activated daemon that
  exists solely because a KWin script can call DBus but cannot be called, and
  Quickshell cannot own a name. The shell follows the daemon's `Changed` signal
  with the same `busctl monitor` pattern as the OSD. Activation goes the other
  way entirely, straight to KWin's `/WindowsRunner` `Run()`, so nothing of ours
  is in that path and the daemon stays one-directional. `rmpr windows
  enable|disable|status|show`; opt-in, ledgered in `kwinrc [Plugins]`.
  Verified live: 11 windows listed, a window opening moved the shell to 12.

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
- **A QML module containing one Quickshell-dependent singleton cannot be
  imported by `qmltestrunner` at all**, which makes every pure function beside
  it untestable by association. `qs.domain.osd.events` exists as its own module
  for exactly that reason.
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

## The Phase 6b gate, run against the live desktop

Passed, on 2026-09-10, with one significant finding.

| step | shell package | Plasma panels | DP-2 available height |
| --- | --- | --- | --- |
| baseline | `caelestia.desktop` | 1 | 1386 of 1440 |
| `set quickshell` | `remappr-shell.desktop` | 0 | 1440 — strut released |
| `set plasma` | `remappr-shell-plasma.desktop` | 1 | 1398 — 42 reserved at the top |
| `set quickshell` | `remappr-shell.desktop` | 0 | 1440 |

Counted with `evaluateScript('print(panels().length)')` and
`StrutManager.availableScreenRect`, which is the maximised-window geometry.
Never more than one panel, no strut leaked, `bar.entries` unchanged across two
round trips, and both the stock and caelestia applet layouts byte-identical
afterwards. The generated panel came up with exactly the expected applets in
zone order, and `changeShell` switched live every time — plasmashell was never
restarted.

**The finding: plasmashell gutted the layout of the package being switched
away from.** Switching `ShellPackage` off `caelestia.desktop` left
`plasma-caelestia.desktop-appletsrc` with every containment gone — the panel
and both desktops it described, deleted, 4.8 KB down to 553 bytes. plasmashell
wrote its own now-empty view of that package's config on the way out. It is not
our write, but it happens because of our switch, so it is our problem: the file
was restored byte-identical from the restore point the switch had just taken,
and `appletsrc_hold` / `appletsrc_restore_if_gutted` now copy the outgoing
layout aside and put it back if it comes out with fewer containments than it
went in with. A layout that lost nothing is left alone, because restoring
unconditionally would undo a change made in the meantime.

**A second finding, reported by the user afterwards: the desktop was left with
no panel.** The gate ended on the `quickshell` renderer, whose shell package
ships no Plasma panel *because our shell draws it* -- and our shell was not
installed as a service on that machine, so nothing drew one. `rmpr renderer
revert` put the previous shell package back from the ledger. `renderer set
quickshell` now refuses unless the shell is running, installed or enabled,
naming the two renderers that draw without it; `--force` is there for someone
who means it.

That revert also left `[PlasmaViews][Panel 811]` behind in `plasmashellrc`:
plasmashell had added its own `floating` key to our panel view's group, and the
ledger can only put back keys we wrote. `kconfig_purge_group` removes a whole
group, and is only for groups named after an id we allocate -- nothing else can
own a key in one.

**Still unverified:** the outgoing-layout guard has not been exercised against
the live failure, only against its exact shape in the sandbox. Doing so means pointing
plasmashell back at `caelestia.desktop` and switching away again.

Two smaller things from the same run:

- The panel view's thickness now applies through the running plasmashell as
  well as the key, because plasmashell holds the geometry in memory — a key
  written alone did not appear until the next start. Waiting for `panels()` to
  be non-empty first is required: the wait must break only on a positive count,
  since an empty answer means plasmashell is still starting.
- The wallpaper is carried across a switch from whichever package was active.
  Without it, moving to a package that has never run hands the user Plasma's
  default wallpaper — a switch about the panel silently redecorating the
  desktop.
- **No `plasma/plasmoids/org.remappr.*`.** Every built-in widget maps to a stock
  applet today, so nothing needed one yet. A widget with no stock equivalent is
  named in the compatibility matrix and left out of the panel.
- **Per-widget settings are not translated into applet settings.** The manifest
  can declare a static `renderers.plasma.config` block and that is written
  verbatim; our own values are deliberately not mapped, because a guessed
  mapping produces a panel that quietly disagrees with its configuration.
