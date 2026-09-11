// A person's picture, round -- or their initial on the accent's container
// colour where there is no picture.
//
// The circle and the initial are plain items, always drawn; only the picture
// goes through a mask. Quickshell's ClippingRectangle draws its whole self,
// colour included, through a shader, and where that shader does not run the
// avatar was simply not there.

import QtQuick
import QtQuick.Effects
import qs.domain.theme

Item {
    id: root

    // A file path, or empty.
    property string source: ""
    property string initial: ""
    property real size: 40

    implicitWidth: root.size
    implicitHeight: root.size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.primaryContainer

        PanelText {
            anchors.centerIn: parent
            text: root.initial
            font.pixelSize: Math.round(root.size * 0.4)
            font.weight: Font.Medium
            color: Theme.primaryContainerFg
        }
    }

    Image {
        id: picture
        anchors.fill: parent
        visible: false
        source: root.source.length > 0 ? `file://${root.source}` : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        asynchronous: true
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        visible: picture.status === Image.Ready
        source: picture
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
