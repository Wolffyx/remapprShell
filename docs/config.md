# Configuration reference

GENERATED FILE -- do not edit. Regenerate with `make docs`.
Source: `config/schema/shell.json`, `config/defaults/shell.json` and each widget's `widget.json`.

## Where it lives

| Path | What it holds |
| --- | --- |
| `~/.config/remappr-shell/profiles/<profile>/shell.json` | your settings |
| `~/.config/remappr-shell/profiles/<profile>/monitors/<output>.json` | overrides for one screen |
| `~/.config/remappr-shell/state.json` | which profile is active |
| `~/.local/share/remappr-shell/config/defaults/shell.json` | the shipped defaults, read-only |
| `~/.local/state/remappr-shell/` | ledgers, restore points, reports |

## How the layers combine

Four layers, each overriding the one before:

1. **defaults** -- shipped, complete, never written to
2. **profile** -- your file, a *sparse* delta against the defaults
3. **monitor** -- a delta on top of that, for one output
4. **runtime** -- in memory only, never saved

Your profile holds only what you actually changed. That is deliberate: it means
upgrading the defaults moves everything you never touched, and a setting you did
not choose does not get frozen at the value it happened to have on the day you
installed. Edits are picked up live -- no restart.

A profile that does not parse blocks writes rather than being overwritten, so a
typo cannot cost you the rest of the file.

## Settings

### Appearance

How the shell itself looks -- light or dark, its accent, its corners -- and the style every Qt application is drawn in. The shell's own colours change nothing outside it.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `theme.mode` | `auto`, `light`, `dark` | `auto` | auto is light by day and dark by night, on KWin's Night Light schedule -- the same sunset that warms your screen, set in System Settings under Display and Monitor. Plasma has no light/dark switching of its own (its sunset switching is for wallpapers), so with Night Light turned off there is no schedule to follow and auto instead turns dark whenever the Plasma colour scheme is dark, following it the moment it changes. light and dark hold it where they say. |
| `theme.accent` | `plasma`, `blue`, `teal`, `magenta`, `orange` | `plasma` | plasma is Plasma's own accent colour, which System Settings can also take from the wallpaper. Every other colour the shell uses is worked out from this one, in Material Design's roles. A colour written as #rrggbb is accepted too. |
| `theme.translucent` | `true` or `false` | `true` | The panel and its popouts let a little of what is behind them through. Off draws them solid. |
| `theme.shadows` | `true` or `false` | `false` | A soft shadow under the panel, its popouts, the start menu and the on-screen display. Off by default: a shadow is a band of dimmed wallpaper around a surface whose own background is blurred, and on a dark desktop the join between the two reads as a second panel behind the first. |
| `theme.rounding` | a number, 0 to 36 | `8` | The radius of the largest surfaces -- the start menu, quick settings, a floating panel. Smaller things are rounded in proportion. |
| `theme.animationMs` | a number, 0 to 400 | `180` | In milliseconds: a popout rising out of the panel, the switcher, the desktop overview. 0 makes them appear at once, which is the fastest the shell can feel and the least it can explain -- a surface that simply exists gives no hint about where it came from. |
| `theme.desktop.enabled` | `true` or `false` | `true` | Applying the theme also re-themes KDE itself, so applications match the shell rather than only the panel and its popouts. Off confines the theme to what this shell draws. Each part below can be left out; anything left out keeps whatever you have chosen in System Settings, and `rmpr theme revert` puts every part back. |
| `theme.desktop.followMode` | `true` or `false` | `false` | With Colour scheme set to auto, the colour scheme and icon theme KDE itself uses are rewritten when night falls, so applications turn dark with the shell instead of staying wherever they were last put. Off by default: it writes KDE's own configuration on a schedule, which is not something to do to a desktop uninvited. `rmpr theme variant` does it once, by hand, and `rmpr theme revert` puts it all back. Plasma's own widgets follow from the next plasmashell start. |
| `theme.desktop.gtk` | `true` or `false` | `true` | Chrome, Electron applications and GTK applications do not read KDE's colour scheme: they ask a portal, and the GTK portal answers from its own dark/light preference. With this on, that preference is written with the rest -- which is what makes them turn light by day and dark by night instead of staying wherever they were. `rmpr theme revert` puts the preference back. |
| `theme.desktop.gtkThemeLight` | text | `` | The GTK theme to wear in light mode, by name. Empty leaves the theme name alone, which is the default. Asking GTK to prefer light is not the same as giving it a light theme: a theme whose name is the dark half of its pair -- Nordic, adw-gtk3-dark -- ignores the preference and stays dark in every mode. Name both halves here and the pair follows day and night. Not guessed from the other name: adw-gtk3's light half drops "-dark", Nordic's is called Nordic-Polar, and a wrong guess puts you in a theme you never chose. |
| `theme.desktop.gtkThemeDark` | text | `` | The GTK theme to wear in dark mode, by name. Empty leaves the theme name alone. See GTK theme by day. |
| `theme.desktop.materialYou` | `true` or `false` | `false` | kde-material-you-colors derives a colour scheme from your wallpaper and applies it to the session -- at login, and again whenever the wallpaper changes. It has its own light/dark switch, so left alone it is the last writer at every login and the desktop wears its answer rather than this shell's. With this on, `rmpr theme variant` writes that switch and restarts the unit so the two agree. Off by default: it is somebody else's service, and rewriting a configuration this project does not own is not something to do uninvited. Ledgered, so `rmpr theme revert` puts it back. |
| `theme.desktop.colours` | `true` or `false` | `true` | The Plasma colour scheme every Qt application is drawn with. Off leaves whatever you have chosen in System Settings. |
| `theme.desktop.icons` | `true` or `false` | `true` | The icon theme, for applications and for the shell's own icons, which come from it rather than from a set of our own. |
| `theme.desktop.style` | `true` or `false` | `true` | The Qt widget style applications are drawn in -- buttons, scrollbars, checkboxes. |
| `theme.desktop.plasmaTheme` | `true` or `false` | `true` | The theme Plasma's own surfaces use: the desktop, its widgets, and anything the shell does not draw itself. |
| `theme.desktop.decorations` | `true` or `false` | `true` | The titlebars and borders KWin draws around windows. |
| `theme.desktop.switcher` | `true` or `false` | `true` | The window switcher's layout. |

