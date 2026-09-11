pragma ComponentBehavior: Bound

// Switching windows: what Alt+Tab looks like, and who gets Alt+Tab and
// Meta+Tab.
//
// KWin draws the switcher and the Overview. The page says first who holds
// each key, because on a desktop with another shell beside ours the answer is
// often "not KWin", and a button that silently took a key back would be the
// one change a person is guaranteed to notice. Everything runs the same
// `switcher` command the CLI has, and every change -- the one taking a key from
// its holder included -- is undone by one button.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.kde
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // `switcher status --json`, parsed. Null until the first read returns.
    property var switcherState: null
    property string status: ""
    property bool busy: false

    readonly property var layouts: root.switcherState?.layouts ?? []
    readonly property var keys: root.switcherState?.keys ?? []

    spacing: 10

    Component.onCompleted: root.refresh()

    function refresh() {
        readProc.running = false;
        readProc.running = true;
    }

    function run(args) {
        if (root.busy)
            return;
        root.status = "";
        runProc.command = [Branding.ctlBin, "switcher"].concat(args);
        runProc.running = true;
    }

    // Who holds a key, said in a sentence rather than as a component id.
    function describe(k) {
        const others = (k.holders ?? []).filter(h => !(h.group === "kwin" && h.action === k.kwinAction));
        const who = others.map(h => h.name ? `${h.group} (${h.name})` : h.group).join(", ");
        const kwins = k.id === "alt-tab" ? "KWin's window switcher" : "KWin's Overview";
        if (k.kwin && others.length === 0)
            return `${kwins}.`;
        if (k.kwin)
            return `${kwins}, but ${who} claims it too, and which of them gets it is down to chance.`;
        if (others.length === 0)
            return "Nothing is bound to it.";
        return `Held by ${who}. Giving it to ${kwins} takes it from them; undo gives it back.`;
    }

    readonly property Process _read: Process {
        id: readProc
        command: [Branding.ctlBin, "switcher", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.switcherState = JSON.parse(text);
                } catch (e) {
                    root.status = "Could not read the window switcher's settings.";
                    Log.warn("settings", `switcher status: ${e}`);
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
                    root.status = errors.pop().replace(/^.*error:?\s*/i, "");
            }
        }
    }

    PanelText {
        text: "Alt+Tab looks like"
        font.pixelSize: 13
    }

    Flow {
        width: root.width
        spacing: 6
        enabled: !root.busy

        Repeater {
            model: root.layouts

            TextButton {
                required property var modelData

                text: modelData.name
                checked: modelData.id === (root.switcherState?.layout ?? "")
                onActivated: if (!checked) root.run(["layout", modelData.id])
            }
        }
    }

    PanelText {
        visible: root.switcherState !== null && !root.layouts.some(l => l.id === Branding.slug)
        width: root.width
        wrapMode: Text.WordWrap
        color: Theme.foregroundInactive
        font.pixelSize: 11
        text: `${Branding.displayName}'s own switcher, in the panel's colours, is installed by "theme apply" and is not installed yet.`
    }

    Repeater {
        model: root.keys

        SettingRow {
            id: keyRow

            required property var modelData

            width: root.width
            enabled: !root.busy
            label: `${keyRow.modelData.key}: ${keyRow.modelData.label.toLowerCase()}`
            description: root.describe(keyRow.modelData)

            TextButton {
                visible: !keyRow.modelData.kwin || keyRow.modelData.holders.length > 1
                text: "Give it to KWin"
                onActivated: root.run(["give", keyRow.modelData.id])
            }
        }
    }

    Row {
        spacing: 8
        enabled: !root.busy

        TextButton {
            visible: root.switcherState?.customised ?? false
            iconName: "edit-undo"
            text: "Undo everything set here"
            onActivated: root.run(["revert"])
        }

        // Plasma's own page has the rest: the switcher's second shortcut set,
        // which windows it lists, the order they come in.
        TextButton {
            iconName: "configure"
            text: "Plasma's task switcher settings"
            onActivated: PlasmaApplets.openSettings("kcm_kwintabbox")
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "view-refresh"
            onActivated: root.refresh()
        }
    }

    PanelText {
        visible: root.status.length > 0
        width: root.width
        wrapMode: Text.WordWrap
        text: root.status
        font.pixelSize: 11
    }
}
