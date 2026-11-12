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
| `theme.mode` | `auto`, `light`, `dark` | `auto` | auto is light by day and dark by night, on KDE's night time schedule -- the same sunset that warms your screen -- or the sun at your own place when KDE has none (see Day and night from). With no schedule and no place to work one out from, auto instead turns dark whenever the Plasma colour scheme is dark, following it the moment it changes. light and dark hold it where they say. |
| `theme.daylight.source` | `kde`, `shell` | `kde` | Whose sunset auto follows. kde is KDE's own night time schedule -- the one Night Light and Plasma's dark-at-night switch use -- and the shell works out the sun itself only when KDE has none: night time uninstalled or not running, or stuck on its fallback 18:00 and 06:00 because it could not find your location at login. shell always works it out itself, from the sun at the place GeoClue gives (the last place it gave, when it is slow to answer), or weather.coordinates. Nothing is looked up on the internet for this. |
| `theme.accent` | `plasma`, `blue`, `teal`, `magenta`, `orange` | `plasma` | plasma is Plasma's own accent colour, which System Settings can also take from the wallpaper. Every other colour the shell uses is worked out from this one, in Material Design's roles. A colour written as #rrggbb is accepted too. |
| `theme.translucent` | `true` or `false` | `true` | The panel and its popouts let a little of what is behind them through. Off draws them solid. |
| `theme.shadows` | `true` or `false` | `false` | A soft shadow under the panel, its popouts, the start menu and the on-screen display. Off by default: a shadow is a band of dimmed wallpaper around a surface whose own background is blurred, and on a dark desktop the join between the two reads as a second panel behind the first. |
| `theme.rounding` | a number, 0 to 36 | `8` | The radius of the largest surfaces -- the start menu, quick settings, a floating panel. Smaller things are rounded in proportion. |
| `theme.animationMs` | a number, 0 to 400 | `180` | In milliseconds: a popout rising out of the panel, the switcher, the desktop overview, a floating panel filling its edge or floating off it, a hidden one coming back. 0 makes them appear at once, which is the fastest the shell can feel and the least it can explain -- a surface that simply exists gives no hint about where it came from. |
| `theme.desktop.enabled` | `true` or `false` | `true` | Applying the theme also re-themes KDE itself, so applications match the shell rather than only the panel and its popouts. Off confines the theme to what this shell draws. Each part below can be left out; anything left out keeps whatever you have chosen in System Settings, and `rmpr theme revert` puts every part back. |
| `theme.desktop.followMode` | `true` or `false` | `false` | With Colour scheme set to auto, the colour scheme and icon theme KDE itself uses are rewritten when night falls, so applications turn dark with the shell instead of staying wherever they were last put. Off by default: it writes KDE's own configuration on a schedule, which is not something to do to a desktop uninvited. `rmpr theme variant` does it once, by hand, and `rmpr theme revert` puts it all back. Plasma's own widgets follow from the next plasmashell start. |
| `theme.desktop.rescuePlasmaSwitch` | `true` or `false` | `true` | Plasma's own "Switch to Dark Mode at Night" is a background module with a timer, and a timer can miss -- a Frameworks upgrade under a running session is enough to stop it. When it does, the shell turns dark at sunset and every application stays light until the next login. On, the desktop is put in the right half here instead, but only after waiting twenty seconds for Plasma to do it first, so the two never write over each other. Off leaves a missed sunset missed. |
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
| `panel.defloat` | `true` or `false` | `true` | With the floating bar or islands, the panel becomes a full-width strip while a window on its monitor reaches into its space -- a maximised one always does -- and floats again when none does, as Plasma's floating panel does. A window on the other monitor does not count, however far it hangs over, and nor does a full-screen one, which covers the edge whatever the panel reserves. The strip is the bar's own thickness, and the margin a floating panel keeps from the edge is given to the windows while it lasts. Off, it always floats. |
| `panel.spacing` | a number, 2 to 16 | `5` | The gap between widgets, in pixels. |
| `panel.iconSize` | a number, 15 to 26 | `18` | The size of the tray's and the status icons, in pixels. |
| `panel.revealOnHover` | `true` or `false` | `true` | With hiding on, the panel comes back when the pointer reaches the screen edge. Off, it comes back only when something opens from it -- the launcher from a key, say. |
| `panel.autoHide` | `true` or `false` | `false` | The panel shrinks to a sliver and comes back when the pointer reaches the screen edge. It reserves no space while hidden, so windows use the whole screen. |
| `panel.fullScreen` | `hide`, `kwin` | `hide` | hide draws nothing on a monitor whose top window is full screen, and takes no clicks there, until that window leaves full screen or another is raised over it. kwin leaves it to KWin's stacking, as Plasma's own panel does: a full-screen window stays above the panel only while it has focus, so the panel shows over a game or a video once focus has gone elsewhere on that monitor. Either way the panel keeps the space it reserves, so no other window is resized. |
| `panel.menu.systemMonitor` | text | `auto` | Which application the right-click menu's System monitor row opens, as a desktop entry id -- any installed application, not only a monitor. `auto` picks Plasma's System Monitor where it is installed, and otherwise the first application whose desktop entry says it is a system monitor (the `Monitor` category), one that opens a window before one that runs in a terminal; `none` leaves the row off. Settings offers the installed monitors first and any other application through a search. One that is not installed any more hides the row rather than showing it and refusing. |
| `panel.menu.entries` | a list | `[]` | Extra rows on the panel's right-click menu, in this order. Each is an object that either opens an application -- `app`, a desktop entry id, drawn with the application's icon and called by its name unless `label` says otherwise -- or runs a command: `label` is the words on the row and `command` a shell command line, run detached, so a script that keeps running does not end when the menu closes. `glyph` is an optional Material Symbols name for the row's icon (`terminal` for a command when left out). An application that is not installed any more is left off the menu. |

