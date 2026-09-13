# The settings window

`rmpr settings`, or Meta+Shift+R. One window, a page per section, and every
page drawn from the same handful of parts. This is how a page is built, what
the schema decides, and how to look at one without guessing.

## The parts

| | |
| --- | --- |
| [`shell/features/settings/SettingsWindow.qml`](../shell/features/settings/SettingsWindow.qml) | the frame. The navigation, the heading, and the loader that turns a section into a page. |
| [`shell/features/settings/SchemaRenderer.qml`](../shell/features/settings/SchemaRenderer.qml) | the whole settings mechanism: keys in, controls out. What a section gets for free. |
| [`shell/domain/settings/groups/SettingGroups.qml`](../shell/domain/settings/groups/SettingGroups.qml) | which key goes in which card. Pure, tested in [`tests/tst_SettingGroups.qml`](../tests/tst_SettingGroups.qml). |
| [`shell/ui/primitives/CardGrid.qml`](../shell/ui/primitives/CardGrid.qml) | one column of cards or two. Tested in [`tests/tst_CardGrid.qml`](../tests/tst_CardGrid.qml). |
| [`shell/ui/primitives/Card.qml`](../shell/ui/primitives/Card.qml), [`SectionLabel.qml`](../shell/ui/primitives/SectionLabel.qml) | a card, and the small capitals over it. |
| [`shell/ui/controls/SettingRow.qml`](../shell/ui/controls/SettingRow.qml) | one setting: label, description, control, and a way back to the default. |

The navigation is `config/schema/shell.json`, in the schema's order, so a page
cannot exist without being documented -- and `rmpr settings <id>` opens the page
[`docs/config.md`](config.md) describes.

## A page is a grid of cards

Every page is a `CardGrid` of `Card`s, each under a `SectionLabel`:

```qml
CardGrid {
    id: root

    count: 2                      // how many cards, when a Repeater builds them

    Card {
        id: card
        width: root.cellWidth     // or root.width, for a card that needs the row

        SectionLabel { text: "What opens" }

        SettingRow { width: parent.width; label: "..."; Toggle { } }
    }
}
```

Two rules worth knowing before drawing one:

**`count`, when the cards come from a model.** `CardGrid` counts its visible
children, and a `Repeater` is one of them -- an `Item` that draws nothing and
that the grid steps over, but a child all the same. A page that builds its cards
from a model says how many it built.

**`root.width`, for a card that cannot be half.** Two columns is the default. A
card holding something that has a size of its own -- the picture of a screen on
the edges page, a widget row with five buttons on it, the tray's three lists --
takes `root.width` and gets a row to itself.

## What the schema decides

A section with `keys` and no `page` needs no QML at all: `SchemaRenderer` draws
it. Each key's `type` picks the control -- `bool` a switch, `enum` a dropdown,
`int` a slider, anything else a text field -- and an unrecognised type falls
back to a text field rather than drawing nothing.

`group` puts a key in a card of its own:

```json
"desktop.border":  { "group": "Screen border", "type": "bool",  ... },
"desktop.clock":   { "group": "Desktop clock", "type": "bool",  ... }
```

Cards come in the order their first key does. Keys with no group share one card
at the top, titled by the section. A widget's own settings come from its
manifest through the same renderer, so a third-party widget gets a real settings
page without anything here knowing it exists.

## Where the control goes

`SettingRow` puts the control beside the label or under it, and this is not a
matter of taste: a switch is 44 pixels wide and a slider wants the whole line.

- `controlWidth` -- the room the control needs beside the text. A switch says
  48, a dropdown 200.
- `stacked` -- the control on its own line under the text, full width. For
  sliders and text fields, and for a dropdown in a card too narrow to keep both
  on one line.

A row that reserves the same slot for every control gives the switch a hundred
pixels of nothing and leaves the description a column too narrow to read. In one
column that is survivable; in two it is what the page looks like.

## Looking at one

```bash
PREVIEW_PAGE=widgets dev/preview/preview.sh dev/preview/settings.qml /tmp/s.png 1120 860 dark
```

`PREVIEW_PAGE` is a schema section id; `light` or `dark` as the fifth argument.
The harness points `Schema`, `Paths` and `Branding.ctlBin` at the worktree, so a
preview shows this tree's pages and this tree's commands rather than the
installed ones.

It is worth doing. The linter passes a row sized against an id that does not
exist, a card whose contents have escaped it, and a button group wider than the
card it sits in. All three were found this way, in one afternoon.