### Taskbar

The panel: where it sits, how big it is, and the widgets that are parts of it -- the clock, the workspace pills and the window buttons. Every one of these is a configuration key, so a profile can set them by hand as well.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `panel.position` | `top`, `bottom`, `left`, `right` | `bottom` | Which edge the panel is anchored to. |
| `panel.thickness` | a number, 28 to 96 | `52` | Height of a horizontal panel, width of a vertical one. Its buttons grow and shrink with it. |
| `panel.style` | `full`, `floating`, `islands` | `full` | full is a strip along the whole edge. floating is a rounded bar held clear of the edge. islands draws no bar at all: each zone -- the start button and workspaces, the windows, the tray and clock -- is a rounded island of its own. |
| `panel.spacing` | a number, 2 to 16 | `5` | The gap between widgets, in pixels. |
| `panel.iconSize` | a number, 15 to 26 | `18` | The size of the tray's and the status icons, in pixels. |
| `panel.revealOnHover` | `true` or `false` | `true` | With hiding on, the panel comes back when the pointer reaches the screen edge. Off, it comes back only when something opens from it -- the launcher from a key, say. |
| `panel.autoHide` | `true` or `false` | `false` | The panel shrinks to a sliver and comes back when the pointer reaches the screen edge. It reserves no space while hidden, so windows use the whole screen. |
| `panel.menu.systemMonitor` | text | `auto` | Which application the right-click menu's System monitor row opens, as a desktop entry id. `auto` picks the first of the usual ones that is installed; `none` leaves the row off. A monitor that is not installed is not offered, and the row is hidden rather than shown and refusing. |
| `panel.menu.entries` | a list | `[]` | Extra rows on the panel's right-click menu, in this order. Each is an object: `label` is the words on the row, `command` is a shell command line run when it is chosen, and `glyph` is an optional Material Symbols name for its icon (`terminal` when left out). The command is run detached, so a script that keeps running does not end when the menu closes. |

### Sidebar