### Dock

A second panel of large application tiles floating clear of the screen's edge, as on macOS: the start button, the applications kept in it and the ones running, each with a dot under it while it has windows, and Downloads and the Trash at the end. A click starts an application or raises it, a middle click starts another, and a right click keeps it in the dock or takes it out. Off by default; the macOS-like layout turns it on. Running applications need the open-window list (`rmpr windows enable`); without it the dock shows what is kept in it.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `dock.enabled` | `true` or `false` | `false` | Draws the dock on every screen. It can be turned off for one monitor in that monitor's own settings file. |
| `dock.position` | `bottom`, `left`, `right` | `bottom` | Which edge the dock floats along. On the same edge as the panel it sits beside the panel, never under it. |
| `dock.iconSize` | a number, 32 to 80 | `48` | How big each tile is, in pixels. The dock grows and shrinks with it. |
| `dock.magnify` | `true` or `false` | `false` | The tile under the pointer grows, and the ones beside it grow less, as on macOS. The dock's own glass stays the same height; the tiles grow out of it, away from the edge. |
| `dock.magnifiedSize` | a number, 48 to 128 | `96` | How big the tile under the pointer grows, in pixels. No larger than the tile size, nothing grows. |
| `dock.visibility` | `always`, `autohide`, `dodge` | `always` | always keeps the dock on screen and keeps windows clear of it, as a maximised window is kept clear of the panel. autohide slides it away until the pointer reaches its edge. dodge keeps it on screen until a window on this monitor reaches into its space -- a maximised one always does -- and brings it back when the pointer reaches the edge. It never hides while the pointer or its menu is on it. |
| `dock.pinned` | a list | `[]` | Desktop entry ids, in the order they sit in the dock. Empty shows the start menu's pinned applications until one is kept or taken out with a right click, which writes the list. |
| `dock.launcher` | `true` or `false` | `true` | The start menu, as the dock's first tile. |
| `dock.running` | `true` or `false` | `true` | Applications with windows open that are not kept in the dock appear after those that are, and go when their last window closes. Off, the dock holds only what is kept in it, and those still carry their dots. |
| `dock.places` | `true` or `false` | `true` | Past a divider at the end of the dock: the Downloads folder and the Trash, opened with whatever the desktop opens them with. |

### Widgets

What appears on the panel, and in which zone.

