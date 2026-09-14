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
import qs.domain.config
import qs.platform.kde
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    // `switcher status --json`, parsed. Null until the first read returns.
    property var switcherState: null
    property string status: ""
    property bool busy: false

    readonly property var layouts: root.switcherState?.layouts ?? []

    // Read from configuration rather than from `switcher status`: these are
    // this shell's own settings, and the shell already has them.
    readonly property string drawnByWindows: ConfigStore.value("switching.windows", "plasma")
    readonly property string drawnByDesktops: ConfigStore.value("switching.desktops", "shell")
    readonly property var keys: root.switcherState?.keys ?? []

    count: 3

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

    // Who draws each of the two, which is a different question from who holds
    // the key: the setting says which is drawn, and the command moves the key
    // to match, because an overview nobody can open is not a choice.
    Card {
        id: drawnBy

        width: root.cellWidth
        spacing: 4

        SectionLabel { text: "Who draws it" }

        SettingRow {
            width: drawnBy.width - 2 * drawnBy.padding
            enabled: !root.busy
            label: "Alt+Tab"
            description: root.drawnByWindows === "shell"
                ? `${Branding.displayName}'s own card row, drawn here. It shows each application's icon: a picture of a window is KWin's to give and it gives one only to its own switcher.`
                : "KWin's own switcher, in this shell's colours if its layout is chosen above. The only one that can show a picture of each window."
            controlWidth: 210

            Segmented {
                width: parent.width
                values: ["plasma", "shell"]
                labels: ["KWin", "This shell"]
                current: root.drawnByWindows
                onPicked: value => root.run(["use", value])
            }
        }

        SettingRow {
            width: drawnBy.width - 2 * drawnBy.padding
            enabled: !root.busy
            label: "Meta+Tab"
            description: root.drawnByDesktops === "shell"
                ? `${Branding.displayName}'s own overview: every desktop, what is open on each, and one more at the end.`
                : "KWin's Overview, which shows a real picture of every window and cannot be restyled -- it is compiled into KWin rather than shipped as a package."
            controlWidth: 210

            Segmented {
                width: parent.width
                values: ["plasma", "shell"]
                labels: ["KWin", "This shell"]
                current: root.drawnByDesktops
                onPicked: value => root.run(["desktops", value])
            }
        }
    }

    Card {
        id: look

        width: root.cellWidth

        SectionLabel { text: "Alt+Tab looks like" }

        Flow {
            width: look.width - 2 * look.padding
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
            width: look.width - 2 * look.padding
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            lineHeight: 1.35
            text: `${Branding.displayName}'s own switcher, in the panel's colours, is installed by "theme apply" and is not installed yet.`
        }
    }

    Card {
        id: keyCard

        width: root.cellWidth
        spacing: 4

        SectionLabel { text: "Who holds the key" }

        Repeater {
            model: root.keys

            SettingRow {
                id: keyRow

                required property var modelData

                width: keyCard.width - 2 * keyCard.padding
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

        Flow {
            width: keyCard.width - 2 * keyCard.padding
            spacing: 8
            enabled: !root.busy

            TextButton {
                visible: root.switcherState?.customised ?? false
                iconName: "edit-undo"
                text: "Undo everything set here"
                onActivated: root.run(["revert"])
            }

            // Plasma's own page has the rest: the switcher's second shortcut
            // set, which windows it lists, the order they come in.
            TextButton {
                iconName: "configure"
                text: "Plasma's task switcher settings"
                onActivated: PlasmaApplets.openSettings("kcm_kwintabbox")
            }

            IconButton {
                iconName: "view-refresh"
                onActivated: root.refresh()
            }
        }

        PanelText {
            visible: root.status.length > 0
            width: keyCard.width - 2 * keyCard.padding
            wrapMode: Text.WordWrap
            text: root.status
            font.pixelSize: 12
        }
    }
}
