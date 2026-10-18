pragma ComponentBehavior: Bound

// Tiling: every way a window is put into one of KWin's tiles, on a page of
// its own -- it grew past a card on the Windows page with auto-tiling.
//
// Auto-tiling (kwin/tile), snap layouts (kwin/snap) and the gap around a
// tiled window. All three are KWin's own tiles, the ones Meta+T edits: the
// scripts only decide which tile a window goes to. Read and written through
// `rmpr windows behaviour`, as the Windows page's settings are, so every
// change is ledgered and `revert` puts the desktop back.

import QtQuick
import Quickshell
import qs.core
import qs.platform.kde
import qs.platform.system
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // Opens another section of the settings window, by its id: the keys
    // live on the Shortcuts page.
    property var openPage: null

    readonly property CtlSession ctl: CtlSession {
        prefix: ["windows", "behaviour"]
        readFailed: "Could not read KWin's tiling settings."
        logLabel: "windows behaviour"
    }

    readonly property var settings: root.ctl.state?.settings ?? []
    readonly property var tilingScripts: root.ctl.state?.tilingScripts ?? []
    readonly property bool otherTiler: root.tilingScripts.length > 0

    function valueOf(id, fallback) {
        return (root.settings.find(s => s.id === id)?.value) ?? fallback;
    }

    function boolOf(id) { return String(root.valueOf(id, "false")) === "true"; }
    function numberOf(id, fallback) { return Number(root.valueOf(id, fallback)); }

    function set(id, value) {
        root.ctl.run(["set", id, value]);
    }

    spacing: 14

    Component.onCompleted: root.ctl.refresh()

    Hint {
        visible: root.ctl.status.length > 0
        text: root.ctl.status
        tone: "error"
        lineHeight: 1
    }

    Hint {
        visible: root.otherTiler
        text: `A tiling script is running: ${root.tilingScripts.join(", ")}. It arranges windows itself, so auto-tiling stays off, and a window dragged to an edge or into a layout may go to it instead.`
        tone: "error"
    }

    Card {
        width: root.width

        SectionLabel { text: "Auto-tiling" }

        ToggleRow {
            label: "Tile every window as it opens"
            description: "As Hyprland does. Dialogs and windows of one size float. Snap layouts step aside while it is on."
            checked: root.boolOf("autoTile")
            enabled: root.boolOf("autoTile") || !root.otherTiler
            onToggled: value => root.set("autoTile", value)
        }

        Segmented {
            width: parent.width
            values: ["dwindle", "master"]
            labels: ["Dwindle", "Master and stack"]
            current: root.valueOf("autoTileLayout", "dwindle")
            onPicked: value => root.set("autoTileLayout", value)
        }

        Hint {
            text: root.valueOf("autoTileLayout", "dwindle") === "master"
                ? "The first window on the left, every other one in a column beside it. A window that closes gives its place to the next."
                : "Each new window takes part of the focused one, split along its longer side. A window that closes gives its part back."
        }

        SliderRow {
            label: root.valueOf("autoTileLayout", "dwindle") === "master" ? "Master's share of the width" : "New window's share of the split"
            unit: "%"
            from: 20
            to: 80
            stepSize: 5
            value: root.numberOf("autoTileRatio", 50)
            onMoved: value => root.set("autoTileRatio", Math.round(value))
        }

        SliderRow {
            label: "Most windows tiled on a screen"
            unit: ""
            from: 0
            to: 16
            stepSize: 1
            value: root.numberOf("autoTileMax", 0)
            onMoved: value => root.set("autoTileMax", Math.round(value))
        }

        Hint {
            text: "0 tiles as many as fit: KWin makes no tile smaller than 15% of the screen either way, which is 16 in dwindle and a column of 6 beside the master. A window past the limit floats until a tiled one closes."
        }

        Hint {
            visible: root.boolOf("autoTile")
            text: "Meta+Alt and an arrow moves the focus that way, with Shift it moves the window, with Ctrl it swaps the two. Meta+Alt+Space floats the active window or tiles it again, and Meta+Alt+T turns tiling off or on for this desktop."
        }

        TextButton {
            visible: root.boolOf("autoTile") && root.openPage !== null
            glyph: "keyboard"
            iconName: "preferences-desktop-keyboard-shortcut"
            text: "Change the keys…"
            onActivated: root.openPage("shortcuts")
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Snap layouts" }

        ToggleRow {
            label: "Snap layouts"
            description: "Drag a window toward the top of a screen and a panel of layouts opens there; let it go over a zone and the window takes that zone. A window dragged out of one gets its size back."
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
            description: "The same panel for the active window, with no drag: click a zone, or move between zones with the arrow keys and press Enter -- or press a layout's number and then a zone's."
            checked: root.boolOf("snapKey")
            onToggled: value => root.set("snapKey", value)
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Gaps" }

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
    }

    Card {
        width: root.width

        SectionLabel { text: "KWin's own" }

        Hint {
            text: "KWin also snaps a window dragged to a screen edge, and Shift while dragging shows the screen's tiles. Its tile editor draws a screen's tiles by hand; a layout made there is offered first in the snap layouts panel."
        }

        TextButton {
            glyph: "dashboard"
            iconName: "view-grid"
            text: "Edit the tiles (Meta+T)…"
            onActivated: Quickshell.execDetached([Paths.ctlBin, "windows", "tile", "edit"])
        }

        TextButton {
            glyph: "tune"
            iconName: "preferences-system-windows-actions"
            text: "Plasma's window behaviour…"
            onActivated: PlasmaApplets.openSettings("kcm_kwinoptions")
        }
    }
}