No individual settings: this is a page in the settings window rather than a
list of values.

### Tray icons

Which tray icons sit on the panel, which go behind the chevron, and which are left out. Drag a row from one list to another.

No individual settings: this is a page in the settings window rather than a
list of values.

### Sidebar

The panel that slides in from an edge: what is playing, the day and the weather, the machine, and the latest notifications. Opened from its edge (below), with a shortcut ('rmpr shortcuts set sidebar'), the panel's Sidebar button, or the launcher's Sidebar action.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `sidebar.position` | `right`, `left` | `right` | Which side it slides in from. A screen edge bound to the sidebar follows this, so the edge you push into is the side it appears on. |
| `sidebar.trigger` | `drag`, `hover`, `none` | `drag` | 'drag': push the pointer against the sidebar's edge and hold it there a moment, and a short grip lights up where the pointer is -- press it and pull inwards, and the sidebar comes out under the pointer; let go before a third of the way and it goes back. Until then nothing is there, so a scrollbar or a window against that edge keeps every pixel. 'hover': push the pointer against the edge and hold it a moment, and the sidebar opens on that screen (see 'Close when the pointer leaves'). Either way on every screen: where another screen meets that side, KWin's edge barrier (on by default) holds the pointer at the edge for that moment instead of letting it cross straight over. Never over a full-screen window, whose edge is its own. 'none' leaves the shortcut, the panel button and the launcher action as the ways in. |
| `sidebar.handleWidth` | a number, 1 to 24 | `1` | How many pixels in from the very edge the lit grip takes a press, in pixels. One is the column the pointer stops in when it is pushed into the edge. While the strip keeps windows off it, this is also how much of that edge they give up. |
| `sidebar.handleReserves` | `true` or `false` | `false` | Reserve the strip's width, as a panel does, so maximised windows stop short of it. Nothing is ever under it then, so it is always there, the whole height of the edge and on every screen, with no push needed -- at the cost of a gap that wide down that edge. Off: no gap, and the grip takes nothing until the edge is pushed into, and then only a short stretch where the pointer is. |
| `sidebar.closeOnLeave` | `true` or `false` | `true` | For a sidebar opened by the pointer at its edge ('Pointer at the edge'): it goes away again once the pointer has been in it and left, or if the pointer never comes to it. Opened by a pull, a key, the panel button or the launcher, it stays until it is closed. |
| `sidebar.closeOnClickOutside` | `true` or `false` | `true` | A click anywhere off the sidebar puts it away, on any screen, as a menu's does -- and goes no further, since nothing can hand it on to the window underneath. The panel still works while it is up. Off: the windows around it keep every click and scroll while it is open, and it closes with Escape, its close button, its key or the panel button. |
| `sidebar.width` | a number, 280 to 720 | `396` | How wide the panel is, in pixels. |
| `sidebar.margin` | a number, 0 to 64 | `16` | The gap between the panel and the screen's edges. |
| `sidebar.reserveSpace` | `true` or `false` | `false` | While it is open, reserve its width so maximised windows move over instead of being covered. Off: it floats above them, and the desktop keeps its shape. |
| `sidebar.expanded` | a list | `["media"]` | Which cards start expanded, by id: media, day, weather, machine, notifications. Every card can be folded away and opened again from the sidebar itself; this is what it remembers. |
| `sidebar.cards` | a list | `["media","day","weather","machine","notifications"]` | Which cards the sidebar draws, in order. Leave a card out to hide it entirely. |

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

### Weather

Where the weather comes from. Off until you turn it on, because it is the one part of this shell that talks to the internet: forecasts come from Open-Meteo (no account, no key). A place you have not named is asked of the OS first -- GeoClue, the location service KDE's night time uses -- and only when the OS cannot say is it looked up once from this machine's IP address.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `weather.enabled` | `true` or `false` | `false` | Fetches a forecast for your place. Nothing is sent but the coordinates being asked about; nothing is stored but the answer, in memory. |
| `weather.place` | text | `` | A town or city to look up -- "Cluj-Napoca", "Lisbon". Left empty, the OS's own location service (GeoClue) says where you are, and only without one is the place guessed once from this machine's IP address -- a guess a network can get wrong. Naming it is exact and asks nobody. |
| `weather.coordinates` | text | `` | "46.77,23.60" -- latitude, longitude. Set, this wins over the place and no lookup of any kind is made. |
| `weather.units` | `metric`, `imperial` | `metric` | Celsius and km/h, or Fahrenheit and mph. |
| `weather.refresh` | a number, 10 to 360 | `30` | Minutes between forecasts. The forecast itself changes hourly at best. |

