# Where the project stands

A snapshot for picking the work up fresh. Written 2026-09-10, across two
sessions, and added to since -- most recently on 2026-09-12, when the
Meridian redesign was finished on its own branch: the first built the Plasma renderer, diagnostics, the wizard, the
theme layer, the open-window list and panel auto-hide; the second added AI
assist, the notification history, crash reporting, and a tray you can curate
whose menus open. A third, on 2026-09-11, added volume, network, Bluetooth
and battery widgets -- and found that every popout had been opening at the
screen's left edge. A fourth, the same evening, built the lock screen -- the
last part of the plan -- and found that Plasma 6 draws it from the shell
package, not the look-and-feel package this file had said.

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

## The redesign, on a branch

Since 2026-09-11 a second line of work has been running in the worktree
`~/Projects/remappr-shell-meridian`, branch **`meridian`**: the user's Claude
Design mockup "Meridian Shell" implemented as this shell's look, with Material
Design colours and a light and a dark scheme. **None of it reaches the screen
until that branch is merged, which is the user's call.** Everything below
describes `main` unless it says otherwise; what the branch changes is under
"The Meridian redesign" further down, and `docs/meridian-handoff.md` in the
worktree carries the detail.

## The state of this machine, right now

Updated 2026-09-11. Everything below was read off the running system rather
than remembered. The machine was rebooted between sessions, and the first two
rows are what that did.

| | |
| --- | --- |
| Shell | installed via `make link` as `remappr-shell.service`, **inactive and deliberately not enabled**: the user starts and stops it by hand for testing (`rmpr start` / `rmpr stop`). Do not enable it or suggest enabling it. After a reboot there is no panel of ours until `rmpr start` |
| plasmashell | on **`remappr-shell.desktop`**, profile `panel.renderer: quickshell` -- the user switched at 14:12 on 2026-09-11 with `rmpr renderer set quickshell`, then restarted plasmashell. Our shell draws the panel; caelestia's bar still runs beside it |
| Plasma services | notifications: **caelestia's Quickshell** (it took the name the moment the plasmashell restart freed it, before our hosted applet could; the user is fine with that for now). Clipboard: our hosted `plasmawindowed` (Klipper). Device notifier: hosted too |
| Panel | bottom, 40px, entries `launcher, tasks, notifications, tray, clock, showdesktop` -- the `windows` preset plus the history bell. The new status widgets are **not** in this profile (only in the defaults and presets); add them in Settings → Widgets |
| Tray | 8 items, nothing pinned, so every one is on the panel and there is no chevron. Curate it with `rmpr settings tray` |
| Notifications | `notifications.history` is on in the profile, so the eavesdrop runs; `ai.enabled` is off |
| Crash dumps | none. Five were written before the `image-data` fix, all with the same stack; they have been cleared |
| Theme | our Look-and-Feel package is active, but it is the one `theme apply` installed on 2026-09-09 at 20:15 -- `defaults` and `osd/` only. The colour schemes, the Alt+Tab switcher, the desktop theme and the splash were added to `theme apply` after that and have **never been installed here** (`theme status`: 0 schemes, switcher not installed; read 2026-09-11). Nothing deleted them. This row used to say they were installed. Re-running `rmpr theme apply` -- or "Install the missing parts" in Settings -> Appearance -- would put them in place |
| Lock screen | **ours is built and not on**: Plasma's draws. `rmpr lockscreen try` has never been run -- it needs the person at the keyboard (item 22). faillock was empty at 19:48, after two failed logins this session's checks caused at 19:32 and 19:42 (see "A greeter stopped mid-authentication is a failed login") |
| Window list | KWin script loaded, daemon answering, 9 windows |
| Also running | caelestia's own Quickshell bar, alongside ours. krohnkite is installed but **not loaded** (`isScriptLoaded krohnkite` false, `krohnkiteEnabled=false`, read 2026-09-11) |
| Screen edges | nothing bound, snapping on -- KWin's defaults; no `edges` ledger entries |
| Shortcuts | Alt+Tab and Meta+Tab are caelestia's; KWin's own switcher is unbound. Ours: `settings` on Meta+Shift+R, bound for real when `75c4a6f` was written and ledgered (`shortcuts revert` removes it) |
| `rmpr doctor` | no problems, 2 warnings (2026-09-11, shell running): caelestia's shell, and one ledgered key no longer set -- `plasmashellrc [PlasmaViews][Panel 811] shell`, left in the ledger when the Phase 6b revert purged that group; harmless. The krohnkite warning is gone: it was about installed scripts, not enabled ones |

