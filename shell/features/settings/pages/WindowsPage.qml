pragma ComponentBehavior: Bound

// Windows: what KWin does with them.
//
// Nothing here is this shell's own behaviour -- KWin decides how focus is
// given, when a window is raised and where a new one lands, and it has kept
// those settings in kwinrc for twenty years. This page reads and writes them
// through `rmpr windows behaviour`, so every change is ledgered and
// `revert` puts the desktop back.
//
// What the mockup showed and KWin does not have -- window gaps, rounded
// window corners, a tiling layout of its own -- is not offered. Saying so is
// more use than a control that writes a key nothing reads.

import QtQuick
import qs.platform.kde
import qs.platform.system
import qs.domain.theme
import qs.domain.windows
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // `windows behaviour status --json`, and the command that changes it.
    readonly property CtlSession ctl: CtlSession {
        prefix: ["windows", "behaviour"]
        readFailed: "Could not read KWin's window settings."
        logLabel: "windows behaviour"
    }

    readonly property var settings: root.ctl.state?.settings ?? []
    readonly property var tilingScripts: root.ctl.state?.tilingScripts ?? []

    function valueOf(id, fallback) {
        return (root.settings.find(s => s.id === id)?.value) ?? fallback;
    }

    function boolOf(id) { return String(root.valueOf(id, "false")) === "true"; }
    function numberOf(id, fallback) { return Number(root.valueOf(id, fallback)); }

    spacing: 14

    Component.onCompleted: root.ctl.refresh()

    function set(id, value) {
        root.ctl.run(["set", id, value]);
    }

    Hint {
        visible: root.ctl.status.length > 0
        text: root.ctl.status
        tone: "error"
        lineHeight: 1
    }

    Card {
        width: root.width

        SectionLabel { text: "Focus" }

        Segmented {
            width: parent.width
            values: ["ClickToFocus", "FocusFollowsMouse", "FocusStrictlyUnderMouse"]
            labels: ["Click to focus", "Follows the mouse", "Strictly under the mouse"]
            current: root.valueOf("focus", "ClickToFocus")
            onPicked: value => root.set("focus", value)
        }

        Hint {
            text: "Strictly under the mouse gives focus to nothing at all when the pointer is over the desktop."
        }

        SliderRow {
            visible: root.valueOf("focus", "ClickToFocus") !== "ClickToFocus"
            label: "Wait before following"
            unit: "ms"
            from: 0
            to: 3000
            stepSize: 50
            value: root.numberOf("focusDelay", 300)
            onMoved: value => root.set("focusDelay", Math.round(value))
        }

        ToggleRow {
            label: "Raise the window under the pointer"
            description: "KWin's auto-raise, which needs focus to follow the mouse to do anything."
            enabled: root.valueOf("focus", "ClickToFocus") !== "ClickToFocus"
            checked: root.boolOf("autoRaise")
            onToggled: value => root.set("autoRaise", value)
        }

        SliderRow {
            visible: root.boolOf("autoRaise")
            label: "Wait before raising"
            unit: "ms"
            from: 0
            to: 3000
            stepSize: 50
            value: root.numberOf("autoRaiseDelay", 750)
            onMoved: value => root.set("autoRaiseDelay", Math.round(value))
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "New windows" }

        Segmented {
            width: parent.width
            values: ["Centered", "Smart", "Maximizing", "UnderMouse"]
            labels: ["Centred", "Least overlap", "Maximised", "Under the mouse"]
            current: root.valueOf("placement", "Centered")
            onPicked: value => root.set("placement", value)
        }

        // KWin calls it Smart, and it is the one that surprises: measured
        // here, with the screen full of large windows, every new window went
        // to the bottom right corner.
        Hint {
            text: "Least overlap puts a new window where it covers the fewest others -- which, on a screen already full of large windows, is a corner."
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Decoration" }

        ToggleRow {
            label: "No border when maximised"
            description: "A maximised window loses its frame and gives the room back to the window."
            checked: root.boolOf("borderlessMaximized")
            onToggled: value => root.set("borderlessMaximized", value)
        }

        Hint {
            text: "Title bars, their buttons and the corner radius belong to the window decoration, which is Plasma's own page and applies to every application."
        }

        TextButton {
            glyph: "top_panel_close"
            iconName: "preferences-system-windows"
            text: "Window decorations…"
            onActivated: PlasmaApplets.openSettings("kcm_kwindecoration")
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Tiling" }

        Hint {
            text: root.tilingScripts.length > 0
                ? `A tiling script is running: ${root.tilingScripts.join(", ")}. It arranges windows itself, and a window dragged to an edge may go to it rather than to KWin's snapping.`
                : "KWin has no tiling layouts of its own: it has snapping at the edges, and custom tiles under Meta+T. Gaps between windows and rounded window corners come from a tiling script, not from a shell, so nothing here pretends to set them."
        }

        TextButton {
            glyph: "tune"
            iconName: "preferences-system-windows-actions"
            text: "Plasma's window behaviour…"
            onActivated: PlasmaApplets.openSettings("kcm_kwinoptions")
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Open windows" }

        Item {
            width: parent.width
            height: 22

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: WindowsService.available ? "Windows the shell can see" : "The window list is not running"
                font.pixelSize: 13
            }

            PanelText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: `${WindowsService.windows.length}`
                font.family: Theme.monoFamily
                font.pixelSize: 13
                color: Theme.mut
            }
        }

        Hint {
            visible: !WindowsService.available
            text: "The task list and the window title need a small KWin script, which `rmpr windows enable` installs."
        }
    }
}
