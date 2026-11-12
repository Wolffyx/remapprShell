pragma ComponentBehavior: Bound

// Windows: the title-bar buttons card -- which side of every window's title
// bar minimise, maximise and close sit on.
//
// The order is KWin's (kwinrc, [org.kde.kdecoration2]); the choice is the
// profile's, windows.titleButtons, so a layout can carry it. Every change
// runs `rmpr windows titlebar set`, which writes both and asks KWin to
// reconfigure, so this card and the CLI do one thing. What the card shows is
// the profile, read live; KWin's own order is read from the CLI for
// Plasma's, which writes nothing and shows what KWin has.
//
// The custom editor is all clicks: choose a chip, then move it. Its moves are
// TitleButtons', in qs.domain.windows.titlebar, where tst_TitleButtons
// checks them; a run of them is sent once the clicking stops, so a chip
// crossing a row is one write to kwinrc rather than four.

import QtQuick
import qs.domain.config
import qs.domain.theme
import qs.domain.windows.titlebar
import qs.platform.system
import qs.ui.primitives
import qs.ui.controls

Card {
    id: root

    spacing: 14

    readonly property CtlSession ctl: CtlSession {
        prefix: ["windows", "titlebar"]
        readFailed: "Could not read KWin's title-bar buttons."
        logLabel: "windows titlebar"
    }

    readonly property string mode: ConfigStore.value("windows.titleButtons", "plasma")
    readonly property string customLeft: ConfigStore.value("windows.titleButtonsLeft", TitleButtons.breezeLeft)
    readonly property string customRight: ConfigStore.value("windows.titleButtonsRight", TitleButtons.breezeRight)
    readonly property var kwin: root.ctl.state?.kwin ?? { left: TitleButtons.breezeLeft, right: TitleButtons.breezeRight }
    readonly property bool custom: root.mode === "custom"

    // The custom order being edited, ahead of the profile until the write
    // lands; null when the profile is what is shown.
    property var draft: null
    property var sel: null

    readonly property var shown: root.draft
        ?? TitleButtons.sidesOf(root.mode, { left: root.customLeft, right: root.customRight }, root.kwin)
    readonly property var editing: ({ left: root.shown.left, right: root.shown.right, sel: root.sel })

    Component.onCompleted: root.ctl.refresh()

    // The profile caught up with the draft: it is what is shown again.
    function settle() {
        if (!root.draft || root.commit.running || root.ctl.busy)
            return;
        if (TitleButtons.letters(root.draft.left) === root.customLeft
                && TitleButtons.letters(root.draft.right) === root.customRight)
            root.draft = null;
    }
    onCustomLeftChanged: root.settle()
    onCustomRightChanged: root.settle()

    function pickMode(id) {
        root.sel = null;
        if (id === root.mode)
            return;
        // Custom starts from what is showing, so changing one thing is one
        // move.
        if (id !== "custom") {
            root.draft = null;
            root.ctl.run(["set", id]);
            return;
        }
        root.draft = { left: root.shown.left.slice(), right: root.shown.right.slice() };
        root.ctl.run(["set", "custom", TitleButtons.letters(root.draft.left), TitleButtons.letters(root.draft.right)]);
    }

    // One of TitleButtons' moves, on what is showing.
    function edit(move, code) {
        const next = move(root.editing, code);
        root.sel = next.sel;
        if (TitleButtons.letters(next.left) === TitleButtons.letters(root.shown.left)
                && TitleButtons.letters(next.right) === TitleButtons.letters(root.shown.right))
            return;
        root.draft = { left: next.left, right: next.right };
        root.commit.restart();
    }

    readonly property Timer commit: Timer {
        interval: 400
        onTriggered: {
            if (root.ctl.busy) {
                root.commit.restart();
                return;
            }
            root.ctl.run(["set", "custom", TitleButtons.letters(root.draft.left), TitleButtons.letters(root.draft.right)]);
        }
    }

    readonly property Connections _landed: Connections {
        target: root.ctl
        function onBusyChanged() { root.settle(); }
    }

    SectionLabel { text: "Title-bar buttons" }

    Hint {
        text: "Where minimise, maximise and close sit on every window. This sets KWin's own button order, so it holds for any window KWin draws a title bar for."
    }

    Hint {
        visible: root.ctl.status.length > 0
        text: root.ctl.status
        tone: "error"
    }

    // A window's title bar, as the choice draws it.
    Rectangle {
        width: parent.width
        height: 101
        radius: 8
        clip: true
        color: Theme.s1
        border.width: 1
        border.color: Theme.out
        Accessible.name: "Preview"

        Row {
            id: leftButtons
            x: 10
            y: (44 - height) / 2
            spacing: 2

            Repeater {
                model: root.shown.left
                delegate: TitleGlyph {}
            }
        }

        PanelText {
            x: leftButtons.x + leftButtons.width + 10
            width: rightButtons.x - 10 - x
            height: 44
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: "Documents — Files"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Row {
            id: rightButtons
            x: parent.width - 10 - width
            y: (44 - height) / 2
            spacing: 2

            Repeater {
                model: root.shown.right
                delegate: TitleGlyph {}
            }
        }

        Rectangle {
            y: 44
            width: parent.width
            height: 1
            color: Theme.out
        }

        Row {
            x: 16
            y: 45 + (56 - height) / 2
            spacing: 12

            Rectangle { width: (root.contentWidth - 2) * 0.38; height: 6; radius: 3; color: Theme.hover }
            Rectangle { width: (root.contentWidth - 2) * 0.22; height: 6; radius: 3; color: Theme.hover }
        }
    }

    Column {
        width: parent.width
        spacing: 3
        topPadding: 4

        PanelText { text: "Where the buttons go"; font.pixelSize: 14 }

        PanelText {
            width: parent.width
            text: TitleButtons.hints[root.mode] ?? ""
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            lineHeight: 1.25
            color: Theme.mut
        }
    }

    Segmented {
        width: parent.width
        values: TitleButtons.modes
        labels: TitleButtons.labels
        glyphs: TitleButtons.glyphs
        current: root.mode
        onPicked: value => root.pickMode(value)
    }

    // The custom editor: the two sides, then what is not shown, then what
    // to do with the chip chosen.
    Rectangle {
        width: parent.width
        visible: root.custom
        height: editor.implicitHeight + 28
        radius: Theme.radiusTiny + 2
        color: Theme.s1
        border.width: 1
        border.color: Theme.out

        Column {
            id: editor
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 10

            Hint { text: "Choose a button, then move it. The title sits between the two sides." }

            SideRow {
                label: "Left"
                codes: root.shown.left
                selCode: root.sel?.code ?? ""
                onChosen: code => root.edit((state, c) => TitleButtons.pick(state, "left", c), code)
            }
            SideRow {
                label: "Right"
                codes: root.shown.right
                selCode: root.sel?.code ?? ""
                onChosen: code => root.edit((state, c) => TitleButtons.pick(state, "right", c), code)
            }

            Item {
                width: parent.width
                height: Math.max(32, pool.implicitHeight)

                RowLabel { text: "Not shown" }

                Flow {
                    id: pool
                    x: 82
                    width: parent.width - 82
                    spacing: 6

                    Repeater {
                        model: TitleButtons.pool(root.editing)
                        delegate: Chip {
                            id: hidden
                            outlined: true
                            glyphName: "add"
                            onActivated: root.edit(TitleButtons.add, hidden.code)
                        }
                    }

                    PanelText {
                        visible: TitleButtons.pool(root.editing).length === 0
                        height: 32
                        verticalAlignment: Text.AlignVCenter
                        text: "Every button is shown"
                        font.pixelSize: 12
                        color: Theme.mut
                    }
                }
            }

            Item {
                width: parent.width
                height: 34
                visible: root.sel !== null

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - actions.width - 12
                    elide: Text.ElideRight
                    text: root.sel ? `${TitleButtons.buttons[root.sel.code].name}, on the ${root.sel.side}` : ""
                    font.pixelSize: 12
                    color: Theme.mut
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    spacing: 8

                    IconButton {
                        glyph: "chevron_left"
                        tooltip: "Move towards the left"
                        onActivated: root.edit(TitleButtons.moveBack)
                    }
                    IconButton {
                        glyph: "chevron_right"
                        tooltip: "Move towards the right"
                        onActivated: root.edit(TitleButtons.moveOn)
                    }
                    TextButton {
                        glyph: "swap_horiz"
                        text: "Other side"
                        onActivated: root.edit(TitleButtons.otherSide)
                    }
                    TextButton {
                        glyph: "visibility_off"
                        text: "Hide"
                        onActivated: root.edit(TitleButtons.hide)
                    }
                }
            }
        }
    }

    ConfigToggleRow {
        path: "windows.titleButtonsFromLayouts"
        fallback: true
        label: "Let layouts change this"
        description: "The macOS-like layout puts the buttons on the left. Applying another layout puts back what you had."
    }

    // What the choice writes, in KWin's own words.
    Rectangle {
        width: parent.width
        height: told.implicitHeight + 24
        radius: Theme.radiusTiny + 2
        color: Theme.s1

        Column {
            id: told
            x: 14
            y: 12
            width: parent.width - 28
            spacing: 4

            PanelText {
                text: "What KWin is told"
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 0.8
                font.capitalization: Font.AllUppercase
                color: Theme.mut
            }

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                text: TitleButtons.line(root.mode, root.shown)
                font.family: Theme.monoFamily
                font.pixelSize: 12
            }

            Hint {
                text: root.mode === "plasma"
                    ? "KWin keeps its own order. Choosing anything else writes these two lines to kwinrc and asks KWin to reload; the old values are kept, and put back by Plasma's or by restoring KDE."
                    : "Written to kwinrc, [org.kde.kdecoration2], then KWin reloads: every open window changes at once. What was there before is kept and put back by Plasma's or by restoring KDE."
            }
        }
    }

    // Which applications follow it.
    Column {
        width: parent.width
        spacing: 8

        Follows {
            follows: true
            text: "KDE applications, and anything else with an ordinary title bar."
        }
        Follows {
            follows: true
            text: "GTK applications that draw their own (Firefox, GNOME applications), when Plasma passes the order on to GTK."
        }
        Follows {
            follows: false
            text: "Applications with a title bar entirely their own (VS Code, Discord) keep theirs: nothing outside them can move it."
        }
    }

    // --- pieces ---------------------------------------------------------------

    component TitleGlyph: Item {
        required property string modelData
        width: 28
        height: 28
        Accessible.name: TitleButtons.buttons[modelData]?.name ?? ""

        Glyph {
            anchors.centerIn: parent
            name: TitleButtons.buttons[parent.modelData]?.glyph ?? ""
            size: 18
            color: Theme.mut
        }
    }

    component RowLabel: PanelText {
        width: 72
        height: 32
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 12
        font.weight: Font.Medium
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
        color: Theme.mut
    }

    // One side's row: its chips, in the order KWin draws them.
    component SideRow: Item {
        id: sideRow

        property string label: ""
        property var codes: []
        property string selCode: ""
        signal chosen(string code)

        width: parent.width
        height: well.height

        RowLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: sideRow.label
        }

        Rectangle {
            id: well
            x: 82
            width: parent.width - 82
            height: Math.max(44, chips.implicitHeight + 12)
            radius: Theme.radiusTiny + 2
            color: Theme.s2

            Flow {
                id: chips
                x: 6
                y: 6
                width: parent.width - 12
                spacing: 6

                Repeater {
                    model: sideRow.codes
                    delegate: Chip {
                        id: shownChip
                        selected: sideRow.selCode === shownChip.code
                        onActivated: sideRow.chosen(shownChip.code)
                    }
                }

                PanelText {
                    visible: sideRow.codes.length === 0
                    height: 32
                    leftPadding: 6
                    verticalAlignment: Text.AlignVCenter
                    text: "Nothing on this side"
                    font.pixelSize: 12
                    color: Theme.mut
                }
            }
        }
    }

    component Chip: Rectangle {
        id: chip

        required property string modelData
        readonly property string code: chip.modelData
        property bool selected: false
        property bool outlined: false
        property string glyphName: TitleButtons.buttons[chip.code]?.glyph ?? ""
        signal activated

        width: chipRow.implicitWidth + 20
        height: 32
        radius: 16
        color: chip.selected ? Theme.accC
             : chip.outlined ? (chipHover.hovered ? Theme.hover : "transparent")
             : (chipHover.hovered ? Theme.s3 : Theme.s1)
        border.width: chip.outlined ? 1 : 0
        border.color: Theme.out
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        Accessible.role: Accessible.Button
        Accessible.name: chip.outlined ? `Add ${TitleButtons.buttons[chip.code]?.name ?? ""} to the right`
                                       : (TitleButtons.buttons[chip.code]?.name ?? "")

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.glyphName
                size: 17
                color: chip.selected ? Theme.accCFg : (chip.outlined ? Theme.mut : Theme.fg)
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: TitleButtons.buttons[chip.code]?.name ?? chip.code
                font.pixelSize: 12
                color: chip.selected ? Theme.accCFg : Theme.fg
            }
        }

        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.activated() }
    }

    component Follows: Item {
        id: line

        property bool follows: true
        property string text: ""

        width: parent.width
        height: Math.max(20, words.implicitHeight)

        Glyph {
            y: 1
            name: line.follows ? "check_circle" : "block"
            size: 18
            color: line.follows ? Theme.positive : Theme.mut
        }

        PanelText {
            id: words
            x: 28
            width: parent.width - 28
            text: line.text
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            lineHeight: 1.35
            color: line.follows ? Theme.fg : Theme.mut
        }
    }
}
