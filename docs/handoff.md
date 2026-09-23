# Where the project stands

A snapshot for picking the work up fresh. Written 2026-09-10, across two
sessions, and added to since -- most recently on the **morning of 2026-09-23**,
which was one bug in two halves: the desktop came up dark two hours after
sunrise while every name in `kdeglobals` said light and all three of this
project's checks agreed with the names -- and then, the colours mended, the
titlebars stayed dark anyway, because writing `kdeglobals` by hand is silent
and nothing in the session was ever told. Read "The morning of 2026-09-23"
first, both parts; the two lessons in it -- *a name in `kdeglobals` is a claim
about the desktop, not the desktop*, and *a write nobody is told about is a
write nobody acts on* -- outlive the bug. Before it, **2026-09-22, a long day in
two halves**. The morning was two shapes of fault: *something was written and
nobody was told*, and *something was installed and nothing could reach it*. It
also ended the queue's first item (shortcuts are in-process now) and found that
**a key can be pressed from inside a session after all**, which this file had
said four times it could not. The afternoon and evening **emptied the rest of
the queue** -- renderer discovery, the panel's binding loop, the restore-point
list -- and then **went over the settings window key by key**: every setting
the shell reads can be changed there now, and the controls that silently saved
the wrong thing were mended. It ended on **a notification that did nothing when
clicked**, which was a device notification with no action and a daemon as its
sender. Read "The session of 2026-09-22" first. Before it, the
**evening of 2026-09-16,
six things asked for after a day of using it, every one of them a case of the
shell being right and the place being wrong**: a screenshot key, a clipboard
menu that opens under the pointer with its pictures pickable, notifications
that open what they are about, a sidebar that follows a side, cards that fold,
and the weather. Before it, **2026-09-16 itself, a day spent almost entirely on
things that looked like this shell being broken and were something else writing
after us**: the panel, the shortcuts, the OSD, and
light-and-dark twice over. Before it, **2026-09-14, the first session run with
the user at the keyboard pressing the keys as they were bound**, which is why it fixed six things nobody could have found offscreen,
gave Alt+Tab back to KWin on the user's judgement, and built the desktop
overview the settings schema had been offering since the redesign.
The earlier sessions: the first built the Plasma renderer, diagnostics, the
wizard, the theme layer, the open-window list and panel auto-hide; the second
added AI assist, the notification history, crash reporting, and a tray you can
curate whose menus open. A third, on 2026-09-11, added volume, network,
Bluetooth and battery widgets -- and found that every popout had been opening
at the screen's left edge. A fourth, the same evening, built the lock screen --
the last part of the plan -- and found that Plasma 6 draws it from the shell
package, not the look-and-feel package this file had said. The redesign itself
was built across 2026-09-11 and 2026-09-12, entirely offscreen.

A fifth, on the evening of **2026-09-13**, did two things. It gave the global
shortcuts an owner, so a key this project binds is grabbed for the first time
in the project's life -- Alt+Tab now opens this shell's own switcher, confirmed
by the user pressing it. And it went over the popout system four times on the
user's report, fixing the placement, the layering, the closing and the radii,
and learning the hard way that `dev/preview` cannot show anything the
compositor does. It also found that **Spectacle will take a real screenshot
from inside a session here**, which changes what a session can check on its own
-- see "Looking at the real screen".

A sixth, late on **2026-09-13**, committed what the fifth had left in the tree
-- 48 files, as four commits -- and then drew the settings window in the
Meridian design. The design was read from the mockup itself rather than
inferred (`Meridian Shell.dc.html`, the settings markup around lines 227-605):
a page there is a grid of cards under small capitals, which five pages already
were and ten were not. It also fixed a widget row whose buttons were drawn
outside the window, which the user reported mid-session, and a lint that had
been failing since the popouts work landed. **None of it has been on a screen**:
every page was rendered offscreen and looked at, which is not the same thing.

A seventh, on **2026-09-14**, worked with the user in front of the screen.
It closed the two CLI papercuts and built the day-and-night desktop (item
26), then spent the rest of the session on the keys: binding them, watching
them fail, and fixing what failed. Alt+Tab is **KWin's own switcher in our
package** now, on the user's decision, after three fixes to ours and an
honest measurement of why it will not match KWin's -- and because that
decision finally put KWin's switcher on screen, it found why the box had
never appeared at all. Meta+Tab is **this shell's desktop overview**, built
from the design file's own Super+Tab view. See "The session of 2026-09-14".

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

## The redesign, merged

The Meridian redesign -- the user's Claude Design mockup implemented as this
shell's look, in Material Design colours -- **is `main`** as of 2026-09-13.
The seventeen commits were fast-forwarded onto `main`, which is how this
project's history is kept: there are no merge commits anywhere in it.

The worktree `~/Projects/remappr-shell-meridian` **has been removed**. Before
removing it, the fifteen untracked files that existed only there were copied
into this tree and verified byte-identical: `dev/preview/` (the offscreen
preview harness, which is how every picture of the redesign was made) and
`docs/meridian-handoff.md`. Both are still untracked here, as they were there.
The branch label `meridian` still exists, pointing inside `main`'s history.

What the redesign changed is under "The Meridian redesign" further down;
`docs/meridian-handoff.md` carries the detail of how it was built, and remains
accurate about that. It is **not** accurate about what is on a screen: it was
written before any of it had been seen.

## The state of this machine, right now

Updated **2026-09-22**. Everything below was read off the running system
rather than remembered; the rows marked *(2026-09-22)* were re-read that day
and the rest still say what 2026-09-16 found.

| | |
| --- | --- |
| Shell | *(2026-09-22)* installed via `make link` as `remappr-shell.service`, **enabled and active** -- it autostarts with the session, and has since 2026-09-15; the old rule to keep it disabled is gone. `rmpr status` says whether it runs from the installed copy or the working tree |
| plasmashell | on **`remappr-shell.desktop`** -- set again on **2026-09-16**, the key having still said `caelestia.desktop` at that session's start. That package ships a lock screen and fonts and **no `contents/layouts/`**, so plasmashell fell back to the stock template and built a Plasma panel of its own beside ours at every login. Ours refuses to: see the comment in the package's own layout js |
| Plasma services | notifications: **this shell serves them itself** (`notifications.server: shell`) -- it holds `org.freedesktop.Notifications` since the renderer switch of 2026-09-16 let plasmashell release it. Clipboard: Klipper is on the bus (plasmashell has a clipboard applet loaded), but **`clipboard.history` is `own`** since the evening of 2026-09-16, so Meta+V shows this shell's own history -- the one whose images can actually be chosen. Device notifier: hosted |
| Panel | bottom, **floating**, 52px, icons 18, spacing 5, rounding 8 -- the user's own settings, made through the settings window on 2026-09-13 once it started saving. Entries `launcher, tasks, notifications, tray, clock, showdesktop`. The status widgets are **not** in this profile (only in the defaults and presets); add them in Settings → Widgets |
| Tray | 8 items, nothing pinned, so every one is on the panel and there is no chevron. Curate it with `rmpr settings tray` |
| Notifications | `notifications.history` is on in the profile, so the eavesdrop runs; `ai.enabled` is off. Night Light is **on**, automatic, 4000K -- which is what `theme.mode: auto` now follows |
| Crash dumps | none. Five were written before the `image-data` fix, all with the same stack; they have been cleared |
| Theme | *(2026-09-23)* **Plasma switches light and dark, and we fill the gaps.** "Switch to Dark Mode at Night" (`kdeglobals [KDE] AutomaticLookAndFeel`) is **on**, pointed at our two packages, and is the user's to set -- `theme variant` writes nothing into kdeglobals while it is on and Plasma is keeping up, only GTK's theme and dark preference and our Plasma desktop theme. When Plasma's switch misses a sunset (it did, on 2026-09-22; see that night's entry) `theme.desktop.rescuePlasmaSwitch` writes the variant after twenty seconds' grace. When the switch fires and its *colours* do not follow (2026-09-23: every name light, every `[Colors:*]` group dark), `plasma_fill_colours` copies them in -- the name is checked and so is the value, because only the value is what applications draw. Every write to kdeglobals is **announced** on the bus (`org.kde.kconfig.notify.ConfigChanged`, `busctl` not `gdbus`, see that day's part two): without it KWin's decorations and the desktop portal keep the old colours, and Chrome, Electron and Claude Code with them. With it off, nothing switches unless `theme.desktop.followMode` says so (off by default; **on** in this user's profile, which is moot while Plasma's switch is on). In force: **`remappr-shell-light`**, GTK **adw-gtk3**. `remappr-shell-theme.service` is **enabled** and settles the variant at login before any application starts. `kde-material-you-colors` is disabled |
| Lock screen | **built, tried twice on a real screen, and still not on**: Plasma's draws. `rmpr lockscreen try` was run twice on 2026-09-13 and **unlocked with the user's real password both times** -- build `b80537960ca3deb1`, recorded, so `enable` will now be accepted. faillock empty after both. It has never been enabled: that wants a text console logged in and waiting (item 22) |
| Window list | KWin script loaded, daemon answering, 10 windows -- put back twice now, on 2026-09-15 after a restore and on **2026-09-22** after the caelestia uninstall unset the kwinrc key again. `rmpr windows enable` is the whole fix; `rmpr doctor` is the only thing that reports it. *(2026-09-22)* **The hover previews draw real windows for the first time**: the compiled `KWinScreencast` module had been installed and unreachable since the day it was built, because `~/.local/lib/qt6/qml` was not on the session's `QML2_IMPORT_PATH` |
| Also running | **nothing else, and caelestia is now fully out of the way**: autostart `Hidden=true`, its kglobalaccel component cleaned up, `kde-material-you-colors` (which its installer created) disabled. Its `kwin_workspace_tracker` KWin effect is the one piece left, retrying a socket every 2s. krohnkite is installed but **not loaded** |
| Branches | **`dev` is where work goes now**, `main` only moves on a release -- they are the channels `rmpr update --channel` follows. See docs/releasing.md. A session that commits to `main` out of habit is working against that |
| CI | **green, for the first time.** It had never passed: five causes, each hiding the next (see 2026-09-14 below). It now runs all six lints rather than three |
| Screen edges | KWin's own: nothing bound, snapping on. **Ours: none, deliberately** -- `sidebar.trigger` is `drag`, so the sidebar is pulled out by its own strip and `rmpr edges follow` gave KWin's edge back. Setting the trigger to `hover` binds the edge again, on the side `sidebar.position` names |
| Shortcuts | *(2026-09-22)* **All of them were `<unbound>` at the start of that session**: the caelestia uninstall wiped this project's entries out of `kglobalshortcutsrc`, and `rmpr doctor` reported it as "19 recorded key(s) are no longer set". Rebound to the project defaults and **grabbed**: Meta (menu), Meta+Space (search), Meta+Shift+R (settings), Meta+V (clipboard), Meta+S (sidebar), Meta+/ (keys). Taken back from plasmashell, krunner and plasmawindowed, all recorded, `rmpr shortcuts revert` gives them back. **Still unbound and the user's to choose**: `switcher`, `overview`, and the three screenshot actions -- Alt+Tab is KWin's here, and the screenshot keys went back to Spectacle with the rest. Since 2026-09-22 a press is handled **in this shell**, off kglobalaccel's own signal, not by spawning the CLI |
| `rmpr doctor` | *(2026-09-22)* no problems, 1 warning -- the recorded keys the caelestia uninstall took, which `revert` would still put back |

### Where the last session left off, and what to pick up

**2026-09-14 evening into 2026-09-15, 25 commits on `dev`. Still true, but
the sessions of 2026-09-16 and 2026-09-22 are below it and are newer -- read
2026-09-22 first.**

Work goes on `dev`, not `main`: the two are release channels and
docs/releasing.md is the whole of it. `main` moves on a release. Nothing is
half-written; `make lint` is clean (seven lints now) and `make test` is 376 QML
cases and 75 shell cases green.

**The one thing to understand before touching anything.** A configuration this
user had built over days was destroyed during the session, and it took an hour
to find out why. The cause was a chain, and every link is now fixed, but the
shape of it is worth carrying: restoring a snapshot old enough that its
manifest predates the configuration directory made the restore read that
absence as "we added this since" and delete `~/.config/<slug>` entire, every
profile in it; the state directory then went back to the snapshot's, which has
no `wizard-done`; the shell therefore decided it was a first run and showed the
wizard; and the wizard's finish wrote a fresh profile over what was left. One
click, from the settings window, no confirmation. `rmpr doctor` and the journal
told the story only because the kconfig ledger's mtime matched a snapshot's
name exactly.

What came out of that: the restore never removes the configuration directory
now; `preset apply` saves what it replaces as a *profile* (the old backup lived
in the state directory, which is what a restore rolls back -- the safety net
shared a fate with the thing it protected); `state.json` is written atomically,
because a redirect truncates and the shell reads a parse error as "stay on
`default`", which looks exactly like a reset; and restoring from the settings
window arms on the first click and goes on the second.

**Four faults of one shape.** A `Process` owned by a window a `LazyLoader`
destroys in the same turn never spawns, and reports nothing at all: no stderr,
no exit code, no error. It cost the panel menu's rows, the wizard's renderer
switch, and hours. If something "does nothing and says nothing", look there
first.

**Three faults of another shape**, all found by reading qmllint output rather
than trusting `make lint`: an undefined singleton (`WindowEvents` in both
switchers, `Log` in Surfaces.qml) is reported as `Unqualified access`, and
lint-qml.sh prints warnings and then logs "qml lint clean" regardless. Making
`[unqualified]` fatal for `shell/` is still open, and wants a cleanup pass
first -- there are five known false positives in Panel.qml (outer-scope ids in
a LazyLoader, no `ComponentBehavior: Bound`) and one in HeldModifiers.qml
(qmllint cannot resolve the compiled module).

**Alt+Tab and Meta+Tab are KWin's now, by the user's choice**, and the reason
generalises: this shell is not the compositor, so a held key's press and its
release each cross kglobalaccel, the session daemon, the CLI and the IPC, as
two detached processes that race. Both switchers got a real fix (a second QML
module, `ShellInput`, exposing `queryKeyboardModifiers`, so a release arriving
while the surface is up can be told from a Tab), and the choice now warns what
it costs. **The structural fix is named and unbuilt**: caelestia binds
shortcuts in-process, and this project already has the idiom for it --
`shell/core/BusLine.qml`, a `busctl monitor` process the window list already
uses. Pointing that at kglobalaccel would delete the whole class.

**The defaults now ship the setup that is in use**, and two files that both
declare defaults had drifted sixteen ways; `scripts/lint-defaults.sh` fails on
any disagreement, in `make lint` and in CI.

**What to pick up first, 2026-09-24.** Nothing is half-written; `make lint`,
`make test` and `rmpr doctor` are all clean, and `dev` is pushed.

1. **Meta+Space opens KRunner, not our search.** Reported by the user on
   2026-09-23 and confirmed: `kglobalshortcutsrc` has **both**
   `[remappr-shell] search=Meta+Space,none,Search` **and**
   `[services][org.kde.krunner.desktop] _launch=Search\tAlt+Space\tAlt+F2\tMeta+Space`.
   kglobalaccel gives a key to whoever registered last, and here that is
   KRunner. The ledger already records `[services/org.kde.krunner.desktop]
   _launch (was: Search\tAlt+Space\tAlt+F2\tMeta+Space)` -- so this project
   *did* take Meta+Space out of KRunner once, and the value on disk is the old
   one again. **The question to answer first is who put it back**: KRunner
   re-registering its default at login is the obvious suspect, and if that is
   it, taking the key once at `shortcuts set` is not enough -- it has to be
   taken again at every start, or KRunner's default has to be changed in a way
   it will not undo. Do not guess; watch `kglobalshortcutsrc` across a login.
2. **Sunset, watched.** Tonight's is the first real one since the theme work:
   Plasma's kded autoswitcher flips the package, `plasma_fill_colours` fills
   the colours in and announces them, and every layer should follow. The two
   failure modes are covered and `doctor` names either; nobody has seen kded
   do it on its own yet.
3. **Press the keys.** Bind `switcher` to a spare key (Alt+Tab is KWin's here
   by the user's choice) and hold it: that one press proves the held
   switcher's commit (queue item 1's leftover) *and* the quick-Alt+Tab fix
   (item 6). `rmpr switcher show` opens it from a terminal, with no modifier
   held, which is not the same test.
4. **The tray shows three of ten icons** because `widgets.tray.pinned` names
   three. Not a bug -- see the afternoon of 2026-09-23 -- but ask the user
   whether that is what they meant to set, because they reported it as
   "missing icons".

**Older, still open. Two of these want the user at the keyboard.**

1. **Press the keys.** Bind `switcher` to a spare key (Alt+Tab is KWin's here
   by the user's choice) and hold it: that one press proves the held
   switcher's commit (queue item 1's leftover) *and* the quick-Alt+Tab fix
   (item 6). `rmpr switcher show` opens it from a terminal, with no modifier
   held, which is not the same test.
2. **Plug a USB stick in and click the notification.** It should open Disks &
   Devices; only the history route has been tried from here.
3. **Ask the user about the other notifications** they said "do not work":
   which application, and what they expected. An application's own `default`
   action is invoked untested.
4. Then the settings window's remaining gaps, listed under "The settings
   window, gone over".

**Open, in the order they are worth doing:**

1. ~~**Shortcuts in-process**~~ -- **done 2026-09-22**, see that session.
   What is left of it is proving the held switcher's commit with a key
   bound to `switcher`.
2. ~~**"Drawn by" discovers nothing**~~ -- **built 2026-09-22**: every
   `<xdg config dir>/quickshell/<name>/shell.qml` other than ours is a renderer
   named `quickshell:<name>` (`scripts/lib/renderers.sh`), run under a new unit
   template `<slug>-renderer@<name>.service` that `renderer set` enables and
   switching away disables. A profile still saying `caelestia` reads as
   `quickshell:caelestia`. The settings page takes its list from `renderer list
   --json`; `doctor` reports a chosen one that is gone or not running. **Tested
   in the sandbox only** -- no second Quickshell shell is installed here, so no
   real switch to one has been made.
3. ~~**caelestia is still running beside this shell**~~ -- **moot since
   2026-09-22**: the user uninstalled it. This shell serves notifications
   itself, and the sidebar is pulled by its own strip (`sidebar.trigger:
   drag`). What is left is the screen edges it wiped, which are the user's to
   rebind -- `rmpr edges status`.
4. ~~**A binding loop**~~ -- **fixed 2026-09-22**. It fired at panel start on a
   crowded bar (ten times on 2026-09-16) and reproduces offscreen:
   `dev/preview/panel.qml` at 900px wide. Each zone's room is now worked out
   once, in `PanelSurface.rooms`, from the zones' *fixed* lengths: a widget
   that sets `givesWay` (the task list) counts as nothing, every other widget
   at its own size. So no room reads another room. While everything fits, the
   spare space goes to whatever gives way; when it does not, the middle gives
   way first, then the right end from its inner side, then the left. **One
   visible change**: on an overfull bar the task list now shrinks before the
   tray is cut, where before the tray was cut to make room for tasks.
5. ~~Snapshot names cramped on a narrow window~~ -- **fixed 2026-09-22**: the
   label is the title ("Before renderer quickshell") and the time is the
   second line, said as a person would ("Today, 09:05", "9 Sep, 20:05"), from
   `qs.domain.settings.snapshots`, tested in `tst_Snapshots.qml`.
6. **Found 2026-09-22, fixed, unproven on a screen**: a quick Alt+Tab
   committed from the switcher's `Component.onCompleted`, emptying the
   Variants model it was being created from -- a binding loop on `model` in
   the journal. Both switchers commit a turn later now. Proven by the same
   key press as item 1's leftover.

### Icons missing from the panel until a restart (2026-09-23, afternoon)

The user's own words named it: *"the taskbar/panel does not have all the icons
... it has some caching or something. If I reset the shell I think the icons
will be displayed, but I do not want to do that every time."* The restart was
doing nothing but forgetting, and forgetting was the fix.

**`WindowIcons.path_for` cached a miss for the life of the daemon.** For an
application whose icon is not in the theme, the daemon reads `_NET_WM_ICON`
off the X11 window and caches the PNG it writes. The cache was careful about a
stale *path* -- a restored snapshot takes the file out from under it, which is
a fault this file already records -- and careless about a stale *answer*:

    if app_id in self._cache:
        cached = self._cache[app_id]
        if cached is None or os.path.exists(cached):
            return cached        # `None` returned for ever

`_NET_WM_ICON` is set by the toolkit a little *after* the window is mapped,
and Electron, Proton and the JVM are all late. A window asked the instant it
appears has no icon yet, the `None` was kept, and that application had no icon
until the daemon was restarted.

A miss is now kept for **three seconds and six attempts** and then looked at
again -- bounded, because one lookup is an `xprop` sweep of every window on
the display and there is an update per window change, which is the cost the
cache exists to avoid. A window with no icon after twenty seconds has none.
Seven checks in `tests/test-windows.sh` cover it, including that a real miss
gives up and that a path whose file went away is still re-read.

**The window daemon is started by the bus, not by the shell's unit**, and that
cost most of the afternoon. `systemctl --user restart remappr-shell.service`
leaves it exactly where it was -- on this machine it had been up since
09:03:46 through three shell restarts -- so a fix to `windowsd.py` lands on
disk and never runs, and the symptom is a fix that "does nothing". It is
`share/dbus/windows.service.in` that starts it, and that is right: the KWin
script has to be able to reach the daemon before the shell exists. So:

* `rmpr windows restart` kills it and calls it back. There is no unit to stop.
  The `List` it makes afterwards is what starts it again -- without that, the
  daemon returns only at the next window change and the task list is empty
  until then.
* `doctor` compares the running process against the file it was installed
  from and says so when they differ, because nothing else will.

**A Steam game's icon comes from Steam now.** `steam_app_1407200` (World of
Tanks) drew a grey rectangle because that is genuinely what its window
publishes as `_NET_WM_ICON` -- under Proton, a window with no icon gets the
Windows default and the cache stored it faithfully. Steam has had the real one
all along, in `appcache/librarycache/<appid>/`, where the artwork is named for
what it is (`library_hero.jpg`, `logo.png`, `header.jpg`) and **the icon is
the one file named for its hash** -- forty hex characters, 32x32. That is the
only rule that tells the icon from the cover art, and it is what
`WindowIcons._steam_icon` matches. Flatpak Steam and `~/.steam/root` are
looked at too. It is asked on every call rather than under the retry budget:
it is two filesystem calls, and an icon Steam writes after a game first runs
is then picked up without waiting.

**Two things found in the same sweep that are not bugs**, worth knowing before
either is "fixed" again:

- **Seven of ten tray icons sit behind the chevron** because
  `widgets.tray.pinned` names exactly three (`Claude_status_icon_1`,
  `discord_status_icon_1`, `ZapZap`), written through the settings window on
  2026-09-22 at 18:18. An empty `pinned` means everything; a non-empty one
  means *only* those. `TrayLayout.split` says so in its own comments, the
  settings page reads the same function, and `tray list` over IPC shows all
  ten items present. Settings -> Tray icons is where it changes.
- **The WoT window's icon really is a grey rectangle.** `steam_app_1407200`
  publishes a generic window pixmap as its `_NET_WM_ICON`, and the cache
  stored what it was given, faithfully. Nothing to fix in this shell; giving
  Steam applications their library icon would be new work, not a repair.

Useful while chasing this: `quickshell -c remappr-shell ipc call panel layout
<screen>` gives every widget's box, and `... ipc call tray list` gives the tray
the shell actually holds, which is how "the items are there and the icons are
not" was told apart from "the items are gone" without a screenshot.

### The morning of 2026-09-23: a light desktop wearing dark colours

**The user reported it the way it looked: "I started the pc a few minutes ago
and the kde theme is dark instead of light."** It was 09:22, two hours after
sunrise, and Dolphin was dark. Nothing in the configuration was wrong, and
nothing this project checks said so:

| what was asked | what it said |
| --- | --- |
| `kdeglobals [KDE] LookAndFeelPackage` | `remappr-shell.lookandfeel` -- light |
| `kdeglobals [General] ColorScheme` | `remappr-shell-light` -- light |
| GTK preference and theme | `prefer-light`, `adw-gtk3` -- light |
| `rmpr doctor`, whole section | every line `ok` |
| `kdeglobals [Colors:Window] BackgroundNormal` | **`30,31,37`** -- the dark scheme's |

**Every name said light and every colour was dark.** Selecting a colour scheme
is two writes, not one: the scheme's *name* under `[General]`, and a copy of
its `[Colors:*]` and `[WM]` groups beside it. The name is a label -- what
System Settings shows and what resolves to a file. The copy is what every Qt
and KDE application actually reads, and what the portal answers Chrome and
every Electron application with. `colors_apply_scheme` has said so in a comment
since 2026-09-16. Three separate checks still asked only the name.

**The fault was ours, and it was the fix of the night before.** That night's
work taught `theme variant` to stop assuming Plasma had switched, and it now
reads `LookAndFeelPackage` before agreeing. That is still right -- and it is
still only half the question. `plasma_agrees` was set from the name alone, and
`scheme_agrees` was set from `plasma_agrees`, so the colours check two lines
above it (`colours_agree`, which was *already computed correctly*) was thrown
away whenever Plasma owned the switch. The login unit ran at 09:03:54, read
the name, agreed, and filled in GTK and the desktop theme around a kdeglobals
it never looked inside. The shell's own path, at 09:03:57, logged *"the
desktop is already in light"* for the same reason.

**What changed.** `plasma_agrees` is `plasma_named` now, and it is honestly
named: it answers about the package's name and nothing else. `scheme_agrees`
takes the colours into account as well. After `plasma_rescue` -- whether it
waited, wrote, or was never called -- `plasma_fill_colours` reads the colours
again and copies the variant's in when they are the other half's. It respects
`theme.desktop.colours`, and it stands aside for kde-material-you-colors,
whose colours are deliberately not ours. The comparison itself is
`colours_match`, one function where the check was inline, and the window
background is the whole test: it is the one colour the two variants can never
share. `doctor` says it outright now --

    fail  kdeglobals names 'remappr-shell-light' and holds another scheme's colours
          'remappr-shell-light' paints windows 236,237,245; kdeglobals says 30,31,37

-- and its neighbouring `ok` was reworded to `Plasma's switch names the right
half for the hour`, because naming is all it was ever checking.

Seven checks in `tests/test-theme.sh` set the trap and prove the repair,
including that it is not repeated once done and that `theme.desktop.colours:
false` still means hands off.

**Who wrote the half-done state is not known.** `kded6` started at 09:03:47
and `kdeglobals` was last written at 09:03:46, so the autoswitcher did not do
it this morning -- the desktop was already in that state when the machine came
up, and it survived the reboot. The likeliest account: the user was in System
Settings at 23:16 the night before, and its Global Theme page applies a theme
through a checklist of parts. A global theme applied with **Colors unticked**
writes the name and leaves the values. That is a guess, and it is written here
as one.

**The lesson generalises past this bug, and is the reason the fix is shaped
the way it is:** any writer can leave `kdeglobals` half-applied, and a name in
it is a claim about the desktop, not the desktop. Check the value.

#### The same morning, part two: written and nobody told

The user came back with the part the first fix did not reach: *"the topbar of
Dolphin was still dark... claude code still seems to detect some dark theme
somewhere. Please check all the places."* So all the places were checked, on
the running desktop, with a probe window and `dbus-monitor`.

**The colours were right and nothing had been told.** KDE's own tools write
`kdeglobals` through KConfig with its `Notify` flag, which puts a
`ConfigChanged` signal on the bus; every `KConfigWatcher` in the session is
listening. This project writes the file by hand -- `kdeglobals-colors.py`, for
the good reason that a scheme is a hundred keys and the per-key ledger would
mean a hundred rewrites twice a day -- and a write by hand is **silent**.

Measured, not guessed. A `kdialog` window was opened and the dark scheme's
colours were written the way this project writes them:

| | before | after a silent write |
| --- | --- | --- |
| window background | light | **dark** |
| titlebar | light | **light** |

