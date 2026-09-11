pragma ComponentBehavior: Bound

// The consent window: what would be sent, to whom, and a button that sends it.
//
// It shows the actual redacted bundle rather than a description of one. A
// dialog that says "a diagnostic report will be sent" is asking for trust; this
// one is asking for a decision, and the text is the thing being decided about.
//
// Everything runs through `rmpr ask`. This window never assembles a bundle or
// talks to a provider itself, so the CLI, the shortcut and this button cannot
// send different things -- and the CLI's own tests cover what gets sent.

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

FloatingWindow {
    id: root

    // Empty means the newest report, or a fresh one if there is none.
    property string reportName: ""

    property string bundle: ""
    property string question: ""
    property string provider: ""
    property var providers: []
    property string status: "Gathering the report..."
    property string answer: ""
    property bool busy: false
    property bool sent: false

    readonly property var available: root.providers.filter(p => p.available).map(p => p.id)
    readonly property var chosen: root.providers.find(p => p.id === root.provider) ?? null
    readonly property bool leaves: root.chosen?.leavesMachine ?? true

    title: `Ask about a report`
    implicitWidth: 760
    implicitHeight: 620
    color: Theme.background

    Component.onCompleted: root.load()

    function load() {
        loadProc.running = false;
        const cmd = [Branding.ctlBin, "ask", "--show", "--json"];
        if (root.reportName.length > 0)
            cmd.push("--report", root.reportName);
        loadProc.command = cmd;
        loadProc.running = true;
    }

    function send() {
        if (root.busy || root.reportName.length === 0)
            return;
        root.busy = true;
        root.answer = "";
        root.status = root.leaves ? `Sending to ${root.provider}...` : `Running ${root.provider}...`;
        sendProc.running = false;
        sendProc.command = [Branding.ctlBin, "ask", "--report", root.reportName,
                            "--provider", root.provider, "--yes"];
        sendProc.running = true;
    }

    readonly property Process _load: Process {
        id: loadProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const got = JSON.parse(text);
                    root.reportName = got.report ?? "";
                    root.bundle = got.bundle ?? "";
                    root.question = got.question ?? "";
                    root.providers = got.providers ?? [];
                    // The configured provider, unless it cannot run here, in
                    // which case the first that can -- and the clipboard is
                    // listed first for a reason.
                    const wanted = String(got.provider ?? "");
                    root.provider = root.available.includes(wanted) ? wanted : (root.available[0] ?? "");
                    root.status = "";
                } catch (e) {
                    root.status = `Could not read the report: ${e}`;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0 && root.bundle.length === 0) root.status = text.trim()
        }
    }

    readonly property Process _send: Process {
        id: sendProc
        onRunningChanged: {
            if (!running) {
                root.busy = false;
                root.sent = true;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) root.answer = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) root.status = text.trim()
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.question.length > 0 ? root.question : "Ask about a report"
            font.pixelSize: 16
        }

        Row {
            spacing: 12

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Send to"
            }

            Select {
                anchors.verticalCenter: parent.verticalCenter
                enabled: !root.busy && root.available.length > 0
                values: root.available
                currentIndex: Math.max(0, root.available.indexOf(root.provider))
                onPicked: value => root.provider = value
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.chosen !== null
                color: root.leaves ? Theme.negative : Theme.foregroundInactive
                font.pixelSize: 11
                text: root.leaves
                    ? "leaves this machine -- everything below, exactly as shown"
                    : "stays on this machine"
            }
        }

        // Unavailable providers are named with the reason, so "why is Ollama
        // not in the list" has an answer on the screen rather than in a log.
        PanelText {
            visible: root.providers.some(p => !p.available)
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.foregroundInactive
            font.pixelSize: 11
            text: "Not available here: " + root.providers.filter(p => !p.available)
                .map(p => `${p.id} (${p.reason})`).join(", ")
        }

        Rectangle {
            width: parent.width
            height: parent.height - y - buttons.height - 16
            radius: 6
            color: Theme.backgroundAlternate
            border.width: 1
            border.color: Theme.alpha(Theme.foreground, 0.15)

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                TextEdit {
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.foreground
                    font.family: "monospace"
                    font.pixelSize: 11
                    text: root.answer.length > 0
                        ? `${root.answer}\n\n----- what was sent -----\n\n${root.bundle}`
                        : root.bundle
                }
            }
        }

        Row {
            id: buttons
            width: parent.width
            spacing: 8

            PanelText {
                width: parent.width - cancel.width - send.width - 16
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.WordWrap
                text: root.status
                color: Theme.foregroundInactive
                font.pixelSize: 11
            }

            Rectangle {
                id: cancel
                width: cancelText.implicitWidth + 24
                height: 30
                radius: 6
                color: cancelHover.hovered ? Theme.hoverBackground : Theme.backgroundAlternate

                PanelText { id: cancelText; anchors.centerIn: parent; text: root.sent ? "Close" : "Cancel" }
                HoverHandler { id: cancelHover }
                TapHandler { onTapped: root.visible = false }
            }

            Rectangle {
                id: send
                width: sendText.implicitWidth + 24
                height: 30
                radius: 6
                visible: root.provider.length > 0 && !root.sent
                color: root.busy ? Theme.backgroundAlternate
                     : (sendHover.hovered ? Theme.alpha(Theme.accent, 0.35)
                                          : Theme.alpha(Theme.accent, 0.25))

                PanelText {
                    id: sendText
                    anchors.centerIn: parent
                    text: root.provider === "clipboard" ? "Copy" : `Send to ${root.provider}`
                }
                HoverHandler { id: sendHover; enabled: !root.busy }
                TapHandler { enabled: !root.busy; onTapped: root.send() }
            }
        }
    }
}
