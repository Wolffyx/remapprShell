pragma ComponentBehavior: Bound

// The install as it happens: each of setup.sh's steps as it starts, with a
// tick or a cross when it ends, and the script's own output folded under it.
// When it is over, what happened, and nothing to do -- or, if a step failed,
// which, and the one command that says why.

import QtQuick
import qs.core
import qs.domain.theme
import qs.ui.primitives

Column {
    id: root

    property var tasks: []
    property int failures: -1          // -1 while it runs
    property string log: ""

    readonly property bool finished: root.failures >= 0

    spacing: 12

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: Theme.mut
        visible: !root.finished
        text: "Installing. This takes a minute or two, longer with the window previews to build. "
            + "Closing this window does not stop it."
    }

    Card {
        width: parent.width
        visible: root.finished
        color: root.failures === 0 ? Qt.alpha(Theme.positive, 0.14) : Qt.alpha(Theme.error, 0.12)

        Row {
            width: parent.width
            spacing: 12

            StatusMark {
                anchors.verticalCenter: parent.verticalCenter
                size: 28
                mark: root.failures === 0 ? "ok" : "fail"
            }

            PanelText {
                width: parent.width - 40
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                text: root.failures === 0
                    ? `${Branding.displayName} is installed and running. There is nothing else to do.`
                    : `Installed, with ${root.failures} step(s) that did not work. `
                      + `'${Branding.shortName} doctor' says why, and '${Branding.shortName} uninstall' takes it all off again.`
            }
        }
    }

    Card {
        width: parent.width
        visible: root.tasks.length > 0

        Repeater {
            model: root.tasks

            Row {
                id: task
                required property var modelData
                width: parent.width
                spacing: 12

                StatusMark {
                    anchors.verticalCenter: parent.verticalCenter
                    mark: ({ done: "ok", failed: "fail", running: "running" })[task.modelData.state] ?? "wait"
                }

                PanelText {
                    width: parent.width - 34
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.WordWrap
                    text: task.modelData.label.charAt(0).toUpperCase() + task.modelData.label.slice(1)
                    font.pixelSize: 14
                    color: task.modelData.state === "failed" ? Theme.error : Theme.fg
                }
            }
        }
    }

    Details {
        width: parent.width
        text: root.log
        follow: true
    }
}
