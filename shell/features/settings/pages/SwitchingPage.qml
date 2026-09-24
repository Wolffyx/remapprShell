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
import qs.core
import qs.platform.system
import qs.domain.config
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    // `switcher status --json`, and the command that changes it.
    readonly property CtlSession ctl: CtlSession {
        prefix: ["switcher"]
        readFailed: "Could not read the window switcher's settings."
    }
    readonly property var switcherState: root.ctl.state

    readonly property var layouts: root.switcherState?.layouts ?? []

    // Read from configuration rather than from `switcher status`: these are
    // this shell's own settings, and the shell already has them.
    readonly property string drawnByWindows: ConfigStore.value("switching.windows", "plasma")
    readonly property string drawnByDesktops: ConfigStore.value("switching.desktops", "plasma")
    readonly property var keys: root.switcherState?.keys ?? []

    Component.onCompleted: root.ctl.refresh()

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

    // Who draws each of the two, which is a different question from who holds
    // the key: the setting says which is drawn, and the command moves the key
    // to match, because an overview nobody can open is not a choice.
    Card {
        id: drawnBy

        width: root.cellWidth
        spacing: 4

        SectionLabel { text: "Who draws it" }

        SettingRow {
            width: drawnBy.contentWidth
            enabled: !root.ctl.busy
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
                onPicked: value => root.ctl.run(["use", value])
            }
        }

        // Said here rather than found out. This shell's switcher is not drawn
        // by the compositor: every press of the key travels kglobalaccel, the
        // session daemon, the CLI and the IPC before anything appears, and the
        // key coming up makes the same trip separately. The two race, and a
        // fast enough Alt+Tab can still leave the switcher on screen.
        //
        // It is a real choice and it stays -- it is the only one this project
        // can restyle. But someone choosing it should know what they are
        // taking on, and KWin's is the one that ships.
        Hint {
            width: drawnBy.contentWidth
            visible: root.drawnByWindows === "shell"
            text: "Held keys are less reliable here than in KWin's. This shell is not the compositor: the key press and the key release each cross four processes to reach it, and they race. Pressed quickly, the switcher can stay on screen after the key is let go. KWin's switcher has none of that, shows a real picture of each window, and is what this shell uses unless you change it."
            tone: "error"
        }

        SettingRow {
            width: drawnBy.contentWidth
            enabled: !root.ctl.busy
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
                onPicked: value => root.ctl.run(["desktops", value])
            }
        }
    }

    Card {
        id: look

        width: root.cellWidth

        SectionLabel { text: "Alt+Tab looks like" }

        Flow {
            width: look.contentWidth
            spacing: 6
            enabled: !root.ctl.busy

            Repeater {
                model: root.layouts

                TextButton {
                    required property var modelData

                    text: modelData.name
                    checked: modelData.id === (root.switcherState?.layout ?? "")
                    onActivated: if (!checked) root.ctl.run(["layout", modelData.id])
                }
            }
        }

        Hint {
            visible: root.switcherState !== null && !root.layouts.some(l => l.id === Branding.slug)
            width: look.contentWidth
            text: `${Branding.displayName}'s own switcher, in the panel's colours, is installed by "theme apply" and is not installed yet.`
        }
    }

    // The overview's own behaviour. Only ours has any: KWin's Overview is
    // compiled into KWin and takes no settings from anybody.
    Card {
        id: overviewCard

        width: root.cellWidth
        spacing: 4
        opacity: root.drawnByDesktops === "shell" ? 1 : 0.45
        enabled: root.drawnByDesktops === "shell"

        SectionLabel { text: "The desktop overview" }

        ConfigToggleRow {
            width: overviewCard.contentWidth
            label: "Closes when the key is released"
            description: "Held, like Alt+Tab. Off, one press opens it and it stays until you choose, press Escape or click away."
            path: "switching.overviewHold"
        }

        ConfigToggleRow {
            width: overviewCard.contentWidth
            label: "Window titles"
            description: "The title strip along the top of each card."
            path: "switching.overviewTitles"
        }

        ConfigToggleRow {
            width: overviewCard.contentWidth
            label: "List minimised windows"
            description: "Off lists only what is on screen."
            path: "switching.overviewMinimised"
        }

        ConfigToggleRow {
            width: overviewCard.contentWidth
            label: "The desktop strip"
            description: "Every desktop along the bottom, with what is on each and a tile for one more."
            path: "switching.overviewStrip"
        }

        ConfigSliderRow {
            width: overviewCard.contentWidth
            label: "Widest a window card gets"
            from: 260
            to: 720
            stepSize: 20
            unit: "px"
            path: "switching.overviewCardWidth"
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

                width: keyCard.contentWidth
                enabled: !root.ctl.busy
                label: `${keyRow.modelData.key}: ${keyRow.modelData.label.toLowerCase()}`
                description: root.describe(keyRow.modelData)

                TextButton {
                    visible: !keyRow.modelData.kwin || keyRow.modelData.holders.length > 1
                    text: "Give it to KWin"
                    onActivated: root.ctl.run(["give", keyRow.modelData.id])
                }
            }
        }

        // Plasma's own page has the rest: the switcher's second shortcut
        // set, which windows it lists, the order they come in.
        UndoFooter {
            spacing: keyCard.spacing
            session: root.ctl
            customised: root.switcherState?.customised ?? false
            settingsModule: "kcm_kwintabbox"
            settingsText: "Plasma's task switcher settings"
        }
    }
}