The panel that slides in from an edge: what is playing, the day and the weather, the machine, and the latest notifications. Opened with a shortcut ('rmpr shortcuts set sidebar'), a screen edge ('rmpr edges shell'), or the launcher's Sidebar action.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `sidebar.position` | `right`, `left` | `right` | Which side it slides in from. A screen edge bound to the sidebar follows this, so the edge you push into is the side it appears on. |
| `sidebar.trigger` | `drag`, `hover`, `none` | `drag` | 'drag' is a thin strip down the sidebar's own edge that you press and pull inwards -- a pointer resting there does nothing, so it cannot open by accident. 'hover' is KWin's screen edge instead ('rmpr edges shell'), which opens on a pointer that merely reaches the edge. 'none' leaves the shortcut and the launcher action as the only ways in. |
| `sidebar.handleWidth` | a number, 2 to 24 | `6` | How wide the strip you pull is, in pixels. It sits at the very edge of the screen, so a click that far out goes to it rather than to the window beneath. |
| `sidebar.width` | a number, 280 to 720 | `396` | How wide the panel is, in pixels. |
| `sidebar.margin` | a number, 0 to 64 | `16` | The gap between the panel and the screen's edges. |
| `sidebar.reserveSpace` | `true` or `false` | `false` | While it is open, reserve its width so maximised windows move over instead of being covered. Off: it floats above them and the desktop keeps its shape. |
| `sidebar.expanded` | a list | `["media"]` | Which cards start expanded, by id: media, day, weather, machine, notifications. Every card can be folded away and opened again from the sidebar itself; this is what it remembers. |
| `sidebar.cards` | a list | `["media","day","weather","machine","notifications"]` | Which cards the sidebar draws, in order. Leave a card out to hide it entirely. |

### Weather

Where the weather comes from. Off until you turn it on, because it is the one part of this shell that talks to the internet: forecasts come from Open-Meteo (no account, no key), and a place you have not named is looked up once from this machine's IP address.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `weather.enabled` | `true` or `false` | `false` | Fetches a forecast for your place. Nothing is sent but the coordinates being asked about; nothing is stored but the answer, in memory. |
| `weather.place` | text | `` | A town or city to look up -- "Cluj-Napoca", "Lisbon". Left empty, the place is worked out once from this machine's IP address, which is a guess a network can get wrong; naming it is exact and asks nobody. |
| `weather.coordinates` | text | `` | "46.77,23.60" -- latitude, longitude. Set, this wins over the place and no lookup of any kind is made. |
| `weather.units` | `metric`, `imperial` | `metric` | Celsius and km/h, or Fahrenheit and mph. |
| `weather.refresh` | a number, 10 to 360 | `30` | Minutes between forecasts. The forecast itself changes hourly at best. |

### Windows

What KWin does with windows: how focus is given, when one is raised, where a new one lands, and whether a maximised window keeps its border. These are KWin's own settings, written through the ledger by `rmpr windows behaviour`, so every change can be undone. Window gaps, rounded window corners and tiling layouts are not KWin's to give, and are not offered here.

No individual settings: this is a page in the settings window rather than a
list of values.

### Launcher

What opens when you press the start button, and what opens when you search.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `launcher.provider` | `auto`, `kickoff`, `builtin`, `krunner`, `fuzzel`, `rofi`, `custom` | `builtin` | Kickoff is Plasma's own menu, but it opens at whichever panel holds plasmashell's launcher applet rather than at this one. |
| `launcher.searchProvider` | `auto`, `krunner`, `builtin`, `kickoff`, `fuzzel`, `rofi`, `custom` | `builtin` | KRunner is Plasma's own search. |
| `launcher.layout` | `twopane`, `grid`, `list` | `twopane` | How the built-in launcher's start menu is laid out. twopane: categories, pinned apps and recent files, with you, what is playing and the machine beside them. grid: pinned apps and recent files. list: every application A to Z. Only when the built-in launcher is the application menu. |
| `launcher.actionPrefix` | `>`, `:`, `/` | `>` | Typed first in the built-in search, it offers the shell's actions -- the colour scheme, the wallpaper, the session, a calculator -- instead of applications. |
| `launcher.dense` | `true` or `false` | `false` | Shorter rows in the built-in search, so more fit. |
| `launcher.hints` | `true` or `false` | `true` | The keys the built-in search answers to, under its results. |
| `launcher.searchSources` | a list | `["apps","windows","files","settings"]` | What the built-in search looks through. apps: everything installed. windows: the open ones, by their titles, so a window can be raised by name. files: what was opened recently. settings: this shell's own pages. Remove a name to stop searching it. |
| `launcher.learn` | `true` or `false` | `true` | What has been opened before is offered first, and an empty search suggests it. Kept in the state directory and never sent anywhere; turning this off stops it being read, and Forget clears what is there. |
| `launcher.pinned` | a list | `[]` | Desktop entry ids at the top of the built-in start menu, in this order. Empty picks a terminal, files, a browser, an editor and so on from what is installed. |
| `launcher.kickoffMode` | `menu`, `windowed` | `menu` | Windowed opens Kickoff as an ordinary window; slower, and it will not close itself when it loses focus. |
| `launcher.command` | a list | `[]` | For the `custom` provider: a launcher and its arguments, run as written. `launcher.provider` or `launcher.searchProvider` set to `custom` runs it. |

