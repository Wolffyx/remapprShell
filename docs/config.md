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

### Panel

Where the panel sits and how big it is.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `panel.position` | `top`, `bottom`, `left`, `right` | `bottom` | Which edge the panel is anchored to. |
| `panel.thickness` | a number, 20 to 96 | `40` | Height of a horizontal panel, width of a vertical one. |
| `panel.autoHide` | `true` or `false` | `false` | The panel shrinks to a sliver and comes back when the pointer reaches the screen edge. It reserves no space while hidden, so windows use the whole screen. |

### Drawn by

What draws the panel. Only one of these can draw at a time, and switching is a real change to your desktop rather than a setting -- so it happens here, with a restore point, rather than as a value you can type.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `panel.renderer` | `quickshell`, `plasma`, `caelestia`, `none` | `quickshell` | Which of them draws the panel. Only one can, so two panels at one screen edge is not a state this can reach. Changing it by hand only tells the shell; the shell package, the applet layout and the restore point are the CLI's job -- use `rmpr renderer set`. |

### Launcher

What opens when you press the start button, and what opens when you search.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `launcher.provider` | `auto`, `kickoff`, `builtin`, `krunner`, `fuzzel`, `rofi`, `custom` | `auto` | Kickoff is Plasma's own menu, but it opens at whichever panel holds plasmashell's launcher applet rather than at this one. |
| `launcher.searchProvider` | `auto`, `krunner`, `builtin`, `kickoff`, `fuzzel`, `rofi`, `custom` | `auto` | KRunner is Plasma's own search. |
| `launcher.kickoffMode` | `menu`, `windowed` | `menu` | Windowed opens Kickoff as an ordinary window; slower, and it will not close itself when it loses focus. |

### On-screen display

The volume and brightness popup. Plasma draws it by default and works well; ours exists for the placement and animation a Plasma OSD cannot do. Turning ours on without silencing Plasma's shows both -- 'rmpr theme osd ours' silences it.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `osd.enabled` | `true` or `false` | `false` | Listens to the same signals Plasma's OSD does. Nothing is taken over, and turning it off leaves Plasma exactly as it was. |
| `osd.timeout` | a number, 500 to 5000 | `1800` | Milliseconds before it fades. |

### Notification history

Plasma draws every notification -- under this shell's own renderer, through the Plasma services it hosts. This only remembers what went past, so a notification that disappeared can be read again -- and, with AI assist on, asked about.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `notifications.history` | `true` or `false` | `false` | Listens on the session bus for notifications as they are sent. Nothing is taken over and nothing is stored on disk; the history lives in memory and is gone when the shell stops. Off, the listener does not run at all. |
| `notifications.historySize` | a number, 5 to 500 | `50` | How many recent notifications to keep. |

### Plasma services

Plasma's notifications, its clipboard history and its device notifier live inside Plasma's system tray, and the panel this shell draws has no Plasma tray. So under this shell's own renderer they are kept running by hosting Plasma's own applets outside any panel, each showing as one icon in the tray. Nothing is reimplemented, and nothing is hosted where a Plasma tray is there to provide them.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `services.hostPlasma` | `true` or `false` | `true` | Off, under the quickshell renderer nothing receives notifications at all -- they are dropped, not queued -- and the clipboard widget keeps a history of its own instead of Plasma's. |

### AI assist

When something breaks, hand a redacted diagnostic report to an assistant. Off by default. Nothing leaves this machine without a confirmation that shows exactly what would be sent.

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `ai.enabled` | `true` or `false` | `false` | Turns on the 'ask' actions: in the notification history, as a global shortcut, and as `rmpr ask`. It also starts the notification listener, since a notification has to have been seen to be asked about. |
| `ai.provider` | `clipboard`, `claude-code`, `ollama`, `custom` | `clipboard` | `clipboard` copies the report for pasting anywhere and sends nothing. `claude-code` opens the `claude` command with the report. `ollama` asks a local model over HTTP. `custom` runs `ai.command`. Providers whose program is not installed are not offered. |
| `ai.command` | a list | `[]` | For the `custom` provider: a command and its arguments. `%report` is replaced with the path of the redacted bundle; without it, the bundle arrives on standard input. |
| `ai.ollamaUrl` | text | `http://127.0.0.1:11434` | Where the `ollama` provider sends its request. An address that is not this machine counts as leaving it, and is confirmed like any other. |
| `ai.ollamaModel` | text | `` | Empty picks the first model Ollama lists. |

### Layouts

Shipped panel layouts. Applying one replaces your current configuration.

No individual settings: this is a page in the settings window rather than a
list of values.

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

### Profiles

Separate configurations you can switch between, and per-monitor overrides within each.

