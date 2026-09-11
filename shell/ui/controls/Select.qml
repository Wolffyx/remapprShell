pragma ComponentBehavior: Bound

// A list of choices, shown as a dropdown.

import QtQuick
import QtQuick.Controls
import qs.ui.primitives
import qs.domain.theme

ComboBox {
    id: root

    property var values: []
    signal picked(string value)

    model: root.values
    implicitWidth: 180
    implicitHeight: 36

    onActivated: index => root.picked(String(root.values[index]))

    background: Rectangle {
        radius: Theme.radiusTiny + 2
        color: root.hovered ? Theme.s3 : Theme.s1
        border.width: 1
        border.color: root.activeFocus ? Theme.acc : Theme.out
    }

    indicator: Glyph {
        x: root.width - width - 10
        y: (root.height - height) / 2
        name: "expand_more"
        fallback: "arrow-down"
        size: 18
        color: Theme.mut
    }

    contentItem: Text {
        leftPadding: 12
        rightPadding: 30
        text: root.displayText
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    delegate: ItemDelegate {
        id: option

        required property var modelData
        required property int index

        width: root.width - 8
        height: 34
        highlighted: root.highlightedIndex === option.index

        // `parent` inside these inline components is the control's internal
        // wrapper, not the delegate, so both refer to the delegate by id.
        background: Rectangle {
            radius: Theme.radiusTiny
            color: option.index === root.currentIndex ? Theme.accC
                 : option.highlighted ? Theme.hover : "transparent"
        }

        contentItem: Text {
            leftPadding: 8
            text: option.modelData
            color: option.index === root.currentIndex ? Theme.accCFg : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
        }
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 280)
        padding: 4

        background: Rectangle {
            radius: Theme.radiusSmall
            color: Theme.s1
            border.width: 1
            border.color: Theme.out
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.delegateModel
            currentIndex: root.highlightedIndex
            spacing: 2
        }
    }
}