### Notifications

Plasma draws every notification -- under this shell's own renderer, through the Plasma services it hosts -- unless this shell is asked to draw them itself. The history remembers what went past either way, so a notification that disappeared can be read again and, with AI assist on, asked about.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `notifications.server` | `plasma`, `shell` | `shell` | plasma: Plasma's own notification server, as always. shell: this shell serves them and draws its own popups beside the panel, with an Ask button on each when AI assist is on. That replaces Plasma's, so it is off unless chosen. It works only under this shell's renderer, and while another program holds the notification service -- Plasma's hosted applet, or another shell's bar -- it waits for the service to be let go of rather than taking it. |
| `notifications.popupTimeout` | a number, 2 to 30 | `6` | Unless the application asks for a time of its own. Critical ones stay until closed, and the pointer resting on a popup holds it. Only when this shell draws them. |
| `notifications.popupPosition` | `auto`, `top-right`, `top-center`, `top-left`, `bottom-right`, `bottom-center`, `bottom-left` | `auto` | auto is the right-hand end of the panel's edge, beside the clock. The centres are the middle of the top or bottom edge. Only when this shell draws them. |
| `notifications.centreStyle` | `grouped`, `stream` | `grouped` | What the bell opens. grouped: one card per application, the latest on top and the rest stacked behind it. stream: every notification in order, under today, yesterday and earlier. |
| `notifications.history` | `true` or `false` | `true` | Listens on the session bus for notifications as they are sent. Nothing is taken over and nothing is stored on disk; the history lives in memory and is gone when the shell stops. Off, the listener does not run at all. |
| `notifications.historySize` | a number, 5 to 500 | `50` | How many recent notifications to keep. |

### Lock & session

This shell's own lock screen -- off until it has been tried -- and which screen asks before the session ends. Plasma's greeter does the locking either way.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `session.prompt` | `plasma`, `shell` | `plasma` | plasma: Plasma's own logout screen, as always. shell: the shell's -- log out, restart, hibernate where the machine can, shut down -- which ends the session through Plasma's session manager all the same, so applications are still asked to save. |

### Desktop

What this shell draws on the desktop itself: a rounded frame over the screen's corners, and a clock on the wallpaper. Both are off until asked for, and neither takes a click or reserves any space.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `desktop.border` | `true` or `false` | `false` | Paints over the screen's corners so the desktop looks inset with rounded corners. Cosmetic: it reserves no space and takes no clicks, and the windows themselves are not rounded -- KWin has no effect for that. |
| `desktop.borderInset` | a number, 0 to 40 | `0` | How far in from each edge the frame is painted, in pixels. |
| `desktop.borderRadius` | a number, 0 to 48 | `13` | How round the painted corners are, in pixels. |
| `desktop.clock` | `true` or `false` | `true` | The time and date on the wallpaper, under every window. |
| `desktop.clockPosition` | `top-left`, `top-right`, `bottom-left`, `bottom-right` | `bottom-right` | Where it sits |
| `desktop.clockSize` | a number, 40 to 200 | `92` | The height of the time, in pixels; the date follows it. |
| `desktop.clockDate` | `true` or `false` | `true` | Show the date |
| `desktop.clockInk` | `auto`, `light`, `dark` | `auto` | auto follows the colour scheme. Nothing here can read the wallpaper, so a dark clock on a dark picture is one setting away rather than guessed. |

### Plasma services

Plasma's notifications, its clipboard history and its device notifier live inside Plasma's system tray, and the panel this shell draws has no Plasma tray. So under this shell's own renderer they are kept running by hosting Plasma's own applets outside any panel, each showing as one icon in the tray. Nothing is reimplemented, and nothing is hosted where a Plasma tray is there to provide them.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `services.hostPlasma` | `true` or `false` | `true` | Off, under the quickshell renderer nothing receives notifications at all -- they are dropped, not queued -- and the clipboard widget keeps a history of its own instead of Plasma's. |
| `clipboard.history` | `own`, `auto`, `plasma` | `own` | Which history Meta+V shows. Ours keeps text in memory and copied images as files, and an image in it can be chosen -- Klipper's DBus hands out text only, so a picture in Plasma's history can be seen and never picked. 'auto' is Klipper's whenever it is running, ours when it is not; 'plasma' is always Klipper's. Both can exist at once: neither writes to the other. |