The contents followed and the decoration did not, because the older
`org.kde.KGlobalSettings notifyChange` this project already sent reaches an
application's palette and **KWin's decoration palette is a `KConfigWatcher`**,
which heard nothing. The same silence is why `xdg-desktop-portal-kde` -- which
is what answers Chrome, every Electron application and Claude Code -- kept
saying `color-scheme: 1` after a switch to light.

The signal was read off the bus from a real `kwriteconfig6 --notify` rather
than remembered:

    path      /kdeglobals
    interface org.kde.kconfig.notify
    member    ConfigChanged
    signature a{saay}     -- {group: [key, ...]}, the keys as byte arrays

`notify` in the helper sends it, and `colors_apply_scheme` calls it. **It is
sent with `busctl`, not `gdbus`**: `gdbus emit` writes a GVariant bytestring,
which is nul-terminated, so `ColorScheme\0` would match nothing on the other
side. `busctl` takes the bytes as numbers.

**Two more places the colours were not reaching.**

- **`[ColorEffects:Disabled]` and `[ColorEffects:Inactive]`** are as much a
  part of a colour scheme as `[Colors:*]`, and the helper had never copied
  them: a light desktop greyed its disabled text with whatever grey the last
  scheme left. They are governed now.
- **`plasma_fill_colours`, written four hours earlier, wrote the colours and
  not the name** -- the same fault upside down, and `doctor` caught it on this
  machine within the hour. It writes both.

**Widening what a scheme governs broke the one promise this project makes
about other people's configuration**, and the fix for that is worth reading
before touching the set again. A backup written under the old set has no
record of `[ColorEffects:*]`, so a `revert` would take those groups away and
put nothing back. The first attempt -- "save anything governed now that the
backup does not mention" -- is wrong, and the test caught it: by the second
apply the groups in `kdeglobals` are **ours**, and the backup would have
handed a revert the very scheme it exists to undo. So the backup records
`governs`, what "governed" meant when it was written, and only groups outside
*that* set are added. The live backup on this machine was stamped by hand
after the fix; its Colors and WM blocks are still the user's own, in hex, from
2026-09-15.

**What the audit found in order, and where each is written:**

| where the variant has to reach | how | state |
| --- | --- | --- |
| `kdeglobals [Colors:*]`, `[WM]` | copied by `colors_apply_scheme` | was already right |
| `kdeglobals [ColorEffects:*]` | same copy | **added 2026-09-23** |
| `kdeglobals [General] ColorScheme` | `apply_defaults`, or `plasma_fill_colours` | **fixed 2026-09-23** |
| `kdeglobals [KDE] LookAndFeelPackage` | Plasma's switch, or `plasma_rescue` | fixed that morning |
| `kdeglobals [Icons] Theme` | the package Plasma applies | checked by `doctor` now |
| KWin's window decorations | `[WM]` + **the ConfigChanged signal** | **fixed 2026-09-23** |
| xdg-desktop-portal-kde -> Chrome, Electron, Claude Code | kdeglobals + the signal | **fixed 2026-09-23** |
| xdg-desktop-portal-gtk -> the same applications | gsettings `color-scheme` | was already right |
| GTK 3 and GTK 4 `settings.ini`, `gtk-theme` | `gtk_apply_variant` | was already right |
| Plasma's own widgets | `install_desktoptheme` | right from the next plasmashell start, as before |
| this shell | reads kdeglobals itself | was already right |
| GTK 3 and GTK 4 `gtk.css` | **nobody's -- and it beats all of the above** | named by `doctor` 2026-09-23 |

#### Who else can change the colours, swept

The user's next question was the right one -- *"find all the places the theme
might be changed, and maybe delete them so the app is forced to use the
default"* -- and the sweep that answered it is worth keeping, because
"delete them" is right for one of the three kinds it found and wrong for the
other two.

**Generated, and follows.** Deleting these gains nothing: they are rewritten
at the next switch, and until then the desktop is missing a bridge.
`gtk-{3,4}.0/settings.ini` (ours), `gtk-{3,4}.0/colors.css` and the three GTK 2
`gtkrc` files (kde-gtk-config), `Trolltech.conf` (Plasma), `kdeglobals` (ours),
`kdedefaults/*` (Plasma).

**Static, and pins a colour.** The dangerous kind, and the reason the sweep
exists. Exactly one existed -- `gtk.css` -- and it cost a morning.

**Dead leftovers**, with no unit, no autostart and the software uninstalled:
`~/.config/caelestia` (36K), `~/.local/state/caelestia` (60K),
`~/.local/share/caelestia` (16K), `~/.config/kde-material-you-colors`,
`~/.cache/wal`, and `gtk-{3,4}.0/thunar.css` (Thunar is not installed; its
rules are all scoped `.thunar ...`, so it paints nothing here). None of these
was doing anything once `gtk.css` was clean. Removing them is tidiness, not a
fix -- and `~/.config/caelestia/stolen-shortcuts.json` and
`stolen-screen-edges.json` are caelestia's record of the KDE shortcuts and
screen edges it took, which is worth keeping until the user is sure they do
not want them back.

So: **not deletion -- detection.** `doctor` sweeps for the dangerous kind now,
and each check was proven by planting the fault and watching it fire:

| planted | what doctor said |
| --- | --- |
| `@define-color card_bg_color` in `gtk.css` | `gtk-4.0/gtk.css paints every GTK window itself: card_bg_color #101014` |
| the same, in a file `gtk.css` imports | `gtk-3.0/probe-palette.css sets the palette itself: view_bg_color #0a0a0a` |
| `GTK_THEME=Adwaita:dark` in the session | `GTK_THEME=Adwaita:dark is set for the whole session` |
| `--force-dark-mode` in a `*-flags.conf` | `probe-flags.conf forces dark mode on the command line` |
| `kdedefaults` naming another scheme | `kdedefaults/kdeglobals still falls back to ...` |

The palette names it looks for are in `GTK_PALETTE_NAMES` in `doctor.sh`:
`window_bg_color`, `view_bg_color`, `headerbar_bg_color` and the rest that
libadwaita and Adwaita actually paint with. The `*_breeze` names
kde-gtk-config generates are deliberately not among them, which is why
`colors.css` is safe and `gtk.css` was not.

**And the sweep turned up something about `kdeglobals` itself.** There are two
of them. `~/.config/kdeglobals` is the user's; `~/.config/kdedefaults/kdeglobals`
is written by Plasma when a global theme is applied and read *beneath* it. On
this machine the user's file has **no `ColorScheme` key at all** -- Plasma took
it out when it applied our package, and the name the whole desktop uses comes
from `kdedefaults`. `kreadconfig6 --file kdeglobals` cascades, so every read in
this project already gets the effective answer; that is why nothing broke. It
also means `plasma_fill_colours` writes the name only when the *effective* name
is wrong, so it cannot pin a name above Plasma's own layer -- which it would
otherwise do, twice a day, for ever.

**Two applications stayed dark through all of it, and neither was ours.** The
user found them and both are worth writing down, because both look exactly
like this shell failing.

- **Mission Center**, set to "system", dark on a light desktop. Not the
  system: `libadwaita` on this machine answers `dark = False`, the portal
  answers `color-scheme: 2`, `gsettings` answers `prefer-light`. The cause is
  `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css`, which carry
  `@define-color window_bg_color #131317` and a dozen more like it. **GTK loads
  that file last and an `@define-color` in it beats the theme, the preference,
  the portal and us.** A GTK 4 window here resolves `window_bg_color` to
  `#131317` while libadwaita's dark flag reads `false` -- the application is
  not in dark mode, it is *painted* dark, which is why nothing that asks about
  dark mode can see it. Neither file is this project's: we write
  `settings.ini` and nothing else. They are a caelestia leftover (they end
  `@import "thunar.css"; @import 'colors.css';` and carry a Material You
  accent, `#c2c1ff`). `doctor` names them now, with the one-line fix:
  `sed -i '/^@define-color /d' ~/.config/gtk-4.0/gtk.css`, which keeps the
  `@import` lines kde-gtk-config manages.

  Worth noticing in passing: `colors.css` beside it was **regenerated at the
  moment of a variant switch for the first time**, by kde-gtk-config, which is
  a `KConfigWatcher` and had never been told. The notification fixed that too.

- **Claude Desktop**, also set to "system", dark under a system in light *and*
  a system in dark -- captured both ways, the window identical. Electron 44,
  `--ozone-platform=wayland`, no dark flag on the command line, nothing in
  `Preferences`, `userThemeMode: system` in its own config. Chromium computes
  its dark preference partly from the GTK colours it resolves, so the same
  `gtk.css` was the cause here too, **confirmed**. The user's own description
  is what identified it: switching the desktop made the window *flash light and
  snap back to dark*. That is not a message that failed to arrive -- it is
  Electron's boot placeholder drawing from the fresh system value, and then the
  renderer painting from Chromium's `prefers-color-scheme`, which on Linux is
  derived from the GTK colours the process resolved **at start**. That process
  had started at 10:34:50; `gtk.css` was mended at 10:47:22, and GTK does not
  re-read it for a process already running. The bus was watched across a whole
  dark-to-light switch to rule out a second writer, and there is none: one
  `ConfigChanged`, one `SettingChanged`, and the session settles. After a
  restart the same window followed `rmpr theme variant dark` and back, live,
  with no restart in between.

Proven on the running desktop afterwards: the same window's titlebar followed
`rmpr theme variant dark`, and the portal's `color-scheme` moved with it. One
thing that does **not** follow and is not ours: a `kdialog --textbox`'s text
view keeps its palette until the window is reopened, which is a Qt widget
holding an explicit palette, not a message that failed to arrive.

### Seven lock screens, and the picker (2026-09-22, late)

**One commit (`b857fcb`).** The design file's two turns of lock screen
directions were built -- `Meridian Lock Options.dc.html`, read through the
design MCP rather than guessed at. Six new ones beside the glass one this
project shipped: **editorial split, console, ambient, widget board, poster,
multi-user**. `rmpr lockscreen set style <name>` picks one; the Lock page
lists all seven as rows carrying the sentence that tells them apart.

**`LockUi.qml` is a frame now and draws no layout at all.** It keeps what must
exist once and must not vary -- the wallpaper and its blur, waking, Plasma's
on-screen keyboard and the StackView it moves, the shake, the OSD, the
`keepShown` binding -- and loads a *style*. A style hands back the `LockPrompt`
it built and the block the keyboard must not cover; an unknown name falls back
to glass rather than to an empty screen. The shared parts are files of their
own: `LockPrompt`, `LockClock`, `LockFace`, `LockMessage`, `LockActions`,
`LockStatus`. **How a password is taken is in one of them**, so it is taken the
same way in all seven -- a style that reimplemented it would be a second
implementation of the only part of this project that can lock somebody out.

Two things worth carrying:

- **A style's `ui` must be a required property set at creation.** A `source`
  binding on the Loader plus `item.ui = ui` in `onLoaded` is a frame too late
  and the greeter refuses the file: *"Required property ui was not
  initialized"*. `setSource(url, {"ui": ui})` is the way.
- **Plasma's own controls take their colours from Kirigami, not from us.** The
  frame asks for `Complementary` (light on dark), which is right for five of
  the seven and invisible on the two that draw dark type on a light ground --
  the battery and the field's reveal button were white on white in the ambient
  render. `LockPrompt` and `LockStatus` set `Kirigami.Theme.textColor` from
  the style's ink.

**Three panels in the designs are not drawn** -- weather, the next calendar
entry, notifications. The greeter is a separate process with no session, no
forecast and no notification history. Where a design had one, these draw what
the greeter does know (the screen, the account, what PAM will accept) or
nothing at all.

**`dev/preview/lock.sh` takes a size now, and defaults to 1920x1080.** Qt's
offscreen platform invents an **800x800** screen, so every picture this
harness had ever taken was a picture of the fallback scaling rather than of
the design. The plugin takes a screen configuration file; `LOCKSCREEN_PLATFORM`
carries it through `lockscreen_offscreen`, which still refuses anything but
offscreen.

**All seven load in the real greeter and all seven were rendered and looked
at.** None has been on a real screen: `rmpr lockscreen try` is still the gate,
and the lock screen is still off (`enabled: no`).

### The night of 2026-09-22, after the handoff was written

**One commit on `dev` (`0588f48`), and one thing that was not ours at all.**

**The desktop stayed light behind a dark shell.** The shell turned dark at
sunset and every application, and System Settings itself, stayed in
`remappr-shell-light`. Nothing in the configuration was wrong:
`AutomaticLookAndFeel` was on, `DefaultLightLookAndFeel` and
`DefaultDarkLookAndFeel` named our two packages, and the autoswitcher's own
schedule had today's sunset at **19:13 -> 19:42**. `kdeglobals` was last
written at **18:34**. Plasma's switch simply never fired.

Why: `kded6` had been running since **09:56**, and a Frameworks upgrade at
**10:56** (`kservice 6.29.0 -> 6.30.0`, among others) replaced **130** of the
libraries mapped into it. Unloading and reloading the module by hand applied
dark instantly, so the module is fine -- its timer was not. Worth knowing:

    qdbus6 org.kde.kded6 /kded unloadModule lookandfeelautoswitcher
    qdbus6 org.kde.kded6 /kded loadModule lookandfeelautoswitcher

**Our part in it.** `theme variant` hard-coded `scheme_agrees=1` whenever
Plasma was the one switching, on the reasoning that whether Plasma had caught
up was Plasma's business and asking would make us race its write. The
reasoning is still right; the conclusion was too strong. It reads
`LookAndFeelPackage` now, and on a mismatch waits **twenty seconds** for
Plasma before writing the variant itself, `LookAndFeelPackage` included so the
next start does not rescue all over again. `theme.desktop.rescuePlasmaSwitch`
turns it off, on by default, in the settings window beside the switch it
covers. `doctor` says so outright when the desktop is in the wrong half for
the hour, because nothing in the configuration is wrong when it happens.
`night_light_daylight` moved to `kwin.sh`, which doctor already sourced.

**The whole DE crashed, and it was not the shell.** `kwin_wayland` SIGSEGV at
21:53, its stack ending in `/usr/lib/libKF6Service.so.6.29.0 (deleted)`;
Xwayland SIGABRT at 21:48. Same cause as the missed sunset: a full system
upgrade at 10:57-11:04 replaced the libraries under a running session.
Separately, `amdgpu: GPU reset succeeded` at 20:50, which is where the
`GL_CONTEXT_LOST` storm before the crash came from. **The remedy for the first
is a reboot after updating; the GPU reset is driver or hardware and wants
watching.** Before blaming this shell for a session-wide crash, check
`grep -c deleted /proc/<pid>/maps` on the process that died.

### The session of 2026-09-22

**Seven commits, pushed to `dev` (`90104a2..5e0a3fa`).** The session began with
the user reporting "after a new bootup Claude Code and the topbars of the
windows are dark" and ended with the queue's first item built. Almost
everything in between was one of two shapes: *something was written and nobody
was told*, or *something was installed and nothing could reach it*.

**The thing worth carrying: a key can be pressed from inside a session.** This
file has said four times that it cannot -- no ydotool, no wtype, no xdotool --
and it was wrong. kglobalaccel's own component object takes `invokeShortcut`:

    busctl --user call org.kde.kglobalaccel /component/<slug with _ for -> \
        org.kde.kglobalaccel.Component invokeShortcut s "launcher"

That is a real press: kglobalaccel emits `globalShortcutPressed` exactly as it
would for the key, and everything downstream cannot tell the difference. The
launcher was opened this way and photographed. It only works for an action
kglobalaccel has registered, which is every action this project binds. A
release cannot be injected that way -- `invokeShortcut` emits the press alone.

**Shortcuts are in-process. Queue item 1 is done.** `ShortcutWatch.qml` reads
`globalShortcutPressed` off the bus with the `BusLine` idiom, and the press and
its release now arrive on one connection in order, so neither can overtake the
other -- which was the whole switcher race. The daemon still registers the keys
and still owns the component, because a key is only grabbed while its component
has a running owner; it no longer *runs* anything for what the shell takes
(`SHELL_ACTIONS` in `bin/windowsd.py.in` names the QML, which names it back).
Left on the old route deliberately: `clipboard` and `sidebar`, which open where
the pointer is and so need a KWin script for the answer; `ask`, which builds a
redacted report before any window opens; the screenshot keys, the only ones
worth anything with no shell running. Measured: zero `remappr-shell-ctl`
processes across three presses, where there had been two per press.

**Still unproven there**: the held switcher and overview commit. The code is
unchanged and only its caller moved, but Alt+Tab is KWin's on this machine and
our `switcher` action is unbound, so `HeldModifiers.held()` has no real
modifier to read. Binding a key to it is the whole check.

#### Light and dark: Plasma switches, we fill the gaps

The user's instruction, in their words: *"the activated 'switch to dark mode at
night' should remain how the user set it and we only should set the necessary
places to make it work... we should only have some kind of watcher or trigger
that uses the KDE switch."* So when `AutomaticLookAndFeel` is on and names our
two packages, Plasma swaps the whole global theme and `theme variant` writes
nothing into kdeglobals -- it fills only what a look-and-feel package cannot
carry: GTK's theme and dark preference, which live in gsettings, and our Plasma
desktop theme, whose colours are generated per variant. With the switch off,
nothing switches unless `theme.desktop.followMode` says so, which is off by
default. Asked and answered by the user: a setting, off by default, and Plasma
wins whenever its own switch is on. Proved by forcing gsettings to
`prefer-dark`, running the trigger, and diffing kdeglobals: empty.

**Four faults behind "dark did not go away", all fixed:**

- **The eight-second window at login.** kdeglobals keeps what the last switch
  wrote, so a machine shut down at night boots dark, and the shell corrected it
  *eight seconds* into the session -- after quickshell, the profile and Night
  Light had all answered. Everything XDG autostart brings up, session restore
  included, starts inside that window and reads the desktop's colours **once**;
  an Electron application asks the portal at startup and never asks again, so
  it spent the whole day dark. `remappr-shell-theme.service` is a oneshot
  ordered `Before=xdg-desktop-autostart.target` that settles it in ~0.14s
  before anything starts. `setup.sh` enables it beside the shell; `doctor`
  reports it.
- **`theme apply` wrote the colours and told nobody.** Only `theme variant`
  sent the palette notification, so an apply left every open window -- KWin's
  titlebars included -- on the colours it read at startup, until somebody
  clicked a scheme in System Settings, which sends that same signal. That is
  what "I still have the dark topbar" was, twice.
- **`resolve_variant` answered dark before Night Light had answered**, which on
  the login path is most of the time. Dark is the one guess that cannot be
  taken back: written out, it reads back as the desktop's own darkness and auto
  latches on its own answer. It waits now, then falls back to whatever the
  desktop is already wearing.
- **The light scheme's tooltip was unreadable.** `theme/colors/dump.qml` used
  `inverseSurface` for the light tooltip while its text stayed `onSurface` --
  Material pairs inverseSurface with *inverseOnSurface*, and KDE's
  `[Colors:Tooltip]` takes its foreground from the one every other group uses.
  Near-black on near-black, which is what the dark folder tooltip on a light
  Dolphin was. Both variants use `surfaceContainerHighest` now. **Regenerate
  with `scripts/gen-palette.sh`, not `gen-colors.sh`**: `palette.json` is the
  cached intermediate and `gen-colors.sh` alone reads it rather than the QML.

#### Installed is not the same as reachable

**The window previews had never worked, and the message said why in a way that
sent you the wrong direction.** The shell logged "the KWinScreencast module is
not installed (build it with `make plugin`)" -- and `make plugin` reported every
file already up to date, in `~/.local/lib/qt6/qml/KWinScreencast/`. The session
launcher put the shell's own config root on `QML2_IMPORT_PATH` and nothing
else, so the compiled module was unreachable from the day it was first built.
caelestia's launcher had added that path explicitly; ours never did. One line
in `bin/session.sh.in`. `doctor` now checks the shell can *import* it, not only
that the library exists, so built-but-unreachable cannot go on impersonating
never-built.

**Then the previews flooded the journal with `invalid image
"EGL_BAD_PARAMETER"`.** Not frame drops: imports of a node that did not exist.
`WindowStream.nodeId` is `-1` while there is no stream, because that is how QML
asks whether there is one; kpipewire's `nodeId` is **unsigned**, so binding the
two handed it 4294967295 on every teardown and it connected to that. Every
warning in a capture was preceded by `created successfully 4294967295`, and no
stream with a real node id produced one. Hovering a row of taskbar buttons is a
preview opening and closing per button: 250 streams in four minutes, 135 to a
node that did not exist, 38 failed imports. Afterwards, none.

#### A volume property that changes is not a volume that changed

The user saw the volume OSD appear while hovering the taskbar, showing the
level it was already at. `AudioStatus.volume` reads through the default sink,
and when that node goes out from under it the value falls to zero and comes
back -- two changes, the second of which draws a pill nobody asked for.
PipeWire's graph churns exactly that way while previews are drawn: 120 "no
global any more" errors in three minutes of hovering. The level is remembered
now and a repeat of it is not an event; a sink that has gone is not one either;
a sink that has been *replaced* records where it stands without announcing it.
Measured after: 154 preview frames, 16 of those errors, no OSD -- and volume
keys still draw it.

**Note for anyone testing the OSD**: `_show` logs at `Log.debug`, which is
gated behind `Log.debugEnabled`. Three captures looked like "the OSD never
fired" when it had fired every time. `rmpr ipc shell debug on` turns it on
without a restart.

#### The taskbar preview, redesigned

The popout drew two different cards. One window put the picture first, the
application's name under it and the title under that; two or more put a header
on top with a grid beneath -- so the same application read top-to-bottom in two
orders depending on how many windows it had, and opening a second one reordered
and *shrank* the first (300x169 became 176x99). An application titled after
itself said its own name twice in a row.

One card now: the header says what the application is, once, at the top, and
every window is a cell below it -- one window is a grid of one, at the same
size. A cell says *where* the window is rather than repeating what it is
called, and says nothing at all when there is nothing to add. Every cell has a
resting surface; transparent ones left each picture floating with its close
cross beside it in open space.

The popout moved out of the 700-line widget into
`shell/widgets/tasks/TaskPreview.qml`, which is what lets
**`dev/preview/taskpreview.qml`** render it offscreen at each window count in
both themes. Both faults above were found by looking at that render, not by
reading the code. Offscreen there is no screencast, so every card falls back to
its icon -- the scene is for layout and captions.

#### What the caelestia uninstall took with it

The user uninstalled caelestia mid-session, and it wiped configuration this
project owns. `rmpr doctor` said so plainly -- **"19 recorded key(s) are no
longer set"** -- and that is the check to run after anything uninstalls
anything. Gone and restored: the `remappr-shell-windows` KWin script's kwinrc
key (so the taskbar had no window list and no hover previews), and **every one
of this shell's global shortcuts**. Rebound to the project defaults: launcher
Meta, search Meta+Space, settings Meta+Shift+R, clipboard Meta+V, sidebar
Meta+S, keys Meta+/.

**Still unset, deliberately, because they are the user's to choose**: every
screen edge (the ledger only records that they were unset *before* us, so what
they had is not knowable), and the three screenshot actions. `rmpr edges
status` lists the edges.

#### The settings window, gone over (late 2026-09-22)

Audited key by key -- every `ConfigStore.value`, `widgetConfig?.x` and
`config_get` against the schema and the pages -- and three kinds of fault
fixed, in `a55fd73`, `8aab52f` and `1875136`:

- **Controls that wrote the wrong thing.** A `list` key fell through to a text
  field and saved a *string*: `sidebar.cards` then threw on `.map`, and the
  tray's and the task list's pins were corrupted when saved from the Widgets
  page. A list with `values` is a set of switches keeping the person's order;
  one without is typed (`format: "words"` for a command, commas otherwise).
  The clock's 12-hour and seconds switches did nothing, because the shipped
  defaults set `format: "HH:mm"`, which wins; defaults and three presets no
  longer pin one, and the Taskbar page says when a format of your own holds
  the switches.
- **Keys read and not settable**: `launcher.command`, `launcher.kickoffMode`,
  `ai.command`, `snapshots.keep`, `theme.desktop.gtk`, `gtkThemeLight/Dark`
  (a dropdown of installed themes, from `theme status --json`),
  `theme.desktop.materialYou`, and `update.channel/remote/localSource` (new in
  the schema, on About, with a check -- never an apply). "Custom" launcher and
  AI providers could only be picked once their command was set, which nothing
  could set. `update.sh` read `profiles/default` alone; it reads the active
  profile now.
- **The window itself**: sections carry a `group` (Look, Behaviour, System) and
  the nav draws headings, tighter rows, and scrolls to the current page;
  dropdowns show labels (`labels` on an enum, and `Select.labels`); the Widgets
  and Tray buttons are glyphs -- as theme icons they were blank.

**`snapshot create` took a flag as a label** (`89b34bf`): `--label X` made a
restore point called `--label`, which is where the one in this machine's list
came from. It takes `--label X` and `--label=X` now and refuses an unknown
flag. The label is also part of a directory name and went in unchecked -- a
slash made directories inside the snapshot root and `..` one outside it -- so
slashes become dashes, and dashes, dots and spaces are trimmed off the front.
Ten cases in `tests/test-snapshot.sh`.

**Per monitor** the Taskbar page now sets position, thickness, style, icon
size and hiding, with "Use the shared settings" to drop them (setting a key
back to the shared value removes the override). **Still not in the window**:
per-screen spacing, reveal-on-hover and `bar.entries`, which `PanelModel`
honours, and per-instance `bar.entries[].config`.

