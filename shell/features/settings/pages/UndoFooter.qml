// The last lines of a page that runs a command: undo what it set, Plasma's own
// page for the same thing, read the state again -- and the command's own
// error line when it refused.
//
// Not a page. The appearance, screen edges and window switching pages each
// ended with this, word for word apart from what their buttons say, so it is
// written once, beside them.
//
// A Column in the card's own column. Give it the card's spacing and the
// buttons and the error line sit exactly where they did as two separate
// children of the card.

import QtQuick
import qs.platform.kde
import qs.platform.system
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // The page's conversation with its command.
    required property CtlSession session

    // Whether there is anything of the page's to undo: the command's status
    // says so, as `customised` or in a word of its own.
    property bool customised: false
    property string undoText: "Undo everything set here"
    property var undoArgs: ["revert"]

    // Plasma's own page for the same settings, and what the button calls it.
    required property string settingsModule
    required property string settingsText

    width: parent ? parent.width : 0

    Flow {
        width: parent.width
        spacing: 8
        enabled: !root.session.busy

        TextButton {
            visible: root.customised
            iconName: "edit-undo"
            text: root.undoText
            onActivated: root.session.run(root.undoArgs)
        }

        TextButton {
            iconName: "configure"
            text: root.settingsText
            onActivated: PlasmaApplets.openSettings(root.settingsModule)
        }

        IconButton {
            iconName: "view-refresh"
            onActivated: root.session.refresh()
        }
    }

    PanelText {
        visible: root.session.status.length > 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.session.status
        font.pixelSize: 12
    }
}
