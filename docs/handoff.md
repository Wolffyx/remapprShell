# Where the project stands

A snapshot for picking the work up fresh. Written 2026-09-10, across two
sessions: the first built the Plasma renderer, diagnostics, the wizard, the
theme layer, the open-window list and panel auto-hide; the second added AI
assist, the notification history, crash reporting, and a tray you can curate
whose menus open. A third, on 2026-09-11, added volume, network, Bluetooth
and battery widgets -- and found that every popout had been opening at the
screen's left edge.

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
| Theme | `rmpr theme apply` has been run: our Look-and-Feel package is active, colour schemes and switcher installed |
| Window list | KWin script loaded, daemon answering, 9 windows |
| Also running | caelestia's own Quickshell bar, alongside ours; krohnkite |
| `rmpr doctor` | no problems, 5 warnings -- two of them the service being down, plus the competing shell and krohnkite |

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
  preset, profile, update. A page name is a schema section id, which is also
  its heading in the generated reference -- so `rmpr settings tray` opens the
  window where the docs say it is.
- **Auto-hide** — `panel.autoHide`, per output like position and thickness.
  The surface really does shrink to a sliver rather than a full-height
  transparent one moved out of sight: a transparent surface still eats every
  click that lands on it. The content keeps its full thickness and slides,
  rather than being squashed, so a reveal does not re-lay-out every widget
  twice. It reserves no space while hiding is on.
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
- **Tests** — 12 shell suites in throwaway HOMEs, plus a QML suite of 160. All
  green.
  `test-ask.sh` fakes every provider, the terminal and the shell's IPC, and
  runs on a whitelisted PATH so a `claude` on the host cannot stand in for a
  missing one. `test-crash.sh` builds dumps by hand, including one belonging to
  another shell.

## Not built yet

- ~~**Tray tooltips.**~~ Built, for every widget rather than only the tray;
  see "Tooltips" under "Working today".
- ~~**AI assist and the notification ring buffer.**~~ Built; see "Working
  today". What is still not built from that plan: a watcher that *notices*
  a failed unit or a core dump by itself. `rmpr ask --failed` gathers them on
  request, and that is as far as it goes -- a watcher that pops something up
  is a notification of our own, which is the thing this project does not do
  uninvited.
- **The lock screen.** Deliberately not shipped. The Look-and-Feel package can
  override `lockscreen/LockScreen.qml`, and a broken one means being unable to
  unlock — the worst failure this project could ship, and the only one that
  cannot be tested from inside the session it would break. Do it only with a
  second TTY open and a tested way back (`loginctl unlock-session` from
  Ctrl+Alt+F2, or `rmpr theme revert`), and gate it behind its own flag rather
  than folding it into `theme apply`.
- **Opt-in notifications.** Plasma owns `org.freedesktop.Notifications` --
  its tray does, and under our renderer the applet we host does -- and a
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
config (see "Non-obvious things"). Also worth knowing: **a `Write` that
replaces a QML file wholesale may not trigger the live reload** -- the
shell kept the old version until `shell.qml` was touched. Check that a
diagnostic field you just added is there before trusting the answer.
