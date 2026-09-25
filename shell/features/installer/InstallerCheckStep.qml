pragma ComponentBehavior: Bound

// The first page: whether this machine can take the shell, before anything
// is asked of the person in front of it.
//
// What preflight.sh said, as rows that pass or do not -- its whole report is
// behind "Details" -- and what the build of the window previews would still
// need to install, which is said here so the password it asks for later is
// not a surprise.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Column {
    id: root

    property bool checking: true
    property bool passed: false
    property string plasma: ""
    property var buildMissing: []
    property string report: ""

    spacing: 12

    component CheckRow: Row {
        id: row
        property string status: "wait"    // wait | ok | warn | fail
        property string title: ""
        property string detail: ""
        width: parent.width
        spacing: 12

        StatusMark {
            anchors.verticalCenter: parent.verticalCenter
            mark: row.status === "wait" ? "running" : row.status
        }

        Column {
            width: parent.width - 34
            spacing: 1
            PanelText { width: parent.width; wrapMode: Text.WordWrap; text: row.title; font.pixelSize: 14 }
            PanelText {
                width: parent.width
                visible: row.detail.length > 0
                wrapMode: Text.WordWrap
                text: row.detail
                font.pixelSize: 12
                color: Theme.mut
            }
        }
    }

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: Theme.mut
        text: "The installer asks a few questions, shows what it will do, and does nothing until you say so. "
            + "A restore point is taken first, and the uninstall puts Plasma back the way it was."
    }

    Card {
        width: parent.width

        CheckRow {
            status: root.checking ? "wait" : root.passed ? "ok" : "fail"
            title: root.checking ? "Checking this machine..."
                 : root.passed ? `Plasma ${root.plasma || "6"}, ready for it`
                 : "This machine is not ready"
            detail: root.checking || root.passed ? ""
                  : "The details below say what is missing. Installing anyway is possible, and not advised."
        }

        CheckRow {
            status: "ok"
            title: "Everything the shell runs with is installed"
        }

        CheckRow {
            visible: !root.checking
            status: root.buildMissing.length === 0 ? "ok" : "warn"
            title: root.buildMissing.length === 0 ? "The tools to build window previews are installed"
                 : "Building window previews needs a few development packages"
            detail: root.buildMissing.length === 0 ? ""
                  : `${root.buildMissing.join(", ")} -- installed during the install if you keep the previews, `
                    + "which asks for your password once."
        }
    }

    Details {
        width: parent.width
        text: root.report
    }
}