No individual settings: this is a page in the settings window rather than a
list of values.

### Restore points

Snapshots of your KDE configuration. Nothing here is ever deleted automatically.

No individual settings: this is a page in the settings window rather than a
list of values.

### About

No individual settings: this is a page in the settings window rather than a
list of values.

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
        "id": "workspaces",
        "zone": "left",
        "enabled": true
      },
      {
        "id": "tasks",
        "zone": "left",
        "enabled": true
      },
      {
        "id": "clock",
        "zone": "middle",
        "enabled": true
      },
      {
        "id": "media",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "clipboard",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "tray",
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
        "id": "bluetooth",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "network",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "brightness",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "volume",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "battery",
        "zone": "right",
        "enabled": true
      },
      {
        "id": "power",
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
| Keyboard layout | `keyboard` | left, middle, right | `org.kde.plasma.keyboardlayout` (in the tray) |
| Application launcher | `launcher` | left, middle, right | `org.kde.plasma.kickoff` |
| Media | `media` | left, middle, right | `org.kde.plasma.mediacontroller` (in the tray) |
| Network | `network` | left, middle, right | `org.kde.plasma.networkmanagement` (in the tray) |
| Notification history | `notifications` | left, middle, right | `org.kde.plasma.notifications` (in the tray) |
| Session | `power` | left, middle, right | `org.kde.plasma.lock_logout` |
| Camera and microphone in use | `privacy` | left, middle, right | `org.kde.plasma.cameraindicator` (in the tray) |
| Show desktop | `showdesktop` | left, middle, right | `org.kde.plasma.showdesktop` |
| Open windows | `tasks` | left, middle, right | `org.kde.plasma.icontasks` |
| System tray | `tray` | left, middle, right | `org.kde.plasma.systemtray` |
| Volume | `volume` | left, middle, right | `org.kde.plasma.volume` (in the tray) |
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
| `format` | text | `HH:mm` | Qt date/time format string. |
| `showDate` | `true` or `false` | `false` | Show date |
| `dateFormat` | text | `ddd d MMM` | Date format |

### `widgets.launcher`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `icon` | text | `start-here-kde` | Icon |
| `label` | text | `` | Shown beside the icon. Empty for icon only. |

### `widgets.media`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `showTitle` | `true` or `false` | `true` | Beside the icon, on a panel along the top or bottom. |
| `maxWidth` | a number, 60 to 400 | `180` | It is elided past this. |

### `widgets.notifications`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `showCount` | `true` or `false` | `true` | A badge with the number of notifications since the list was last opened. |

### `widgets.power`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `action` | `promptAll`, `promptLogout`, `promptReboot`, `promptShutDown` | `promptAll` | Action |

### `widgets.showdesktop`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `width` | a number, 2 to 40 | `8` | Strip width |
| `peek` | `true` or `false` | `false` | Rest the pointer on the strip to move the windows aside until it leaves. A click while peeking keeps the desktop. |
| `peekDelay` | a number, 100 to 2000 | `500` | Peek after (ms) |

### `widgets.tasks`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `groupByApp` | `true` or `false` | `true` | One button per application, as KDE and Windows do, with a mark per window. Clicking moves through that application's windows. |
| `pinned` | a list | `[]` | Desktop entry ids ("org.kde.dolphin"), kept on the taskbar in this order whether or not they are running. Right-click a button and choose "Pin to taskbar" rather than typing them. |
| `thisScreenOnly` | `true` or `false` | `false` | Each monitor's panel lists the windows on that monitor, as Windows does with "show taskbar apps on the taskbar where the window is open". |
| `showTitles` | `true` or `false` | `false` | Off by default: a panel runs out of room after four or five titles, and the title is one hover away. |
| `maxWidth` | a number, 60 to 400 | `180` | Titles are elided past this. |
| `iconSize` | a number, 0 to 48 | `0` | 0 follows the panel's thickness, so resizing the panel resizes the icons with it. |

### `widgets.tray`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `iconSize` | a number, 12 to 48 | `18` | Icon size |
| `pinned` | a list | `[]` | StatusNotifierItem ids shown on the panel, in this order. Empty shows every item; pin any and the rest move behind the chevron. Settings has a page that edits this by dragging, which is easier than typing ids. |
| `hidden` | a list | `[]` | Ids left out altogether, not even behind the chevron. |

### `widgets.volume`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `step` | a number, 1 to 20 | `5` | Percent per notch of the wheel. |
| `maxVolume` | a number, 100 to 150 | `100` | Scrolling and the slider stop here. Above 100 is amplification, which can distort. |
| `showMicrophone` | `true` or `false` | `true` | A second slider in the popout, for the default input. |

### `widgets.workspaces`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
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