### Widgets

What appears on the panel, and in which zone.

No individual settings: this is a page in the settings window rather than a
list of values.

### Tray icons

Which tray icons sit on the panel, which go behind the chevron, and which are left out. Drag a row from one list to another.

No individual settings: this is a page in the settings window rather than a
list of values.

### Screen edges

What happens when the pointer is pushed into a corner or an edge of the screen, and whether a window dragged there snaps. KWin does all of it; this only configures KWin, and every change can be undone.

No individual settings: this is a page in the settings window rather than a
list of values.

### Shortcuts

Every global shortcut this shell can take, and what each is bound to. These live in KDE's own kglobalshortcutsrc rather than in this shell's profile, so they are not part of a preset and do not move with one. Nothing is bound by default.

No individual settings: this is a page in the settings window rather than a
list of values.

### Switching windows

What Alt+Tab looks like, and which program gets Alt+Tab and Meta+Tab. KWin draws the window switcher and the Overview; another shell running beside it may be holding the keys, and nothing here moves one without being asked.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `switching.windows` | `plasma`, `shell` | `plasma` | plasma is KWin's own switcher, in this shell's colours. It is the default, it is the only one that can show a picture of each window -- KWin renders those for its own switcher and for nothing else -- and being inside the compositor it sees the keyboard directly. shell is this shell's card row, drawn here, which shows each application's icon instead. Choose it knowing the cost: the shell is not the compositor, so the key going down and the key coming up each cross kglobalaccel, the session daemon, the CLI and the IPC to reach it, and the two race. A quick enough Alt+Tab can leave the switcher on screen after the key is let go. Changing this rebinds Alt+Tab to whichever draws it. |
| `switching.desktops` | `plasma`, `shell` | `plasma` | shell is this shell's own desktop overview -- every desktop, what is open on each, and one more at the end -- drawn here in the panel's colours. plasma is KWin's Overview, which shows a real picture of every window but cannot be restyled: it is compiled into KWin rather than shipped as a package. Changing this rebinds Meta+Tab, taking it from whatever holds it; `rmpr switcher revert` gives it back. |
| `switching.overviewHold` | `true` or `false` | `true` | On, Meta+Tab is held: the desktops are shown while the key is down and letting go switches to whatever is selected, the way Alt+Tab works. Off, one press opens it and it stays until you choose something, press Escape or click away -- which is closer to how Windows behaves. |
| `switching.overviewTitles` | `true` or `false` | `true` | The title strip along the top of each window card. Off leaves the application's name and its state underneath, and a card that is only the application. |
| `switching.overviewMinimised` | `true` or `false` | `true` | Minimised windows appear in the overview, dimmed. Off lists only what is actually on screen. |
| `switching.overviewStrip` | `true` or `false` | `true` | The row along the bottom with every desktop, what is on each, and a tile for one more. Off gives the whole surface to the selected desktop's windows, and the desktops move on the arrows alone. |
| `switching.overviewCardWidth` | a number, 260 to 720 | `560` | In pixels. Cards share the room between them, three to a row at most, and never grow past this. |

### Sound

What a volume control here may do. PipeWire will amplify past 100% and distort doing it, so nothing in this shell offers that headroom until it is asked for -- the same choice, under the same name, as Plasma's own applet.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `audio.raiseMaxVolume` | `true` or `false` | `false` | Lets every volume slider in this shell go to 150% instead of stopping at 100%. Above 100% the sound is amplified in software, which distorts on most hardware. A level something else has already set above the ceiling is always shown, switch or no switch. |

### On-screen display

The volume and brightness popup. Plasma draws it by default and works well; ours exists for the placement and animation a Plasma OSD cannot do. Turning ours on without silencing Plasma's shows both -- 'rmpr theme osd ours' silences it.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `osd.enabled` | `true` or `false` | `false` | Listens to the same signals Plasma's OSD does. Nothing is taken over, and turning it off leaves Plasma exactly as it was. |
| `osd.timeout` | a number, 500 to 5000 | `1800` | Milliseconds before it fades. |

### Layouts

Shipped panel layouts. Applying one replaces your current configuration.

