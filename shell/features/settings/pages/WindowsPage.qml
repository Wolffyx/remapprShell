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
// window corners -- is not offered. Saying so is more use than a control
// that writes a key nothing reads. Snap layouts are offered because the
// zones are KWin's own tiles: only the panel to pick them from is ours
// (kwin/snap).

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

        // A window rule rather than a kwinrc key, but the same kind of
        // setting: KWin's own behaviour, through `windows behaviour`. See
        // placeGames in scripts/windows.sh for why it exists.
        ToggleRow {
            label: "Place Steam games like other windows"
            description: "Games run through Proton often ask for a spot of their own -- World of Tanks' launcher asks for the middle of everything the screens span, which can be the edge of one of them. A KWin window rule has KWin ignore that. From the next window a game opens."
            checked: root.boolOf("placeGames")
            onToggled: value => root.set("placeGames", value)
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

        ToggleRow {
            label: "Snap layouts"
            description: "Drag a window toward the top of a screen and a panel of layouts opens there; let it go over a zone and the window takes that zone. The zones are KWin's own tiles, the ones Meta+T edits, so a window dragged out of one gets its size back."
            checked: root.boolOf("snapLayouts")
            onToggled: value => root.set("snapLayouts", value)
        }

        Segmented {
            visible: root.boolOf("snapLayouts")
            width: parent.width
            values: ["top", "drag"]
            labels: ["When the window nears the top", "As soon as a window is dragged"]
            current: root.valueOf("snapReveal", "top")
            onPicked: value => root.set("snapReveal", value)
        }

        ToggleRow {
            visible: root.boolOf("snapLayouts")
            label: "Snap Assist"
            description: "Once a window is snapped into a layout with zones still empty, the other windows on that screen are offered for the next one. Click one, or choose it with the arrow keys and Enter; Esc or a click anywhere else puts it away."
            checked: root.boolOf("snapAssist")
            onToggled: value => root.set("snapAssist", value)
        }

        ToggleRow {
            visible: root.boolOf("snapLayouts")
            label: "Meta+Z opens the layouts"
            description: "The same panel for the active window, with no drag: click a zone, or move between zones with the arrow keys and press Enter -- or press a layout's number and then a zone's. The key itself can be changed on the Shortcuts page."
            checked: root.boolOf("snapKey")
            onToggled: value => root.set("snapKey", value)
        }

        ToggleRow {
            label: "Auto-tiling"
            description: root.tilingScripts.length > 0
                ? `Off while ${root.tilingScripts.join(", ")} is enabled: two tiling scripts would undo each other at every window that opens.`
                : "Every window is tiled as it opens, as Hyprland's dwindle layout does: each new one takes half of the focused window, split along its longer side. Dialogs and windows of one size float. Snap layouts step aside while it is on."
            checked: root.boolOf("autoTile")
            enabled: root.boolOf("autoTile") || root.tilingScripts.length === 0
            onToggled: value => root.set("autoTile", value)
        }

        Hint {
            visible: root.boolOf("autoTile")
            text: "Meta+Alt and an arrow moves the focus that way, with Shift it moves the window, with Ctrl it swaps the two. Meta+Alt+Space floats the active window or tiles it again, and Meta+Alt+T turns tiling off or on for this desktop. The keys can be changed on the Shortcuts page."
        }

        SliderRow {
            label: "Gap around tiled windows"
            from: 0
            to: 64
            stepSize: 1
            value: root.numberOf("tileGap", 4)
            onMoved: value => root.set("tileGap", Math.round(value))
        }

        Hint {
            text: "Between tiled windows and at the screen's edges, on every screen and desktop. 0 puts tiled windows edge to edge and against the panel; KWin's own is 4."
        }

        Hint {
            text: root.tilingScripts.length > 0
                ? `A tiling script is running: ${root.tilingScripts.join(", ")}. It arranges windows itself, and a window dragged to an edge or into a layout may go to it instead.`
                : "KWin also snaps a window dragged to a screen edge, and Shift while dragging shows the screen's tiles."
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