### What to check first, before building anything

Everything below needs a real mouse or keyboard, which no session here has
had: `ydotool`, `wtype`, `dotool` and `xdotool` are all absent, so a keystroke
and a click cannot be produced from inside. Each is quick, and some are a bug
if they fail.

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
   proven -- the popout showed the Scarlett at 100%, as `wpctl` does. Writing
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
19. **Alt+Tab and Meta+Tab, by hand.** `rmpr settings switching`. Pick a
    layout -- Large Icons, say -- and press Alt+Tab: nothing changes while
    caelestia holds the key. Then "Give it to KWin" beside Alt+Tab: the
    shortcuts service restarts, and Alt+Tab should draw KWin's switcher in
    that layout, with caelestia's silent. The same for Meta+Tab and the
    Overview. "Undo everything set here" hands both back to caelestia.
    Verified: the whole round trip in the sandbox, seeded like this machine,
    down to a byte-identical kglobalshortcutsrc after the undo; and the live
    `switcher status` naming caelestia for both keys. Not tried live,
    because it takes the user's Alt+Tab. **Unknown before trying:** whether
    caelestia's shell notices losing a key when kglobalaccel restarts, or
    asks for it back.
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
    commands (61 checks). Not seen: any of it on a screen, or a real
    password through it.

23. **The redesign, once it is merged -- everything in it needs eyes.** No
    part of `meridian` has ever been on a screen: every picture of it was
    drawn offscreen. Worth going through in order: the panel in its three
    styles on each edge; the start menu in its three layouts and the search
    overlay; quick settings, the calendar and the notification centre; the
    sidebar (`rmpr sidebar`) and the key sheet (`rmpr keys`); the session
    screen (Settings -> Lock & session -> "Show it"); a notification popup in
    each position; the settings window's new pages; the rounded screen border
    and the desktop clock (Settings -> Desktop, both off by default).
24. **The lock screen, again, on the merged build.** The Meridian lock screen
    is a different build from the one `try` recorded on 2026-09-11, so
    `lockscreen status` will say "changed since it was tried" and `enable`
    will refuse until `rmpr lockscreen try` has unlocked the new one. Same
    rules as item 22, and the same way back.
25. **The taskbar reported missing on 2026-09-12 -- answered, and it needs
    one command.** Nothing is drawing a panel on this machine, and both halves
    of the reason are in `rmpr renderer status`: the profile says
    `panel.renderer: plasma`, so this shell deliberately draws none, while
    plasmashell is on `caelestia.desktop` rather than the expected
    `remappr-shell-plasma.desktop`, so the generated Plasma panel is not
    loaded either. Something moved plasmashell back after the last switch --
    the ledger still holds `ShellPackage (was: caelestia.desktop)`.

    The way out is `rmpr renderer set quickshell` (this shell draws it, which
    is what `make run` and `rmpr start` are for) or `rmpr renderer set plasma`
    again, which actually moves plasmashell onto our package; check `renderer
    status` afterwards either way. **Left to the user**, because both write
    KDE keys and change what is on their screen.

    Confirmed by the user on 2026-09-12: `rmpr renderer set quickshell` was
    what made the panel appear, under `rmpr start`.

    The run exposed two bugs of ours, both fixed on `meridian`. The flash in
    the log -- "panel: up on DP-2" a line before "profile loaded" -- is
    `f094923`: the defaults name this shell as what draws the panel, so a
    profile naming Plasma got a panel for one frame; `ConfigStore.profileLoaded`
    gates it now. And **every "is the shell running?" check missed a shell
    started by `make run`**, because it matched only the installed config
    directory while a working-tree run names the source tree instead -- so
    `rmpr status` said "no" with a panel on screen, and `renderer set` refused
    on the grounds that nothing would draw. `shell_running` in `brand.sh`
    answers for both copies now, and `rmpr status` says which one it found.

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
  were gone: Chrome was recording the Scarlett's microphone during this
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
- **No window thumbnails, and here is exactly why.** Investigated properly
  after "how does caelestia do it?", which turned out to be the right question.

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
5. **No window thumbnails in the task preview**, and this one is settled rather
   than open: see the entry under "Not built yet". It needs privileges KWin
   does not give us.
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
keeps the merge for themselves.

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

What is left is a person's: none of it has been on a screen, the lock screen
needs `try` again on the new build, and the merge is the user's decision. See
items 23 to 25 under "What to check first" -- item 25 is a taskbar the user
reported missing on `main` on 2026-09-12, which no session has yet been able
to measure.
