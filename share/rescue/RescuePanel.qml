// What the rescue window says, and its three buttons. See shell.qml beside it.
//
// Self-contained on purpose: no import from the shell's tree, no theme, no
// font that might not be there. It is drawn when the shell has failed, and
// anything it shared with the shell could be the thing that failed.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string name: ""
    property string unit: ""
    property string errors: ""
    property string report: ""
    property string hint: ""

    signal done()

    readonly property color surface: "#1e1f24"
    readonly property color card: "#2a2b31"
    readonly property color line: "#3a3b42"
    readonly property color fg: "#e4e2e9"
    readonly property color fg2: "#a9a8b3"
    readonly property color danger: "#f2b8b5"
    readonly property color accent: "#a8c7fa"
    readonly property color accentFg: "#062e6f"

    implicitHeight: column.implicitHeight + 48
    focus: true

    Keys.onEscapePressed: root.done()
    Keys.onReturnPressed: root.tryAgain()
    Keys.onEnterPressed: root.tryAgain()

    // Starting the unit again, from a unit of this window's own: the reset
    // first, since a unit that hit its start limit refuses a plain start, and
    // --no-block, so the window closes now rather than when the shell is up.
    // It waits for systemctl to return before it quits -- quitting stops this
    // window's unit, and that takes everything still running in it along.
    function tryAgain() {
        if (retry.running)
            return;
        status.text = "Starting it again…";
        retry.running = true;
    }

    Process {
        id: retry
        command: ["sh", "-c", 'systemctl --user reset-failed "$1"; exec systemctl --user start --no-block "$1"',
                  "sh", root.unit]
        onExited: root.done()
    }

    // In a scope of its own, as the shell starts applications: a file manager
    // started from here would otherwise be stopped with this window's unit.
    function openReport() {
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--slice=app.slice", "--collect",
                                 "--quiet", "--", "xdg-open", root.report]);
    }

    Column {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
        spacing: 14

        Text {
            width: parent.width
            text: `${root.name || "The shell"} couldn't start`
            color: root.fg
            font { pixelSize: 19; weight: Font.DemiBold }
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            text: "systemd tried and stopped trying, so the desktop has no panel until it starts. "
                + "This is what the last try said."
            color: root.fg2
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }

        Rectangle {
            width: parent.width
            height: Math.min(errorText.implicitHeight + 24, 240)
            radius: 10
            color: root.card
            border { width: 1; color: root.line }
            clip: true

            Flickable {
                anchors { fill: parent; margins: 12 }
                contentHeight: errorText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: errorText
                    width: parent.width
                    text: root.errors
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: root.danger
                    selectionColor: root.accent
                    selectedTextColor: root.accentFg
                    font { family: "monospace"; pixelSize: 12 }
                }
            }
        }

        Text {
            width: parent.width
            visible: root.report !== ""
            text: `Report: ${root.report}`
            color: root.fg2
            font { family: "monospace"; pixelSize: 12 }
            elide: Text.ElideMiddle
        }

        Text {
            width: parent.width
            visible: root.hint !== ""
            text: `In a terminal: ${root.hint}`
            color: root.fg2
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Item {
            width: parent.width
            height: buttons.implicitHeight + 6

            Text {
                id: status
                anchors { left: parent.left; verticalCenter: buttons.verticalCenter }
                color: root.fg2
                font.pixelSize: 12
            }

            Row {
                id: buttons
                anchors { right: parent.right; bottom: parent.bottom }
                spacing: 8

                RescueButton {
                    text: "Open report"
                    visible: root.report !== ""
                    fg: root.fg; fill: root.card; edge: root.line
                    onClicked: root.openReport()
                }
                RescueButton {
                    text: "Close"
                    fg: root.fg; fill: root.card; edge: root.line
                    onClicked: root.done()
                }
                RescueButton {
                    text: "Try again"
                    fg: root.accentFg; fill: root.accent; edge: root.accent
                    onClicked: root.tryAgain()
                }
            }
        }
    }
}
