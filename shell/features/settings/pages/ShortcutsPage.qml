pragma ComponentBehavior: Bound

// Every global shortcut this shell can take, and what each is bound to.
//
// The keys were only ever settable from the terminal, so the window listed
// none of them and a key nobody remembered binding could not be found, let
// alone changed. They are read and written through the same `shortcuts`
// command the CLI has -- one path that writes, one ledger that can undo it.
//
// Nothing is bound by default, deliberately: a shortcut is the one setting a
// user is guaranteed to notice being taken, and the obvious keys here are the
// ones another shell is most likely to be holding. Binding one here takes it
// from whoever holds it, and `shortcuts revert` gives every one of them back.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // `shortcuts status --json`, parsed. Null until the first read returns.
    property var shortcutState: null
    property string status: ""
    property bool busy: false

    // Which row is listening for a key, by action id, or "".
    property string capturing: ""

    readonly property var actions: root.shortcutState?.actions ?? []
    // kglobalaccel only grabs a component's keys while something owns it. A
    // key with no owner is recorded and never fires, which from the outside
    // is indistinguishable from a key that does nothing.
    readonly property bool grabbed: root.shortcutState?.active === true

    spacing: 14

    Component.onCompleted: root.refresh()

    function refresh(): void {
        readProc.running = false;
        readProc.running = true;
    }

    function run(args): void {
        if (root.busy)
            return;
        root.status = "";
        runProc.command = [Branding.ctlBin, "shortcuts"].concat(args);
        runProc.running = true;
    }

    // Qt's key to the name KDE writes in kglobalshortcutsrc. Anything not
    // named here is refused rather than guessed: a shortcut written wrong is
    // recorded, never fires, and gives no hint why.
    function keyName(key): string {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F12)
            return `F${key - Qt.Key_F1 + 1}`;
        switch (key) {
        case Qt.Key_Space:  return "Space";
        case Qt.Key_Tab:    return "Tab";
        case Qt.Key_Return:
        case Qt.Key_Enter:  return "Return";
        case Qt.Key_Home:   return "Home";
        case Qt.Key_End:    return "End";
        case Qt.Key_PageUp: return "PgUp";
        case Qt.Key_PageDown: return "PgDown";
        case Qt.Key_Left:   return "Left";
        case Qt.Key_Right:  return "Right";
        case Qt.Key_Up:     return "Up";
        case Qt.Key_Down:   return "Down";
        case Qt.Key_Print:  return "Print";
        case Qt.Key_Comma:  return "Comma";
        case Qt.Key_Period: return "Period";
        case Qt.Key_Slash:  return "Slash";
        }
        return "";
    }

    function isModifier(key): bool {
        return key === Qt.Key_Meta || key === Qt.Key_Control
            || key === Qt.Key_Alt || key === Qt.Key_Shift
            || key === Qt.Key_Super_L || key === Qt.Key_Super_R;
    }

    function modifiersOf(mods): var {
        const out = [];
        if (mods & Qt.MetaModifier)    out.push("Meta");
        if (mods & Qt.ControlModifier) out.push("Ctrl");
        if (mods & Qt.AltModifier)     out.push("Alt");
        if (mods & Qt.ShiftModifier)   out.push("Shift");
        return out;
    }

    function bind(id, key): void {
        root.capturing = "";
        root.run(["set", id, key]);
    }

    Card {
        width: root.width

        SectionLabel { text: "Global shortcuts" }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.grabbed
                ? "Click a shortcut and press the keys you want. Esc leaves it as it was; Backspace unbinds it. A key already held by something else is taken from it, and “Revert every shortcut” gives them all back."
                : "These are recorded but not grabbed: nothing owns them, so none of them fire. The session daemon is the owner — if it is not running, a key here will do nothing however it is bound."
            font.pixelSize: 12
            lineHeight: 1.35
            color: root.grabbed ? Theme.mut : Theme.error
        }

        Repeater {
            model: root.actions

            Item {
                id: row

                required property var modelData
                readonly property bool active: root.capturing === row.modelData.id
                readonly property string shortcut: String(row.modelData.shortcut ?? "")

                width: root.width - 32
                implicitHeight: 42

                PanelText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - keyButton.width - clearButton.width - 24
                    elide: Text.ElideRight
                    text: row.modelData.label
                    font.pixelSize: 13
                }

                // The key, and the thing you click to change it. Focused when
                // it becomes active, because a key press has to land somewhere.
                Rectangle {
                    id: keyButton

                    anchors.right: clearButton.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 168
                    height: 32
                    radius: Theme.radiusTiny + 2
                    color: row.active ? Theme.accC : (keyHover.hovered ? Theme.s3 : Theme.s1)
                    border.width: row.active ? 2 : 1
                    border.color: row.active ? Theme.acc : Theme.out

                    PanelText {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: row.active ? "Press the keys…"
                            : row.shortcut.length > 0 ? row.shortcut : "Not bound"
                        font.pixelSize: 13
                        color: row.active ? Theme.accCFg
                             : row.shortcut.length > 0 ? Theme.fg : Theme.mut
                    }

                    HoverHandler { id: keyHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            root.capturing = row.active ? "" : String(row.modelData.id);
                            if (root.capturing.length > 0)
                                capture.forceActiveFocus();
                        }
                    }

                    Item {
                        id: capture

                        anchors.fill: parent
                        focus: false

                        // A modifier pressed on its own is not a shortcut yet
                        // -- Meta+S sends Meta first, and committing there
                        // would bind Meta and never see the S. So a modifier
                        // commits on release, when it is known that nothing
                        // followed it, and everything else commits at once.
                        Keys.onPressed: event => {
                            if (!row.active)
                                return;
                            event.accepted = true;
                            if (event.key === Qt.Key_Escape) {
                                root.capturing = "";
                                return;
                            }
                            if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
                                root.capturing = "";
                                root.run(["clear", String(row.modelData.id)]);
                                return;
                            }
                            if (root.isModifier(event.key))
                                return;
                            const name = root.keyName(event.key);
                            if (name.length === 0) {
                                root.status = "That key cannot be written as a shortcut.";
                                return;
                            }
                            root.bind(String(row.modelData.id), root.modifiersOf(event.modifiers).concat([name]).join("+"));
                        }

                        Keys.onReleased: event => {
                            if (!row.active || !root.isModifier(event.key))
                                return;
                            event.accepted = true;
                            // Meta on its own is a shortcut people really do
                            // want -- it is what opens the menu on Windows.
                            const mods = root.modifiersOf(event.modifiers);
                            root.bind(String(row.modelData.id), mods.length > 0 ? mods.join("+") : "Meta");
                        }
                    }
                }

                IconButton {
                    id: clearButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.shortcut.length > 0
                    glyph: "close"
                    iconName: "edit-clear"
                    tooltip: "Unbind this"
                    onActivated: root.run(["clear", String(row.modelData.id)])
                }
            }
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Undo" }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Gives every key this project bound back to whoever held it before, including the ones taken from KWin and from another shell."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }

        TextButton {
            text: "Revert every shortcut"
            glyph: "undo"
            iconName: "edit-undo"
            enabled: !root.busy
            onActivated: root.run(["revert"])
        }

        PanelText {
            width: parent.width
            visible: root.status.length > 0
            wrapMode: Text.WordWrap
            text: root.status
            font.pixelSize: 12
            color: Theme.error
        }
    }

    readonly property Process _read: Process {
        id: readProc
        command: [Branding.ctlBin, "shortcuts", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.shortcutState = JSON.parse(text);
                } catch (e) {
                    root.status = "Could not read the shortcuts.";
                    Log.warn("settings", `shortcuts status: ${e}`);
                }
            }
        }
    }

    readonly property Process _run: Process {
        id: runProc
        onRunningChanged: {
            root.busy = running;
            if (!running)
                root.refresh();
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const errors = text.split("\n").filter(l => /error/i.test(l));
                if (errors.length > 0)
                    root.status = errors[errors.length - 1].replace(/^.*error:\s*/i, "");
            }
        }
    }
}