No individual settings: this is a page in the settings window rather than a
list of values.

### Profiles

Separate configurations you can switch between, and per-monitor overrides within each.

No individual settings: this is a page in the settings window rather than a
list of values.

### Restore points

Snapshots of your KDE configuration. Nothing is removed when reverting or uninstalling. They are removed here, or by pruning if you have set how many to keep -- and pruning never takes one you have locked, nor the oldest, which is the state the machine was in before this shell was installed.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `snapshots.keep` | a number, 0 to 200 | `0` | How many restore points are kept when a new one is taken. 0 keeps every one of them, which is the default: deleting somebody's restore points without being asked is not a thing to start doing quietly. Two are never removed by pruning whatever this says -- any restore point you have locked, and the oldest, which is the state the machine was in before this shell was installed. |

### Drawn by

What draws the panel. Only one of these can draw at a time, and switching is a real change to your desktop rather than a setting -- so it happens here, with a restore point, rather than as a value you can type.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `panel.renderer` | text | `quickshell` | Which of them draws the panel: `quickshell` (this shell), `plasma`, `none`, or `quickshell:<config>` for any other Quickshell configuration on this machine -- `rmpr renderer list` names them. Only one can draw, so two panels at one screen edge is not a state this can reach. Changing it by hand only tells the shell; the shell package, the applet layout and the restore point are the CLI's job -- use `rmpr renderer set`. |

### AI assist

When something breaks, hand a redacted diagnostic report to an assistant. Off by default. Nothing leaves this machine without a confirmation that shows exactly what would be sent.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `ai.enabled` | `true` or `false` | `false` | Turns on the 'ask' actions: in the notification history, as a global shortcut, and as `rmpr ask`. It also starts the notification listener, since a notification has to have been seen to be asked about. |
| `ai.provider` | `clipboard`, `claude-code`, `ollama`, `custom` | `clipboard` | `clipboard` copies the report for pasting anywhere and sends nothing. `claude-code` opens the `claude` command with the report. `ollama` asks a local model over HTTP. `custom` runs `ai.command`. Providers whose program is not installed are not offered. |
| `ai.command` | a list | `[]` | For the `custom` provider: a command and its arguments. `%report` is replaced with the path of the redacted bundle; without it, the bundle arrives on standard input. |
| `ai.ollamaUrl` | text | `http://127.0.0.1:11434` | Where the `ollama` provider sends its request. An address that is not this machine counts as leaving it, and is confirmed like any other. |
| `ai.ollamaModel` | text | `` | Empty picks the first model Ollama lists. |

### About

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `update.channel` | `main`, `dev` | `main` | Which branch `rmpr update` follows: `main` moves on a release, `dev` is where work lands and moves every day. |
| `update.remote` | text | `` | A git URL to update from. Empty uses the checkout's own origin, then the project's public address. |
| `update.localSource` | text | `` | A checkout on this machine to update from instead of a remote -- for testing a change before it is pushed. Empty for none. |

## The panel contents

`bar.entries` is an ordered list. Order matters *within* a zone, and every entry
needs a `zone` -- an entry without one is reported and skipped rather than
silently landing on the left.

```json
{
  "bar": {
    "entries": [
      {
        "id": "launcher",
        "zone": "left",
        "enabled": true
      },
      {
        "id": "search",
        "zone": "left",
        "enabled": true
      },
      {
        "id": "tasks",
        "zone": "left",
        "enabled": true
      },
      {
        "id": "tray",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "volume",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "brightness",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "clipboard",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "privacy",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "keyboard",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "status",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "notifications",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "clock",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "showdesktop",
        "zone": "right",
        "enabled": true
      }
    ]
  }
}
```

## Widgets

Each has its own settings, written under `widgets.<id>`, or inline on one entry
when two copies of a widget should differ.

