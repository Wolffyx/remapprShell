pragma ComponentBehavior: Bound

// Which global keys the shell takes. The list is setup.sh's own
// (`setup.sh --describe`), so the window cannot offer a key the script does
// not know how to bind.

import QtQuick
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    required property var answers
    property var keys: []
    signal answered(string key, var value)

    spacing: 12

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: Theme.mut
        text: "A key another program holds is taken from it, and given back when you uninstall. "
            + "Every key can be changed later in Settings."
    }

    Card {
        width: parent.width

        Repeater {
            model: root.keys

            Item {
                id: keyRow
                required property var modelData
                readonly property bool on: root.answers.keys.indexOf(keyRow.modelData.id) >= 0

                width: parent.width
                implicitHeight: Math.max(cap.height, toggle.implicitHeight)

                KeyCap {
                    id: cap
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyRow.modelData.key
                }

                ToggleRow {
                    id: toggle
                    anchors.left: cap.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: undefined
                    label: keyRow.modelData.what.charAt(0).toUpperCase() + keyRow.modelData.what.slice(1)
                    checked: keyRow.on
                    onToggled: value => {
                        const next = root.answers.keys.filter(k => k !== keyRow.modelData.id);
                        if (value)
                            next.push(keyRow.modelData.id);
                        root.answered("keys", next);
                    }
                }
            }
        }
    }
}
