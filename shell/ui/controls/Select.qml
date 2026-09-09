pragma ComponentBehavior: Bound

// A list of choices, shown as a dropdown.

import QtQuick
import QtQuick.Controls
import qs.domain.theme

ComboBox {
    id: root

    property var values: []
    signal picked(string value)

    model: root.values
    implicitWidth: 180
    implicitHeight: 28

    onActivated: index => root.picked(String(root.values[index]))

    background: Rectangle {
        radius: 5
        color: PlasmaColors.backgroundAlternate
        border.width: 1
        border.color: PlasmaColors.alpha(PlasmaColors.foreground, 0.15)
    }

    contentItem: Text {
        leftPadding: 8
        rightPadding: 24
        text: root.displayText
        color: PlasmaColors.foreground
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    delegate: ItemDelegate {
        id: option

        required property var modelData
        required property int index

        width: root.width
        highlighted: root.highlightedIndex === option.index

        // `parent` inside these inline components is the control's internal
        // wrapper, not the delegate, so both refer to the delegate by id.
        background: Rectangle {
            color: option.highlighted ? PlasmaColors.hoverBackground : PlasmaColors.background
        }

        contentItem: Text {
            leftPadding: 8
            text: option.modelData
            color: PlasmaColors.foreground
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
        }
    }

    popup: Popup {
        y: root.height
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight, 240)
        padding: 4

        background: Rectangle {
            radius: 6
            color: PlasmaColors.background
            border.width: 1
            border.color: PlasmaColors.alpha(PlasmaColors.foreground, 0.15)
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.delegateModel
            currentIndex: root.highlightedIndex
        }
    }
}