**Notification clicks** (`9f39640`): "USB Device Detected" is kded's, with no
actions and `org.kde.kded6` as its sender, so a click started a second kded.
`Popups.targetFor` now maps `x-kde-eventId: deviceAdded` to Disks & Devices
(the device notifier's tray item, `activate()`), a display to kcm_kscreen, and
never starts a service as an application; popups and history share it.
`rmpr ipc notifications open <n>` says what it did. **Proven through the
history route only** -- a real plug, clicking the popup, is the check. The desktop-theming switches on
Appearance still act only on the next Apply, as designed, without saying so.

#### Two mistakes this session made

**The shell was down for about two minutes.** A new method named
`_audioChanged` collided with the auto-generated change signal of the `_audio`
property beside it. qmllint passed it; the QML runtime refused to load
`OsdService` and took `OsdOverlay` and the whole panel with it. **qmllint does
not catch this class** -- a `function xChanged()` next to a `property ... x` is
a load-time error, not a lint one. Restart the shell and check `rmpr status`
after any singleton edit, before moving on to test something else.

**A commit was made on a failing lint.** `make lint` was grepped for two
specific lines, both of which passed, while the slug lint was erroring on a
hardcoded project name in a new test. Grep the exit status, not the output:
`make lint >/dev/null 2>&1; echo $?`. The commit was amended before the push,
so the history is clean, but only because it was caught a step later.

### The session of 2026-09-16, evening

**Six things the user asked for after a day of using it, and every one of them
was the same shape: the shell was right and the *place* was wrong.** A
screenshot key nothing held, a clipboard menu that opened against the panel
instead of under the pointer, notifications that closed on a click rather than
opening what they were about, a sidebar pinned to one edge. Nothing here was a
rewrite; all of it was asking where the user is looking.

**The screenshot key.** `screenshot`, `screenshot-screen` and
`screenshot-window` are shell actions now (`scripts/screenshot.sh`), and
Meta+Shift+S is bound to the first. The script is a *chooser*, not a
screenshotter: Spectacle when it is installed, because that is the selector, the
save location and the notification a KDE user already knows, and grim+slurp when
it is not -- saving under the pictures directory, copying to the clipboard and
posting a notification that carries the file. `rmpr screenshot status` says
which it would use.

**And the bug that made the last session's key silently do nothing** is fixed
with it: `accel_keycode` and the daemon's `keycode()` knew `Slash` but not
`/`, which is how kglobalshortcutsrc actually spells it, so
`shortcuts set keys "Meta+/"` wrote a binding kglobalaccel could not be told
about and reported success. Punctuation is in both tables now, and
`shortcuts set` refuses a key it cannot convert instead of writing it.

**A click on a notification opens what it is about.** The spec's `default`
action first, as before; then the file the notification named (`x-kde-urls`),
opened the way the desktop opens files; then the application that sent it
(`desktop-entry`), raised if it has a window and started if it does not --
`WindowsService.open`. The popups and the history rows both do it. The server
now asks for the hints that carry all this: without `extraHints` they were
dropped before the popup was built, which is why a click had nothing to act on.

**A screenshot notification shows the screenshot.** Spectacle sends no image at
all -- only `x-kde-urls` with the path it saved to, which was read off the bus
rather than guessed -- so the card loads that file itself, bounded to 760x400,
and only when it is a local file whose name ends in an image type.
Photographed working.

**The clipboard opens under the pointer, and its images can be chosen.** Two
separate faults.

Wayland tells a client where the pointer is only while it is over that client's
own surface, so a shell cannot ask at all. KWin can: `rmpr clipboard` loads a
one-shot KWin script -- the idiom `windows close` already used -- which reads
`workspace.cursorPos` and calls the daemon's new `/Pointer`, which emits a
signal the shell listens for. `ClipboardOverlay` is the menu: full-screen and
transparent so a click anywhere else puts it away, with the card placed by
`Place.atPointer`, which flips at an edge and is tested because nobody can
check that by hand. `rmpr ipc surfaces clipboardAt <x> <y> <output>` is the
same route without a pointer, which is how it was checked.

Images: Klipper's DBus hands out text and nothing else, so an image in *its*
history can be seen and never picked -- and Klipper is running here, because
plasmashell has a clipboard applet. So `clipboard.history` is a setting
(`own`, `auto`, `plasma`) and **ours is the default**: a second watcher takes
`image/png` off the clipboard into `~/.local/state/remappr-shell/clipboard`,
the menu draws thumbnails, and choosing one copies the file back. Files are
deleted as their entries fall off the end of the history (`clipboardOrphans`,
pure and tested) and the lot goes when it is cleared. Both histories can exist
at once: neither writes to the other.

**The sidebar follows a setting now.** `sidebar.position` (left or right),
`sidebar.width`, `sidebar.margin`, `sidebar.cards`, `sidebar.expanded` -- and
**`sidebar.reserveSpace`, off**, which is the margin down one side of the
screen the user was seeing: an exclusive zone moved every maximised window
aside for as long as the sidebar was up. The surface follows the side in its
anchor, its margins and the direction it slides in from. The screen edge
follows too: `rmpr edges follow` moves a bound sidebar edge to the side the
sidebar is on, and `SidebarEdge` calls it when the setting changes -- and does
nothing at all when no edge is bound to the sidebar, because an edge is the
user's to give.

**Every card in the sidebar folds**, and which are open is a setting rather
than a property, so a sidebar opened tomorrow looks the way this one was left.
`Cards` is the pure part (order, toggling, which edge); the cards are media,
day, weather, machine and notifications.

**The weather, which is the first thing in this shell to talk to the
internet.** `weather.enabled` is off by default and the whole of it is
`Forecast` (pure: WMO codes, URLs, parsing parallel arrays into records) plus
`WeatherStatus` (curl, a timer, a cache in the state directory). Open-Meteo:
no account, no key. A place you name is geocoded once; coordinates you type are
used as they are and nothing is looked up; only with neither set is the IP
address used -- one call, cached, and the setting that avoids it is one line of
text away. There is a panel widget (absent from the panel while the weather is
off), a sidebar card with the next twelve hours and five days, and **the
forecast on the calendar**: `MonthGrid` -- extracted from the clock's popout so
the sidebar and the calendar draw the same month -- puts each day's glyph under
its number, and choosing a day says what it will do. Bucharest, 24 °C, fetched
and cached on this machine.

**Then the user used it for twenty minutes and found four more**, which is what
a session with somebody at the keyboard is for.

**The clipboard menu drew its rows outside its own card.** The card was capped
at 520 pixels and never clipped, so everything past the cap was painted over
whatever was on the screen under it. It clips and scrolls now.

**The notification centre could not be clicked, and showed no picture.** Two
faults with one cause -- the work stopped at the popups. The row was a bare
`Column`, so a click beside the text landed on nothing; it is an `Item` with a
hover tint and a real hit area now, in both the grouped and the stream views.
And the picture a notification names is drawn in the centre as it is in the
popup: `NotificationEvents.pictureOf`, pure and tested, the same rule as
`Popups.pictureOf`. `rmpr ipc notifications open <index>` does what a click
does, which is how the opening half was checked without a pointer.

**The sidebar is pulled out, not hovered into.** KWin's screen edge answers a
pointer that merely reaches the edge -- a scrollbar at the right of the screen
opened the sidebar all day. `SidebarHandle` is a strip at the sidebar's own
edge, `sidebar.handleWidth` wide (6 px), one per screen, that has to be pressed
and pulled 28 px inwards. `sidebar.trigger` chooses: `drag` (the default),
`hover` (KWin's edge, bound and moved by `rmpr edges follow`), or `none`.
Choosing anything but `hover` gives KWin's edge back, so the two can never both
be live.

**And it opens on the screen it was asked for on.** A handle belongs to one
output, so a drag on the second monitor opens the sidebar there. The keyboard
route was the same bug as the clipboard's -- `rmpr sidebar` opened on
`screens[0]` -- and it now takes the same one-shot KWin script: `pointer
sidebar` reads `workspace.cursorPos` and the sidebar comes out of the screen
the pointer is on. Photographed: the sidebar on the pointer's monitor, cards
folding, Bucharest at 24 °C in the weather card.

**And one more, found by looking at System Settings.** kdeglobals named the
colour scheme `Remappr Shell Dark` while the file installed is
`remappr-shell-dark.colors`. KDE resolves a scheme by the base name of its
file and never by the name it shows -- `BreezeDark.colors` carries
`Name=Breeze Dark` and `ColorScheme=BreezeDark` -- so System Settings said
the scheme was not installed and offered the default in its place. The
colours still reached most of the desktop, because they are copied into
kdeglobals as well, so the fault looked like "dark reached some places and
not others" rather than like a name. `gen-colors.sh` writes the id and the
display name separately now, the look-and-feel defaults write the id, and
`doctor` fails on a scheme kdeglobals names that no file is called.

**And the one underneath both of those, found in System Settings' Global Theme
page.** Plasma 6 has a day/night switch of its own -- "Switch to Dark Mode at
Night", `kdeglobals [KDE] AutomaticLookAndFeel` -- which applies a whole
*global theme* at sunset. It was on, and nothing of ours was named as its two
halves, so at sunset it applied `org.kde.breezedark.desktop`: our
look-and-feel package, colour scheme, icons and decorations replaced in one
write. The desktop was then half ours and half Breeze Dark, which is what
"dark did not reach everywhere" actually was.

The answer, on the user's choice, is to be the pair rather than to fight it.
There are two packages now -- light and dark -- each carrying only its own
variant's `defaults` lines (a file with both ends with whichever comes last,
which is why applying ours from the Global Theme page had always given light),
and `DefaultLightLookAndFeel` / `DefaultDarkLookAndFeel` name them. Plasma
keeps its toggle and its schedule; what it switches between is ours.

Two things measured rather than assumed, both on Plasma 6.7:
`plasma-apply-lookandfeel` writes every line of a package's defaults **except**
the colour scheme unless the package carries a `contents/colors` of its own --
so each package ships its scheme inside it, and both halves were then applied
end to end and read back. And `--apply` turns the automatic mode off unless
`-k` is passed, which is worth knowing before running it on somebody's desktop.

`doctor` fails when the switch is on and does not name ours, and says what
sunset will do about it.

**Open, in order. The first four are work the user has already said yes to**
-- asked as "what next?", answered "I want all of them" -- so they are a
queue rather than a menu. The rest are what the evening left behind.

1. ~~**Shortcuts in-process.**~~ **Done on 2026-09-22**, exactly as described
   here: a `BusLine` monitor on kglobalaccel's `globalShortcutPressed`. The one
   thing left of it is proving the held switcher's commit, which needs a key
   bound to `switcher` -- see that session.
2. **Polish what landed on 2026-09-16.** Named by the user, in their words:
   the sidebar has no keyboard navigation; the clipboard menu has no search or
   filter; the weather has no per-widget place (one place for the machine); the
   sidebar handle does not follow the drag -- it opens at a threshold rather
   than sliding out under the pointer.
3. **Renderer discovery.** "Drawn by" has `RENDERERS=(quickshell plasma
   caelestia none)` hardcoded and detects caelestia by a hardcoded unit name.
   Discovery is the easy half -- every Quickshell config is a directory in
   `~/.config/quickshell/`; `renderer set` then having to start and stop an
   arbitrary discovered shell is the substantial one.
4. **Housekeeping.** caelestia's `kwin_workspace_tracker` KWin effect is still
   retrying a dead socket every 2 seconds (`kwriteconfig6 --file kwinrc --group
   Plugins --key kwin_workspace_trackerEnabled false`). The binding loop at
   `ZoneRow.qml:27` via `PanelSurface.qml:187` -- the left and right zones'
   `implicitWidth` depend on each other through the middle; a warning only, and
   fixing it is a zone-budget redesign. And making qmllint's `[unqualified]`
   fatal for `shell/`, which wants a cleanup pass first: five known false
   positives in Panel.qml (outer-scope ids in a LazyLoader, no
   `ComponentBehavior: Bound`) and one in HeldModifiers.qml.

5. **Press the keys, and pull the strip.** Meta+Shift+S and Meta+V are bound
   and the sidebar's handle is drawn on both screens; the drag itself has been
   seen on a screen and never performed.
6. **Watch one sunrise.** Plasma's day/night switch now names our two
   packages, and both halves were applied by hand through Plasma's own path and
   read back. What has not happened yet is the switch firing on its own.
7. A fullscreen game sat above every layer surface on that monitor for the
   whole session, which is why the sidebar and the popups were photographed
   only on the other screen. Worth knowing before concluding a surface is
   missing.
8. The weather card in the sidebar has been photographed; the panel widget has
   not, and is not on the panel -- Settings -> Widgets adds it.

### The session of 2026-09-16

**Read this first.** A whole day at the keyboard with the user, and almost all
of it was the same shape: a thing that looked like this shell being broken,
which measurement showed was something else writing after us. Nothing was
committed; the tree is 44 files across four sessions' work.

**The one lesson.** Four separate faults this session had the same cause --
*another process is the last writer, and our setting reads correct while the
desktop disagrees*. Every one was invisible until a journal or a bus monitor
was read, and every one looked exactly like our own bug. When a setting reads
right and the screen is wrong, find out who wrote last before changing
anything of ours.

**The panel doubling.** `plasmashellrc [Shell] ShellPackage` was still
`caelestia.desktop`. That package has no `contents/layouts/`, so plasmashell
fell back to the stock template and built a full Plasma panel beside ours at
every login. `rmpr renderer set quickshell` fixed it, and as a side effect
plasmashell released `org.freedesktop.Notifications` -- this shell serves them
itself now, which closed the open item that had been waiting for exactly that.

**Global shortcuts, and a trap worth carrying.** `kglobalshortcutsrc` edits
made with `kwriteconfig6` **are silently reverted**: on Plasma 6.7 kglobalaccel
lives inside kwin_wayland, holds every `[services]` entry in memory and writes
the lot back over the file. `scripts/shortcuts.sh` says so in its own header
and it still cost an hour. Bind through `accel_bind` + `accel_reload`
(`scripts/lib/accel.sh`), which pushes live -- never by writing the file.
Spectacle's `_launch` (Print) and `RectangularRegionScreenShot`
(Meta+Shift+Print) are bound that way now. caelestia's component held 32 keys
while not running; `Component.cleanUp` on `/component/caelestia_shell` dropped
it from kglobalaccel **and** removed the group from the file. KWin's
`Switch to Desktop 1..4`, which caelestia's installer had nulled, were restored
from the konsave profile its own installer made
(`~/.config/konsave/profiles/caelestia-preinstall/`). Ours gained
`sidebar=Meta+B`, `keys=Meta+Slash`, `settings=Meta+Shift+R`.
**Known bug, unfixed:** `rmpr shortcuts set keys "Meta+/"` reports success for
a key `accel_keycode` cannot convert, and binds nothing.

**The OSD, which never worked and now does.** plasmashell emits **no**
`osdProgress`/`osdText` at all on this desktop -- the method call arrives, no
signal follows. Bisected against Plasma's own stock OSD QML, so it is not ours;
`OSDEnabled` exists in no binary in /usr and is a dead key. Our OSD was a pure
listener on those signals, so it was silent wherever Plasma's was: "ours" was
parasitic on Plasma's. It is driven by our own sources now -- `AudioStatus`
(PipeWire) and `BrightnessStatus` (powerdevil's `org.kde.ScreenBrightness`) --
with the bus listener kept for what we do not read. The Meridian OSD surface
already existed from redesign phase 5 and had never been on a screen; it is
what draws. Volume, mute, microphone and brightness all photographed working.

**Caps Lock and Num Lock.** Nothing on this desktop announces a lock key: over
90 seconds of pressing them, `org.kde.osdService` carried not one message.
caelestia's answer -- read for the lesson, no code taken -- is
**`KModifierKeyInfo`** from KGuiAddons, which on Wayland binds KWin's own
`org_kde_kwin_keystate` global (advertised here at version 5). Global rather
than per-surface, so keyboard focus does not matter, and it reports changes
rather than being polled. `plugin/src/lockkeys.{h,cpp}` wraps it as a
`LockKeys` singleton in the existing `ShellInput` module;
`shell/platform/input/LockState.qml` reaches it through a `Loader` so a machine
without `make plugin` loses only this. **Caps Lock photographed working; Num
Lock is built and was never pressed.**

**Light and dark, which was two bugs on top of each other.**
`kde-material-you-colors` -- a service caelestia's `10-autostart.sh` installed
-- ran with `light = False` and applied `MaterialYouDark` at every login. It
was the last writer, so `theme.mode: auto` read *its* answer and correctly said
dark. Underneath that, `Theme.mode` resolved `auto` against
`PlasmaColors.background`'s deliberately-dark fallback **before** kdeglobals was
read, so every start answered dark for a moment; with
`theme.desktop.followMode` on, that answer could be written to the desktop and
read back as the desktop's own darkness -- a latch, not a flash. `auto` now
gives no answer until `PlasmaColors.loaded` or `NightLight.known`, holding
light meanwhile because only that guess is safe to write. Separately,
`scripts/theme.sh` never touched `gtk-theme-name` at all: a GTK theme whose
*name* is the dark half of its pair (Nordic, adw-gtk3-dark) ignores
`color-scheme` and `gtk-application-prefer-dark-theme` and stays dark in every
mode. Three new keys: `theme.desktop.gtkThemeLight`, `.gtkThemeDark`,
`.materialYou`. Names, never guessed -- adw-gtk3's light half drops "-dark",
Nordic's is called Nordic-Polar.

**Screen edges, this shell's own.** Open item 3 is built. `kwin/edges/` is a
second KWin script -- separate from the window list, whose header says it is a
read -- that calls `registerScreenEdge` and pushes to `/Edges` on the daemon,
which runs the action detached because the callback is inside the compositor.
Bindings are rendered into the script rather than read from a KConfigXT file,
and live in kwinrc under the script's own group so the ledger and
`edges revert` cover them. The action list is read out of the daemon's
`SHORTCUT_ACTIONS`, so an edge can do anything a key can. `rmpr edges shell
Left sidebar` is live. The daemon half is proven end to end; **the pointer half
has never been tried**, and the sidebar draws on the *right*, so `Right` may be
the better edge.

**`rmpr doctor` gained a "light and dark" section** that names a competing
colour-scheme writer -- the thing that took a journal read to find. It also had
a real bug: three checks read `profiles/default/shell.json` while the active
profile is `recovered-appearance`, so the renderer, window-list and OSD checks
were reading a file the shell is not using. Line 138 of that same file already
carried the comment explaining why not to.

**Open, in the order they are worth doing:**

1. **Commit.** 44 files, four sessions. Today's work splits cleanly: renderer
   + notifications / shortcuts + spectacle + caelestia release / OSD sources +
   lock keys / theme light-and-dark / screen edges / doctor. The launcher,
   installer and ranking work from earlier sessions is a separate pile.
2. **Try the left edge with a pointer**, and decide `Left` vs `Right`.
3. **Press Num Lock once** -- built, never fired.
4. `rmpr shortcuts set` reporting success for an unconvertible key.
5. caelestia's `kwin_workspace_tracker` effect, still retrying a dead socket
   every 2 seconds: `kwriteconfig6 --file kwinrc --group Plugins --key
   kwin_workspace_trackerEnabled false`.
6. Shortcuts in-process per `BusLine` -- still the structural fix for the
   switcher race, and still unbuilt.

### The session of 2026-09-15, evening

Two things: the keys this shell wanted were finally taken, and the install
became one command.

**Meta and Meta+Space are ours now.** They were `<unbound>` at the start of
this session -- caelestia held both, under one action of its own -- so nothing
this project binds was pressed. `shortcuts set launcher Meta` and
`shortcuts set search Meta+Space` took them, kglobalaccel answers with our
component for both (checked with `accel_holders`, not read off the file), and
the session daemon re-registered them without a logout. The ledger has
caelestia's old value, so `rmpr shortcuts revert` hands them back.

**caelestia still autostarts**, which is the open question here: if its shell
re-registers its own launcher shortcut at login, the two race for Meta every
boot and whoever registers last wins. Nothing was measured -- it wants a
reboot. `rmpr shortcuts status` after the next login is the whole check.

**Alt+Tab was left exactly as it was**, on the user's decision restated this
session: KWin walks the windows, drawing our `remappr-shell` switcher package
(`kwinrc [TabBox] LayoutName`), which is persistent config and needs nothing
at boot. Meta+Tab is still KWin's Overview.

**The guided install exists**: `make setup`, or `rmpr setup`.

`scripts/lib/dialog.sh` is one API over four front ends -- kdialog in a
graphical session, whiptail (or dialog) in a terminal, numbered prompts when
there is neither, and `none` when nobody is attached, which is what makes
`--unattended` need no second code path. The front end is forced with
`REMAPPR_SHELL_UI`, which is how the tests drive it. Cancel is not "no": a
dismissed question returns 2 and the setup stops, because somebody who presses
Escape on "which renderer?" has not chosen the first one.

`scripts/setup.sh` asks every install-time choice first, shows the plan, and
applies it on one answer -- the wizard's shape, for the wizard's reason. Each
step shells out to the script that owns it (`install.sh`, `renderer set`,
`theme apply`, `shortcuts set`, `switcher use`), so the guided path cannot
drift from the manual one. A restore point is taken before the first change;
`--dry-run` prints the commands and writes nothing. The defaults are the setup
in use here: copy, quickshell renderer, Meta and Meta+Space, Alt+Tab left with
KWin, theme applied, unit enabled.

`tests/test-setup.sh` is 40 cases -- every front end's defaults and parsing,
the plan for each answer, and that a no at the summary runs nothing. It stubs
kdialog and unsets the session's own `WAYLAND_DISPLAY`, without which every
detection case answers kdialog on a developer's machine. `test-ctl` gained two
cases for the new command. `make lint` clean, `make test` 381 QML cases and
every shell suite green.

`make link` was run afterwards, so the installed CLI has `setup` in it.

**Then the search was rebuilt, on the user's report that its results read like
KRunner's "not in a bad way but not in a best way either".** They were right,
and the reason was structural: both eat the same corpus (XDG desktop entries),
and ours ranked it in five buckets with ties broken alphabetically, so the
order was independent of what anybody had ever run. Four things came out of
it, each of them found by the user pressing keys and saying what came back.

`shell/domain/launcher/apps/Rank.qml` is the scoring, pure and tested: nine
classes a thousand apart (exact, prefix, word prefix, acronym, substring,
exec, generic, keyword, subsequence), two bonuses that sum to less than the
gap (recency 250, the system default 150), and a tie-break on name length.
Exec flags and field codes are stripped -- matching them made "unity" find
Visual Studio Code.

`shell/domain/launcher/Frecency.qml` is the history: a count and a timestamp
per result id in the state directory, decayed by half every 21 days, pruned
on write. `launcher.learn` turns it off; Settings has a Forget button.

`shell/domain/launcher/apps/Results.qml` merges the sources: **score decides
what is in the list, the group decides the order**. Applications are never
capped (a cap of four turned "termina" into four terminals and three
unrelated rows -- the user caught it within a minute); every other source
takes at most three. Pinned results sort **ahead of the score entirely**,
which is the second thing the user caught: as a bonus a pin could not cross a
class, so a pinned Kate still sat under "Menu Editor" for "editor".

The sources besides applications are open windows (raised by title through
the existing daemon), recent files and this shell's own settings pages, all
under small-capital headings, `launcher.searchSources` choosing which. The
list stays flat, so the selection is still an index and Up and Down still
step one row.

`shell/domain/launcher/DefaultApps.qml` is "what this machine opens things
with". **Reading mimeapps.list is not enough** and the first version did only
that, on a machine whose System Settings shows Gwenview, Haruna, Kate,
Dolphin and Konsole while its mimeapps.list names none of them: most defaults
are derived, and `xdg-mime query default` is what resolves them. The file is
followed for *when* to ask; xdg-mime is asked for *what the answer is*, once,
for the thirteen types the KCM itself lists.

**Loose matching was gated twice, both times on something real on screen.** A
subsequence match put a browser window titled with a video's name under a
search for "terminal", and "SchedExt GUI Manager" under "image". A name is
now matched that way only when it is short enough for the letters to mean
something (3x the query plus 2), and a window title is declared `prose` and
never matched that way at all.

**`rmpr ipc launcher results` is new, and is how all of the above was
checked.** A result list holds the keyboard exclusively, so no screenshot
survives it and nothing in this session could type into one: `launcher query
<text>` then `launcher results` prints what the card would draw, as JSON.
Anything about search behaviour should be checked that way rather than argued
from the code.

**Pinning is from the results now**: Ctrl+P on the selection, or the pin
glyph on the row. It writes `launcher.pinned`, the same list the start menu
uses -- one idea, not two.

**Two settings keys are new**, in the schema, the shipped defaults and
Settings -> Launcher: `launcher.searchSources` and `launcher.learn`.

### caelestia, and the notifications

**caelestia no longer autostarts, at the user's decision.** `systemctl --user
disable` cannot do it -- the unit is *generated* from
`~/.config/autostart/caelestiashell.desktop` by systemd-xdg-autostart-generator
and `is-enabled` answers `generated`. What does it is `Hidden=true` in that
file (`X-GNOME-Autostart-enabled=false` alongside it), after which the
generated unit is `not-found`. Undo by flipping `Hidden` back. The running
instance was left alone.

**The notifications are still not ours, and disabling the autostart is not
enough on its own.** `rmpr ipc services status` says
`servingNotifications: false`, `reason: plasmashell is on caelestia.desktop`
-- the check is on the shell *package*, not on whether caelestia is running.
The user was asked and said not now, so `rmpr renderer set quickshell` is
the outstanding command; the `notifications.server` setting is already
`shell`.

**Still unmeasured**: whether anything re-registers Meta at login now that
caelestia does not autostart. `rmpr shortcuts status` after the next login is
the whole check.

### The session of 2026-09-15, afternoon

**The chain that destroyed a configuration on 2026-09-14 has no links left.**
Item 1 is done.

"The wizard has never run here" was one question with one answer: a marker
file in the state directory. The state directory is what a restore point
rolls back, so the marker went missing on a machine configured over days,
the shell read its absence as a first run, and the wizard's Finish wrote a
fresh profile over what was left.

It is two questions now -- `shell/domain/config/FirstRun.qml`. The marker
says whether the wizard has finished here; `ConfigStore.configured` says
whether anybody has ever set anything, which is any key in the profile other
than the `schemaVersion` the shell writes itself. Only a machine where both
say no is a first run. A configured machine with no marker gets the marker
written back, quietly. Both directions were tried on this machine: taking
the marker away wrote it back and showed nothing; forcing the configuration
check off brought the wizard up, which is the fresh-install path.

The reverse is deliberately not symmetric. A marker with an empty profile is
ordinary -- somebody skipped the wizard -- and showing it again would make
the skip button a lie.

**And Finish keeps what it replaces.** `rmpr wizard` re-runs this on a
machine set up months ago, so the last step now says what the button is
about to do, and the profile is copied aside first. The routine is
`preset apply`'s, moved to `scripts/lib/profiles.sh` and exposed as
`rmpr profile keep <label>`, so there is one implementation rather than one
and a missing one. Keeping is skipped when there is nothing to keep, and
"nothing" means what the shell means by it; a profile that does not parse is
kept anyway, being the one somebody most wants back. `tests/test-profiles.sh`
pins all of it, and found two faults in the old code doing so.

### The session of 2026-09-15, morning

The first session after the shell started drawing at login, and both things
the user reported were real.

**The taskbar was empty because the window list was off.** Not a widget bug:
the KWin script had been removed from `~/.local/share/kwin/scripts/`, the
kwinrc key was unset, and the kconfig ledger had no `windows` scope -- the
restore of the night before rolled the state directory back past the day it
was enabled, and took the script with it, exactly as it took the unit file.
`rmpr windows enable` put it back and the daemon answered with ten windows.

What is worth carrying is that **nothing on the screen says so**. The task
list with no daemon behind it is a widget with nothing to show, which the
panel correctly draws as no widget at all, and `rmpr doctor` is the only
thing in the project that reports the state. Anything a restore can take
away should be checked after one -- the unit file is already recorded here
as such, and this is the second.

**A widget's click target was smaller than the bar it sat in.** `panel
layout` gave the measurement: on a 52px panel, every widget but the task
list was 33 to 37px tall and centred, leaving an 8px strip along the top and
the bottom of the bar that belonged to no widget. The bottom one is the
strip a pointer thrown at the screen edge lands on. A slot is the bar's
thickness now, and a right click a widget has no use for opens the panel's
own menu rather than being swallowed -- `wantsRightClick` in the widget
contract, declared by the task list and the tray.

**The panel's own menu does open**, and there is now a picture of it. It had
been shipped unopened; `quickshell ipc call panel menu <screen> <along>`
opens it the way the right click does, which is how it was checked without a
pointer -- and how "the click does nothing" was told apart from "the click
opens a menu I did not expect". `panel closeMenu` puts it away.

**This shell starts at login now** (2026-09-15). `remappr-shell.service` is
enabled -- the standing "keep the unit disabled, they start it by hand" rule is
gone -- and plasmashell's shell package is `remappr-shell.desktop` rather than
caelestia's. Plasma's lock screen still draws; ours is built and deliberately
not enabled.

**caelestia is kept on purpose** and still autostarts, so both draw at login
and both want the same global shortcuts. That is the user's choice: they keep
it to take ideas from. `systemctl --user disable app-caelestiashell@autostart`
is the one command that changes it, and nothing should run it uninvited.

Note the unit file at `~/.config/systemd/user/remappr-shell.service` is written
by `make link` and is in `owned_paths`, so a restore deletes it -- systemd then
keeps running an in-memory copy while `is-enabled` reports `not-found`. Check
both after any restore.

**What is live on the user's machine**: profile `recovered-appearance` (their
settings, recovered from the 13:02 snapshot, with `launcher.provider` put back
to `builtin` -- `auto` chose kickoff, which reports itself available whenever
Plasma is running and opens nothing when plasmashell runs another shell's
package). Alt+Tab is KWin's drawing `remappr-shell` (the Meridian row layout,
which was never installed until this session). Meta+S opens the sidebar.
`snapshots.keep` is 0, so nothing is pruned until they set it.

**What no session here can check**: a click or a keystroke. There is no
key-injection tool on this machine. Screenshots work (`spectacle -b -f -n -o`),
but a surface holding exclusive keyboard focus may not survive being
photographed. Racing the two CLI commands the daemon itself spawns *is* a
faithful reproduction of a fast Alt+Tab, and is how both switcher fixes were
verified -- do that rather than arguing from the code.

Otherwise nothing is half-written: `make lint` clean, `make test` 376
QML cases and every shell suite green. The shell is **running** and the user
has been using it all afternoon, which is why most of what follows is theirs to
press rather than ours to build.

**1. The window previews are new, and the last mile is cosmetic.** They work
(see "Window previews" below): KWin grants the screencast protocol to a client
whose desktop file asks, `plugin/` binds it, and the taskbar's hover preview,
the overview and this shell's switcher all draw real windows. What is left is
one known roughness: the shell binds protocol **version 1** and reads the
deprecated `created(node)` event, so occasionally kpipewire answers `target
not found` for a node id that has been reused. Version 6's `serial` event
exists for exactly that. The card falls back to the application's icon when it
happens, so this is a blemish rather than a fault -- the user was asked and has
not yet said.

**2. Alt+Tab is KWin's, in our package, and now in three layouts.** "Remappr
Shell", "(grid)" and "(icons)" are installed side by side; `rmpr switcher
layout <id>` or the settings page picks one. **Nobody has looked at the grid
or the icons layout on a screen** -- they load (`dev/preview/switcher.sh`
checks all three) and that is all that is known.

**3. Meta+Tab is this shell's overview, and it has been used twice.** Tab steps
windows, the arrows step desktops, Del removes one, and five settings govern
it. What has never been exercised: **stay-open mode**
(`switching.overviewHold: false`), removing a desktop from the card, and the
`1..9` jumps.

**4. The taskbar's right click works for the first time.** Its menu had been
built with no width, so every row laid out 0 wide and the click looked dead.
The panel's own menu is new. Both want a pointer: **nobody has clicked either
on a screen**.

**5. Light and dark now reach the whole desktop**, and this is the one to keep
an eye on. `theme variant` writes the colour scheme's `[Colors:*]` groups into
kdeglobals (naming a scheme is not applying it -- see the session notes), and
GTK's dconf preference beside it. `theme.desktop.followMode` is **on in the
user's profile**, so this follows Night Light twice a day now. It is the most
invasive thing this project does to a machine; `theme revert` is tested to
leave every KDE file byte-identical.

**6. A popout visual the user still sees and no session has reproduced.**
Unchanged. `docs/popouts.md` is the map, and the measurements there came back
clean. Ask for an uncropped capture and the screen name before theorising.

**7. The key path is still two processes per press.** kglobalaccel -> the
session daemon -> `rmpr` (bash) -> `quickshell ipc`, 88 ms measured. The named
and unbuilt fix: have the daemon emit a D-Bus signal the shell follows with the
`busctl monitor` pattern it already uses for the window list. It costs the
launcher, the search and the overview on every press, and it is why this
shell's own Alt+Tab lost to KWin's.

**8. The lock screen has still never been enabled** (item 22 below).

### What to check first, before building anything

Everything below needs a real mouse or keyboard, which no session here has
had: `ydotool`, `wtype`, `dotool` and `xdotool` are all absent, so a keystroke
and a click cannot be produced from inside. Each is quick, and some are a bug
if they fail.

**Seeing, though, is no longer a problem.** A session can open anything over
IPC and take a real screenshot of it -- `rmpr ipc panel click status DP-2`,
then `spectacle -b -f -n -d 2000 -o /tmp/shot.png` -- and read the pixels. Four
rounds of this session were spent arguing from offscreen renders that could not
show the bug. Do not repeat that: see "Looking at the real screen".

1. **Type into the launcher.** `rmpr launcher`, then type. The keyboard-focus
   fix is only proven as far as item focus; proving a keystroke lands needs a
   keystroke, and no key-injection tool is installed here.
2. **Click a task button once.** It should activate the window on the first
   click, not the second.
3. **Drag a row in Settings → Widgets.** Reordering by dragging is new.
4. **Right-click a tray icon.** The application's own menu should open, drawn
   by us. Left click activates, middle click is the secondary action, the wheel
   scrolls the icon under the pointer. The menu data was read successfully from
   every tray item on this machine, including submenus -- what is unproven is
   the drawing and the clicking.
5. **Drag a row in `rmpr settings tray`.** Three lists: on the panel, behind
   the chevron, never shown. Dragging between them is the whole point of the
   page.
6. **Click the bell, then click Ask on an entry** (after turning AI assist on
   in Settings → AI assist). The consent window was proven to map -- the
   window list reports "Ask about a report" -- and `rmpr ask` is tested in a
   sandbox with every provider faked, but nobody has yet pressed Send in the
   window with a real provider behind it. The claude-code path opens a
   terminal; that was exercised only with a fake terminal.
7. **Scroll on the volume icon, and middle-click it.** Reading PipeWire is
   proven -- the popout showed the USB interface at 100%, as `wpctl` does. Writing
   to it is not: no session can scroll. Then drag a slider in its popout;
   `NumberSlider` gained a live mode for it.
8. **Click a paired Bluetooth device, and the Wi-Fi switch.** Each is one
   property write, and neither has been pressed.
9. **Any of the four on a laptop.** No battery has ever been seen by this
   project -- this desktop has none, so the battery widget is proven only to
   take no room. Its charge is accepted as 0..1 or 0..100, because which one
   Quickshell hands over could not be checked here.
10. **The "…" button at the foot of each popout.** It opens Plasma's own
    applet with `plasmawindowed`. That the volume applet opens that way is
    verified; the buttons themselves are not.
11. **Open any popout, and check it appears under its widget.** Until
    2026-09-11 every one opened at the left edge of the screen (see "A binding
    on a function call" below). Over IPC they land in the right place now; by
    hand is still worth a look.
12. **Notifications under our own renderer -- first.** With plasmashell on
    our package and the shell running, `rmpr doctor` should name
    plasmawindowed as the provider of notifications and clipboard, the tray
    should hold two new icons, and `notify-send hello` should draw Plasma's
    own popup. If doctor says nothing provides notifications, every
    notification is being dropped -- which is what this renderer did until
    2026-09-11.

    **Run once, by the user, 2026-09-11.** First attempt: no popup --
    plasmashell still held the old tray's notification server after the live
    switch (fixed: `renderer set` now restarts it). After a restart: Klipper
    and the device notifier hosted in `plasmawindowed` (the first real proof
    of the hosting); notifications taken by caelestia's still-running
    Quickshell bar, which registers a server whenever the name is free and
    got there first. With caelestia gone, the hosted Plasma applet should get
    the name -- that is the case still to see.
13. **The clipboard under our own renderer.** With plasmashell on our
    package, confirm first that `org.kde.klipper` really is gone
    (`busctl --user status org.kde.klipper`), then copy two things and open
    the clipboard widget: both should be listed, as "this shell keeps the
    history". Then choose the older one and paste it. Verified here: Klipper
    mode with the real history (49 entries, 9 of them images, counted without
    reading them), and the fallback's `wl-paste --watch` pipeline recording
    the current clipboard. Not verified: choosing an entry, in either mode --
    it writes to the user's clipboard.
14. **Rest the pointer on a widget.** Every tooltip has been seen drawn, with
    the right text, but only when asked for over IPC. Whether hover reaches it
    by the two routes described under "Tooltips" -- and in particular through
    the tray's MouseArea -- needs a pointer.
15. **Brightness and the keyboard layout, by hand.** Add `brightness` in
    Settings → Widgets (neither widget is in this profile), then drag a
    slider in the popout: the monitor should follow it without jerking back
    as the reads come in. Also scroll on the icon, flick the Night Light
    switch, and middle-click. Over IPC it is all proven -- `brightness step`
    moved both monitors 1% and back, and `brightness nightLight` suspended
    Night Light and resumed it -- but the popout was never actually *seen*:
    a full-screen game covered DP-2 when the screenshots were taken. The
    keyboard widget needs a second layout in System Settings before it
    appears at all.
16. **Popouts, as the user reported them.**
    - Open the tray's chevron with several icons behind it: every icon
      should be inside the flyout.
    - Open it, then click the desktop or a window: it should close, and that
      click should do nothing else.
    - Open it, then click the launcher: the flyout closes and the launcher
      opens.
    - Get a message in Discord or ZapZap while another window has focus: its
      taskbar button should flash orange, then stay orange until clicked.
    - Add `activewindow` in Settings → Widgets: each monitor's panel should
      name a window on that monitor, dimmed on the one without the focus.
      Clicking the dimmed one should bring that window forward.
    - Click the active window's task button: it should minimise, and a
      second click should bring it back. Middle-click Konsole's: a new
      Konsole should open. Right-click Chrome's: "New Incognito Window"
      should be offered. Choose "Pin to taskbar", close Chrome, and the
      button should stay, now as a launcher. "Close window" on a window with
      unsaved work should let the application ask first.

    None of this could be tried here. A full-screen game had the screen, and
    popouts are now on the overlay layer, so they would have opened on top of
    it.
17. **Screen edges, by hand.** `rmpr settings edges`. Pick the bottom-right
    corner on the picture, choose "Show the desktop", then push the pointer
    into that corner: the windows should go. Turn the master switch off: the
    corner should do nothing, and dragging a window to the top of the screen
    should not maximise it. Turn it on: both come back exactly. "Plasma's
    screen edge settings" should open System Settings on KWin's page, and
    after changing a corner there, the refresh button should show it.
    Verified: every command the page runs, by the suite (53 checks) and
    read-only against this machine's kwinrc; the page drawn offscreen with
    the real data (see "Rendering a page without a screen"). Never clicked.
18. **Peek, and the strip under the pointer.** Set `widgets.showdesktop.peek`
    in Settings -> Widgets, then rest the pointer on the strip at the end of
    the panel: after half a second the windows go, and moving away brings
    them back. A click while peeking keeps the desktop. Separately, and with
    peek off: the strip should now light up under the pointer, which it
    could never do before, and after Meta+D its tooltip should say "Bring
    the windows back". Verified: the reloaded shell watches `/KWin` and reads
    `showingDesktop`. The peek itself needs a pointer.
19. **Press a key -- any of ours. This is the one thing to do first.**
    Until 2026-09-13 no shortcut this project bound had ever been grabbed;
    now the component has a running owner and kglobalaccel says every key is
    registered (see "Global shortcuts" below for the numbers read back off
    the server). Nobody has pressed one. Try, in this order:
    - **Alt+Tab** -- this shell's own switcher, the card row, should come up.
      Hold Alt and press Tab again: the selection should move along, and
      Alt+Shift+Tab should move it back. Letting Alt go chooses.
    - **Meta** alone: the start menu. **Meta+Space**: search.
      **Meta+Shift+R**: settings. **Meta+V**: the clipboard.
    - If nothing happens, `rmpr shortcuts status` says whether the component
      is grabbed, and `journalctl --user -t remappr-shell-windowsd` says
      whether the press arrived and the command ran.
    - The way back is `rmpr switcher revert` (Alt+Tab to KWin) and
      `rmpr shortcuts revert` (everything else).
20. **The application style, by hand.** `rmpr settings appearance`, then
    Darkly: an open Dolphin or Konsole should restyle at once, and "Undo the
    style" should bring Breeze back. Verified: the key written and put back,
    in the sandbox; the live `theme status --json` finding Breeze, Fusion,
    Darkly and Kvantum installed and Union not. Not seen: an application
    restyling on the notification. **Union**, once installed (`sudo pacman
    -S --needed union`): check its plugin's file name against the
    `*union*.so` glob and its key against "Union" in `scripts/theme.sh`
    before trusting the button. "Install the missing parts" is a real
    `theme apply` on this machine -- see the state table.
21. **Notifications drawn by the shell.** Settings -> Notifications, "Drawn
    by": shell. On this machine caelestia's bar holds the notification
    service, so at first nothing changes: `quickshell ipc -p
    ~/.config/quickshell/remappr-shell/shell.qml call notifications server`
    should say `serving: true, ours: false` and name caelestia's quickshell,
    and doctor should warn the same. Stop caelestia's bar and the shell
    should take the name at once (`ours: true`). Then `notify-send -i
    dialog-information hello world` should pop up beside the clock, go
    after six seconds, stay while the pointer rests on it and close on a
    click; `notify-send -A yes=Yes question` should print `yes` when the
    button is pressed; with AI assist on, "Ask" should open the consent
    window on it. The bell's popout gains a do-not-disturb switch. Back to
    plasma, the popups stop, and the shell hosts Plasma's applet again once
    the name is free. Verified: all of it on a private session bus,
    offscreen, including the hand-over from a stand-in for our hosted
    applet. Not seen: a popup on the real screen -- its placement, its icon
    (offscreen has no icon theme), the hover hold.
22. **The lock screen: try it, then turn it on, with a way back ready.**
    `rmpr lockscreen try` covers every screen and takes the keyboard, as a
    real lock does, but nothing is locked. Type the password: it goes, and
    the build is recorded as tried. If it will not unlock it closes by
    itself after 90 seconds -- which PAM counts as one failed login. Then,
    with a text console logged in and waiting (Ctrl+Alt+F3), `rmpr
    lockscreen enable`, back to the desktop, Meta+L. Look for: the clock
    alone until a key; the first key typed landing in the field; a wrong
    password said, three seconds' rest, then the right one unlocking;
    Escape hiding the prompt; typing mirrored on both monitors; the volume
    OSD while locked. `enable` prints the way back: `loginctl
    unlock-session <id>` from the console, then `rmpr lockscreen disable`.
    Verified without a person: the real greeter loading it (`lockscreen
    check`, now part of `make test`), every state drawn offscreen under a
    stand-in authenticator, the unlock rules (21 QML cases) and the
    commands (61 checks). **Done on 2026-09-13**: tried twice on a real
    screen, unlocked with the user's real password both times. Not done:
    `enable`, and everything after it in this item.

23. **The redesign is merged and has been seen -- but only in part.** On
    2026-09-13 it drew on the user's two screens for the first time. Confirmed
    working by eye: the panel in all three styles (full, floating, islands) and
    on all four edges; popouts on a side panel, which the placement fix was
    for; the notification centre; the sidebar (`rmpr sidebar`), with its media
    card, calendar and live CPU, memory, GPU and network readings. **Still not
    seen by anyone**: the start menu in its three layouts, the search overlay,
    quick settings, the calendar popout, the key sheet, the session screen, a
    notification popup in each position, the settings window's newer pages, the
    rounded screen border and the desktop clock (Settings -> Desktop, both off
    by default).

24. **The lock screen has been tried on a real screen; it has never been
    enabled.** `rmpr lockscreen try` was run twice on 2026-09-13 and unlocked
    with the user's real password both times, so build `b80537960ca3deb1` is
    recorded and `enable` will be accepted. faillock was empty after both. What
    remains is item 22's second half: `rmpr lockscreen enable` with a text
    console logged in and waiting (Ctrl+Alt+F3), then Meta+L, and the list of
    things to look for there. The user chose not to on 2026-09-13.

25. **The taskbar reported missing on 2026-09-12 -- answered, twice over.**
    The first answer was the profile: `panel.renderer: plasma` while
    plasmashell sat on `caelestia.desktop`, so nothing drew a panel.
    `rmpr renderer set quickshell` fixed it, confirmed by the user.

    On 2026-09-13 the profile said `plasma` again, and the cause was never
    found. Two theories were tested and both failed: a second shell holding a
    stale copy and writing it back was **disproved** -- two shells were run
    side by side, the file was replaced by `mv` underneath them, and both
    picked the change up within three seconds -- and no background writer
    exists. `panel.renderer` has exactly two writers: `scripts/renderer.sh`
    (`set` and `revert` both write it) and nothing else, the settings page
    having been written deliberately to shell out to the CLI rather than set
    the key. So a `rmpr renderer` command ran; `revert` is the one that would
    do it as a side effect. **If it drifts again, that is the thing to watch.**

26. ~~**The desktop does not follow day and night; only the shell does.**~~
    Built on 2026-09-14, opt-in under `theme.desktop.followMode` and off by
    default; `rmpr theme variant light|dark|auto` does it once by hand. The
    defaults file carries both variants behind `# variant:` markers and only
    the one being applied is written. What follows is the premise it was
    written against, which held:
    `theme.mode: auto` now turns the shell light by day and dark by night on
    KWin's Night Light schedule, but `theme apply` writes one fixed colour
    scheme -- `@DISPLAY_NAME@ Dark` in the look-and-feel `defaults` -- so
    applications stay wherever they were put. Making the desktop switch too
    needs a light variant of those defaults and something to re-apply them when
    `daylight` changes. It writes KDE keys on a timer, so it is the user's call
    to ask for, and they had not.

### Looking at the real screen

`dev/preview/preview.sh` is not what is on the screen, and a session that
forgets this will report a fix that is not one. It deletes
`BackgroundEffect.blurRegion` and the input mask from `WidgetSlot.qml` before
rendering (they have nothing to attach to on a `FloatingWindow`), and it turns
every full-screen layer surface into a plain `Item`. So it cannot show
anything the compositor does: the blur behind a card, how a mask takes input,
what layer a surface is on. Three rounds of "it looks right in my render" were
spent on this before the user pointed it out.

**Spectacle will take a real screenshot from here**, which `grim` will not --
KWin does not implement `wlr-screencopy`, so grim writes nothing at all:

```
spectacle -b -f -n -o /path/out.png      # background, full screen, no notification
```

It captures every output into one image: on this machine 4000x2560, with DP-3
(1440x2560) at x=2560 and DP-2 (2560x1440) at x=0, y=1041. Open the popout
over IPC first (`panel click <widget> <screen>`), take the shot from a
backgrounded subshell a second or two later, and crop with Pillow. Reading the
pixels beats looking at them: `panel layout <screen>` gives the slot, and a
scan across the card's edge gives the corner radius, the border and the gap to
the panel in numbers.

### The lesson this session paid for twice

**Everything in this file that says something is impossible is a claim, not a
fact — re-verify it before repeating it.** Three of them were wrong:

- "Quickshell exposes no layer-shell keyboard-focus mode" — it does,
  `WlrLayershell.keyboardFocus`, and the launcher works because of it.
- "Quickshell's Wayland module exposes only session-lock types" — it ships
  `ToplevelManagement`; the real obstacle was a KWin protocol, found only by
  running it.
- "A window with no desktop entry cannot have an icon" — never stated outright,
  but assumed; `_NET_WM_ICON` had it all along.

Each cost more time to work around than it would have cost to check. The
measurements in this file are trustworthy; the conclusions drawn from absence
are not.

## Working today

- **Panel** — Quickshell layer-shell, one per monitor, position/thickness from
  config, live reload with no restart.
- **Widgets** — launcher, workspaces (KWin virtual desktops), clock, tray,
  power (Plasma's logout prompt), show-desktop, notification history. Built-ins
  and third-party plugins share one manifest format and one code path.
- **Tray** — three states: on the panel, behind the chevron, never shown.
  `widgets.tray.pinned` is the ordered panel list and **empty means everything**,
  so a fresh install shows the tray it has rather than an empty strip and a
  chevron. Settings has a Tray icons page that edits all three lists by
  dragging a row between them, because the alternative is typing ids like
  `org.kde.StatusNotifierItem-5616-1`. `rmpr settings tray` opens it. The rules are in
  `qs.domain.tray.layout`, which the page and the panel both read, so they
  cannot disagree. Left click activates, right click opens the application's
  own menu, middle click is the secondary action, the wheel scrolls the icon
  under the pointer.
- **Status widgets** — `volume`, `network`, `bluetooth`, `battery`. Plasma's
  volume, network, Bluetooth and battery indicators are *applets inside its
  system tray*, not StatusNotifierItems, so under our renderer they never
  reached our tray at all: the panel had no volume icon. Each is now a widget
  that reads the service directly through Quickshell (PipeWire,
  NetworkManager, BlueZ, UPower, power-profiles-daemon), with a small popout
  for what people do daily -- volume and microphone sliders and an output
  picker, the Wi-Fi switch, connecting a paired device, the power profile --
  and a button that opens *Plasma's own applet* with `plasmawindowed` for
  everything else: the Wi-Fi password prompt, a volume per application,
  pairing. Nothing Plasma already does is rebuilt. Scroll on the volume icon
  to change it, middle-click to mute.

  Battery and Bluetooth set `present: false` (new on `BarWidget`) where there
  is no hardware, and take no room -- which is what makes them safe in presets
  shared by laptops and desktops. All four are in the defaults and in every
  preset (minimal gets network, volume and battery). The rules -- which icon,
  how far a notch scrolls, which battery scale -- are pure functions in
  `qs.domain.status.icons`, tested; the services are singletons in
  `qs.domain.status`.

  Under the Plasma renderer each maps to its stock applet, and is **left out
  when `tray` is also on the panel**: Plasma's tray already hosts it, and it
  would be drawn twice (`renderers.plasma.inSystemTray` in the manifest). The
  notification bell had the same latent duplicate and is marked too. `renderer
  set` names what it left to the tray.
- **IPC for working on the shell without a pointer.** `status
  audio|network|bluetooth|power` prints what each widget is reading. `panel
  click <widget> <screen>` does what a left click does. `config setRuntime
  <path> <json>` writes the in-memory layer, never persisted -- which is how a
  second copy of the shell can draw a panel while the profile names another
  renderer:
  `quickshell ipc -p shell/shell.qml call config setRuntime panel.renderer '"quickshell"'`.
  `panel tooltip <widget> <screen>` shows a widget's tooltip for four seconds.
  `panel layout <screen>` lists every shown widget's box on that screen, in
  screen coordinates -- which answers "why is this cut off" in one call where
  screenshots took five.
- **Tooltips, and windows beside the panel on every edge.** A widget sets
  `tooltip` (and, if it is made of several things, `tooltipCentre`); the slot
  shows it after the pointer has rested 600 ms, never while the popout is
  open, and drops it at the first press. It is its own window, because a
  tooltip has to escape the panel just as a popout does, and it takes no
  input at all (an empty `mask`). The tray names the icon under the pointer in
  the application's own words, markup stripped; the status widgets give their
  numbers; the clock gives the whole date in the user's locale. The task list
  keeps its hover preview instead.

  The popout and the tooltip are both an `EdgeWindow`
  (`features/panel/EdgeWindow.qml`), which owns placement for all four panel
  edges. The popout used to place itself and assumed a horizontal panel -- on
  a panel down the side of the screen it opened at the bottom. Verified on a
  runtime-only `left` panel: the volume popout 44 px in from the left edge,
  clamped above the bottom of the screen.

  Hover reaches the tooltip from wherever it actually arrives: the slot's
  MouseArea for widgets with `wantsHover`, and a HoverHandler on `BarWidget`
  (`hovered`) for the rest.
- **A click outside the start menu used to break it for good** (2026-09-13,
  from the user's report: "not working any more, I do not know if clicking
  outside the launcher affects this" -- it did). The panel closed a popout by
  assigning `popoutVisible = false` onto the widget. That is right for the
  fourteen widgets that keep the flag as plain state and silently fatal for
  the one that does not: assigning to a QML property **replaces its binding
  with a constant**, and the launcher's `popoutVisible` is a binding on "is
  the provider open, here, in menu mode". One outside click and the start
  button did nothing for the rest of the session -- including every press of
  Meta.

  `BarWidget` now has a `closePopout()` the panel calls instead, whose default
  is the old assignment; the launcher overrides it to close the provider, so
  its binding survives. `tests/tst_Popouts.qml` holds the contract. The same
  report's "does not open every time" had a second cause in the same file:
  the button closed the menu when it was open *anywhere*, so on two monitors
  clicking the other screen's button put it away instead of moving it over.

- **The popout system, gone over on a real screen** (2026-09-13, from the
  user's report: a start menu nowhere near its button that the button could
  not close, "another popup underneath" every popout, and a calendar that was
  a different size each time). Four separate faults, and none of them could be
  seen without a screen:

  - **A popout reached back over the panel.** The window keeps a transparent
    border for its shadow and was placed `extent + gap - shadowMargin` from
    the screen edge -- 12 px, which is *inside* a 52 px panel. For the popouts
    that carry an input mask that was invisible; the start menu cannot carry
    one (mask + exclusive keyboard focus = a window KWin maps and never draws,
    see WidgetSlot), so its window sat over the start button and the second
    click on it went nowhere. The room on the panel side is now capped at the
    gap: there is nothing to see behind the panel anyway.
  - **The start menu was centred on a button it is twenty times wider than**,
    then shoved back on screen, so it lined up with neither. `popoutAlign:
    "start"` puts its near edge level with the button's.
  - **The shadow was drawing a second card.** Blur 40 and drop 12 is a 52 px
    band of dimmed wallpaper around a card whose own background is blurred by
    the compositor, and the join between the two reads as another surface.
    22 and 7 now.
  - **A popout's contents cannot set their own width.** The Loader anchors
    them to fill the card, so `width: 348` in CalendarPopout was overwritten
    and the card came out as wide as the longest line of text in it -- which
    changes with the locale. The widget says `popoutWidth` instead. (Assigning
    `implicitWidth` in the contents is not the fix: on a `Column` it is
    read-only, which qmllint does not catch and the running shell reports as
    the whole widget failing to load.)

  The arithmetic is now `qs.domain.panel.Placement`, four pure functions with
  `tests/tst_Placement.qml` on them, because every placement bug this project
  has had has been one of these numbers and none of them needed a screen to
  check.

  Then a second round, the same evening, from the same screen:

  - **Shadows are a setting now, `theme.shadows`, and it is off by default.**
    Settings -> Appearance. A drop shadow is a band of dimmed wallpaper around
    a surface whose own background the compositor has blurred, and on a dark
    desktop the join reads as a second panel behind the first. Off, a popout
    keeps no transparent border at all: the card *is* the window, there are no
    dead bands above and below it, and an aligned popout lands exactly on its
    widget. It gates the four places the shell draws one -- the popout, a
    floating panel and its islands, the OSD and the search.
  - **Popouts and the search came off the overlay layer.** The overlay layer
    is above everything a compositor draws, full-screen windows included, so
    the start menu sat on top of Spectacle's region selector -- and would have
    sat on top of a game or a video. They are on the top layer with the panel
    now, where KWin puts them under a window that has asked for the screen.
    The session screen, the Alt+Tab switcher and the rounded screen border are
    still on the overlay layer, deliberately.
  - **The click-catcher is mapped from the start and made deaf instead.**
    Sharing a layer with the popouts means the two stack in the order they
    were mapped, and a surface that maps *with* the popout is a race the
    popout can lose -- losing it means every click on a popout closes it. One
    that never unmaps always loses. It takes no input at all (an empty region)
    while there is nothing to close.
  - **Radii inside a popout follow `theme.rounding` now.** Reported as "the
    bottom corners have straight corners under the corners with a radius", and
    it is the other way round: this machine has `theme.rounding` at **8**, the
    design is drawn at 28, and all 34 radii inside the popouts were the
    design's numbers written out. So a tile at 20 sat inside a card at 8 --
    a rounder corner inside a straighter one, at every corner of every popout.
    `Theme.radiusOf(designed)` rescales them. The tray's flyout and the task
    popout were worse again: both hardcoded `popoutRadius: 18` and ignored the
    setting outright, which is why the flyout was the clearest example. Both
    dropped.
  - **One surface per popout.** Reported as "multiple backgrounds on the same
    popup", and the offscreen render (`dev/preview/preview.sh
    dev/preview/popout.qml`, `PREVIEW_WIDGET=launcher`) showed three tones
    stacked inside one card: the card's own glass, the start menu's rail and
    side filled a shade lighter, and inside those, cards a shade darker again.
    The rule now is that a popout is one surface and only what can be pressed
    or typed into gets a background of its own -- everything else is space and
    a hairline. The rail, the side column, the "what is playing" and "the
    machine" cards, the quick settings' slider panel and the search overlay's
    hint bar all lost their fills; tiles, buttons and list rows kept theirs.
    The search field is an outline rather than a third shade.
  - **An aligned popout at the corner of the screen keeps its alignment.** A
    window cannot start at a negative position, so with shadows on the start
    menu -- its button 12 px from the corner, its shadow wanting 29 -- opened
    17 px to the right of it. `Placement.shift` moves the card inside its own
    window instead, which costs nothing: the shadow on that side is off the
    screen either way.
  - **The gap opens up for a shadow rather than the shadow being cut.** The
    first answer to "the window must not reach over the panel" was to cap the
    room on that side at the gap. That cuts the blur off square where the room
    runs out, and a card with a straight bottom-left corner is what that looks
    like -- reported. `Placement.away` widens the gap to the shadow's reach
    instead, so the window still starts at the panel's edge and none of the
    shadow is clipped. With shadows off, which is the default, there is
    nothing to make room for: the card *is* the window.

- **Popouts behave like menus** (2026-09-11, from the user's report). Three
  things were wrong. Every popout window was sized to its contents, with the
  contents 8 px in from each edge, so every popout was 16 px too small. Most
  hid it behind a fixed width and an extra 8 px of height. The tray's
  flyout, a grid of fixed-size icons, lost its last column instead, which is
  what "not responsive to the number of icons" was. The slot adds the margin
  now, and the +8 workarounds are gone. Second, nothing but its own widget
  closed a popout, because a layer surface has no popup grab to do it. Now
  `PanelModel.openPopoutSlot` holds the one open popout. Opening another
  closes it, and so does a press on any other widget or on the panel between
  widgets. While one is open, each panel also shows a transparent top-layer
  surface over the rest of its screen, and a press there closes it. Third,
  popouts and tooltips moved to the overlay layer so they stay above that
  surface. The task preview follows the pointer and opts out
  (`popoutClosesOnOutsideClick: false`).
- **Taskbar buttons ask for attention.** The KWin script now sends
  `demandsAttention` and republishes whenever it changes. A button whose
  window asks flashes orange (`PlasmaColors.neutral`) for six seconds, then
  keeps a steady tint until the window is activated, which is when KWin
  clears the request. When each request began is kept in
  `WindowsService.attentionSince` (`WindowEvents.attentionSince`, tested),
  because any change to the list rebuilds every button: a flash timed from
  the button would restart whenever another window changed its title.
  Verified: the reloaded script's list carries the field. Not seen: a button
  actually flashing. Nothing asked for attention while this was built, and
  no request was faked.
- **Task buttons that behave like Windows'.** Clicking the window that is
  already active minimises it, by invoking KWin's own "Window Minimize"
  action, which acts on the active window, the very one clicked. A middle
  click starts another instance. A right click opens `TaskMenu`, a jump list
  built from what Linux applications declare: their desktop actions first
  (Chrome's "New Incognito Window", Konsole's "Open New Tab"), then the
  application itself, "Pin to taskbar", and "Close window" or "Close all N
  windows". **Pinned applications** (`widgets.tasks.pinned`, desktop entry
  ids) come first, in pin order. A pinned application holds its windows when
  running and is a plain launcher when not. The ordering is
  `WindowEvents.arrangeTasks`, tested.

  Closing a window that is not active has no KWin call, so `rmpr windows
  close <uuid>` loads a one-shot KWin script that finds the window and calls
  `closeWindow()`, the close button's request, so unsaved work can still ask.
  The id is written into the script's source, so it must match a uuid
  exactly, and the suite checks that a script in its place is refused and
  that nothing reaches KWin without a session.

  The popout keeps one window for two contents, the preview and the menu. It
  can turn from one into the other while open, so `WidgetSlot` now follows
  "open and closes-on-outside-click" as a pair (`modal`) rather than only the
  moment of opening.

  Not tried on screen: none of the clicks, the menu, pinning or closing. The
  screen was in use throughout, and each of these would have acted on the
  user's real windows.
- **Active window** — `activewindow`, the last widget from Phase 2 of the
  plan. KWin has one active window for the whole desktop, so each panel
  names the window last active on *its own* monitor instead. That is the
  active window wherever it is; failing that, the one last active there;
  failing that, the topmost window on that monitor that isn't minimised. On
  the monitor without the focus the title is dimmed, and a click brings the
  window forward. For this, the KWin script now also sends each window's
  `output` (named as Quickshell names screens) and its `stacking` position.
  The rule is `WindowEvents.lastActiveByOutput`, tested. It maps to Plasma's
  `windowlist` applet, and it is in the macOS preset. The same data gives the
  task list a `thisScreenOnly` option, Windows' "show taskbar apps on the
  taskbar where the window is open". `status windows` says which window each
  monitor's panel names. Verified live: DP-2 named the focused Chrome
  window, and DP-3 named its topmost window (Claude), passing over a
  minimised game.

  The renderer suite's fixture had used `activewindow` as its example of a
  widget with no Plasma applet. The real widget, added to the same index,
  won the lookup, and three checks failed. The fixture is `unrenderable` now.
- **Media** — `media`, the fifth applet Plasma keeps inside its tray and our
  tray therefore never had. Reads MPRIS through Quickshell: the title beside a
  play/pause glyph on the panel, middle-click to pause, and a popout with art,
  artist and album, a seek bar, the three buttons, a chip per player when
  there are several, "Show <player>" and Plasma's own media applet. Absent
  while nothing is open. Which player is shown is `StatusIcons.pickPlayer`,
  tested: playerctld (a proxy) is never offered, and music starting
  elsewhere is followed without forgetting a paused choice. A browser with
  Plasma's integration is on the bus twice, and the two do *not* report the
  same track -- Chrome's own entry has the tab title (" - YouTube" on the end)
  and no artist, the integration's the clean title, the artist and `kde:pid`
  naming the browser process. The browser's `...instance<pid>` entry is
  dropped when the integration claims that pid, the rule Plasma's own applet
  follows; matching on the title, tried first, left the video listed twice. MPRIS
  does not announce the position as it moves, so it is asked once a second
  while playing. In the defaults and every preset but minimal.
- **Plasma services — notifications were being dropped.** The most serious
  finding of 2026-09-11. Plasma's notification server is not in plasmashell:
  it is `libnotificationmanager`, and apart from the task manager and the
  settings page the only thing loading it is the notifications applet's QML
  plugin (`org/kde/notificationmanager`). Our renderer's shell package has no
  system tray, so under it **nobody owns `org.freedesktop.Notifications`**.
  An application sending one then triggers bus activation, and here that goes
  nowhere: dbus-broker ignores Plasma's activation file as a duplicate of
  mako's ("Ignoring duplicate name ... org.kde.plasma.Notifications.service"),
  and systemd skips mako on KDE (`ConditionEnvironment=!XDG_CURRENT_DESKTOP=KDE`,
  logged as skipped). The notification is dropped. The previous boot's journal
  has nine `WaitForName: Service was not registered within timeout` between
  12:28 and 14:58 on 2026-09-10 -- while the quickshell renderer was being
  worked on. Klipper is the same story (below).

  The fix hosts **Plasma's own applets** outside any panel:
  `plasmawindowed --statusnotifier org.kde.plasma.notifications` (and
  `...clipboard`, and `...devicenotifier`, so a USB stick being plugged in is
  announced and has somewhere to be ejected from). The device notifier holds
  no bus name, so "already provided" also means plasmawindowed already shows
  the applet's tray item, whose Id is `plasmawindowed_<applet>`
  (`Hosting.provided`). The applet stays alive with its service, and shows as one
  item in our tray -- where Plasma's notification history and do-not-disturb
  are then reached. Nothing is reimplemented. `domain/backend/PlasmaServices`
  decides with a tested pure rule (`qs.domain.backend.hosting`): only under
  the quickshell renderer, only when plasmashell is on our own package (so no
  Plasma tray can be about to provide them), only for a name nobody owns, and
  each applet at most once per run -- quitting one from its tray menu is
  respected. It looks again whenever either name changes hands.
  `rmpr renderer set` stops the host before switching to a renderer with a
  Plasma tray (only if plasmawindowed actually owns one of the names -- a
  window opened from a widget's "..." button is not ours to close), and asks
  the shell to rehost after switching to quickshell or rolling back.
  `services.hostPlasma` turns it off. `rmpr doctor` has a "Plasma services"
  section naming who provides each, and calls no notification owner a
  problem. IPC: `services status|reconcile|rehost`.

  Verified here: the hosting mechanism itself, with a harmless applet (one
  tray item per applet, a second applet handed to the same process, the item
  gone the instant the process is). Not verified: hosting the notifications
  applet for real, which needs plasmashell on our package -- see "What to
  check first".
- **Clipboard** — `clipboard`. Under our renderer there is **no clipboard
  history at all** without it, and Meta+V does nothing: Klipper is not a
  program in Plasma 6 but `libklipper`, and the only thing on the system that
  loads it is the clipboard applet's QML plugin
  (`org/kde/plasma/private/clipboard/libklipperplugin.so`, found by scanning
  every library's `NEEDED` entries; plasmashell does not link it). No system
  tray, no clipboard applet, no Klipper. Established statically -- the live
  check needs plasmashell on our package, which only the user should switch.

  The widget reads Klipper over DBus when `org.kde.klipper` is on the bus
  (following `clipboardHistoryUpdated` and the name changing hands), and
  otherwise keeps its own history from `wl-paste --watch`: text only, 8 KB an
  entry, 50 entries, in memory, never written, nothing offering KDE's
  password-manager hint. Choosing an entry goes through `wl-copy` on stdin in
  both cases, so clipboard text never sits in a process's arguments. Klipper
  lists an image as text starting with "▨"; those are shown but not offered.
  `status clipboard` gives counts, never contents. `rmpr clipboard` and
  `rmpr shortcuts set clipboard <key>` open it from a key -- Meta+V is still
  plasmashell's, doing nothing, and taking it is left to the user.

  Rejected: loading Klipper's private plugin into our shell (a second Klipper
  whenever plasmashell has one: two clipboard managers, one history file),
  and opening Plasma's clipboard applet with `plasmawindowed` (the same, in
  another process).
- **Brightness and Night Light** — `brightness`. Plasma keeps its brightness
  applet in the system tray, so under our renderer there was no way to dim a
  screen or hold Night Light off from the panel. The keys never stopped
  working: powerdevil handles them itself. A slider per display powerdevil
  can dim (here: both monitors, over DDC), scroll to dim every screen at
  once, middle-click to suspend Night Light, and a switch in the popout.
  `BrightnessStatus` reads `org.kde.ScreenBrightness` (one busctl per
  display, in one process) and KWin's `NightLight` object. Writes pass flag 1,
  powerdevil's SuppressIndicator, since the slider is its own indicator --
  verified: no call reached `/org/kde/osdService`. They are queued, and only
  the latest value per display is sent once the previous write returns, which
  over DDC takes a while. Night Light is suspended by **invoking KWin's own
  "Toggle Night Color" shortcut** through kglobalaccel. `NightLight.inhibit`
  is no use from busctl: KWin drops an inhibition as soon as the connection
  that asked for it closes. The rules -- the 1% floor that keeps a scroll
  from blacking out a panel, the five Night Light states, which glyph the
  panel shows -- are in `StatusIcons`, tested.
  Present wherever there is a display to dim or Night Light is available.
- **Keyboard layout** — `keyboard`. The same story for Plasma's layout
  indicator: KWin still switches, but nothing on screen said which layout
  was on. It reads `org.kde.keyboard /Layouts`, shows the short name (or the
  user's own label), a click moves to the next layout, and the wheel cycles
  through them, one layout per whole notch. With a single layout it sets
  `present: false` and takes no room, as it does on this machine, so it is in
  every preset.
- **Camera and microphone in use** — `privacy`. This one is not cosmetic.
  Plasma's microphone-in-use icon is `MicrophoneIndicator`, which lives only
  in the volume applet's own plugin (`libplasma-volume-declarative`), and its
  camera icon is the `cameraindicator` tray applet. Under our renderer both
  were gone: a browser was recording the interface's microphone during this
  session with nothing on screen to say so. The widget is present only while
  something records. The tooltip names the applications, and a click mutes
  the default microphone, as Plasma's indicator does. `PrivacyStatus`
  describes PipeWire's links to `StatusIcons.recorders`, which counts an
  *active* link from a microphone into an application's capture stream, or
  from a v4l2/libcamera camera into a video stream. It leaves out a
  speaker's monitor being read (caelestia's visualiser, here), PipeWire's own
  `/Internal` streams, and screencasts. Verified live: `status privacy`
  names "Google Chrome input" and neither of the others. Getting there took
  three Quickshell surprises, recorded under "Non-obvious things".

  **Audit, 2026-09-11: nothing else Plasma's tray hosts is silently lost
  under our renderer**, beyond the microphone and camera indicators above
  (the audit first missed them, as display-only). Every applet's `NEEDED` libraries and the live
  kglobalaccel components were checked. Volume and media keys belong to the
  kded modules `audioshortcutsservice` and `mprisservice` (components `kmix`
  and `mediacontrol`, both active), brightness keys to powerdevil, and layout
  switching to KWin. The notifications applet links `libKF6GlobalAccel` for
  its own shortcuts, and we host it. What is left is display only: the
  Caps Lock indicator, the camera/microphone-in-use indicator, KDE Connect,
  and weather. (Caps Lock cannot be done from here: KWin exposes no key state
  on DBus, and Plasma reads it through a Wayland protocol Quickshell does not
  bind.)
- **Side panels.** The tray, the clock and the workspace pills lay out along
  the panel on either axis (the tray used to cut to two icons, the clock ran
  off the side), the tray's chevron points away from whichever edge the panel
  is on, and the launcher drops its label down the side. A widget whose
  manifest does not list the panel's orientation -- the task list -- is left
  off that panel and logged, rather than drawn broken.
- **Config** — layered defaults → profile → per-monitor → runtime. Sparse
  deltas. Live reload. Refuses to write over a file that does not parse.
- **Settings window** — schema-driven; every control is generated from a schema,
  including a third-party widget's own settings. A page is a grid of named
  cards; `group` in the schema is what puts a key in one. See `docs/settings.md`.
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
  report, ask, crash, wizard, edges, shortcuts, launcher, search, `settings [page]`,
  preset, profile, update, switcher, reload, lockscreen. A page name is a schema section id, which is also
  its heading in the generated reference -- so `rmpr settings tray` opens the
  window where the docs say it is.
- **Auto-hide** — `panel.autoHide`, per output like position and thickness.
  The surface really does shrink to a sliver rather than a full-height
  transparent one moved out of sight: a transparent surface still eats every
  click that lands on it. The content keeps its full thickness and slides,
  rather than being squashed, so a reveal does not re-lay-out every widget
  twice. It reserves no space while hiding is on.
- **Screen edges** (2026-09-11, §D of the plan) -- Settings -> Screen edges,
  `rmpr settings edges`. A picture of a screen with its eight corners and
  edges and what each does, a dropdown for the one picked, window snapping,
  and the master switch that turns every mouse trigger off at once. The page
  runs `rmpr edges` for everything, including the new `status --json`, and
  never writes kwinrc itself.

  KWin's model is kept rather than flattened: a *border* action (show
  desktop, search, lock, activities, Plasma's launcher) is the corner's own
  value in `[ElectricBorders]`; an *effect* holds a list of edges in its own
  group. `set` puts an edge in exactly one place and takes it out of every
  other list, writing only keys whose value changes. The effect keys were
  read out of KWin 6.7's own config modules (`strings` on
  `kwin_overview_config.so` and `kwin_windowview_config.so`): the grid is
  `Effect-overview GridBorderActivate`, because KWin 6.1 removed the desktop
  grid effect, and the `Effect-desktopgrid` key `edges` used to write was
  read by nothing. Window view has current-desktop, all-desktops and
  this-application keys.

  The master switch writes to a ledger scope of its own, `edges-off`, and
  `enable-all` reverts exactly that scope -- which needed the ledger to
  record a key once *per scope* rather than once overall. Before, the only
  way back from `disable-all` was `revert`, which also undid every corner
  set before it. A corner or snap change while the switch is off is refused,
  since turning it on would overwrite it. `revert` undoes `edges-off` first,
  then `edges`. Loaded tiling scripts (krohnkite, bismuth, polonium, kzones)
  are named beside the snap switch. The trigger delay, corner size and
  touch edges are left to KWin's own page, one button away.
- **Show desktop follows KWin, and can peek.** The strip used to keep its own
  flag, flipped on its own clicks, so Meta+D or a hot corner left it saying
  the opposite of what was on screen. `Desktops.showingDesktop` reads KWin's
  property and follows `showingDesktopChanged`. `widgets.showdesktop.peek`
  (off by default, as in Windows) shows the desktop while the pointer rests
  on the strip; a click while peeking keeps it. It is KWin's show-desktop
  underneath, so the windows move away rather than turn to glass.

  The strip takes hover from the panel so that it is clickable at all, and
  the slot's MouseArea then covered the strip's own HoverHandler: its hover
  highlight could never have lit. The slot passes its hover down as
  `BarWidget.hostHovered`, folded into `hovered`, so `hovered` means the same
  thing for every widget.
- **Switching windows** (§D) -- Settings -> Switching windows,
  `rmpr switcher`. Alt+Tab's look, from every installed window-switcher
  package (`kwin/tabbox` and `kwin-wayland/tabbox` under each data
  directory; KWin's own `thumbnail_grid` lives in the second), and which
  program gets Alt+Tab and Meta+Tab. `give alt-tab` binds KWin's "Walk
  Through Windows" (and its reverse to Alt+Shift+Tab), `give meta-tab` its
  Overview -- Windows' task view. Each *adds* to KWin's existing keys and
  takes the key from whoever held it, all under the `switching` ledger
  scope. The page says who holds each key before offering to move it.
- **Shortcuts are taken, not only claimed.** `shortcuts set` warned that it
  would take a key from its holder, then did not; kglobalaccel gives a key
  to one action, so with two in the file the winner was down to
  registration order. `scripts/lib/accel.sh` finds holders anywhere in a
  multi-key binding, takes the key off them (ledgered), and writes each
  group in its own format: `[services][x.desktop] _launch` is the key
  alone, a component's action is `active,default,friendly`.
- **Appearance** (§C) -- Settings -> Appearance, `rmpr theme style`. The Qt
  style applications are drawn in, from the ones installed (found by plugin
  file in Qt's styles directory; Fusion is built in), written to
  `kdeglobals [KDE] widgetStyle` under its own `style` ledger scope, with
  KDE's StyleChanged notification so open KDE applications follow. A
  missing style shows the command that installs it; `install-style <id>`
  prints it, and runs it only with `--run` in a terminal. The page also
  names the theme parts that are not installed and offers a plain `theme
  apply` -- which now keeps a silenced OSD silenced, rather than copying
  Plasma's back over it.
- **Notifications drawn by the shell** (Phase 8, opt-in) --
  `notifications.server` "shell", default "plasma". A Quickshell
  NotificationServer on org.freedesktop.Notifications and popups in a
  corner beside the panel (`NotificationPopups`, `NotificationCard`), with
  an "Ask" button on each when AI assist is on: the plan's second tier.
  Whether to serve is `Hosting.serveNotifications`, beside the hosting rule
  and tested -- only under our renderer with plasmashell on our package --
  and while serving, Plasma's notifications applet is not hosted. It never
  takes the name from another holder: Quickshell's server waits and
  registers when the name is let go of (measured). The one holder it does
  close is our own hosted Plasma applet, which it exists to replace
  (`handOverNotifications`, only when plasmawindowed really holds the
  name). renderer.sh asks the shell to let go before a switch to a renderer
  with a Plasma tray, because it writes panel.renderer only after the
  switch. The popup rules are `qs.domain.notifications.popups`, tested:
  critical ones stay and are never pushed off, the application's timeout is
  kept, the pointer holds a popup, the body is plain text, do-not-disturb
  holds back all but critical. Deadlines live in the service, because the
  popup list is rebuilt on every change. IPC: `notifications
  server|dnd|dismissAll|release`.
- **Lock screen** (Phase 8, opt-in) -- `rmpr lockscreen
  status|check|try|enable|disable`. Plasma's greeter draws it and does all
  the locking; only the drawing is ours. **Plasma 6 takes the lock screen
  from the shell package, not the look-and-feel package**:
  `lockscreenmainscript` in the package `plasmashellrc [Shell] ShellPackage`
  names, falling back to `org.kde.plasma.desktop`'s. The plan and this file
  said look-and-feel; the greeter's strings and source say otherwise. So
  ours is `contents/lockscreen/` inside our two shell packages, put there by
  `enable` and nothing else, and no KDE key is written: `disable` deletes a
  directory carrying our marker, and needs no session -- it is meant to be
  run from a text console. Source in `theme/lockscreen/`. Unlocking is
  `Unlock.qml`, which draws nothing and is tested against a stand-in for
  kscreenlocker's `PamAuthenticators`; the drawing is `LockUi.qml`, with
  Plasma's own password field, on-screen keyboard, battery and layout
  switcher. The gates:
  - `check` loads it in the **real greeter** -- `kscreenlocker_greet
    --testing --shell <path>` takes a path -- offscreen, with no display,
    no session bus and no runtime directory, under a stand-in
    authenticator. It fails on anything the greeter says about our files,
    on the greeter falling back, and on authentication starting with
    nobody there. qmllint had passed a file the greeter refused.
  - `try` shows it for real in the greeter's testing mode. The greeter
    exits 0 only once its authenticator says unlocked, and that is the only
    way to the "tried" record: the build's hash and the greeter binary's
    (its `--version` says 0.1 whatever the release).
  - `enable` installs the tried copy, not the working tree, and refuses
    after a kscreenlocker update until tried again; `doctor` loads an
    enabled one in the current greeter.
  - Should the greeter lack what unlocking needs, `LockScreen.qml` draws
    Plasma's own lock screen instead. Should ours fail to load, the greeter
    draws its built-in locker (seen, with the Kirigami.Avatar mistake).

  Plasma's rules are kept where they decide whether anyone gets in:
  authentication starts when the prompt shows, and again after the
  three-second rest that follows a failure -- the authenticator goes idle on
  a failure, and a password sent to it then goes nowhere. A fingerprint or
  smartcard failure is not a wrong password, an empty password is never
  sent, and a no-password unlock waits for a click. System Settings' clock
  options are honoured. `renderer.sh` puts the lock screen back into a shell
  package it installs afresh.
- **Generated docs** — `docs/config.md` comes from the schema and the widget
  manifests; `make lint` fails when it is stale. A schema section carrying both
  `page` and `keys` renders as the page in the settings window while its keys
  still reach the reference, which is how `panel.renderer` is documented as the
  config key it is without becoming a text field in the GUI.
- **AI assist** — `rmpr ask`, off by default. Every path writes a report
  locally first, through the same reporter and the same redaction, and the
  bundle a provider receives is byte-for-byte what `rmpr report show` prints
  plus a question. Sources: the newest report, `--new`, `--report <name>`,
  `--last-notification` / `--notification <n>` (over IPC from the running
  shell), `--unit <name>` (its journal tail) and `--failed` (failed user units
  and `coredumpctl`). Providers: `clipboard` (default, sends nothing),
  `claude-code` (opens `claude` in a terminal), `ollama` (local HTTP; an
  address that is not localhost counts as leaving), `custom` (`ai.command`
  with `%report`, or the bundle on stdin). A provider whose program is missing
  is reported as unavailable with the reason, not offered. Consent for a
  provider that leaves the machine is asked once, showing the whole bundle:
  in a terminal, or in the shell's consent window when there is none
  (`rmpr ask` hands off to the window with exit code 2; `--review` forces the
  window whatever the provider). `--forget` withdraws it. Everything the
  window and the widget do goes through the CLI, so there is one code path
  that sends. Wizard step 6 offers the detected providers, default off.
  `rmpr shortcuts set ask <key>` binds "ask about the last notification".
- **Notification history** — `notifications.history`, off by default. A
  `busctl monitor` match on `Notify` method calls to
  `org.freedesktop.Notifications`, the OSD listener's pattern: Plasma keeps
  the name and keeps drawing, we read what goes past. (Under our renderer
  that was **not true** until 2026-09-11 -- nobody held the name and every
  notification was dropped; the history recorded calls no one answered. See
  "Plasma services".) Memory only, capped by
  `notifications.historySize`, never written to disk -- a notification body is
  the sort of thing a person would not expect to find in a file later. The
  `notifications` widget is a bell with an unseen badge and a popout list; its
  Ask button runs `rmpr ask --notification <n> --review`. Maps to
  `org.kde.plasma.notifications` under the Plasma renderer. The listener runs
  when either the history or AI assist is on. The parser lives in its own
  module (`qs.domain.notifications.events`) for the qmltestrunner reason
  below, and its fixture is a line captured from the real bus.
- **Crash reporting that survives quickshell catching its own crash.** The
  engine traps a fatal signal itself: it writes `~/.cache/quickshell/crashes/
  <id>/` and restarts the shell **in process**. systemd sees nothing -- the
  unit stays `active`, `NRestarts` stays at 0 -- so the `OnFailure=` reporter
  built for exactly this moment never ran, and five real crashes produced five
  dumps and no report of ours.

  That same restart is what makes the fix work: the config loads again, so
  `domain/diagnostics/CrashWatch.qml` runs again and the dump is still there.
  It writes a report bundle with the stack trace and the shell's last log lines
  in it, redacted like every other part, and says so in the journal. It does
  **not** put a window on screen -- a shell that has just come back should not
  open a dialog over whatever the user was doing.

  The whole decision is in the CLI (`rmpr crash check`) rather than in QML, so
  a test can reach it -- and it needed to. The first version kept it in QML and
  got two things wrong: it compared by **identity**, so deleting the recorded
  dump made an *older* one look new; and on a machine with no dumps at all it
  wrote no record, so the very first crash was seeded away as history instead
  of reported -- losing exactly the crash that matters most. Both are tests
  now. The QML runs the command and reacts to what it prints.

  `rmpr crash list|show|remove|since`; `rmpr ask --crash` asks about one, and
  reuses the bundle already written rather than making another. Ownership is
  checked on every path, including when an id is named by hand: the dump
  directory is shared by every quickshell on the machine, and a second shell's
  crash is not ours to read or report.
- **Tests** — 14 shell suites in throwaway HOMEs, a QML suite of 217, and the
  lock screen loaded in Plasma's real greeter. All
  green. Suites touching KDE put fakes for `systemctl`, `kquitapp6`,
  `qdbus6` and `busctl` on PATH and check nothing reached them.
  `test-ask.sh` fakes every provider, the terminal and the shell's IPC, and
  runs on a whitelisted PATH so a `claude` on the host cannot stand in for a
  missing one. `test-crash.sh` builds dumps by hand, including one belonging to
  another shell.

## The Meridian redesign

On `meridian`, nine commits, none of it merged. The mockup is the user's
Claude Design project (file "Meridian Shell.dc.html"), read with DesignSync;
the two standing asks were Material Design colours and a light and a dark
scheme that follow the system.

| commit | what |
| --- | --- |
| `2ba2c82` | the colours: Material 3 roles from one seed, light and dark |
| `1e2bc4a` | the panel: full, floating or islands, on every edge |
| `27cb96f` | quick settings, the calendar, the notification centre |
| `19ffc64` | the built-in start menu in three layouts, and search |
| `877c60b` | the sidebar, the key sheet, the session screen, the OSD, toasts |
| `8323eac` | the settings window, and five new pages |
| `85f465c` | the lock screen |
| `f80456e` | the rounded screen border and the desktop clock |
| `8ef209a` | KDE's colour schemes generated from the same palette |

What it adds, in the terms the rest of this file uses:

- **One palette for everything.** `qs.domain.theme.palette.Scheme` computes
  Material 3 roles from a seed in CIELAB and OKLCH (pure, tested), `Theme`
  turns them into the names every file draws with, and
  `scripts/gen-palette.sh` runs that same scheme offscreen to generate the
  palette Plasma's colour schemes are built from. KDE's applications and this
  shell are drawn from one set of colours rather than two that drift.
  `theme.mode` auto follows the active colour scheme's darkness, live.
- **New surfaces**, each a layer-shell window of its own, each opt-in or
  opened deliberately: the sidebar, the key sheet (read from
  kglobalshortcutsrc, so it shows only what is really bound), the session
  screen (behind `session.prompt`, ending the session through Plasma's own
  session manager), notification popups with two new centred positions, and
  the desktop's rounded border and clock (`desktop.*`, both off).
- **A settings window in the design's shape**, still driven entirely by the
  schema: the navigation is `Schema.sections` in order, so `rmpr settings
  <id>` and the generated reference cannot disagree with the window. Sections
  `panel` and `session` were renamed `taskbar` and `lock`.
- **`rmpr windows behaviour`** (status/set/revert): KWin's focus policy, its
  delays, auto-raise, placement and borderless-maximised keys, ledgered like
  every other KDE key. What KWin does not have -- window gaps, rounded window
  corners, tiling layouts -- is named as absent rather than offered.
- **`rmpr lockscreen set`** and a lock screen in the new look. Plasma's three
  lock settings stay Plasma's; this shell's own live in
  `~/.config/<slug>/lockscreen.conf`, because the greeter's `config` object is
  built from the *desktop* package's config.xml and cannot carry ours.
- **`rmpr sidebar`, `rmpr keys`**, with a desktop entry each, bindable through
  `rmpr shortcuts set`.

What it does not add, deliberately: notifications on the lock screen (the
greeter has none of the shell's memory, and bodies are never written to disk),
window thumbnails (unchanged -- see "Not built yet"), and light and dark
look-and-feel packages (Plasma 6.7.5 has no automatic theme switching to feed
them; its day/night belongs to the wallpaper).

Everything in it was drawn offscreen and nothing has been clicked; see items
23 to 25 under "What to check first".

## Not built yet

- ~~**Tray tooltips.**~~ Built, for every widget rather than only the tray;
  see "Tooltips" under "Working today".
- ~~**AI assist and the notification ring buffer.**~~ Built; see "Working
  today". What is still not built from that plan: a watcher that *notices*
  a failed unit or a core dump by itself. `rmpr ask --failed` gathers them on
  request, and that is as far as it goes -- a watcher that pops something up
  is a notification of our own, which is the thing this project does not do
  uninvited.
- ~~**The lock screen.**~~ Built, and off until tried; see "Lock screen"
  under "Working today". The premise written here was wrong -- Plasma 6's
  greeter does not read the look-and-feel package's `lockscreen/` -- and
  the rest held: a gate of its own rather than `theme apply`, and a way back
  from a console.
- ~~**Opt-in notifications.**~~ Built, opt-in and off by default; see
  "Notifications drawn by the shell" under "Working today". It takes the
  name from nobody but our own hosted Plasma applet.
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
  Icons resolve against the installed desktop entries by id, by id without the
  suffix and by `StartupWMClass` -- 10 of 11 windows here, where guessing from
  the window class alone produced a row of generic placeholders.
- **Icons for windows with no application.** A Steam game's window class is a
  numeric app id and Steam installs a desktop entry for only some titles, so
  nothing can match it -- but the window carries `_NET_WM_ICON`, which is the
  copy Plasma's own task manager draws. The daemon reads it with `xprop`,
  writes a PNG into `$STATE_DIR/window-icons/`, and reports the path; the shell
  prefers a matched application, then that file, then a guess. Needs `xprop`
  and Pillow, and does nothing where either is missing. Verified on WoT
  (`steam_app_1407200`), which has no `steam_icon_1407200` in any theme here.
- **`pgrep -f` and `pkill -f` match the command running them.** Both killed
  this session's own shell while trying to restart the daemon. Use a bracket in
  the pattern (`remappr-shell-window[s]d`).
- **KWin ignores `loadScript` for a script it already has**, so re-running
  `windows enable` after editing the script silently kept the old one running.
  It unloads first now.
- ~~**No window thumbnails, and here is exactly why.**~~ **Wrong, and fixed on
  2026-09-14**: the protocol is restricted, not absent. KWin grants a
  restricted Wayland interface to a client whose **desktop file** names it in
  `X-KDE-Wayland-Interfaces` -- 66 globals without the declaration, 68 with
  it. The shell asks (`share/applications/wayland-interfaces.desktop.in`),
  `plugin/` binds it, and the previews are live. See "Window previews" below.
  What follows is the reasoning that was right about the measurement and wrong
  about the conclusion, kept because the measurement is still true:

  Caelestia renders previews with `org.kde.pipewire`'s `PipeWireSourceItem`
  (kpipewire, installed here) fed by its own compiled QML plugin
  (`~/.local/lib/qt6/qml/Caelestia/libcaelestia-*.so`), which binds the Wayland
  protocol `zkde_screencast_unstable_v1` to turn a window uuid into a PipeWire
  node. Rendering is free from QML; *obtaining the stream* is the part that
  needs the protocol.

  That protocol is **not advertised to ordinary clients on this KWin**: 66
  globals are offered and no screencast interface is among them. It is
  privileged, like `ScreenShot2.CaptureWindow`, which refuses us outright with
  "The process is not authorized to take a screenshot". So a compiled plugin
  alone may well not be enough — whether KWin would grant it to a Quickshell
  process is untested and only testable by building one.

  Which leaves three honest options, none of them a small edit:
  1. **The `plasma` renderer.** `org.kde.plasma.icontasks` is what actually
     draws the previews people have seen "in caelestia" -- caelestia's Plasma
     panel ships it, and plasmashell is a client KWin allows. Our `tasks`
     widget already maps to it, so this works today with no new code.
  2. **A compiled QML plugin** binding `zkde_screencast_unstable_v1`. Not a
     KWin effect -- no root, no KWin ABI -- but it introduces a C++ build to a
     project that has none, and may still be refused by KWin.
  3. **Leave it.** The preview shows the application, its real name, the full
     title and the window's state, which is what is knowable without any of the
     above.

## Known problems

1. ~~**`plasmashellrc` names a shell package that does not exist.**~~ Resolved,
   and since superseded: plasmashell is on `remappr-shell.desktop` and the
   configured renderer agrees with it.

   What replaced it: the service is not enabled -- **by choice**, as of
   2026-09-11. The user runs the shell with `rmpr start` / `rmpr stop` while
   testing, so the panel does not survive a reboot, and that is intended.
   Worth knowing with that workflow: the Plasma applets the shell hosts under
   the quickshell renderer are started detached, so they outlive `rmpr stop`
   -- notifications keep working with the shell stopped -- and the next start
   finds their names owned and does not start them again.
2. ~~**Typing into the built-in launcher only works after clicking it.**~~
   The claim behind this was wrong, in the same way the ToplevelManager one
   was. Quickshell 0.3.1 *does* expose a layer-shell keyboard-focus mode:
   `WlrLayershell.keyboardFocus`, attachable to any PanelWindow, with
   `WlrKeyboardFocus.None | Exclusive | OnDemand`. `focusable: true` is merely
   the OnDemand case, which is why the keyboard only ever arrived after a
   click. A popout that says it needs the keyboard now asks for **Exclusive**,
   which the compositor grants as soon as the surface is mapped; every other
   popout asks for **None** and takes nothing from the window in use.

   Opened purely over IPC with nothing clicked, the search field now reports
   `search has the keyboard`. That is item focus, which is necessary but not
   sufficient -- proving keystrokes actually arrive needs a keystroke, and no
   key-injection tool is installed here. **Worth confirming by hand:** run
   `rmpr launcher` and type.
3. ~~**A crash inside quickshell never reaches systemd, so no report is
   written.**~~ Closed; see "Working today". The finding stands, though, and
   anything built on top of it should know: **the unit staying `active` with
   `NRestarts` at 0 is not evidence the shell has not been dying.**
4. **caelestia's bar is still running alongside ours**, holding Meta, and
   krohnkite is installed, which can fight edge tiling. Both are reported by
   `doctor`. Two bars on screen is a side-by-side development arrangement, not
   a bug — but it is why the screen looks busy.
5. ~~**No window thumbnails in the task preview**~~ -- built on 2026-09-14.
   The privileges KWin "does not give us" are given to any client that asks
   for them in its desktop file.
6. ~~**Some widgets still lay out horizontally on a vertical panel.**~~
   Resolved the same day; see "Side panels" under "Working today".

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
make link     # symlink into ~/.config/quickshell/<slug>; most edits reload
              # live, a widget's own files need `rmpr reload`
make run      # foreground, against the working tree
make lint     # slug, layer and QML lints -- do NOT pipe it, see below
make test     # QML suite plus shell suites in throwaway HOMEs
rmpr doctor   # what is wrong with the installation right now
```

Non-obvious things that cost time to discover:

- **A layer surface cannot take the keyboard AND mask its input region.** On
  KWin 6.7.5, a surface with `WlrKeyboardFocus.Exclusive` *and* a
  `mask: Region` is mapped and then drawn as nothing at all: the window is
  there, the right size on the right screen, the log says so, and the screen
  stays empty. Either alone is fine. The start menu was the only thing in the
  shell that asked for both, and it had never once appeared on a screen. **Any
  offscreen render will hide this from you**: `dev/preview/preview.sh` strips
  both properties to make a layer surface renderable offscreen at all, so the
  menu looked perfect in every picture taken of it across six sessions.
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
- **A Repeater handed a fresh array rebuilds every delegate.** `model:` bound
  to a function call over config produced a new array on *any* configuration
  change, so adjusting the panel thickness destroyed and recreated every widget
  on the panel -- "the taskbar resets when I change a setting". Binding a
  JSON string and reassigning the model only when that string changes fixes it,
  and needs no deep-compare.
- **Replacing a Controls `background`/`handle` with plain Rectangles collapses
  the control.** A `Slider` takes its implicit height from them, so custom ones
  with no implicit size of their own made the whole slider zero pixels tall: it
  drew nothing and there was nothing to drag, and the setting looked broken
  because it was. Give replacements an `implicitWidth`/`implicitHeight`, or the
  control an explicit size. The other controls set their own and were fine.
- **`Grid { rows: 1; columns: 0 }` is not "one row, any number of columns".**
  Zero is not unset -- Qt reads `rows * columns` as the capacity, so a zone with
  two widgets in it warned and laid them out wrongly. The unset value is -1. It
  stayed hidden until a zone held more than one widget.
- **Every line off a bus monitor goes through `core/BusLine.qml`.** It strips
  byte arrays, bounds the length, and answers the questions each listener used
  to ask for itself (is this a signal on that interface, is the payload long
  enough). The three parsers -- OSD, notifications, windows -- all read through
  it, so the fix below is applied everywhere rather than only where it bit.
  Pure, and in `core/`, so those parsers stay loadable by qmltestrunner.
- **`busctl --json=short` renders a byte array as one integer per byte, and
  parsing one segfaults the QML engine.** An application with no icon file
  sends its icon as pixels in an `image-data` hint, `(iiibiiay)`. A 512x512
  icon arrives as a 3.7 MB line holding a million numbers, and `JSON.parse` on
  it inside the read handler takes the whole shell down: SIGSEGV, no QML error,
  nothing in the journal, and a stack that is entirely Qt internals under
  `QQmlBoundSignalExpression::evaluate`. Telegram, Spotify and KDE Connect all
  send icons this way, so it is ordinary desktop traffic -- which is why it
  looked like a shell that crashed at no particular time.

  `BusLine.stripByteArrays` removes any run of 64 or more plain integers
  **before** the line reaches `JSON.parse`; after is too late, since parsing is
  the step that dies. It is a string scan that respects quotes and escapes, so
  a body full of numbers is left alone. Nothing is lost: the only icon read
  here is `image-path`, which is a string. Reproduced first, in an isolated
  shell that did nothing but this pipeline, and the fixed parser now takes a
  15 MB line (1024x1024) and still reports the summary.

  The general lesson, and the reason the guard is shared rather than local:
  **a `SplitParser` line is attacker-shaped input even when it comes from your
  own desktop.** The OSD listener and the window list read the same way and
  were fixed at the same time, before either was the one that crashed.
- **A crash in a signal handler leaves no QML error at all.** The only
  evidence was `~/.cache/quickshell/crashes/`, and the three dumps had
  byte-identical stacks -- which is what made it clear it was one bug and not
  three. Comparing dumps before reading code was the step that paid.
- **Nearest-symbol lookup lies in an LTO build.** Resolving the crash
  addresses against `libQt6Qml.so` named functions up to 10 KB away
  (`changeVTableImpl`, `cleanupDeletedQObjectWrappersInSweep`) and sent the
  first guess in the wrong direction. Reproducing was faster than symbolising.
- **`SystemTrayItem.display()` does not work over layer-shell.** It is the
  obvious way to show an application's tray menu and it fails twice: first with
  "Cannot display PlatformMenuEntry as quickshell was not started in
  QApplication mode", and then, once `//@ pragma UseQApplication` is added and
  the shell **restarted** (a reload is not enough), with "Cannot attach popup
  ... as the popup is not an xdg_popup" and a grabbing-popup warning. A
  platform menu is a QWidget popup needing an xdg parent that has already
  received input; our panel is a layer surface. The pragma was reverted.

  `QsMenuOpener` is the way through: it exposes the DBus menu as a plain model
  of text, icons, check states and submenus, and `widgets/tray/TrayMenu.qml`
  draws it in the widget's own popout. Verified against every tray item on this
  machine -- Steam's game list, Discover, Cachy-Update's four submenus.
- **A QML component cannot instantiate itself** ("TrayMenu is instantiated
  recursively"), and a menu of submenus is recursive by nature. `Loader` with a
  **file name** rather than a type resolves at runtime and breaks the cycle:
  `setSource("TrayMenu.qml", { ... })`.
- **`StartLimitIntervalSec` and `StartLimitBurst` belong in `[Unit]`.** They
  were in `[Service]`, where systemd ignored them -- "Unknown key
  'StartLimitIntervalSec' in section [Service]" in the journal on every start,
  and no start limit actually applied. The unit looked correct and was not.
- **A Quickshell-dependent singleton poisons its whole module for the QML
  tests.** Putting `NotificationWatch` beside `Redact` in
  `qs.domain.diagnostics` made the redaction test fail to compile with "Type
  NotificationWatch unavailable" -- exactly the trap recorded for the OSD, and
  walked into again. Then `CrashWatch` landed in the same directory and broke
  the same test a third time. The rule is now enforced rather than remembered:
  `scripts/lint-tests.sh` reads each test's `qs.*` imports and fails if any
  file in that module imports Quickshell. The pure parts live in leaf modules
  of their own -- `qs.domain.osd.events`, `qs.domain.notifications.events`,
  `qs.domain.diagnostics.redact`.

  Worth noticing about this one: **the test that breaks is not the test that
  was changed**, and the error names the type that was added rather than the
  module that cannot load. That is why it was walked into twice after being
  written down.
- **`git mv -k` silently skips an untracked directory.** It reported nothing
  and moved nothing; the next test run said the module was not installed.
- **`echo "$@"` in a fake terminal eats a leading `-e`.** Fakes that record
  their arguments must use `printf '%s\n' "$@"`.
- **`"$(cat file)"` drops the file's final newline**, so a byte comparison
  between what a provider received as an argument and the bundle on disk is
  off by one byte. Compare with the newline added back.
- **A widget must not define a function named after a `BarWidget` signal.**
  QML refuses the whole file ("Duplicate method name") and the widget silently
  never appears; qmllint cannot see it, because it does not resolve BarWidget.
  `scripts/lint-widgets.sh` checks for it now.
- **The panel was `focusable: true` unconditionally**, which cost a click on
  every widget: clicking an on-demand layer surface hands it the keyboard, so
  activating a window and then taking focus straight back off it looked like
  the first click doing nothing. It bought nothing either -- `openPopout` was
  never assigned, so the key-forwarding it existed for never ran. Now it is
  focusable only while a popout that wants the keyboard is open, and the slot
  assigns `openPopout`.
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
- **A binding on a function call never re-evaluates.** WidgetSlot placed its
  popout with `readonly property real slotX: root.mapToItem(null, 0, 0).x`.
  `mapToItem` notifies nothing, so the binding ran once -- at creation, before
  the zone had positioned the slot -- and stayed 0. Every popout on the panel
  opened against the screen's left edge, whichever widget it came from, for
  as long as popouts have existed; nobody here could click, so nobody saw it.
  `slotX` is taken when the popout opens now. Found by opening popouts over
  IPC and asking the shell where they went (`popout '<id>' on <screen>: left
  N, WxH`, at debug level) after screenshot diffs had failed -- see below.
- **Quickshell's service singletons start lazily.** The first read of
  `Pipewire`, `Bluetooth` or `Networking` comes back empty and fills in a
  moment later. `status audio` straight after start, under the Plasma
  renderer where no widget had touched them yet, reported no output and no
  devices; asked again, it had everything.
- **`quickshell ipc call` reads an argument starting with `[` as a list of
  arguments,** so a JSON array arrives as N arguments and the call is refused.
  A leading space avoids it: `' [{"id":"clock","zone":"middle"}]'`.
- **Screenshots: `spectacle -b -n -f -o file.png` works here; `grim` does not**
  (KWin has no wlr-screencopy). Diffing a closed and an open popout to find it
  fails, because the popout background is the same dark as most windows behind
  it. Ask the shell for the geometry and crop exactly that -- which also keeps
  whatever else is on the screen out of the picture.
- **`plasmawindowed` is a unique DBus service** (`org.kde.plasmawindowed`): a
  second invocation hands its request to the first and exits 0.
- **`$(timeout 5 tail -F log | grep -m1 pattern)` always takes the full five
  seconds.** `grep` exits at the first match, but `tail` only notices when it
  next writes, and the substitution waits for the whole pipeline. Every
  tooltip "failed" to appear because of it -- they were shown for four
  seconds and the screenshot came at five. Poll the file instead.
- **Anchors switched by bindings do not survive the panel changing edge.**
  The zones and the panel surface used `right: horizontal ? parent.right :
  undefined` beside `horizontalCenter: horizontal ? undefined : ...`. When
  the orientation flips, the new anchor can be applied while the old one on
  the same axis is still set, and it is dropped: moving the panel to the left
  edge and back to the bottom left the right-hand widgets off the end of the
  screen until a restart. They are placed with `x`/`y` bindings now, which are
  simply re-evaluated. Found because tooltips were being clamped to the screen
  edge -- their slots had left it.
- **A Plasma service that looks like plasmashell's may belong to an applet.**
  Notifications and Klipper both run inside plasmashell's process, and both
  exist only because an applet in the system tray loaded them. Check with the
  libraries' `NEEDED` entries (`readelf -d`), not with `busctl status`, which
  only says which process holds the name today. The same question is worth
  asking of anything else Plasma's tray hosts: device notifier, keyboard
  layout, brightness.
- **Switching shell packages live leaves the old tray's services behind.**
  Found by the user's first real test of the hosting: after `renderer set
  quickshell` from caelestia's layout, plasmashell -- switched with
  `changeShell`, not restarted -- still owned `org.freedesktop.Notifications`
  and `org.kde.klipper`. Both are process-wide singletons the previous tray's
  applets created, and they outlive the applets. With no notifications applet
  loaded, plasmashell accepted `notify-send hello` into its history and drew
  no popup; the shell, seeing the name taken, rightly refused to start a
  second server. `renderer set quickshell` now restarts plasmashell when it
  still holds either name, and `rmpr doctor` calls plasmashell holding them on
  our package a problem. Owning a bus name is not the same as doing the job.
- **Seeing a method call on the bus proves nothing about who answered it.**
  The notification history recorded every `Notify` call through a whole
  session in which nobody owned the name; the calls went out, and nothing
  received them. `busctl --user status <name>` at the time says whether
  anyone could have.
- **dbus-broker ignores a second activation file for the same name.** With
  both mako and Plasma installed, mako's file wins -- and mako's unit refuses
  to start on KDE. Where two activation files claim a name, read the journal
  for "Ignoring duplicate name" before assuming either works.
- **Right after the panel changes edge, everything is mid-animation.** The
  panel's thickness animates over 120 ms, and the surface is placed from the
  window's width, so `panel layout` asked straight after a switch to the left
  edge put every widget at x = -36; 0.13 s later all were where they belong.
  Poll until it settles before believing a measurement -- or a screenshot.
- **A Grid's `rows` and `columns` change one at a time.** Flipping `rows: 1,
  columns: -1` to the reverse passes through 1 x 1 and warns that the zone
  holds more than fits -- and so does swapping `rows: 1, columns: N` for
  `rows: N, columns: 1`, whichever updates first. Only `columns` is set now,
  so there is no second property to be out of step with. It counts the slots
  actually *shown*: counting entries kept an empty column for the hidden
  battery, and the zone sat ten pixels off its edge.
- **Anything a DBus service ties to the caller's connection cannot be done
  with busctl.** KWin's `NightLight.inhibit` is the example: the inhibition
  lasts exactly as long as busctl does. Look for a shortcut or action that
  the service itself carries out -- kglobalaccel's `invokeShortcut` on
  `/component/kwin` did it here -- before writing a helper whose only job is
  to hold a connection open.
- **The test suite restarted the real shell, on every run.** `test-update.sh`
  runs `update.sh` against a copy of the repo in a throwaway HOME, and
  `update.sh` ends by restarting the unit when it is active. A HOME does not
  sandbox systemd: that was the user's own running shell. On 2026-09-11 the
  journal shows it stopped and started seven times, each at a `make test`,
  some while the user was playing a game. Nothing reported it. `NRestarts`
  stays at 0 for a restart asked for by hand, and it looked like a live
  reload. It was found only because the shell's PID had changed.

  Now `update.sh` restarts only with a session (`NO_SESSION_VAR` unset), and
  so do `install.sh`'s `daemon-reload` and bus `ReloadConfig`.
  `scripts/test.sh` exports the switch for every suite, rather than trusting
  each one to. `test-update.sh` checks that the update said it was not
  restarting, and the whole suite was run once with the unit's start time
  compared before and after. **A throwaway HOME is not a throwaway session**
  was already written down in this file, for `changeShell`. It needed
  enforcing, not remembering.
- **Quickshell's PipeWire link API is half live.** Each of these was found by
  running a throwaway config in the scratchpad, not by reading the docs:
  - An ObjectModel's `values` is a Qt sequence, not a JS array. Its `filter`
    returns another sequence, and that one has no `flatMap`, so a binding
    using it throws "is not a function" on every change and nothing lints it.
    Use `Array.from(model.values)` first.
  - A node's `properties` arrive only while the node is tracked, and only
    when it is tracked as an element of `Pipewire.nodes`. Tracking the same
    node reached through `linkGroup.source` left all 20 unbound.
  - `PwLinkGroup.state` reads "unlinked" whatever is tracked. `PwLink.state`
    reads active or paused once `Pipewire.links` is tracked.
  - Once bound, a capture stream's `description` is empty; the application
    is in `properties["application.name"]`.
  - `type` (`AudioInStream`, `AudioSink`, `Untracked` for PipeWire's own
    `/Internal` streams) and `name` are there without binding anything.
- **Check what is on screen before taking a screenshot or clicking the
  panel.** The first screenshots of the brightness popout caught a
  full-screen game on DP-2, which hid the panel entirely, so they proved
  nothing -- and the IPC clicks, the 1% dim and the Night Light toggle had all
  happened while the user was playing. `panel layout` and `status` answer
  most questions without putting anything on screen.
- **Quickshell does not watch a widget's files.** It reloads for files the
  config imported when it loaded -- touching `BarWidget.qml` reloads at once
  -- and not for a widget's own `Widget.qml`, which `WidgetHost` loads later
  with `Loader.setSource`, nor for a singleton only a widget uses
  (`Desktops.qml`, first used by the show-desktop strip). Edits to both sat
  unloaded for minutes while the shell looked current; the tell was a
  `gdbus monitor` on `/KWin` that should have been running and was not.
  After editing a widget, run `rmpr reload`. This is also what the previous
  session's "a Write failed to trigger the reload" was: it was a widget
  file, and the observation was right before it was called wrong.
- **The shell-restart fix had a twin.** `shortcuts.sh` restarted
  `plasma-kglobalaccel.service` after every write, with no session check,
  and `test-shortcuts.sh` writes three times and reverts once: four restarts
  of the user's global-shortcut server per `make test`, in the journal at
  each run. `edges.sh` asked the real KWin to reload the same way.
  `session_available` is now defined once, in `brand.sh`, and both suites
  put fakes for `systemctl`, `kquitapp6`, `qdbus6` and `busctl` on PATH and
  check that nothing reached them. The question to ask of any new script:
  what here reaches the running desktop, and is it behind the check?
- **Rendering a page without a screen.** Copy `shell/` into the scratchpad,
  put a `preview.qml` at its root that shows the page in a `FloatingWindow`
  inside a `Rectangle`, run it with `QT_QPA_PLATFORM=offscreen`, and
  `grabToImage` the Rectangle after a few seconds. The window's
  `contentItem` refuses ("item has no QML engine"). The page's processes
  still run, so it draws real data, and nothing appears on the user's
  screen -- used here because a Meet window was open.
- **jq's `@tsv` is not a transport.** It escapes a tab inside a field as a
  literal `\t`, and `read -r` keeps the backslash. `kconfig_revert` read
  the ledger that way, so a two-key shortcut came back from a revert as one
  key with a backslash in it. Fields travel base64-encoded now. Anything
  else that round-trips values through `@tsv` and writes them back has the
  same bug; `doctor.sh` only displays them.
- **A sandbox HOME still reads the real kdedefaults.** kreadconfig6 falls
  back through `XDG_CONFIG_DIRS` for an unset key, and on Plasma the first
  entry is `~/.config/kdedefaults` -- an absolute path. The switcher suite
  read this machine's `big_icons` as the Alt+Tab layout of an empty
  sandbox. `scripts/test.sh` pins `XDG_CONFIG_DIRS=/etc/xdg`.
- **kglobalaccel keeps two formats in one file**, and a line of ours was in
  neither: `_launch=Meta+Shift+R, , Settings` is what kglobalaccel made of
  our "key,none,label" in a `[services]` group. It worked only because it
  took the first field. Read a line's neighbours before deciding its
  format.
- **kglobalaccel says what it registered.** `allComponents` on
  `/kglobalaccel`, then `allShortcutInfos` on a component, gives each
  action's keys as Qt key codes (301989970 is Meta+Shift+R): the way to
  check that a binding in the file actually took, without pressing it.
- **Quickshell's NotificationServer waits for the name.** A second server
  logs "Could not register ... Registration will be attempted again if the
  active service is unregistered", and does. So a server can exist while
  another program holds the name without fighting it -- which is also how
  caelestia's bar got the name first on 2026-09-11.
- **A private bus is not private from what it activates -- and it broke the
  real desktop once.** `dbus-run-session` gives a throwaway session bus,
  the right place to try a notification server. But whatever the code
  under test starts there activates more. PlasmaServices hosted
  plasmawindowed before the probe switched hosting off, which brought up
  kactivitymanagerd, xdg-desktop-portal, ksecretd and the document portal;
  four outlived the session, and a pipe they held open hung the command.
  Worse, the user's **real** `xdg-document-portal.service` exited (status
  21) at 18:51:42, in the same second: the document portal's FUSE
  mountpoint, `/run/user/1000/doc`, is the same path whichever bus a copy
  of it runs on. Flatpak apps lost portal file access until it was noticed
  in the journal ten minutes later and restarted by hand (`systemctl
  --user start xdg-document-portal.service`, after checking the
  mountpoint was a clean empty directory). The rule: on a private bus,
  nothing may start Plasma applets or anything else that activates
  services -- a probe config sets `services.hostPlasma` false before
  anything loads -- WAYLAND_DISPLAY is unset, and afterwards check
  `systemctl --user --failed` and look for processes whose
  DBUS_SESSION_BUS_ADDRESS is a /tmp/dbus-* path.
- **`make test` opened windows on the desktop, and a locked screen made it
  ten times slower.** On Wayland, qmltestrunner opens a real window per
  test file and waits up to five seconds for it to be shown; with the
  session locked it never is. The suite went from five seconds to fifty,
  every file exactly 5.1 -- measured, with `LockedHint=yes` at the time,
  and 39 ms per file offscreen. The QML tests run offscreen now: they are
  pure functions, and a suite has no business drawing on the screen of the
  person running it.
- **A killed probe still reports.** Restarting a Process kills the one in
  flight, and its StdioCollector still delivers what it had. PlasmaServices
  acted on that, so a partial list could read Klipper's name as free. A
  probe whose output decides anything ends with a sentinel line now.
- **A test that references nothing tests nothing.** The first hand-over run
  found nothing: the probe config never touched the singletons, so they did
  not exist until its last IPC call. Reference what shell.qml references.
- **`image://icon/<name>` has no fallback.** The notification server hands
  an icon sent by name over as that URL, and a name the theme lacks drew
  Qt's magenta checkerboard. It is looked up as a name instead.
- **`kscreenlocker_greet --testing --shell <path>` is a harness.** With
  `QT_QPA_PLATFORM=offscreen` and no bus it loads a package from any path,
  sets every context property and draws the real wallpaper, and
  `grabToImage` on the root gives a picture of it. Set
  `QT_FORCE_STDERR_LOGGING=1`, or its QML messages go to the journal and
  the output looks empty.
- **A greeter stopped mid-authentication is a failed login.** Twice on
  2026-09-11 a check loaded the lock screen with the real authenticator, a
  bug woke the prompt, the prompt started PAM, and the check's timeout
  stopped the greeter: `pam_unix(kde:auth): authentication failure`, and
  pam_faillock counted both -- three lock the account for ten minutes.
  Checks now use a stand-in authenticator and fail if anything starts one.
  `try` timing out still costs one, and says so before it starts.
- **The greeter takes the keyboard in testing mode too.** On Wayland it is
  a full-screen layer surface with exclusive keyboard, test or not, so
  `try` has a hard timeout: a lock screen that could not unlock would
  otherwise trap its own test, with the terminal out of reach.
- **`HoverHandler.onPointChanged` fires with nothing moving** --
  continuously, in the greeter. The lock screen woke on it, so the prompt
  never went idle, and each wake started PAM. Compare positions.
- **Kirigami.Avatar is not in Kirigami since KF6** (it moved to
  kirigami-addons, not installed here). qmllint warned; the greeter refused
  the file and drew its built-in locker.
- **Plasma's `VirtualKeyboardLoader` needs the StackView's id to be
  `mainStack`.** Its `PropertyChanges { mainStack.y: ... }` resolves the name
  as an id through the creating context, not as its own property of that
  name; with any other id it warns, and the on-screen keyboard never moves
  the prompt out of its way.
- **A `layer.effect` shadow on the clock drew nothing** in the offscreen
  greeter, so the lock screen's text carries its own (`Text.Raised`).
  Which GPUs share that was not worth learning on a lock screen.
- **`Qt.formatDate(d, Locale.LongFormat)` is not a long date.** The second
  argument is a `Qt.DateFormat`, and 0 is `TextDate` ("Fri Sep 11 2026").
  `d.toLocaleDateString(Qt.locale(), Locale.LongFormat)` is the locale's.

- **`font.pixelSize` must be an integer, and qmllint does not say so.** A
  `12.5` refused the whole file at load ("Invalid property assignment: int
  expected") and took every page that imported it with it. The linter passed
  it; the first offscreen render caught it.
- **A Loader resizes what it loads.** A switch put straight into one is
  stretched across the whole control slot and reads as a bar rather than a
  switch. Wrap anything with a size of its own, and let sliders and text
  fields fill it.
- **quickshell does not act on `Qt.quit()`** -- the engine logs "Signal
  QQmlEngine::quit() emitted, but no receivers connected" and keeps running.
  A script that reads a value out of QML has to stop it with a timeout, and
  must write to a file rather than a pipe: `timeout N quickshell ... | grep`
  waits out the whole timeout and then fails on it under `pipefail`.
- **The greeter's settings are not the drawn package's.** kscreenlocker builds
  the `config` object from `org.kde.plasma.desktop`'s `lockscreen/config.xml`,
  whatever package it is drawing, so a key added to ours never appears. Its
  values live in kscreenlockerrc under **`[Greeter][LnF][General]`** -- the
  kcfg's own group nested inside the greeter's -- which was found by giving a
  throwaway HOME a config and asking the real greeter what it got. Anything of
  ours has to be read from a file of our own instead.
- **The lock screen package must be a verbatim copy of its source.** `try`
  records the hash of the copy it showed and `status` compares it with the
  source, so rendering a template into the package -- which seemed a tidy way
  to give the greeter a path -- made `enable` refuse every build. Generated
  files belong in the source tree, beside Branding.qml.
- **`lint-slug.sh` only sees tracked files.** A test with the project's name
  hardcoded passed the lint for as long as it was untracked, and failed the
  build the moment it was committed.
- **A preview of the settings window reads the installed schema.** `Schema` and
  `Paths` name `Branding.dataDir`, which is the installed copy, so a preview
  run against a worktree shows the *other* tree's pages until those two paths
  are repointed. The same goes for `Branding.ctlBin`: a page that shells out
  runs the installed CLI unless the preview points it at the worktree's.

## The plan

`~/.claude/plans/in-this-project-i-cryptic-horizon.md` holds the full approved
plan, including the sections not yet built.

## Where the second session of 2026-09-10 left off

Seven commits, `e2b3957..HEAD`, 44 files, about 4,300 lines added. In order:

| commit | what |
| --- | --- |
| `0c4f3d6` | AI assist (`rmpr ask`) and the notification history |
| `525b887` | the crash: a notification carrying an icon took the shell down |
| `baaa528` | notice a crash quickshell caught and systemd did not |
| `07531bb` | bound every line off the bus, not just the one that crashed |
| `7e61506` | the first crash on a fresh install was never reported |
| `737cbcb` | a tray you can curate, with menus that open |
| `7cf9e7e` | open the settings window on a page |

The shape of the session is worth knowing, because two of those commits exist
only because of the first one: a feature landed, it crashed the shell five
times, the fix exposed that **nothing was reporting the crashes**, and closing
that exposed two bugs in the closing. Each step was found by reproducing rather
than by reading, and each ended as a test.

Nothing is half-finished. `make lint` and `make test` are green, `rmpr doctor`
reports no problems, and the six items under "What to check first" are things
no session here can do rather than things left undone.

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

## Where the session of 2026-09-11 left off

Five commits. The fifth, and the one that matters most: under our renderer
nobody was receiving notifications at all; Plasma's own notifications and
clipboard applets are now hosted outside the panel. The fourth: the
clipboard widget, after finding that our renderer leaves the desktop with no
Klipper at all. The third: the media
widget, and every built-in widget drawn properly on a side panel. The second: tooltips for every widget; `EdgeWindow`, which
places both popouts and tooltips on any panel edge; and the panel no longer
coming apart when its edge is changed while it runs (bottom → left → bottom
now leaves it exactly as it was, compared by screenshot). The first:

- The four status widgets, their services, 20 QML test cases, and their
  place in the defaults and presets. Verified on the live desktop in a second
  copy of the shell drawing a runtime-only panel: the icons on the panel, all
  three popouts drawn with real data -- output and microphone at 100%, three
  outputs, wired at 2.5 Gbit/s and Wi-Fi at 80%, six paired devices with the
  keyboard's battery -- and the battery widget taking no room. Writes are not
  verified; see items 7-10 under "What to check first".
- The Plasma renderer no longer draws tray applets twice. Seven new checks in
  `test-renderer.sh`.
- The popout placement bug, which predates this session and affected every
  popout on the panel.
- `panel click`, `status` and `config setRuntime` over IPC.

After those, three more: the device notifier hosted too; the service left
disabled on purpose (the user starts and stops the shell by hand while
testing); and the fix the user's first real test turned up -- a live switch
to our renderer left plasmashell holding the old tray's notification server,
so `renderer set quickshell` now restarts plasmashell when it does.

The machine ended the day on our renderer, with caelestia's bar still
running and holding notifications. See the table at the top.

## The second session of 2026-09-11

Two widgets, for the two indicators Plasma keeps in its tray that still had
nothing standing in for them under our renderer: `brightness` (with Night
Light) and `keyboard`. See "Working today". Before either was built, every
other tray applet was audited for a service it might be quietly providing,
as the notifications applet had been; none was.

Verified live, without a pointer and without writing to disk: both services
read the real machine (two DDC monitors, Night Light `day` with "Warmer from
19:34", one layout); powerdevil accepted and applied the writes; the OSD
stayed down; the Night Light toggle went round and back; the brightness
widget laid out at 24x24 beside the tray, and the keyboard widget took no
room. The runtime layer that put them on the panel for that check has been
cleared. The popout has never been seen; see item 15 under "What to check
first".

Then a third: `privacy`, the camera and microphone indicator, after finding
that Chrome was recording with nothing on screen to show it. The rule was
right the first time and the tests passed; the live answer was still empty
until three Quickshell PipeWire behaviours were pinned down in a throwaway
config (see "Non-obvious things"). It was written at the time that a
wholesale `Write` of a QML file had failed to trigger the live reload, and
then that this was wrong, because the "reload" that brought the new code in
was the test suite restarting the whole shell. Both were true. The file was
a widget's, and Quickshell does not watch those -- measured in the third
session; see "Quickshell does not watch a widget's files".

Then the user's report: popouts too small for their contents, none closing on
a click elsewhere, and taskbar buttons that never asked for attention. See
"Popouts behave like menus" and "Taskbar buttons ask for attention" under
"Working today", and item 16 under "What to check first".

Then the active-window widget, which finishes Phase 2 of the plan, and the
task list's per-monitor option that the same data made cheap. Then task
buttons that behave like Windows': minimise on the active one, middle-click
for a new instance, a right-click jump list, and pinned applications.

## The third session of 2026-09-11

Picked up §D of the plan, the one part of it with a CLI and no page. In
order:

| commit | what |
| --- | --- |
| `37b8fc1` | the test suite restarted the user's global shortcuts |
| `fd693af` | a settings page for the screen edges; the master switch reversible on its own; the dead `desktopgrid` key |
| `604b919` | peek at the desktop, and a strip that knows whether it is showing |
| `91cd1ca` | `rmpr reload`, for the widget edits Quickshell does not see |
| `988c7a3` | doctor warned about KWin scripts that were not running |
| `153a9fc` | a revert that turned a tab into a backslash; the suite reading the real kdedefaults |
| `c594525` | shortcuts said they took a key from its holder, and did not; and wrote the wrong format |
| `b78bb38` | Alt+Tab and Meta+Tab, and who holds them |
| `e123ab6` | the application style, and the theme's missing parts |
| `135e990` | notifications drawn by the shell itself, when asked |
| `e749875` | a probe cut short could host a second Klipper; notifications handed over from our own hosted applet |
| `8f0790c` | `make test` drew windows on the desktop, and stalled on a locked screen |

The fixes were all found while building the features, and each by
measuring: the kglobalaccel restarts were in the journal at the times of
`make test`, the stale widget was a monitor process that should have
existed and did not, and the mangled tab was a byte comparison failing in
the new suite.

One experiment did damage. A private-bus test of the notification
hand-over took down the user's real document portal at 18:51:42; it was
found in the journal ten minutes later and restarted. See "A private bus is
not private from what it activates" for how, and for the rule that keeps it
from happening again. The shell's PID was the same before and after every
test run this session (611253).

Nothing was clicked and nothing was put on the user's screen: a Meet window
was open, so the settings page was rendered offscreen instead. Items 17 and
18 under "What to check first" are what needs a pointer.

§D, the widget style from §C and Phase 8's notifications are complete
apart from what needs a pointer or a person (items 17-21). The
notifications were built opt-in and off by default after the user said
"continue"; nothing on this machine uses them yet.

The lock screen, the last of the plan, followed in a fourth session. The
colours-only desktop theme already stands in for the "SVG desktoptheme".

## The fourth session of 2026-09-11

The lock screen, built and not turned on: `try` and `enable` are the
person's to run (item 22 under "What to check first"). The premise was
measured before anything was written, and was wrong -- see "Lock screen"
under "Working today". The real greeter, run offscreen, found three things
nothing else would have: a type missing from KF6 (it drew its built-in
locker instead), a clock whose shadow layer drew nothing, and a prompt that
woke itself.

That last one did harm. While a check held the real authenticator, the
prompt woke, started PAM, and the check's timeout stopped the greeter: two
failed logins recorded against the user's account, at 19:32 and 19:42, one
short of pam_faillock's lockout. Found by reading `faillock` after the
checks -- a precaution taken because the rule written at the start of the
session was "never send a wrong password", and stopping a conversation
turned out to be one. Checks cannot reach PAM now. faillock was empty
again by 19:48.

Nothing was put on the screen: every picture was taken offscreen.

## The redesign sessions, 2026-09-11 to 2026-09-12

Six sessions, all in the worktree `~/Projects/remappr-shell-meridian` on
branch `meridian`, cut from `main` at `1a0b10c`. The main tree was not
touched, and nothing was merged: the user asked for one commit per phase and
kept the merge for themselves.

*(Read as history. The merge happened on 2026-09-13 and the worktree has since
been removed; `dev/preview/` and `docs/meridian-handoff.md` were copied into
the main tree first, and are still untracked there.)*

The shape of it: the mockup was read with DesignSync rather than described,
each phase ended green (`make lint`, `make test`, and for the lock screen
`lockscreen check` in Plasma's real greeter), and every screen was rendered
offscreen and looked at before being called done -- the panel and its popouts
through `dev/preview/preview.sh`, the lock screen through the greeter itself
with a stand-in authenticator. Nothing was put on the user's screen, and no
notification, password or KDE key was written outside a sandbox except the
two colour-scheme files the build generates.

Four things were measured that contradicted an assumption, and each changed
what got built rather than being worked around: the greeter cannot be given
settings through its own package; a lock screen package must stay a verbatim
copy or the try gate refuses it; Plasma has no automatic light/dark theme
switching, so no packages were built for one; and `font.pixelSize` refuses a
fraction at load, which qmllint does not catch. They are all under
"Non-obvious things".

*(The third still holds -- Plasma has no light/dark switch. What changed on
2026-09-13 is that the shell stopped needing one: KWin's Night Light already
knows when night is, and `theme.mode: auto` follows it.)*

What was left then was a person's, and most of it was done on 2026-09-13: the
branch was merged, the redesign ran on both screens, and the lock screen was
tried twice with a real password. See "The session of 2026-09-13" at the end of
this file for what that found, and items 23 to 26 under "What to check first"
for what is still unseen.

## The session of 2026-09-13: merged, and met a screen

The redesign was fast-forwarded onto `main` and run on the user's two monitors.
**Every bug below was found by looking at it or by the user using it**, and the
suite was green throughout: 306 QML cases passed before the session and passed
after every one of these was fixed. That is the whole lesson of the day.

Eleven fixes, in the order they were found. The last three came from a sweep
of every command, every IPC call and every surface, run at the end of the
session because "what else has never been looked at?" is a question worth
asking once the answer stops being "all of it":

1. **`make run` named no tree, so nothing counted it as running** (`fe58850`).
   `1eae99a`, the session before, had taught every check to recognise a shell
   run from a checkout -- and tested it against an absolute command line the
   Makefile never produced. The recipe passed `shell/shell.qml`, relative. So
   the bug it fixed was still there. The recipe names `$(CURDIR)` now, and the
   test reads the recipe rather than an invented string. The suite also stubs
   `pgrep`: its sandbox gave every script a throwaway HOME while the process
   list still answered for the real machine, so the refusal test passed or
   failed depending on whether whoever ran it had `make run` going.

2. **A popout's shadow kept the card's shape** (`32ab44d`). Reported as "the
   popup from the taskbar have some kind of a second popup behind". At 0.45
   alpha in dark the blur never faded far enough to stop being a silhouette, so
   a rounded card's shadow read as a second rounded card. The mockup casts
   these at .26 to .34; the dark shadow is 0.28 now. The window was also too
   small for the shadow it asked for -- margin 28 against blur 40 and a 12px
   drop -- so the blur was cut square against the window's edge. The margin is
   derived from the blur and the drop now.

3. **The notification centre opened as a small round blob** (`5f47904`).
   Reported as "first click shows round nothing, second time it shows the
   list", and dismissed in this session as a capture artefact before the user
   insisted -- they were right. The window is sized from its content's implicit
   size on the frame it is shown, and this was the one widget whose popout was
   a bare `Column`. A Column has no implicit width until its children have been
   laid out, and the card's radius is clamped to half the smaller side, so the
   first opening drew a circle. Every other widget's popout is an `Item` that
   states its own width. Measured at the moment the window is shown: 144x208
   before, 528x208 after.

4. **Every IPC command asked the installed shell, never the running one**
   (`49ac51e`, then `995fa1b`). `rmpr settings` answered "No running instances"
   with the settings window's own shell on screen, because the socket is keyed
   by the config path the shell was started with and all nine IPC commands
   named the installed path outright. The first fix knew two paths, the
   installed copy and this tree -- and the shell being run at the time was in a
   *third*, the worktree, so it went on failing after the fix was installed.
   The second fix asks the question of the path: any `<tree>/shell/shell.qml`
   with a `branding.json` two levels up naming this slug.

5. **An icon given as a path was looked for inside qrc** (`9bdc370`). A bare
   path is not a URL, and Qt resolves one against the base URL of the component
   that uses it -- for a type from a module, inside `qrc:`. So an absolute path
   off the bus became `qrc:/home/...` and drew nothing: every Spectacle
   screenshot notification had a blank icon. `Paths.fileUrl` does the
   conversion, encoding each segment, and `PanelIcon` puts everything through
   it rather than the next caller having to remember.

6. **Choosing a setting's default value did nothing at all** (`d871ac2`). The
   user: picking "auto" for the theme left it on light, and "some other actions
   in the settings are behaving the same". The profile is a sparse delta, so a
   value returning to its default *removes* its key -- and `ConfigStore`
   compared the parsed file (which carries `schemaVersion`) against its own
   copy (which has it stripped on load) to decide whether the file had moved.
   Never equal. Every write took the merging path, and the merge put back the
   key the write had just removed. The log said so fifty times over one
   afternoon. The comparison is made on one shape now, dropped keys are
   remembered and re-dropped after a merge, and the decision is a pure function
   beside `Hosting`, in its own module so a test can import it without pulling
   `Quickshell.Io` in after it.

7. **A setting that was off read back as on** (`cda709d`). `config_get` used
   jq's `//`, which takes its right-hand side when the left is false as well as
   null, so `.x // true` answered "true" for a setting deliberately turned off.
   Latent -- every existing caller wanted a string -- and it would have made
   every checkbox in the next commit impossible to untick.

8. **The theme themes the desktop, by parts the user chooses** (`f3be17b`).
   Asked for: picking this shell's theme should change KDE's global theme, with
   checkboxes for what it affects, defaulting to everything. `theme apply` now
   writes the colour scheme, icon theme, widget style, Plasma theme, window
   decorations and Alt+Tab switcher unless told otherwise; `theme.desktop` holds
   one switch for the lot and one per part; a part left off keeps what System
   Settings says. The parts are declared once, as `# part:` markers in the
   look-and-feel `defaults`, so the checkbox, the key written and what `theme
   status` prints cannot drift. In Settings → Appearance and in the wizard.

9. **The start menu opened a window and drew nothing in it** (`31286ef`). It
   had never worked on a screen, in any session. See the first entry under
   "Non-obvious things": exclusive keyboard focus and an input mask on one
   layer surface, and KWin maps it and paints nothing.

10. **The session screen could only be opened from the settings window**
    (`73dde8e`). Its IPC takes a required argument, so `ipc call surfaces
    session` is refused outright and the `kind || "promptAll"` inside the
    handler never runs -- which looks exactly like a broken session screen
    from a terminal. `rmpr session [kind]` now exists and always passes one.
    The overlays log when they come up, which is how "it never appears" was
    told apart from "it appears and something closes it".

11. **The preview harness pointed at a worktree that no longer exists**
    (`6cb1aad`). It had the path hardcoded, so removing the worktree broke
    every offscreen render, and it never deleted the copy of the shell it
    makes per run -- 550 files of leftovers. It is committed now rather than
    living untracked in a directory that nearly went with the worktree.

And one feature, asked for by the user after the theme work (`d7f5147`):
**`theme.mode: auto` is light by day and dark by night**, on KWin's Night Light
schedule -- `daylight` on `org.kde.KWin.NightLight`, the same sunset that warms
the screen. Plasma has no automatic light/dark switching of its own, which this
file had said and which remains true; Night Light is simply the one thing that
already knows when night is. With it off, auto means what it meant before.
Writing it turned up the same trap `f094923` did: `known` was read from
`DbusProperty.available`, which is set one statement before the value, and a
binding re-evaluated between the two statements said "night" on every start.

### What was measured rather than assumed

- **Two shells do not clobber each other's config.** Run side by side, with the
  file replaced by `mv` underneath them, both picked the change up within three
  seconds. The theory that a stale second shell had been rewriting
  `panel.renderer` is dead; see item 25.
- **Spectacle is not broken and it was not us.** Its global shortcut is
  `_launch=none` in `kglobalshortcutsrc`, nothing in this project writes that
  key, our ledger holds one entry (`Meta+Shift+R` for settings), and nothing
  else holds Print. The CLI drove Spectacle perfectly all afternoon.
- **The user's "two taskbars" were two checkouts**, not two shells: `make run`
  in `~/Projects/remappr-shell` before the merge built the pre-redesign shell
  (18 widgets, 52 qmldirs) beside the redesign running from the worktree (22
  and 69).

### The switchers, and where they stand

**Alt+Tab has two implementations now, and a setting that picks.**
`switching.windows` is `plasma` (the default, and what the machine is left on)
or `shell`; `rmpr switcher use plasma|shell` writes it and moves the key with
it.

- **plasma** is KWin's own switcher drawn by `theme/windowswitcher`, rewritten
  to the Meridian design this session. It is the only one that can show a
  picture of each window: `KWin.WindowThumbnail` is rendered by KWin for its
  own layouts and is available to nothing else. **Its box has never been seen
  on this machine** -- Alt+Tab switches windows silently. `ShowTabBox` is now
  explicitly `true`, KPackage lists the package, the metadata is right, KWin
  logs no QML error, and `dev/preview/switcher.sh` loads the file cleanly
  against a stub of KWin's own type -- checked again on 2026-09-13 with a
  fresh stub, which found only that the stub needed a default property, the
  file itself loading without a single error. Still unexplained.

  **KWin logs nothing here by design**, which is why there is no error to
  find: a layout that fails to load is reported with `qCDebug(KWIN_TABBOX)`,
  off unless the category is turned on, and the category is read at KWin's
  startup. So "no QML error in the journal" is not evidence of anything.

  Two things to try, in this order, both needing a person:
  - **Press Alt+`** (Walk Through Windows of Current Application) with two
    windows of one application open. It is still KWin's, it uses the *same*
    layout, and it does not need Alt+Tab back to test. If no box draws there
    either, KWin's tabbox is not drawing at all and the layout is innocent.
  - Then a stock layout (`rmpr switcher layout big_icons`) and the same press.
    If big_icons draws and ours does not, the difference is our package -- and
    the first suspect is that this KWin started at 15:46 on 2026-09-13 and the
    package was installed at 19:45, four hours later, so a re-login is the
    thing to rule out before anything is rewritten.
- **shell** is `shell/features/switchers/WindowSwitcher.qml`, the design's
  card row drawn by this shell, which **works**: `rmpr switcher show` puts it
  on screen, and there is a screenshot of it in this session's scratch. It
  cannot show window pictures -- that needs the screencast protocol bound in
  C++ and fed to PipeWire, which is what caelestia's
  `libcaelestia-servicesplugin.so` does. **It now has the key**: as of
  2026-09-13 `rmpr switcher use shell` is what this machine is on, Alt+Tab and
  Alt+Shift+Tab belong to this project's kglobalaccel component, and the
  component is active -- see "Global shortcuts" below.

  A repeated press while it is up cannot arrive as a key: KWin takes a global
  shortcut before any client sees it, so the second Alt+Tab never reaches the
  surface even though the surface holds the keyboard exclusively. It comes
  back as another call to `surfaces switcher` instead, and
  `Surfaces.windowSwitcherTick` turns that into a step. Alt+Shift+Tab is a
  second action, `switcher-reverse`, for the same reason: by the time the call
  arrives there is nothing left to say which of the two keys was pressed.

**Meta+Tab is KWin's Overview and cannot be restyled.** Overview is compiled
into KWin -- `/usr/share/kwin/effects/` holds one scripted effect, `cube`, and
nothing else -- and KWin 6.7 removed desktop TabBox layouts, so there is no
`desktoptabbox` directory to put a package in. The design's Desktops switcher
has to be an overlay of ours, on the same pattern as the window one. Not
built. Everything it needs exists: each window record carries `desktops`, and
KWin publishes the desktop list on `org.kde.KWin.VirtualDesktopManager`.

### The sweep at the end of the session

Every read-only CLI command (17), every IPC function (53, across 14 handlers),
`rmpr doctor`, and all 19 settings pages were exercised, and every surface the
shell can draw was either put on the screen or rendered offscreen. Two things
were broken and are fixed above; everything else drew what it should.

Worth knowing when reading a status source: **the first read of one is cold**.
`status audio` answered `ready: false` with empty fields, and a second read a
moment later had the USB interface, every output, and the levels. Same for
bluetooth (`present: false`, then "1 device") and the DDC displays. They poll
on demand. A script that reads one once and believes it will be wrong.

What is built, works, and is simply **not turned on here**:

- **The shell's own notification popups.** `notifications.server` is `plasma`,
  so Plasma draws them and ours are unused. They render correctly -- actions,
  a critical border, the lot. Turning them on takes the bus name from Plasma's
  own applet, which is why it is opt-in.
- **Fifteen status widgets.** Quick settings, volume, network, Bluetooth,
  battery, brightness and night light, keyboard layout, media, clipboard,
  search, session, task view, virtual desktops, active window, camera and
  microphone in use. All in the defaults and the presets, none in this
  profile; Settings → Widgets lists them. Quick settings was rendered and is
  live -- the joined Wi-Fi network by name, Bluetooth "1 device", Night
  Light "Suspended".
- **The desktop clock and the rounded screen border**, both off by default.

### Global shortcuts: what was wrong, and what was done about it

**Nothing this project bound had ever reached a key press on this machine.**
The chain, measured end to end on 2026-09-12:

- The key reaches KDE. Meta+D (KWin's own "Show Desktop") works.
- The command works. `rmpr switcher show` run from a terminal puts the
  switcher on screen.
- The action works. `invokeShortcut` over D-Bus runs it.
- The record is right. `getGlobalShortcutsByKey` shows our key against our
  action.
- **The component was not active, so the key was never grabbed.**

`setShortcutKeys` takes a flags word. Passing `0` files a perfect record and
grabs nothing. **`SetPresent` is bit 2**, and the KF6 client library passes
`SetPresent | NoAutoloading` = 6; measured, by registering the same shortcut
seven times with different flags and reading `isActive` back:

```
flags=0 active=False    flags=2 active=True     flags=6 active=True
flags=1 active=False    flags=3 active=True     flags=7 active=True
flags=4 active=False
```

#### What was built, 2026-09-13

**The shortcuts have an owner.** Every action is now a component action under
`[remappr-shell]` in kglobalshortcutsrc -- the same place and shape as any
other shell's -- registered by `GlobalShortcuts` in `bin/windowsd.py.in` with
`doRegister` and `setShortcutKeys` at flags 6, and run from the
`globalShortcutPressed` signal. The daemon was the right place because the
KWin script D-Bus-activates it at login, before the shell is up, so the keys
work whether the shell is running or not; each one runs the same `rmpr`
command its desktop file used to run.

Measured after the change, on the running session:

```
component remappr-shell      isActive = true
launcher          16777250   (Meta)
search           268435488   (Meta+Space)
settings         301989970   (Meta+Shift+R)
clipboard        268435542   (Meta+V)
switcher         150994945   (Alt+Tab)
switcher-reverse 184549377   (Alt+Shift+Tab)
```

Every one of those is what kglobalaccel hands back when asked, not what was
written to a file. **What is still unproven is the last inch**: nobody has
pressed one. That is the first thing to do, and it needs a person -- there is
no `ydotool`, `wtype`, `dotool` or `xdotool` on this machine.

`rmpr shortcuts status` now says `component remappr-shell: grabbed` or `NOT
grabbed -- no owner is running` as its first line, and `rmpr doctor` fails on
the second, because the failure is invisible in the file: the record is
perfect either way.

#### Two things kglobalaccel does that cost an attempt each

- **It keeps every `[services]` entry it read at login in memory and writes
  the lot back when it saves.** Emptying the group in the file does nothing:
  the old holder keeps the key, our new claim on it is refused, and the group
  reappears in the file minutes later. `accel_release` hands the key back in
  the *running server* (`setForeignShortcutKeys` with no keys) and
  `accel_unregister` drops the action, and only then is purging the group from
  the file safe. `rmpr shortcuts migrate` does all of it, and this is why
  `accel_reload` now pushes everyone else's changes *before* telling our own
  daemon: the holder has to let go before the new claimant asks.
- **Its writeback is on a timer.** An unregister returns long before
  kglobalaccel saves, so keys written to the file in between are overwritten
  from memory -- which is exactly how the first run of `migrate` left every
  action at `none` while reporting success. `migrate` waits for the writeout,
  then checks what actually landed and retries once, and says which action it
  could not place rather than claiming five were moved.

#### The test suite unbound the user's keys, twice

Worth writing down because it took the second report to find. `make test`
runs `tests/test-windows.sh`, which renders the real `bin/windowsd.py.in` and
**runs it against the real session bus** -- there is no other one -- under a
bus name of its own. The moment the daemon grew a `GlobalShortcuts`, that copy
registered the shell's kglobalaccel component with the *sandbox's* empty
bindings, and kglobalaccel does what it is told: it took every key off the
real daemon. From outside it looked exactly like the fix not working.

Two guards now, either of which is enough:

- `shortcuts_wanted()` -- only the daemon holding the shell's own bus name
  claims the shell's keys. The bus name is the one thing only one process can
  hold, so it is what decides; a copy under any other name leaves them alone
  and says so on stderr.
- `test-windows.sh` sets the no-session variable as well, and checks that the
  test daemon registered no component.

Reproduced, fixed and re-checked by measurement: bind the keys, run `make
test`, read them back off kglobalaccel. Before: all gone. After: all six
still there.

#### What is left

- **The desktop files are still installed** (`~/.local/share/applications/
  remappr-shell-*.desktop`) and still carry `X-KDE-GlobalAccel-CommandShortcut`.
  They are no longer how a key is bound, and nothing writes `_launch` any
  more; they are kept because binding one from System Settings is a route a
  person may reach for, and `migrate` takes the key back from it. If they are
  ever dropped, the manifest, `KeyMap.shellRows` and `shortcuts migrate` all
  refer to them.
- **A held modifier is not watched.** `globalShortcutReleased` exists on the
  component and the switcher does not use it: it takes the release from its
  own exclusive keyboard focus instead. That works while the surface is up
  before the key goes, which is the case that has not been tried by hand.

### Two papercuts left, both small

Both closed on 2026-09-14 (`22fe7b5`), and both were as described:

- ~~`rmpr settings <page>` run within a few seconds of the shell starting says
  "no such page: <name> ()"~~ -- the window remembers the name now and lands
  on the page when the schema arrives. Verified on a real screen: run seconds
  after a reload, it said "opening once the schema loads" and came up on the
  page asked for.
- ~~`rmpr settings pages` is unreachable~~ -- the CLI routes it, which
  reserves `pages` as a section id; the suite asserts both.

## The settings session, 2026-09-13, late

Two things: the previous session's work was committed, and the settings window
was drawn in the Meridian design. **Nothing here has been on a screen.**

### The 48 files, committed

The fifth session left everything in the working tree. It went in as four
commits rather than one, because they are four separate pieces of work:

| commit | what |
| --- | --- |
| `feb9543` | global shortcuts that were filed and never grabbed -- the `SetPresent` ownership fix, the daemon's `Shortcuts` interface, `accel_release`/`accel_clear`/`accel_unregister` |
| `8a5919f` | Alt+Shift+Tab steps the switcher backwards, as its own action |
| `3c93b52` | popouts that land where the widget is, on every edge -- `Placement.qml`, alignment, layering, one surface, `theme.shadows` |
| `8f924e5` | the handoff |

`make test` was run before committing and was green: 353 QML cases, every
shell suite.

### The design was read, not inferred

`docs/meridian-handoff.md` names the design source, and it has settings markup
in it -- `Meridian Shell.dc.html`, around lines 227-605, read with DesignSync.
Worth doing before drawing anything: the mockup answers the question this file
had been holding open.

**A page there is a grid of cards.** Each card is `s2`, radius 16, padded
16-18, under a label in small capitals -- `COLOUR SCHEME`, `WALLPAPER`,
`ACTION PREFIX` -- laid out `grid-template-columns: 1fr 1fr`, gap 16. That is
the whole of it, and it is what five pages already were: the redesign's commit
`8323eac` wrote launcher, lock, notifications, taskbar and windows to it and
left the other ten alone. `Card` and `SectionLabel` already existed.

So the redesign was not a new design. It was finishing one.

### What was built

- **`shell/ui/primitives/CardGrid.qml`** -- two columns where there is room for
  two, one where there is not, and the whole width for a lone card. It has a
  `count` property because `visibleChildren` counts a `Repeater` as a child:
  an `Item` that draws nothing, which the Flow steps over but the count does
  not. Tested in `tests/tst_CardGrid.qml`, including the two ways it can divide
  by zero and hand every card a NaN width -- which draws as an empty page.
- **`shell/domain/settings/groups/SettingGroups.qml`** -- which key goes in
  which card. Pure, in a leaf module, tested in `tests/tst_SettingGroups.qml`.
  A group keeps the position of its first key, so cards come in the schema's
  order; ungrouped keys share one card at the top, titled by the section.
- **`SchemaRenderer`** draws its keys in those cards. A `group` in the schema
  key's spec is what makes one. It is additive -- `gen-docs.sh` ignores the
  field, so `docs/config.md` did not move -- and it reaches every schema-only
  section and every third-party widget's settings at once.
- **`SettingRow`** gained `controlWidth` and `stacked`. It used to reserve the
  same slot for every control, which gave a 44px switch a hundred pixels of
  nothing and left the description a column too narrow to read. Survivable in
  one column; in two it is what the page looks like.
- **The ten pages that predated the design**: about, AI assist, screen edges,
  layouts, profiles, restore points, renderer, switching windows, tray icons,
  widgets. Appearance went with them -- it had the section labels and one card.
  They were also still on the pre-palette names (`foregroundInactive`,
  `hoverBackground`, `backgroundAlternate`) and 11px text.
- **`theme.rounding` reaches the window**, through `Theme.radiusOf`.

### What the linter passed and the render caught

Every page was rendered with `PREVIEW_PAGE=<id> dev/preview/preview.sh
dev/preview/settings.qml out.png 1120 860 dark`. Three bugs survived a clean
`qmllint` and were obvious in a picture:

1. **A card whose contents had escaped it.** Unwrapping the old nested card on
   the appearance page put its closing brace in the wrong place, so two toggles
   drew full-width below the grid, outside any card.
2. **A row sized against an id that did not exist.** A patch that added
   `id: grip` silently did not apply -- wrong indentation in the pattern -- and
   the width binding referenced it anyway. qmllint said nothing; the shell
   logged `ReferenceError: grip is not defined` a hundred times and the rows
   overflowed the window.
3. **Button groups wider than the half-width cards they sit in.** A `Row` of
   two `TextButton`s and an `IconButton` does not fit in half a page. They are
   `Flow`s now. Note that a positioner's children cannot use `anchors`, so the
   `anchors.verticalCenter` on each had to go.

### The widget row, reported mid-session

The user sent a screenshot: hovering a row on the widgets page put its last
button outside the dialog. The row reserved a written-down `320` for everything
that is not the widget's name -- an icon, a zone dropdown, a switch, a drag
grip and four buttons, nearly 400 -- and it was short *only while the pointer
was on the row*, because the four buttons are `visible: rowHover.hovered` and a
`Row` skips invisible children. So hovering widened the contents past the card.

The width comes from the widths of the things on the line now, and the buttons
hold their place with `opacity` rather than `visible`, so the line does not
change width under the pointer. `5dbdab6`.

### The lint that had been failing

`make lint` was red before this session started, and the fifth session did not
know it: `tests/tst_Popouts.qml` imports `qs.ui.primitives`, and `PanelIcon`
in that module imports Quickshell.

The rule's own comment explains itself in terms of **singletons** --
qmltestrunner instantiates every singleton in a module it imports, so one that
touches the runtime makes the whole module unimportable. It was grepping every
file in the directory. An ordinary component is compiled with the module and
instantiated only where a test writes one down; `qs.ui.primitives` has no
singletons at all, which is why the suite passed while the lint refused it.

It reads the module's `qmldir` now. Verified both ways: it goes quiet on
`qs.ui.primitives`, and still fires on `qs.domain.config`, naming `ConfigStore`
and `Schema`. `e72d7ef`.

### Where it stands

`main` clean, `make lint` clean, `make test` 369 QML cases and every shell
suite green. `docs/settings.md` is the new map, linked from the README beside
`docs/popouts.md`.

**What needs a real screen**, in order:

1. **The two drag lists** -- tray icons and widgets. The offscreen harness
   cannot exercise a drag at all, and both pages were restructured around them.
2. **A small window.** The grid drops to one column below about 800px of page;
   rendered once at 800x700 and it held, but that is one size.
3. **Light mode.** Rendered, not lived in.
4. **The hover state of a widget row** -- the fix above is arithmetic that
   reserves space unconditionally, so it is right by construction, but the bug
   it replaces was also invisible until someone hovered.

The two papercuts below are untouched, and so is the user's report that the
window **feels unresponsive** -- nothing in this session was aimed at it. Ask
which part is slow before optimising anything.

## The session of 2026-09-14: the keys, pressed

The first session with the user at the keyboard while the keys were being
bound. That is the whole character of it: six of the eight commits are things
no offscreen render or passing test could have found, and three of them are
bugs this session itself introduced and the user caught within a minute of
pressing a key.

### What was committed

| commit | what |
| --- | --- |
| `22fe7b5` | settings said a page did not exist when the schema had not loaded |
| `734c92b` | the desktop follows day and night, when asked to |
| `00f659e` | a row in a settings card read the width off a parent that was null |
| `6843624` | a quick Alt+Tab left the switcher on screen with the key already up |
| `90e0a46` | the switcher closed on the first Tab instead of when Alt came up |
| `682cdc6` | the switcher came back after the choice that closed it |
| `e25ab13` | KWin's switcher had no width, so it drew nothing |
| `77856d6` | the desktops, drawn by this shell, on Meta+Tab |

### The desktop follows day and night (item 26)

`theme.mode: auto` already turned the shell light by day and dark by night on
Night Light's schedule; the applications stayed wherever `theme apply` last
put them. The defaults file carries both variants now -- a `# variant:` marker
beside the `# part:` ones -- and only the variant being applied is written.
Nothing else differs between light and dark: the widget style, the Plasma
theme, the decorations and Alt+Tab are written once either way.

`rmpr theme variant light|dark|auto` writes just those keys, through the same
ledger as everything else. `auto` asks Night Light the same three properties
the shell reads -- available, enabled, daylight -- and falls back to dark when
there is no schedule. On this machine it resolves correctly: `theme.mode: auto
· night light: daylight · resolved: light`, and the desktop was already in the
light scheme, so the guard against pointless writes fired.

Following the schedule is **opt-in, off by default**:
`theme.desktop.followMode`, offered on the appearance page. `DesktopVariant`
in the shell decides *when* (debounced, and it asks once rather than on every
colour-scheme write); the script decides *what*, so there is one
implementation of the writing and it is the ledgered one.

### The shortcuts, and what pressing them found

The shell was running with **every action unbound** -- caelestia held Meta,
Meta+Space, Meta+Tab, Alt+Tab and Alt+Shift+Tab, and the earlier session's
bindings were gone. Binding ours took them back (ledgered; `rmpr shortcuts
revert` gives them back). plasmashell was also still on `caelestia.desktop`
while the configured renderer was quickshell -- `rmpr renderer set quickshell`
put it on ours.

Then the user pressed the keys, and the switcher came apart in three ways:

1. **A quick tap left it on screen.** The release that commits was a key event
   on the switcher's own surface, which only reaches it while that surface is
   up and holding the keyboard -- and a tap releases before it is mapped.
   kglobalaccel has a `globalShortcutReleased` signal beside the pressed one;
   the daemon subscribes and runs `switcher commit`.
2. **Then it closed on the first Tab.** What kglobalaccel reports is the
   release of the *shortcut* -- Tab coming up, not Alt -- so acting on it
   while the switcher was up made stepping impossible. That release is read
   **once, when the surface is created**, and never again. This is the one
   case it exists for.
3. **Then it came back after the choice that closed it.** Every tap spawns an
   open of its own, so the last one can land after the modifier came up and
   the window was chosen. An open within 600 ms of a close is dropped.

All three are in Surfaces as "held key" state shared by the switcher and the
overview, not as switcher-specific fields.

### Why Alt+Tab is KWin's now

The user's report after the three fixes: "the alt+tab freezes a second or 2
until the tab next window select works... and for some reason the alt key is
kept held. the kde task switcher is more refined that this one." Both halves
are structural, and both were measured rather than argued:

- **88 ms per key press** through kglobalaccel -> daemon -> `rmpr` (bash) ->
  `quickshell ipc`, of which 34 ms is the ipc process alone. Five taps spawn
  ten processes and cost 411 ms of spawning, overlapping and competing for
  CPU. The surface build is 10 ms and the enter animation 180 ms.
- **The stuck modifier is what exclusive keyboard focus costs.** Our overlay
  takes the keyboard mid-chord; when it goes, the application behind it never
  received the release. KWin's switcher runs inside the compositor, sees raw
  key events, and is the only thing that can show a picture of a window.

So Alt+Tab is `kwin: Walk Through Windows`, drawn by our own switcher package
(`switching.windows: plasma`, TabBox layout `remappr-shell`). The shell's own
card row is still there and still works; it is one command away.

### KWin's switcher box had never appeared, and this is why

Known problem, carried as unexplained since 2026-09-10. The layout sized its
content with `cards.implicitContentWidth + 2 * pad`, and **no ListView has an
`implicitContentWidth`** -- QtQuick's own type data has no such property on
any type. The sum was NaN, so `PlasmaCore.Dialog`'s main item had no width and
KWin drew nothing at all. `contentWidth` is the property that means what was
wanted.

qmllint had been printing it from the start -- "Member implicitContentWidth
not found on type ListView. Did you mean implicitWidth?" -- in the middle of
its unavoidable warnings about KWin's own unresolvable types, which is exactly
how an eye learns to skip a block of output. **Whether the box now appears has
not been confirmed by a person.**

### The desktop overview, on Meta+Tab

`switching.desktops` has offered "plasma" or "shell" since the redesign and the
shell half did not exist. It does now, built from the design file's own
Super+Tab view -- `Meridian Switchers.dc.html` in the same Claude Design
project, read with DesignSync, which nothing in this project had looked at
before. **That file also specifies the Alt+Tab switcher in three layouts (row,
grid, icons), which our card row implements only as the row.**

The overview: a glass header with the desktop count and what the keys do, the
windows of the selected desktop drawn large and centred (scrolling when they
do not fit), and a strip along the bottom with every desktop, up to three
application icons as a glance at what is on it, and a dashed "New desktop"
tile that calls KWin's `createDesktop`. Held like Alt+Tab -- another press
steps, arrows step windows, 1..9 jumps, release switches and raises.

`rmpr switcher desktops plasma|shell` moves the key and writes the setting, and
the settings window now offers both keys under **"Who draws it"** -- that
choice had been reachable only by editing the profile by hand. **Ours is the
default** for Meta+Tab.

### What the render caught that the linter could not

Three in the overview alone, and none of them is visible to qmllint:

1. **`font.pixelSize` is an int.** The design's 12.5px is a load error, and a
   load error in a surface takes the whole surface with it -- "Invalid
   property assignment: int expected", reported against the model line above
   it.
2. **A tile sized against `parent` in a Repeater delegate.** The same bug as
   the settings rows, found the same day: `parent` is null until the delegate
   is reparented.
3. **A selection pointing past the end of the desktop list**, which drew a
   header saying "No desktops" over a strip that was showing them.

And one in the harness: `dev/preview/preview.sh` rewrites a full-screen
surface into an `Item`, and its range delete from `anchors {` to `    }`
**took most of the file with it** for the switchers, which write all four
anchors on one line. Every error it then reported pointed at a line number
that no longer meant anything, which cost three rounds of chasing a parse
error that was not there.

### Measured, not assumed

- **Popout builds are 1-10 ms** (start menu 10, quick settings 5, volume 1),
  measured from the moment the popout was asked for. The debug log carries it
  now. So "the popouts feel slow" is not construction; what is left is the
  180 ms enter animation, the compositor and the blur.
- **The config layer is not slow either**: `Obj.deepMerge` of the real
  defaults is 0.25 ms, `Obj.get` 3.2 us. A whole page of rows re-reading
  configuration costs about 2 ms.
- **The per-page CLI calls are the settings window's only real cost**: `edges
  status --json` 331 ms, `theme status --json` 141 ms, the rest 54-81 ms.
- **The user says the settings window is not the slow part** -- "the popups
  and launcher feel slow" -- so the note in this file about the window feeling
  unresponsive was aimed at the wrong surface all along.
- The launcher's search is a linear scan of **364 desktop entries** capped at
  `maxResults`, which is not it either.

### Still to press

Alt+Tab (KWin's, freshly given a width), Meta+Tab held and released, and the
drag lists in Settings. And `systemctl --user stop
app-caelestiashell@autostart.service` remains untouched: caelestia still holds
`org.freedesktop.Notifications`, so this shell's notification server cannot
register, and `doctor` reports it.

### The second half of the day: the taskbar, the colours, and eight more bugs

The keys work, so the user used the shell -- and reported a list. Everything
below came out of that, in one afternoon.

| commit | what |
| --- | --- |
| `74a6bd0` | ignore the pattern hooks' local decision logs |
| `0650152` | the overview's cards drew on top of each other |
| `0f1e367` | every window looked like it was on every desktop, and right-click drew nothing |
| `d0b9b68` | light and dark reached the scheme's name and nothing else |
| `7609944` | the taskbar's icons fill their buttons, and the panel has a menu of its own |

**A Flow positions y as well as x.** The overview's cards lifted themselves
with a `y` binding, which fights the positioner, and the row drew on top of
itself. The window switcher does the same thing and is fine because a Row
positions x alone. The lift is a transform now. Worth remembering: **a
positioner's children may not set x or y**, which is the same class of rule as
"a positioner's children cannot use anchors" from the settings session.

**`desktops` never reached the shell.** `WindowEvents._window` normalises each
window to a fixed set of fields and that one was not among them, so every
window arrived with it undefined -- which the overview reads as KWin's "on all
desktops". It listed all eleven windows under each of two desktops. Carried
through now, with an empty list still meaning all of them, and tested both
ways.

**The taskbar's right-click menu had no width.** The popout's Loader was never
given one, so every row laid out 0 wide inside a card of the right size: the
menu was built, the actions were there, and the click looked dead. The menu's
width is the widget's to state, because the rows are as wide as the menu and
the menu as wide as the card -- asking the menu how wide it wants to be is a
loop. `PREVIEW_MENU=1 PREVIEW_WIDGET=tasks dev/preview/preview.sh
dev/preview/popout.qml ...` opens a widget's menu offscreen, which is how both
the empty box and the fix were seen without a pointer.

### "Dark mode is active globally", and why our light scheme changed nothing

The most important finding of the day, because it means **this project's
theme layer had never actually applied a colour scheme**.

Selecting one in KDE is two things: naming it in `kdeglobals [General]
ColorScheme`, and copying the scheme's `[Colors:*]` and `[WM]` groups into
kdeglobals, where every Qt and KDE application reads its colours. We did the
first. So kdeglobals said "Remappr Shell Light" while the colour groups in the
same file still held dark values from whatever applied a dark scheme last --
and the desktop portal, which tells Chrome and every Electron application what
to do, reads those same values and answered "prefer dark".

`scripts/lib/kdeglobals-colors.py` does the copy, on lines rather than through
a parser, and only on the groups a colour scheme governs -- `theme revert` has
to leave every KDE file **byte-identical**, and a parser that rewrites the file
reorders keys even when the values are the ones already there. It cost two
bytes to learn that KConfig writes a blank line before each group, so the blank
above a group we later remove is left at the end of the file.

The other half: **GTK and everything that asks a portal do not read KDE's
configuration at all.** xdg-desktop-portal-gtk answers from
`org.gnome.desktop.interface color-scheme` in dconf, which said prefer-dark.
`theme variant` writes that too, under a new `theme.desktop.gtk` part, with the
`gtk-application-prefer-dark-theme` key in the GTK 3 and 4 ini files beside it.
The dconf value is remembered in a note of our own, since dconf is nobody's ini
file.

Measured before and after on the real desktop: the portal answered **1 (prefer
dark)** and now answers **2 (prefer light)**, with Night Light saying daylight.
`theme.desktop.followMode` is **on in the user's profile now**, so this follows
the schedule from here.

### Window thumbnails are possible after all, and this is the evidence

This file has said since 2026-09-10 that previews need a protocol KWin does not
give ordinary clients, citing 66 advertised globals with no screencast
interface among them. **That conclusion is wrong**, and caelestia is the proof
sitting on this machine:

- `~/.local/lib/qt6/qml/Caelestia/lib/libcaelestia-services.so` contains
  `caelestia::services::WindowScreencastGlobal`, a
  `QWaylandClientExtensionTemplate` -- which is a client binding
  `zkde_screencast_unstable_v1`, KWin's own screencast protocol.
- Its QML side is `components/images/WindowPreview.qml`: a `WindowStream` from
  that plugin feeding `org.kde.pipewire`'s `PipeWireSourceItem`, with the
  application icon standing in until a frame arrives.
- KWin's `supportInformation` lists screencast here.

So a live window preview is a **compiled Qt/Wayland plugin** away, not a
protocol away. That is still a real decision -- it introduces a C++ build to a
project that has none -- but it is a decision, not an impossibility. The user
asked for hover previews explicitly; this is what answering that costs.

### What the user asked for that is not built yet

1. **More settings for both switchers.** The design file's Alt+Tab comes in
   three layouts -- row, grid and icons -- and ours implements the row only.
   Nothing yet exposes the overview's behaviour either.
2. **Hover previews**, per the finding above.
3. **Whether the overview should stay up when the key is released**, the way
   the user remembers Windows behaving. They said to leave it if unsure; a
   setting is the honest answer.

## Window previews, and the lesson in how they were missed

Built on **2026-09-14**. This is the entry to read before concluding that
anything is impossible on this desktop.

### What was wrong

Since 2026-09-10 this file has said a picture of a window cannot be had here,
citing two true measurements: KWin advertises 66 Wayland globals to us and no
screencast interface is among them, and `ScreenShot2.CaptureWindow` refuses us
with "the process is not authorized to take a screenshot". The conclusion drawn
from them -- that the protocol is not available to ordinary clients -- was
wrong. It is **restricted**, which looks identical from outside: the global is
simply not there.

KWin's own words, in `libkwin.so`: *"not in X-KDE-Wayland-Interfaces of"*. A
client may bind a restricted interface if its **desktop file** names it. The
portal that does screencast on this machine
(`org.freedesktop.impl.portal.desktop.kde.desktop`) names three, and
`org.kde.plasmawindowed.desktop` names four.

Proven with a throwaway client before anything was built:

| what was run | globals | screencast |
| --- | --- | --- |
| a plain binary | 66 | no |
| the same binary, with a desktop file declaring it | 68 | **yes** |
| a differently-named copy, no declaration | 66 | no |
| that copy again, named in another file's `Exec` | 67 | **yes** |

So the match is on the **executable's absolute path**, from any desktop file's
`Exec`, and the arguments are ignored. Two consequences worth knowing:

- One desktop file covers a shell whose config path differs per install.
- It grants the interfaces to **any Quickshell shell this user runs**, ours and
  caelestia's alike. There is no narrower way to ask; KWin compares binaries.

### How it works now

`share/applications/wayland-interfaces.desktop.in` asks for
`org_kde_plasma_window_management` and `zkde_screencast_unstable_v1`, and is
installed by `make link` like every other desktop file.

`plugin/` is this project's **only compiled part** and exists for the one thing
QML cannot do: bind a Wayland protocol. It turns a window's uuid into a
PipeWire node id; `org.kde.pipewire`'s `PipeWireSourceItem` draws the node,
which is free. `make plugin` builds and installs it into the user's own Qt
import path; `make plugin-clean` removes it. **Nothing else needs a C++
toolchain**: `ui/primitives/WindowThumbnail.qml` reaches the stream through a
Loader by *file name* rather than an import, so a machine without the module,
without kpipewire, or with a KWin that says no draws the application's icon
exactly as before. `rmpr doctor` has a section saying which of the three is
missing.

Drawn in three places: the taskbar's hover preview, the desktop overview, and
this shell's own switcher. KWin's switcher has had real previews all along --
its layouts run inside kwin_wayland, where `KWin.WindowThumbnail` exists.

### What the building taught, all of it silent failure

- A QML module must be a **shared** library. A static one installs an archive
  nothing can dlopen, which looks exactly like not installing it.
- Sources must go through `qt6_add_qml_module`. Added to the target afterwards
  they compile, and the generated type registration does not see the type.
- `project(LANGUAGES CXX)` leaves **wayland-scanner's C output uncompiled**, and
  the module then fails to load with an undefined symbol.
- A stream is released with the protocol's **own destructor request**. A raw
  `wl_proxy_destroy` leaves KWin capturing a window nobody is looking at and
  takes the process down on the way out.
- **One stream at a time.** Eleven cards asking at once, with the list rebuilt
  on every window change, got "target not found" for all of them. Only the card
  under the selection streams.
- A stream can arrive and **draw nothing**: a fullscreen game's buffer is one
  kpipewire cannot turn into an EGL image. The icon sits under the picture
  rather than being swapped out for it.

### What is still not from this

`ToplevelManager` still reports nothing, and that finding stands: it speaks
`zwlr_foreign_toplevel_manager_v1`, which KWin does not implement at all. The
window list still comes from the KWin script and the daemon. The grant now in
place does include `org_kde_plasma_window_management` -- the protocol KWin
*does* implement -- so a client that spoke it directly could read windows
natively. Quickshell is not that client, and the plugin does not bind it yet.

### The rest of that afternoon: settings, layouts, and two windows nobody opened

| commit | what |
| --- | --- |
| `29ddd97` | the overview has settings, and one speed for everything that appears |
| `50f692b` | Alt+Tab in three layouts, as the design draws it |
| `e8281d3` | Meta+Tab opened with a desktop selected while Tab moved the windows |
| `b17ea74` | live window previews, drawn by this shell |
| `bb5f983` | thirteen streams at once, and a picture that could draw nothing |
| `8738097` | say which window got a stream, in the debug log |
| `b818479` | the installed preview module pointed at the directory it was built in |
| `6db8134` | the clipboard and the device notifier opened a window on every start |

**The overview's five settings** are `switching.overviewHold` (held like
Alt+Tab, or open until something is chosen -- the Windows behaviour the user
half-remembered), `overviewTitles`, `overviewMinimised`, `overviewStrip` and
`overviewCardWidth`. With the strip off the windows get the whole surface and
the desktops move on the arrows alone. `theme.animationMs` is one number for
how long any surface takes to appear -- popouts, switcher, overview, search --
and it was 180 ms written into four files.

**Three switcher packages from one source.** A layout running inside
kwin_wayland cannot read this shell's configuration, so a *setting* would have
had nothing to read it with. KWin picks a switcher by package, so the layout is
a template (`main.qml.in`, `@SWITCHER_LAYOUT@`) rendered three times. Inside
it, one delegate is shared by a horizontal list (row, icons) and a GridView
(grid), and the selection moves through `select()`/`step()` rather than through
whichever view happens to be drawn -- KWin sets the index and both have to
follow.

**Two windows nobody opened.** The shell hosts two of Plasma's tray-only
applets because their services live in the applets rather than in plasmashell,
and `plasmawindowed --statusnotifier` opens a window before settling into the
tray. They are closed as they appear now. *How* to tell them apart is the
interesting part, and `Hosting.windowsToClose` carries it: **not by pid** --
plasmawindowed is a unique application, so the second invocation hands its
applet to the first process and exits, leaving the pid we ran pointing at
something already gone -- and **not by title**, which is the applet's name in
the user's language. What is left is the host application's own windows while
windows are *expected*: twenty seconds after hosting, no more than were
started.

**What a crash report was worth.** The user sent
`~/.cache/quickshell/crashes/6wrs6dwclt`. The crash itself was a probe of this
session's own, from before the stream teardown was fixed -- but every frame in
it named the preview library **in the directory it had been built in**, which
was a session-temporary one. Qt splits a QML module into a plugin and a backing
library, and the plugin's RUNPATH is the build directory unless told otherwise:
a build directory that later goes away leaves a module that silently stops
loading and a shell drawing icons with nothing to say why. `$ORIGIN` now. A
crash report is worth reading even when the crash is not the bug.
