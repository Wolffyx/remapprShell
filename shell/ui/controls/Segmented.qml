pragma ComponentBehavior: Bound

// A row of choices, all of them visible: the design's segmented buttons.
//
// A dropdown hides every option but one, which is right for a long list and
// wrong for three. Where the choices are few and the difference matters --
// which edge the panel is on, how the start menu is laid out -- they are all
// on screen and one press away.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Flow {
    id: root

    // The values written to configuration, and what to call each on screen.
    // `labels` may be shorter than `values`: a value with no label shows
    // itself.
    property var values: []
    property var labels: []
    property var glyphs: []
    property string current: ""
    property int minimumWidth: 0
    property bool equal: true
    signal picked(string value)

    readonly property int count: Math.max(1, (root.values ?? []).length)

    spacing: 8

    Repeater {
        model: root.values ?? []

        Rectangle {
            id: seg

            required property var modelData
            required property int index

            readonly property bool selected: String(seg.modelData) === root.current
            readonly property string text: root.labels[seg.index] ?? String(seg.modelData)
            readonly property string glyph: root.glyphs[seg.index] ?? ""

            width: root.equal ? Math.max(root.minimumWidth, (root.width - root.spacing * (root.count - 1)) / root.count)
                              : Math.max(root.minimumWidth, label.implicitWidth + (seg.glyph.length > 0 ? 30 : 0) + 28)
            height: 38
            radius: Theme.radiusTiny + 2
            color: seg.selected ? Theme.acc : (segHover.hovered ? Theme.s3 : Theme.s1)
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: seg.glyph.length > 0
                    name: seg.glyph
                    size: 18
                    color: seg.selected ? Theme.accFg : Theme.fg
                }

                PanelText {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.text
                    font.pixelSize: 13
                    color: seg.selected ? Theme.accFg : Theme.fg
                }
            }

            HoverHandler { id: segHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.picked(String(seg.modelData)) }
        }
    }
}
