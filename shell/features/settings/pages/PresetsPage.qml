pragma ComponentBehavior: Bound

// Layouts: the ones that ship, and the person's own.
//
// Everything here runs the same command the CLI does (`preset`), so the two
// cannot diverge: list, apply, save and delete. Applying one keeps the
// previous profile -- trying a layout must not be a one-way door -- and when
// the configuration is a layout of the person's own that is in no list yet,
// the command saves it to "Your layouts" first.
//
// Saving is offered only when there is something new to save: a
// configuration changed from the defaults that is not already one of the
// layouts. Which one is in use is marked, so the list says where you are.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    property var layouts: []
    // "defaults", "saved", "custom" or "unreadable": see `preset list --json`.
    property string layoutState: "defaults"
    property string current: ""
    // What the last command said when it refused, in its own words.
    property string problem: ""
    property bool busy: false

    readonly property var mine: root.layouts.filter(l => l.custom)
    readonly property var shipped: root.layouts.filter(l => !l.custom)

    Component.onCompleted: root.reload()

    function reload() {
        listProc.running = false;
        listProc.running = true;
    }

    // The configuration changing under the page -- a setting changed
    // elsewhere, a layout applied -- changes which layout is in use.
    Connections {
        target: ConfigStore
        function onProfileDataChanged() { settle.restart(); }
    }
    Timer { id: settle; interval: 300; onTriggered: root.reload() }

    readonly property Process _list: Process {
        id: listProc
        command: [Paths.ctlBin, "preset", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let reply = null;
                try {
                    reply = JSON.parse(text);
                } catch (e) {
                    Log.warn("settings", `layouts: could not read the list: ${e}`);
                    return;
                }
                root.layouts = Array.isArray(reply?.layouts) ? reply.layouts : [];
                root.layoutState = String(reply?.state ?? "defaults");
                root.current = String(reply?.current ?? "");
            }
        }
    }

    // Apply, save and delete: one at a time, and the list read again after.
    readonly property Process _run: Process {
        id: runProc
        stderr: StdioCollector { id: runErr }
        onExited: code => {
            root.busy = false;
            const said = String(runErr.text ?? "").replace(/\x1b\[[0-9;]*m/g, "");
            const refusal = said.split("\n").map(l => /^error:\s*(.*)$/.exec(l.trim())).filter(m => m);
            root.problem = code === 0 ? "" : (refusal.length > 0 ? refusal[refusal.length - 1][1]
                                                                  : "That did not work; the log says why.");
            root.reload();
        }
    }

    function run(args) {
        if (root.busy)
            return;
        root.busy = true;
        root.problem = "";
        runProc.running = false;
        runProc.command = [Paths.ctlBin, "preset"].concat(args);
        runProc.running = true;
    }

    // Deleting asks twice: the first click arms the button for a few
    // seconds, the second deletes. A layout deleted is gone -- unlike one
    // replaced, nothing keeps it.
    property string armed: ""
    Timer { id: disarm; interval: 4000; onTriggered: root.armed = "" }

    function remove(id) {
        if (root.armed !== id) {
            root.armed = id;
            disarm.restart();
            return;
        }
        root.armed = "";
        root.run(["delete", id]);
    }

    function save(name) {
        const n = String(name ?? "").trim();
        root.run(["save", n.length > 0 ? n : "My layout"]);
    }

    // ---- your layouts -------------------------------------------------------

    Card {
        id: mineCard

        width: root.cellWidth
        spacing: 8

        SectionLabel { text: "Your layouts" }

        Hint {
            width: mineCard.contentWidth
            text: "Layouts you saved. Change anything after applying a layout and you can save the result here; applying another layout saves yours here first, so it is never lost."
        }

        // Shown only when there is something new to keep.
        Rectangle {
            visible: root.layoutState === "custom"
            width: mineCard.contentWidth
            height: saveColumn.implicitHeight + 28
            radius: Theme.radiusOf(12)
            color: Theme.s1
            border.width: 1
            border.color: Theme.acc

            Column {
                id: saveColumn
                x: 14
                y: 14
                width: parent.width - 28
                spacing: 10

                Row {
                    spacing: 8

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "bookmark_add"
                        fallback: "bookmark-new"
                        size: 20
                        color: Theme.acc
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Your current layout is not saved"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8

                    TextInputRow {
                        id: nameField
                        width: parent.width - saveButton.width - parent.spacing
                        placeholderText: "My layout"
                        maximumLength: 40
                        Accessible.name: "Name for this layout"
                        onAccepted: root.save(nameField.text)
                    }

                    TextButton {
                        id: saveButton
                        anchors.verticalCenter: parent.verticalCenter
                        primary: true
                        glyph: "save"
                        iconName: "document-save"
                        text: "Save layout"
                        enabled: !root.busy
                        onActivated: root.save(nameField.text)
                    }
                }
            }
        }

        Repeater {
            model: root.mine

            OptionRow {
                id: mineRow

                required property var modelData

                width: mineCard.contentWidth
                height: 58
                hoverable: true
                selected: mineRow.modelData.current
                title: mineRow.modelData.name || mineRow.modelData.id
                detail: mineRow.modelData.current ? `In use · ${mineRow.modelData.description}` : mineRow.modelData.description

                TextButton {
                    visible: !mineRow.modelData.current
                    anchors.verticalCenter: parent.verticalCenter
                    tonal: true
                    width: 74
                    height: 30
                    radius: Theme.radiusOf(10)
                    text: "Apply"
                    enabled: !root.busy
                    onActivated: root.run(["apply", mineRow.modelData.id])
                }

                IconButton {
                    readonly property bool armed: root.armed === mineRow.modelData.id
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: armed ? "delete_forever" : "delete"
                    iconName: "edit-delete"
                    tooltip: armed ? "Click again to delete this layout" : "Delete this layout"
                    color: armed ? Theme.error : mineRow.modelData.current ? Theme.accCFg : Theme.mut
                    onActivated: root.remove(mineRow.modelData.id)
                }
            }
        }

        Hint {
            visible: root.mine.length === 0 && root.layoutState !== "custom"
            width: mineCard.contentWidth
            text: root.layoutState === "defaults"
                ? "Nothing saved yet. You are on the defaults; change the panel or the look and your layout can be saved here."
                : "Nothing saved yet."
        }

        Hint {
            visible: root.layoutState === "unreadable"
            width: mineCard.contentWidth
            tone: "warning"
            text: "The active profile does not parse, so it cannot be saved as a layout. It is still kept before any layout replaces it."
        }

        Hint {
            visible: root.problem.length > 0
            width: mineCard.contentWidth
            tone: "error"
            text: root.problem
        }
    }

    // ---- shipped ------------------------------------------------------------

    Card {
        id: card

        width: root.cellWidth
        spacing: 8

        SectionLabel { text: "Shipped layouts" }

        Hint {
            width: card.contentWidth
            text: "Applying a layout replaces your current configuration. The previous one is kept as a profile first, and saved to Your layouts when it is a layout of your own that is not there yet."
        }

        Repeater {
            model: root.shipped

            OptionRow {
                id: preset

                required property var modelData

                width: card.contentWidth
                height: 58
                hoverable: true
                selected: preset.modelData.current
                title: preset.modelData.name || preset.modelData.id
                detail: preset.modelData.current ? `In use · ${preset.modelData.description}` : preset.modelData.description

                TextButton {
                    visible: !preset.modelData.current
                    anchors.verticalCenter: parent.verticalCenter
                    tonal: true
                    width: 74
                    height: 30
                    radius: Theme.radiusOf(10)
                    text: "Apply"
                    enabled: !root.busy
                    onActivated: root.run(["apply", preset.modelData.id])
                }
            }
        }

        PanelText {
            visible: root.shipped.length === 0
            text: "No presets found."
            font.pixelSize: 13
            color: Theme.mut
        }
    }
}