### Windows

What KWin does with windows: how focus is given, when one is raised, where a new one lands, whether a maximised window keeps its border, and which side of the title bar its buttons sit on. These are KWin's settings, written through the ledger by `rmpr windows behaviour` and `rmpr windows titlebar`, so every change can be undone. Tiling has a page of its own. Rounded window corners are not KWin's to give, and are not offered here.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `windows.titleButtons` | `plasma`, `right`, `left`, `custom` | `plasma` | Where KWin draws minimise, maximise and close on every window's title bar. plasma writes nothing and leaves KWin's order to Plasma's Window Decorations page. right is minimise, maximise and close at the right; left is close, minimise and maximise at the left, as the macOS-like layout has them; custom is the two strings below. Anything but plasma is written to kwinrc ([org.kde.kdecoration2] ButtonsOnLeft and ButtonsOnRight) through the ledger by `rmpr windows titlebar set`, and what was there before is put back by choosing plasma again, by restoring KDE and by an uninstall. KDE applications follow it, and GTK applications that draw their own title bar when Plasma passes the order on; an application with a title bar entirely its own, such as VS Code or Discord, keeps its own. |
| `windows.titleButtonsLeft` | text | `MS` | For custom: KWin's button letters, in order from the left edge. M window menu, S on all desktops, H help, I minimise, A maximise, X close, F keep above, B keep below, L shade. Each letter once, across both sides. |
| `windows.titleButtonsRight` | text | `HIAX` | For custom: the same letters, in order towards the right edge. The default, with the one on the left, is Breeze's own. |
| `windows.titleButtonsFromLayouts` | `true` or `false` | `true` | Whether applying a layout may set the title-bar buttons: the macOS-like layout puts them on the left, and the next layout that says nothing about them puts back what you had. Off, `rmpr preset apply` leaves them as they are. This switch is yours, never a layout's: no layout carries it, and saving a layout leaves it out. |

### Tiling

Windows in KWin's own tiles, the ones Meta+T edits: auto-tiling -- off unless turned on -- which tiles every window as it opens in Hyprland's dwindle layout; snap layouts, a panel at the top of the screen while a window is dragged or on Meta+Z, and Snap Assist after a snap; layouts of your own for that panel, drawn here; and the gap around a tiled window. Written through the ledger by `rmpr windows behaviour` and `rmpr windows snap layouts`, so every change can be undone.

No individual settings: this is a page in the settings window rather than a
list of values.

### Launcher

What opens when you press the start button, and what opens when you search.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `launcher.provider` | `auto`, `kickoff`, `builtin`, `krunner`, `custom` | `builtin` | Kickoff is Plasma's own menu, but it opens at whichever panel holds plasmashell's launcher applet rather than at this one. |
| `launcher.searchProvider` | `auto`, `krunner`, `builtin`, `kickoff`, `custom` | `builtin` | KRunner is Plasma's own search. |
| `launcher.layout` | `twopane`, `grid`, `list`, `launchpad` | `twopane` | How the built-in launcher's start menu is laid out. twopane: categories, pinned apps and recent files, with you, what is playing and the machine beside them. grid: pinned apps and recent files. list: every application A to Z. launchpad: every application over the whole screen, a page at a time, as macOS has it -- type to filter, arrows and Return to start one. Only when the built-in launcher is the application menu. |
| `launcher.launchpadBackdrop` | a number, 40 to 100 | `85` | How much Launchpad covers the screen behind it, in percent: the theme's own surface at this opacity, blurred where KWin blurs. 100 hides the windows behind entirely. |
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

### On-screen display