| Widget | id | Zones | Plasma renderer |
| --- | --- | --- | --- |
| Active window | `activewindow` | left, middle, right | `org.kde.plasma.windowlist` |
| Battery | `battery` | left, middle, right | `org.kde.plasma.battery` (in the tray) |
| Bluetooth | `bluetooth` | left, middle, right | `org.kde.plasma.bluetooth` (in the tray) |
| Brightness and Night Light | `brightness` | left, middle, right | `org.kde.plasma.brightness` (in the tray) |
| Clipboard | `clipboard` | left, middle, right | `org.kde.plasma.clipboard` (in the tray) |
| Clock | `clock` | left, middle, right | `org.kde.plasma.digitalclock` |
| Divider | `divider` | left, middle, right | **not supported** |
| Keyboard layout | `keyboard` | left, middle, right | `org.kde.plasma.keyboardlayout` (in the tray) |
| Application launcher | `launcher` | left, middle, right | `org.kde.plasma.kickoff` |
| Media | `media` | left, middle, right | `org.kde.plasma.mediacontroller` (in the tray) |
| Network | `network` | left, middle, right | `org.kde.plasma.networkmanagement` (in the tray) |
| Notification history | `notifications` | left, middle, right | `org.kde.plasma.notifications` (in the tray) |
| Session | `power` | left, middle, right | `org.kde.plasma.lock_logout` |
| Camera and microphone in use | `privacy` | left, middle, right | `org.kde.plasma.cameraindicator` (in the tray) |
| Search | `search` | left, middle, right | `org.kde.milou` |
| Show desktop | `showdesktop` | left, middle, right | `org.kde.plasma.showdesktop` |
| Sidebar | `sidebar` | left, middle, right | **not supported** |
| Quick settings | `status` | left, middle, right | **not supported** |
| Open windows | `tasks` | left, middle, right | `org.kde.plasma.icontasks` |
| Task view | `taskview` | left, middle, right | **not supported** |
| System tray | `tray` | left, middle, right | `org.kde.plasma.systemtray` |
| Volume | `volume` | left, middle, right | `org.kde.plasma.volume` (in the tray) |
| Weather | `weather` | left, middle, right | **not supported** |
| Virtual desktops | `workspaces` | left, middle, right | `org.kde.plasma.pager` |

A widget with no Plasma applet is left out of the panel under the `plasma`
renderer, and is named before you switch rather than discovered afterwards.

One marked *in the tray* is an applet Plasma's system tray hosts by itself.
With `tray` also on the panel it is left to the tray rather than drawn twice;
without `tray` it stands on the panel alone.

### `widgets.activewindow`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `maxWidth` | a number, 80 to 800 | `320` | It is elided past this. |
| `showIcon` | `true` or `false` | `true` | Show the application's icon |
| `showAppName` | `true` or `false` | `false` | "Dolphin" rather than the folder it has open, as a macOS menu bar does. |

### `widgets.battery`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `showPercentage` | `true` or `false` | `false` | Beside the icon. The icon alone moves in steps of ten. |

### `widgets.brightness`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `step` | a number, 1 to 20 | `5` | Percent per notch of the wheel. |

### `widgets.clipboard`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `shown` | a number, 5 to 50 | `15` | How many of the most recent entries the popout lists. |

### `widgets.clock`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `hour12` | `true` or `false` | `false` | 12-hour clock |
| `showSeconds` | `true` or `false` | `false` | Show seconds |
| `showDate` | `true` or `false` | `true` | Under the time; beside it on a thin panel, and not at all down the side of the screen. |
| `format` | text | `` | A Qt date/time format string, which wins over the choices above. Empty for those. |
| `dateFormat` | text | `ddd d MMM` | Date format |

### `widgets.launcher`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `glyph` | text | `blur_on` | A Material Symbols name, drawn on the accent tile. Empty draws the theme icon below instead. |
| `icon` | text | `start-here-kde` | Drawn when the glyph is empty, or where Material Symbols is not installed. |
| `label` | text | `` | Shown beside the icon. Empty for icon only. |

### `widgets.media`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `showTitle` | `true` or `false` | `true` | Beside the icon, on a panel along the top or bottom. |
| `maxWidth` | a number, 60 to 400 | `180` | It is elided past this. |

### `widgets.notifications`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `showCount` | `true` or `false` | `false` | Something unseen shows as a dot on the bell; on, as the number since the list was last opened. |

### `widgets.power`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `action` | `promptAll`, `promptLogout`, `promptReboot`, `promptShutDown` | `promptAll` | Action |

### `widgets.search`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `label` | text | `Search` | The word in the field. Empty for the icon alone; down the side of the screen there is never room for it. |

### `widgets.showdesktop`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `width` | a number, 2 to 40 | `8` | Strip width |
| `peek` | `true` or `false` | `false` | Rest the pointer on the strip to move the windows aside until it leaves. A click while peeking keeps the desktop. |
| `peekDelay` | a number, 100 to 2000 | `500` | Peek after (ms) |

