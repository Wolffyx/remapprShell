pragma ComponentBehavior: Bound

// Screen edges and corners, and window snapping.
//
// KWin does every one of these. This page configures it through the same
// `edges` command the CLI has -- it never writes kwinrc itself -- so there is
// one path that writes, one ledger that can undo it, and one set of tests
// behind both.
//
// The corners are drawn around a picture of a screen because that is how
// people think of them. Eight dropdowns in a list read like a form, and
// "BottomLeft" is not a word anyone uses about their own monitor.

import QtQuick
import qs.platform.system
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    // `edges status --json`, and the command that changes it. A refusal -- a
    // corner set while the triggers are off, say -- is explained on the
    // command's error line, and shown as it is.
    readonly property CtlSession ctl: CtlSession {
        prefix: ["edges"]
        readFailed: "Could not read the screen edges from KWin's configuration."
    }
    readonly property var edgeState: root.ctl.state
    property string selected: "TopLeft"

    readonly property bool triggersOn: root.edgeState?.triggers ?? true
    readonly property var actions: root.edgeState?.actions ?? []
    readonly property string selectedAction: root.edgeState?.edges?.[root.selected] ?? "none"
    readonly property bool selectedKnown: root.actions.some(a => a.id === root.selectedAction)
    readonly property bool snapOn: (root.edgeState?.snap?.tiling ?? true) || (root.edgeState?.snap?.maximize ?? true)
    readonly property var tilingScripts: root.edgeState?.tilingScripts ?? []

    // Where each edge sits on the picture, as fractions of the screen.
    readonly property var places: [
        { edge: "TopLeft",     name: "Top-left corner",     x: 0,   y: 0   },
        { edge: "Top",         name: "Top edge",            x: 0.5, y: 0   },
        { edge: "TopRight",    name: "Top-right corner",    x: 1,   y: 0   },
        { edge: "Right",       name: "Right edge",          x: 1,   y: 0.5 },
        { edge: "BottomRight", name: "Bottom-right corner", x: 1,   y: 1   },
        { edge: "Bottom",      name: "Bottom edge",         x: 0.5, y: 1   },
        { edge: "BottomLeft",  name: "Bottom-left corner",  x: 0,   y: 1   },
        { edge: "Left",        name: "Left edge",           x: 0,   y: 0.5 }
    ]

    function labelOf(id) {
        const a = root.actions.find(x => x.id === id);
        return a ? a.label : id;
    }

    function nameOf(edge) {
        return root.places.find(p => p.edge === edge)?.name ?? edge;
    }

    Component.onCompleted: root.ctl.refresh()

    // The picture is 460px of screen with a chip in each corner, so this card
    // takes the whole row rather than half of it.
    Card {
        id: screenCard

        width: root.width
        spacing: 10

        SectionLabel { text: "Corners and edges" }

        SettingRow {
            width: screenCard.contentWidth
            enabled: !root.ctl.busy
            label: "Mouse triggers at the screen edges"
            description: root.triggersOn
                ? "Turn off to stop every corner, edge and snap below at once."
                : "Off. Turning this back on puts every corner and edge back exactly as it was."

            Toggle {
                checked: root.triggersOn
                onToggled: value => root.ctl.run([value ? "enable-all" : "disable-all"])
            }
        }

        Item {
            id: picture

            width: screenCard.contentWidth
            height: screenFrame.height + 8
            enabled: root.triggersOn && !root.ctl.busy
            opacity: root.triggersOn ? 1 : 0.4

            Rectangle {
                id: screenFrame

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(460, picture.width - 16)
                height: Math.round(width * 9 / 16)
                radius: Theme.radiusOf(14)
                color: Theme.s1
                border.width: 1
                border.color: Theme.out

                Repeater {
                    model: root.places

                    Rectangle {
                        id: chip

                        required property var modelData

                        readonly property bool current: chip.modelData.edge === root.selected
                        readonly property string action: root.edgeState?.edges?.[chip.modelData.edge] ?? "none"
                        readonly property real margin: 8

                        width: Math.min(chipText.implicitWidth + 18, (screenFrame.width - 4 * chip.margin) / 3)
                        height: 28
                        x: chip.margin + chip.modelData.x * (screenFrame.width - 2 * chip.margin - chip.width)
                        y: chip.margin + chip.modelData.y * (screenFrame.height - 2 * chip.margin - chip.height)
                        radius: Theme.radiusOf(9)
                        color: chip.current ? Theme.accC
                             : chipHover.hovered ? Theme.hover
                             : Theme.alpha(Theme.fg, chip.action === "none" ? 0.04 : 0.09)

                        PanelText {
                            id: chipText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, chip.width - 14)
                            elide: Text.ElideRight
                            text: root.labelOf(chip.action)
                            font.pixelSize: 12
                            color: chip.current ? Theme.accCFg
                                 : chip.action === "none" ? Theme.mut : Theme.fg
                        }

                        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.selected = chip.modelData.edge }
                    }
                }
            }
        }

        SettingRow {
            width: screenCard.contentWidth
            enabled: root.triggersOn && !root.ctl.busy
            opacity: root.triggersOn ? 1 : 0.4
            label: root.nameOf(root.selected)
            description: root.selectedKnown
                ? "Pick a corner or an edge on the screen above, then what pushing the pointer into it does."
                : `Set elsewhere to "${root.selectedAction}", which this page does not know. Choosing here replaces it.`

            Select {
                values: root.actions.map(a => a.label)
                currentIndex: Math.max(0, root.actions.findIndex(a => a.id === root.selectedAction))
                onPicked: value => {
                    const a = root.actions.find(x => x.label === value);
                    if (a && a.id !== root.selectedAction)
                        root.ctl.run(["set", root.selected, a.id]);
                }
            }
        }
    }

    Card {
        id: snapCard

        width: root.cellWidth

        SectionLabel { text: "Snapping" }

        SettingRow {
            width: snapCard.contentWidth
            enabled: root.triggersOn && !root.ctl.busy
            opacity: root.triggersOn ? 1 : 0.4
            label: "Snap windows to the screen edges"
            description: "Drag a window to the top to maximise it, or to a side to fill that half."
                + (root.tilingScripts.length > 0
                   ? ` ${root.tilingScripts.join(", ")} is also on, and may take the drag instead.`
                   : "")

            Toggle {
                checked: root.snapOn
                onToggled: value => root.ctl.run(["snap", value ? "on" : "off"])
            }
        }
    }

    Card {
        id: elsewhere

        width: root.cellWidth
        spacing: 12

        SectionLabel { text: "Undo, and the rest" }

        // Plasma's own page has what this one leaves out: the delay before a
        // trigger fires, touch-screen edges, the corner size.
        UndoFooter {
            spacing: elsewhere.spacing
            session: root.ctl
            customised: root.edgeState?.customised ?? false
            settingsModule: "kcm_kwinscreenedges"
            settingsText: "Plasma's screen edge settings"
        }
    }
}