The volume and brightness popup. Plasma draws it by default and works well; ours exists for the placement and animation a Plasma OSD cannot do. Turning ours on without silencing Plasma's shows both -- 'rmpr theme osd ours' silences it.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `osd.enabled` | `true` or `false` | `false` | Listens to the same signals Plasma's OSD does. Nothing is taken over, and turning it off leaves Plasma exactly as it was. |
| `osd.timeout` | a number, 500 to 5000 | `1800` | Milliseconds before it fades. |

### Sound

Where the volume and the devices are read from, and what a volume control here may do. A sound server will amplify past 100% and distort doing it, so nothing in this shell offers that headroom until it is asked for -- the same choice, under the same name, as Plasma's own applet.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `audio.backend` | `auto`, `pipewire`, `pulse` | `auto` | Where the volume, the mute and the list of devices are read from. 'auto' asks who answers the PulseAudio socket: PulseAudio itself is read through pactl, because the devices it holds are ones PipeWire cannot open, and anything else -- PipeWire's own pipewire-pulse, or nobody -- is read from PipeWire directly. 'pipewire' and 'pulse' hold it to one. Both servers running at once is a broken setup whichever is read: each holds devices the other cannot open, and applications play through whichever owns the socket. |
| `audio.raiseMaxVolume` | `true` or `false` | `false` | Lets every volume slider in this shell go to 150% instead of stopping at 100%. Above 100% the sound is amplified in software, which distorts on most hardware. A level something else has already set above the ceiling is always shown, switch or no switch. |

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

### Screen edges

What happens when the pointer is pushed into a corner or an edge of the screen, and whether a window dragged there snaps. KWin does all of it; this only configures KWin, and every change can be undone.

No individual settings: this is a page in the settings window rather than a
list of values.

### Shortcuts

Every global shortcut this shell can take, and what each is bound to. The keys are part of this shell's configuration, so a preset or profile carries them, and the session daemon applies them at every login -- taking a configured key back from anything that grabbed it meanwhile, as KRunner does with Meta+Space. An empty value leaves that action to KDE's own shortcut settings; 'none' keeps it unbound. Meta opens the menu, Meta+Space the search and Meta+Z the snap layouts by default; auto-tiling's keys are bound when it is turned on.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `shortcuts.launcher` | text | `Meta` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.search` | text | `Meta+Space` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.settings` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.ask` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.clipboard` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.sidebar` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.keys` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.switcher` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.switcher-reverse` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.overview` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.overview-reverse` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.screenshot` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.screenshot-screen` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.screenshot-window` | text | `` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it. |
| `shortcuts.snap` | text | `Meta+Z` | The key, as KDE writes it ("Meta+Space", "Meta+/"). Empty leaves it to KDE's shortcut settings; "none" keeps it unbound. `rmpr shortcuts set` and the Shortcuts page write it, and so does Settings > Tiling, which binds Meta+Z or unbinds it. It does nothing while snap layouts are off. |
| `shortcuts.tile-focus-left` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+Left, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-focus-right` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+Right, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-focus-up` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+Up, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-focus-down` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+Down, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-move-left` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+Shift+Left, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-move-right` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+Shift+Right, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-move-up` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+Shift+Up, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-move-down` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+Shift+Down, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-swap-left` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Ctrl+Alt+Left, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-swap-right` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Ctrl+Alt+Right, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-swap-up` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Ctrl+Alt+Up, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-swap-down` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Ctrl+Alt+Down, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-float` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+Space, and turning it off unbinds it. It does nothing while auto-tiling is off. |
| `shortcuts.tile-desktop` | text | `` | The key, as KDE writes it. Turning auto-tiling on (Settings > Tiling) binds it, when nothing is, to Meta+Alt+T, and turning it off unbinds it. It does nothing while auto-tiling is off. |

### Lock & session

This shell's own lock screen -- off until it has been tried -- and which screen asks before the session ends. Plasma's greeter does the locking either way.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `session.prompt` | `plasma`, `shell` | `plasma` | plasma: Plasma's own logout screen, as always. shell: the shell's -- log out, restart, hibernate where the machine can, shut down -- which ends the session through Plasma's session manager all the same, so applications are still asked to save. |

