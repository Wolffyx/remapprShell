# Popouts

Every panel in this shell is a strip of widgets, and a widget that has more to
say opens a **popout**: the start menu, quick settings, the calendar, the tray
flyout, the media card, a task's preview. This is how one is built, where each
part of what you see on screen comes from, and how to look at one without
guessing.

## The four files

| | |
| --- | --- |
| [`shell/ui/primitives/BarWidget.qml`](../shell/ui/primitives/BarWidget.qml) | the contract. A widget says *what* its popout is and how it should behave; it never draws the window. |
| [`shell/features/panel/WidgetSlot.qml`](../shell/features/panel/WidgetSlot.qml) | the card. Builds the window, draws the background, the border and the shadow, and loads the widget's contents into it. |
| [`shell/features/panel/EdgeWindow.qml`](../shell/features/panel/EdgeWindow.qml) | the window. A layer surface beside the panel, on any of the four edges. Shared with tooltips. |
| [`shell/domain/panel/Placement.qml`](../shell/domain/panel/Placement.qml) | the arithmetic. Where the window goes and where the card sits inside it. Pure functions, tested in [`tests/tst_Placement.qml`](../tests/tst_Placement.qml). |

One more decides *when* a popout closes:
[`shell/features/panel/model/PanelModel.qml`](../shell/features/panel/model/PanelModel.qml)
holds the one open popout, and the surface that catches a click outside it
lives at the foot of
[`shell/features/panel/Panel.qml`](../shell/features/panel/Panel.qml).

## What a widget declares

All of it on `BarWidget`, all of it optional:

```qml
popout: Component { MyContents { } }   // null means this widget has no popout
popoutVisible: false                   // the widget's own state; the panel reads it
popoutAlign: "centre"                  // or "start": the card's near edge on the widget's
popoutWidth: -1                        // the card's width; -1 takes it from the contents
popoutPadding: 20                      // how far in from the card's edge the contents sit
popoutRadius: -1                       // -1 follows theme.rounding, and should
popoutGrabsFocus: false                // true only if it must be typed into
popoutClosesOnOutsideClick: true       // false for one that follows the pointer
function closePopout() { }             // how the panel asks this widget to put it away
```

Two of these have sharp edges.

**`closePopout()`, not `popoutVisible = false`.** The panel closes a popout by
calling the function. If your widget keeps its open state somewhere else and
binds `popoutVisible` to it -- the launcher does, to
`LauncherService.builtin` -- then an assignment would replace that binding with
a constant and the popout would never open again. Override `closePopout()` to
change the state where it actually lives. `tests/tst_Popouts.qml` holds this.

**`popoutWidth`, not a width in the contents.** The contents are anchored to
fill the card, so a `width:` inside them is overwritten and the card ends up as
wide as the longest line of text in it -- a different size in every locale.
Assigning `implicitWidth` in the contents is not the fix either: on a `Column`
it is read-only, qmllint does not catch it, and the running shell reports the
whole widget as failing to load.

## What you see, layer by layer

From the back:

1. **The window** -- an `EdgeWindow`, a Wayland layer surface on the **top**
   layer, `color: "transparent"`. Not the overlay layer: that is above
   full-screen windows, and a popout there covers Spectacle's region selector
   and games.
2. **The shadow** -- a `RectangularShadow`, drawn only when `theme.shadows` is
   on, which it is not by default.
3. **The card** -- one `Rectangle`. Its colour is `Theme.glass`, its border is
   `Theme.out`, its radius comes from `theme.rounding`. This is the popout's
   only background.
4. **The contents** -- the widget's `popout` component, in a `Loader` anchored
   to fill the card inset by `popoutPadding`. Built when the popout opens and
   destroyed when it closes.

### One surface

A popout is one surface. Inside it, **only what can be pressed or typed into
gets a background of its own**; everything else is space and a hairline
(`Theme.out`, 1 px).

This is the rule that was missing: the start menu had the card's glass, then a
rail and a side column filled a shade lighter, then cards a shade darker again
inside those -- three tones stacked, reported as "multiple backgrounds on the
same popup".

### Radii

Every radius inside a popout goes through `Theme.radiusOf(n)`, where `n` is the
number from the design, which is drawn at a rounding of 28. Writing `radius: 20`
means that shape ignores `theme.rounding`, so at a small setting it is *rounder
than the card containing it* and draws a curve inside the card's straighter
corner. `Theme.radius`, `radiusMedium`, `radiusSmall` and `radiusTiny` are the
named steps of the same scale.

## Where it goes

`Placement` works in two directions named for the panel, so one set of rules
covers all four edges:

- **along** -- the length of the panel; x on a top or bottom panel
- **away** -- out from the screen's edge; y on a bottom panel

```
away(extent, gap, shadowMargin)          how far out the window starts
along(align, slotStart, centre, size,    where it starts along the panel
      extent, shadowMargin, edgeMargin)
shift(...)                               how far the card moves inside the window
```

`extent` is the panel's whole strip, a floating bar's own margin included.
`shadowMargin` is the transparent room the window keeps for its shadow -- **0
unless `theme.shadows` is on**, in which case the gap widens to match rather
than the shadow being cut off square at the window's edge.

`shift` exists because a window cannot start at a negative position: a menu
aligned to a button 12 px from the corner, with a shadow wanting 29, would open
17 px to the right of it. The card moves inside its own window instead.

`slotStart` is taken when the window is shown, never bound: `mapToItem` is a
function call, so a binding on it is evaluated once -- before the zone has laid
the slot out -- and every popout on the panel opened at the screen's left edge.

## Closing

A layer surface has no popup grab, so nothing closes a popout for us.

