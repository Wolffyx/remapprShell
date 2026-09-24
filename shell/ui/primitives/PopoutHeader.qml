// The first line of a panel widget's popout: its title, and a control or two
// at the end of the line -- a switch, a button that clears.
//
// The controls are written inside it and become this Row's own children,
// after the title, so they line up with it exactly as they did when every
// popout wrote the Row out by hand: centre each one with
// `anchors.verticalCenter: parent.verticalCenter`, as the title is. The title
// takes whatever width the controls that are showing leave it.
//
//   PopoutHeader {
//       title: "Bluetooth"
//       Toggle { anchors.verticalCenter: parent.verticalCenter; ... }
//   }

import QtQuick

Row {
    id: root

    property alias title: label.text

    // The room the controls take, the spacing before each included. Only the
    // ones showing count: a switch hidden with its hardware gives its room
    // back to the title.
    readonly property real trailingWidth: {
        let taken = 0;
        for (const child of root.children) {
            if (child !== label && child.visible)
                taken += child.width + root.spacing;
        }
        return taken;
    }

    width: parent ? parent.width : 0
    spacing: 8

    PanelText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - root.trailingWidth
        font.bold: true
    }
}
