// The frame every setting shares: label, description, control, and a way back
// to the default.
//
// Having one row type is what keeps a settings page from drifting into a
// collection of subtly different layouts.
//
// The control sits beside the text or under it, and which one is not a matter
// of taste. A switch is 44 pixels wide and a slider wants the whole line, so a
// row that always reserved the same slot for both gave the switch a hundred
// pixels of nothing and the description a column too narrow to read -- six
// lines of wrapping beside an empty space, which is what a card in two columns
// made obvious. So: `controlWidth` for a control that has a size of its own,
// and `stacked` for one that does not.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Item {
    id: root

    required property string label
    property string description: ""

    // How much room the control needs beside the text. -1 takes the old
    // share of the row, which is right for a control with no size of its own.
    property real controlWidth: -1

    // Draws the control on its own line under the text, full width. For a
    // slider or a text field, which have nothing to gain from being squeezed
    // into a third of the row.
    property bool stacked: false

    // Shown only when the user has changed this from the shipped default,
    // which is also the answer to "what have I actually customised?".
    property bool overridden: false
    signal resetRequested

    default property alias control: controlSlot.data

    readonly property real slotWidth: root.controlWidth >= 0
        ? Math.min(root.controlWidth, root.width * 0.5)
        : Math.min(220, root.width * 0.4)

    implicitHeight: root.stacked
        ? text.implicitHeight + controlSlot.implicitHeight + 28
        : Math.max(text.implicitHeight, controlSlot.implicitHeight) + 20

    Item {
        id: resetButton

        width: root.overridden ? 30 : 0
        height: 30
        visible: root.overridden

        // Beside the control when there is one on this line, and at the end of
        // the label's line when the control is underneath.
        x: root.stacked ? root.width - 4 - width
                        : root.width - 4 - root.slotWidth - width
        y: 10

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: resetHover.hovered ? Theme.hover : "transparent"

            Glyph {
                anchors.centerIn: parent
                name: "undo"
                fallback: "edit-undo"
                size: 18
                color: Theme.mut
            }

            HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.resetRequested() }
        }
    }

    Column {
        id: text

        x: 4
        y: 10
        width: root.width - 8 - resetButton.width
               - (root.stacked ? 0 : root.slotWidth + 10)
        spacing: 3

        PanelText {
            text: root.label
            font.pixelSize: 14
        }

        PanelText {
            visible: root.description.length > 0
            text: root.description
            width: parent.width
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            lineHeight: 1.25
            color: Theme.mut
        }
    }

    Item {
        id: controlSlot

        implicitHeight: childrenRect.height
        height: implicitHeight

        width: root.stacked ? root.width - 8 : root.slotWidth
        x: root.stacked ? 4 : root.width - 4 - root.slotWidth
        y: root.stacked
           ? text.y + text.height + 10
           : text.y + Math.max(0, (text.height - controlSlot.height) / 2)
    }
}
