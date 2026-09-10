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

### Layouts

Shipped panel layouts. Applying one replaces your current configuration.

No individual settings: this is a page in the settings window rather than a
list of values.

### Widgets

What appears on the panel, and in which zone.

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
        "id": "tray",
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
| Clock | `clock` | left, middle, right | `org.kde.plasma.digitalclock` |
| Application launcher | `launcher` | left, middle, right | `org.kde.plasma.kickoff` |
| Session | `power` | left, middle, right | `org.kde.plasma.lock_logout` |
| Show desktop | `showdesktop` | left, middle, right | `org.kde.plasma.showdesktop` |
| Open windows | `tasks` | left, middle, right | `org.kde.plasma.icontasks` |
| System tray | `tray` | left, middle, right | `org.kde.plasma.systemtray` |
| Virtual desktops | `workspaces` | left, middle, right | `org.kde.plasma.pager` |

A widget with no Plasma applet is left out of the panel under the `plasma`
renderer, and is named before you switch rather than discovered afterwards.

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

### `widgets.power`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `action` | `promptAll`, `promptLogout`, `promptReboot`, `promptShutDown` | `promptAll` | Action |

### `widgets.showdesktop`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `width` | a number, 2 to 40 | `8` | Strip width |

### `widgets.tasks`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `groupByApp` | `true` or `false` | `true` | One button per application, as KDE and Windows do, with a mark per window. Clicking moves through that application's windows. |
| `showTitles` | `true` or `false` | `false` | Off by default: a panel runs out of room after four or five titles, and the title is one hover away. |
| `maxWidth` | a number, 60 to 400 | `180` | Titles are elided past this. |
| `iconSize` | a number, 0 to 48 | `0` | 0 follows the panel's thickness, so resizing the panel resizes the icons with it. |

### `widgets.tray`

| Setting | Accepts | Default | Meaning |
| --- | --- | --- | --- |
| `iconSize` | a number, 12 to 48 | `18` | Icon size |
| `hidden` | a list | `[]` | StatusNotifierItem ids to leave out. |

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