### Plasma services

Plasma's notifications, its clipboard history and its device notifier live inside Plasma's system tray, and the panel this shell draws has no Plasma tray. So under this shell's own renderer they are kept running by hosting Plasma's own applets outside any panel, each showing as one icon in the tray. Nothing is reimplemented, and nothing is hosted where a Plasma tray is there to provide them.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `services.hostPlasma` | `true` or `false` | `true` | Off, under the quickshell renderer nothing receives notifications at all -- they are dropped, not queued -- and the clipboard widget keeps a history of its own instead of Plasma's. |
| `clipboard.history` | `own`, `auto`, `plasma` | `own` | Which history Meta+V shows. Ours keeps text in memory and copied images as files, and an image in it can be chosen -- Klipper's DBus hands out text only, so a picture in Plasma's history can be seen and never picked. 'auto' is Klipper's whenever it is running, ours when it is not; 'plasma' is always Klipper's. Both can exist at once: neither writes to the other. |
| `clipboard.preview` | `true` or `false` | `true` | The clipboard history -- Meta+V and the panel's clipboard button -- shows the selected entry whole beside the list: all of a text, a link's address, a colour, a picture. Off, the card is the list alone and about half as wide. |
| `clipboard.confirm` | `true` or `false` | `true` | Choosing an entry from the clipboard history copies it and closes; a shell cannot paste into another window on Wayland. This shows "Copied" and what was copied for a second and a half where it was chosen -- at the pointer for Meta+V, beside the button for the panel's clipboard -- so you know it is ready for Ctrl+V. Off, nothing is shown. |
| `clipboard.keepPins` | `true` or `false` | `true` | Pinned entries of this shell's own history are written down -- in the state directory, readable by you alone -- and are back after the shell or the machine restarts. Nothing unpinned is ever written. Off, pins last as long as the shell does, and the file is removed. Klipper keeps its own. |

### Drawn by

What draws the panel. Only one of these can draw at a time, and switching is a real change to your desktop rather than a setting -- so it happens here, with a restore point, rather than as a value you can type.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `panel.renderer` | text | `quickshell` | Which of them draws the panel: `quickshell` (this shell), `plasma`, `none`, or `quickshell:<config>` for any other Quickshell configuration on this machine -- `rmpr renderer list` names them. Another shell's configuration is always written with the `quickshell:` in front: a bare name is not a renderer, and is not guessed at. Only one can draw, so two panels at one screen edge is not a state this can reach. Changing it by hand only tells the shell; the shell package, the applet layout and the restore point are the CLI's job -- use `rmpr renderer set`. |

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
| Global menu | `appmenu` | left, middle, right | `org.kde.plasma.appmenu` |
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

### `widgets.appmenu`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `showAppName` | `true` or `false` | `true` | As macOS draws it. Off, the menus alone. |

### `widgets.battery`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `showPercentage` | `true` or `false` | `false` | Beside the icon. The icon alone moves in steps of ten. |

### `widgets.brightness`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `step` | a number, 1 to 20 | `5` | Percent per notch of the wheel. |

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
| `parts` | `privacy`, `network`, `bluetooth`, `brightness`, `volume`, `battery` | `["privacy","network","bluetooth","volume","battery"]` | Which glyphs the panel shows in the group, in this order. One for hardware the machine does not have is left out whether or not it is on here. Leave out one that has a widget of its own on the panel, or it shows twice. |
| `capsule` | `true` or `false` | `false` | The glyphs sit on a rounded background all the time, so the group reads as one button, as Windows draws its quick settings. Off, the background shows only while the pointer is over it. |
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
| `previewHeader` | `true` or `false` | `false` | The application's icon and name over the window cards, with how many windows it has. Off, each card's own icon and title say it. |
| `previewScreen` | `true` or `false` | `false` | With more than one monitor, the one a window is on ("DP-2") after its title. The desktop it is on is said whenever there is more than one. |
| `stackGroups` | `true` or `false` | `true` | A second square behind the icon when an application has more than one window open, so the count shows on the button itself. |
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