`PanelModel.openPopoutSlot` holds the one open popout. Opening another closes
it, and so does a press on any other widget or on the panel between them. For a
press anywhere *else*, `Panel.qml` keeps a transparent surface over the rest of
the screen, leaving the panel's own strip uncovered so a click on another widget
still reaches that widget.

That surface is **mapped from the start and made deaf** -- an empty input
region -- rather than shown and hidden with the popout. It shares the top layer
with the popouts, two surfaces on one layer stack in the order they were
mapped, and a catcher that maps *with* the popout is a race the popout can lose.
Losing it means every click on a popout closes it instead of reaching it.

## Looking at one

### Offscreen, fast, and lying to you

```bash
PREVIEW_WIDGET=launcher dev/preview/preview.sh dev/preview/popout.qml out.png 1100 820 dark 3000
```

Good for layout, spacing, colour and text. **It cannot show anything the
compositor does.** `preview.sh` deletes `BackgroundEffect.blurRegion` and the
input mask from `WidgetSlot.qml` before rendering, and turns every full-screen
layer surface into a plain `Item`. Do not conclude from a preview that a
blur, a mask, a layer or a shadow is right.

`PREVIEW_RUNTIME='{"theme.rounding":28}'` overrides configuration for the run.

A preview reads a copy of the profile and keeps its state in its own
temporary root: it never writes the running shell's files.

### On the real screen

`grim` writes nothing here -- KWin does not implement `wlr-screencopy`.
Spectacle does:

One image for every output. Open the popout over IPC, then let Spectacle wait
for it: `-d` delays the capture, so nothing has to be put in the background and
the two lines work the same in fish and in bash.

```
rmpr ipc panel click status DP-2
spectacle -b -f -n -d 2000 -o /tmp/shot.png
```

`rmpr ipc` finds the running shell for you. The path is not fixed: a shell
started with `make run` answers on this worktree's `shell/shell.qml`, an
installed one on `~/.config/quickshell/<slug>/shell.qml`, and
`quickshell ipc -p <the other one>` replies "No running instances".

`-b` background, `-f` the whole desktop, `-n` no notification, `-d` the delay in
milliseconds. Add `-p` to include the pointer.

Spectacle takes no focus, so the popout stays open across the capture; close it
afterwards with `rmpr ipc surfaces close`. Note that `( ... ) &` is a bash
idiom: in fish those parentheses are command substitution and the line is a
syntax error.

**Read the pixels rather than looking at them.** `panel layout <screen>` gives
every slot's box in screen coordinates; a scan across the card's edge gives the
corner radius, the border and the gap to the panel as numbers. Eyes disagree
about screenshots; a column of pixel values does not.

### What the IPC offers

All of these take `rmpr ipc` in front of them:

```
panel layout <screen>            every shown widget's box, in screen coordinates
panel click <widget> <screen>    what a left click does
panel tooltip <widget> <screen>  its tooltip, for four seconds
config get <path>                what a setting actually is right now
config setRuntime <path> <json>  override one in memory, never written to the profile
surfaces close                   close whatever is open
shell reload                     reload the QML
```

`Log.debug("panel", ...)` in `EdgeWindow.report()` prints where a window
actually went -- which is how the left-edge bug was found -- but debug logging
is off unless `REMAPPR_SHELL_DEBUG` is set in the shell's environment, so it
needs a restart rather than a reload.

## Settings that change how a popout looks

| Key | Default | What it does |
| --- | --- | --- |
| `theme.rounding` | 28 | the card's corner radius, and the scale every radius inside it follows |
| `theme.translucent` | true | the card lets a little of what is behind it through |
| `theme.shadows` | false | a drop shadow under the card, and the transparent room the window keeps for it |

## Constraints worth knowing before you change something

- **A mask and exclusive keyboard focus cannot be combined.** A layer surface
  that asks for both is mapped by KWin 6.7.5 and then drawn as nothing at all:
  the window is there, at the right size on the right screen, and the log says
  so, but the screen stays empty. That was "the start menu does not open". So a
  popout that needs the keyboard takes no input mask, and its transparent
  border takes clicks -- which is why that border must never reach back over
  the panel.
- **A layer surface, not an xdg popup.** Wayland grants a popup the keyboard
  only if its parent surface has already received input, so a popup-based
  launcher can be focused by clicking the button but never by a keybinding or
  `rmpr launcher`.
- **No window thumbnails.** A picture of a window is KWin's to give and it
  gives one only to its own switcher layouts; `ScreenShot2.CaptureWindow`
  refuses us outright.

## Every popout, and where it is drawn

| Widget | Contents |
| --- | --- |
| launcher | [`widgets/launcher/StartMenu.qml`](../shell/widgets/launcher/StartMenu.qml) |
| status (quick settings) | [`widgets/status/QuickSettings.qml`](../shell/widgets/status/QuickSettings.qml) |
| clock | [`widgets/clock/CalendarPopout.qml`](../shell/widgets/clock/CalendarPopout.qml) |
| tray | [`widgets/tray/Widget.qml`](../shell/widgets/tray/Widget.qml) -- the flyout and the application's own menu |
| tasks | [`widgets/tasks/Widget.qml`](../shell/widgets/tasks/Widget.qml) (preview) and [`TaskMenu.qml`](../shell/widgets/tasks/TaskMenu.qml) |
| volume, network, bluetooth, battery, brightness, media, clipboard, keyboard, privacy | each widget's own `Widget.qml` |
| notifications | [`widgets/notifications/Widget.qml`](../shell/widgets/notifications/Widget.qml) |

The full-screen surfaces are not popouts and are placed by themselves: the
search overlay, the key sheet, the session screen, the sidebar and the Alt+Tab
switcher.