### `widgets.status`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `tiles` | `wifi`, `ethernet`, `bluetooth`, `microphone`, `dnd`, `night`, `game`, `vpn` | `["wifi","ethernet","bluetooth","microphone","dnd","night","game","vpn"]` | Which switches the grid draws, in this order. A tile for hardware the machine does not have is left out whether or not it is on here -- no Bluetooth adapter, no Bluetooth tile. |
| `density` | `roomy`, `dense` | `roomy` | roomy: a grid of tiles. dense: a list of rows, each with its switch. |
| `step` | a number, 1 to 25 | `5` | Percent per notch of the wheel. |

### `widgets.tasks`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `groupByApp` | `true` or `false` | `true` | One button per application, as KDE and Windows do, with a mark per window. Clicking moves through that application's windows. |
| `pinned` | a list | `[]` | Desktop entry ids ("org.kde.dolphin"), kept on the taskbar in this order whether or not they are running. Right-click a button and choose "Pin to taskbar" rather than typing them. |
| `thisScreenOnly` | `true` or `false` | `false` | Each monitor's panel lists the windows on that monitor, as Windows does with "show taskbar apps on the taskbar where the window is open". |
| `thisDesktopOnly` | `true` or `false` | `true` | The windows on the virtual desktop in front, as KDE's own task manager and Windows both do. Off lists every window on every desktop. A window set to be on all desktops is always listed. |
| `showTitles` | `true` or `false` | `true` | The window's title beside its icon, as far as the widest a button gets. Off, buttons are icons alone and the title is one hover away. |
| `maxWidth` | a number, 60 to 400 | `230` | Titles are elided past this. |
| `iconSize` | a number, 0 to 48 | `0` | 0 follows the panel's thickness, so resizing the panel resizes the icons with it. |
| `iconScale` | a number, 40 to 100 | `72` | How much of a button's height the icon fills, in percent. 100 leaves no room around it; the default leaves a little. Ignored when "Icon size" is set to an exact number of pixels. |

### `widgets.taskview`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `effect` | `Overview`, `Grid View`, `Expose`, `ExposeAll` | `Overview` | Which of KWin's views: the Overview, the grid of virtual desktops, or the windows of this desktop (Expose) or of all of them (ExposeAll). |

### `widgets.tray`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `iconSize` | a number, 0 to 48 | `0` | 0 follows the panel's tray icon size. |
| `chevron` | `after`, `before` | `after` | after: at the end of the tray, past the icons, as the design has it. before: at the start, so the icons that come and go do not push it around -- which is what Plasma's tray does. |
| `pinned` | a list | `[]` | StatusNotifierItem ids shown on the panel, in this order. Empty shows every item; pin any and the rest move behind the chevron. Settings has a page that edits this by dragging, which is easier than typing ids. |
| `hidden` | a list | `[]` | Ids left out altogether, not even behind the chevron. |

### `widgets.volume`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `step` | a number, 1 to 20 | `5` | Percent per notch of the wheel. |
| `maxVolume` | a number, 0 to 150 | `0` | Percent. 0 follows Settings → Sound, where "Raise maximum volume" lives and which every other slider in this shell reads; anything else is this widget's own ceiling. |
| `showMicrophone` | `true` or `false` | `true` | A second slider in the popout, for the default input. |

### `widgets.weather`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `showTemperature` | `true` or `false` | `true` | Beside the icon. Off leaves the icon alone, which is narrower on a full panel. |
| `showPlace` | `true` or `false` | `false` | The town the forecast is for, after the temperature. |
| `days` | a number, 1 to 6 | `5` | How many days of the forecast the popout lists. |

### `widgets.workspaces`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `style` | `numbers`, `icons`, `dots` | `numbers` | numbers: the desktop's number. icons: the icons of the windows on it. dots: a dot. An empty desktop is always a dot. |
| `maxShown` | a number, 1 to 20 | `8` | At most this many; the current desktop is always among them. |
| `showNames` | `true` or `false` | `false` | Show desktop names |
| `scrollToSwitch` | `true` or `false` | `true` | Switch by scrolling |

## A complete example

Everything below is optional; anything left out comes from the defaults.

```json
{
    "panel": { "position": "top", "thickness": 32 },
    "bar": {
        "entries": [
            { "id": "launcher", "zone": "left" },
            { "id": "clock", "zone": "middle" },
            { "id": "tray", "zone": "right" }
        ]
    },
    "widgets": {
        "clock": { "format": "HH:mm", "showDate": true }
    }
}
```
