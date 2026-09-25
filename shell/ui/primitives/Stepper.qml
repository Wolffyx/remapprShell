pragma ComponentBehavior: Bound

// Numbered steps along a line, the one in progress in bold: where a
// multi-page window is, and how far it has come.
//
// Done steps are filled in the positive colour and show a tick; the line
// between two steps takes that colour once the first is done. The circles are
// spread over whatever width it is given, so the row fits the window rather
// than the other way round, and a label too long for its share is elided
// rather than overlapping its neighbour.
//
// `current` past the last step marks every step done -- the finished state.
// A done step can be pressed to go back to it, where `navigable` allows.

import QtQuick
import qs.domain.theme

Item {
    id: root

    property var steps: []
    property int current: 0
    property bool navigable: true
    signal stepClicked(int index)

    readonly property int count: (root.steps ?? []).length
    readonly property real dot: 30
    readonly property real share: root.count > 0 ? root.width / root.count : root.width

    implicitHeight: root.dot + 26

    function centreOf(i) {
        return root.share * i + root.share / 2;
    }

    // The lines first, under the circles.
    Repeater {
        model: Math.max(0, root.count - 1)

        Rectangle {
            id: line
            required property int index
            x: root.centreOf(line.index) + root.dot / 2
            y: root.dot / 2 - 1
            width: root.centreOf(line.index + 1) - root.centreOf(line.index) - root.dot
            height: 2
            color: line.index < root.current ? Theme.positive : Theme.outlineVariant
            Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
        }
    }

    Repeater {
        model: root.steps

        Item {
            id: stepItem

            required property int index
            required property string modelData

            readonly property bool done: stepItem.index < root.current
            readonly property bool here: stepItem.index === root.current

            x: root.centreOf(stepItem.index) - root.share / 2
            width: root.share
            height: root.implicitHeight

            Rectangle {
                id: circle
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.dot
                height: root.dot
                radius: root.dot / 2
                color: stepItem.done ? Theme.positive : Theme.s2
                border.width: stepItem.here ? 2 : 0
                border.color: Theme.acc
                Behavior on color { ColorAnimation { duration: Theme.durationMedium } }

                PanelText {
                    anchors.centerIn: parent
                    visible: !stepItem.done
                    text: String(stepItem.index + 1)
                    font.pixelSize: 13
                    font.bold: stepItem.here
                    color: stepItem.here ? Theme.fg : Theme.mut
                }

                Glyph {
                    anchors.centerIn: parent
                    visible: stepItem.done
                    name: "check"
                    fallback: "dialog-ok"
                    size: 18
                    color: "white"
                }
            }

            PanelText {
                anchors.top: circle.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: stepItem.modelData
                font.pixelSize: 12
                font.bold: stepItem.here
                color: stepItem.here || stepItem.done ? Theme.fg : Theme.mut
            }

            TapHandler {
                enabled: root.navigable && stepItem.done
                onTapped: root.stepClicked(stepItem.index)
            }

            HoverHandler {
                enabled: root.navigable && stepItem.done
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
