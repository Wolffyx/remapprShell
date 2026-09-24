// A widget's popout where it opens: the screen, the panel along one edge of it,
// and the popout's own window beside the widget that opened it -- placed by
// the same arithmetic the real window uses (the stub EdgeWindow, placed).
//
//   PREVIEW_WIDGET     the widget whose popout is shown (tasks)
//   PREVIEW_EDGE       bottom, top, left or right (bottom)
//   PREVIEW_BAR        full, floating or islands (full)
//   PREVIEW_THICKNESS  the panel's thickness (52, this machine's)
//   PREVIEW_ZONE       the zone the widget sits in (middle)
//   PREVIEW_ALONE      1: nothing else on the panel, so a widget in the left
//                      or right zone is hard against the end of the screen
//   PREVIEW_BUTTON     the taskbar: which button the pointer rests on; -1 is
//                      the last (0)
//   PREVIEW_MOVE       the taskbar: a second button to move the pointer on to
//                      once the card has settled, and PREVIEW_MOVE_MS how long
//                      after that to take the picture (60) -- the neck caught
//                      on its way from one button to the next
//   PREVIEW_TAIL       1: hang the popout from its widget by a neck, as the
//                      taskbar's preview does, whatever the widget -- the
//                      taskbar runs along a top or bottom panel only, and
//                      this is how the neck is seen on a side one
//   PREVIEW_RUNTIME    configuration overrides, as JSON
//   PREVIEW_POPOUT     also save the popout's window alone, to this path --
//                      what a before/after comparison of one popout wants
//
// The popout is a window of its own, so it is not in the picture the harness
// takes of this one. It is photographed separately once it has settled and
// laid on top here, at the place its window would be on the screen.
//
// Run with PREVIEW_DEMO=1: the taskbar is then a fixed list of invented
// windows rather than this machine's own.

import QtQuick
import Quickshell
import qs.domain.config
import qs.features.panel
import qs.features.panel.model

Stage {
    id: stage

    readonly property string wid: Quickshell.env("PREVIEW_WIDGET") || "tasks"
    readonly property string edge: Quickshell.env("PREVIEW_EDGE") || "bottom"
    readonly property string barStyle: Quickshell.env("PREVIEW_BAR") || "full"
    readonly property int thickness: parseInt(Quickshell.env("PREVIEW_THICKNESS") || "52")
    readonly property string zone: Quickshell.env("PREVIEW_ZONE") || "middle"
    readonly property int button: parseInt(Quickshell.env("PREVIEW_BUTTON") || "0")
    readonly property string alone: Quickshell.env("PREVIEW_POPOUT") || ""
    readonly property int moveTo: parseInt(Quickshell.env("PREVIEW_MOVE") || "-1000")
    readonly property bool moves: stage.moveTo > -1000
    readonly property bool horizontal: stage.edge === "top" || stage.edge === "bottom"

    orientation: stage.horizontal ? Gradient.Horizontal : Gradient.Vertical

    Component.onCompleted: {
        const runtime = JSON.parse(Quickshell.env("PREVIEW_RUNTIME") || "{}");
        for (const k of Object.keys(runtime))
            ConfigStore.setRuntime(k, runtime[k]);
        // A few neighbours either side, so the widget is somewhere a panel
        // would have it rather than alone on an empty strip.
        const alone = Quickshell.env("PREVIEW_ALONE") === "1";
        const entries = alone ? [] : [{ id: "launcher", zone: "left" }, { id: "search", zone: "left" }];
        entries.push({ id: stage.wid, zone: stage.zone });
        for (const id of ["tray", "volume", "status", "clock"])
            if (id !== stage.wid && !alone)
                entries.push({ id: id, zone: "right" });
        ConfigStore.setRuntime("bar.entries", entries);
    }

    MockBar {
        id: mock
        position: stage.edge
        horizontal: stage.horizontal
        style: stage.barStyle
        thickness: stage.thickness
        screenObject: ({ width: stage.width, height: stage.height })
    }

    PanelSurface {
        bar: mock
        x: stage.edge === "right" ? stage.width - mock.extent : 0
        y: stage.edge === "bottom" ? stage.height - mock.extent : 0
        width: stage.horizontal ? stage.width : mock.extent
        height: stage.horizontal ? mock.extent : stage.height
    }

    // The popout's window, as it would sit on the screen.
    Image {
        id: shot
        // Set once it has opened: the window is found by walking the slot's
        // children, which nothing can bind to.
        property var win: null
        // In whole pixels, as the real window's margins are: an image laid
        // at half a pixel is drawn blurred.
        x: !win ? 0 : stage.edge === "left" ? Math.round(win.away)
            : stage.edge === "right" ? stage.width - Math.round(win.away) - win.implicitWidth
            : win.placedAlong
        y: !win ? 0 : stage.edge === "top" ? Math.round(win.away)
            : stage.edge === "bottom" ? stage.height - Math.round(win.away) - win.implicitHeight
            : win.placedAlong
    }

    function slotOf(id) {
        return PanelModel.slots.find(s => s.entry?.id === id && s.bar === mock) ?? null;
    }

    // The slot's popout window: the one EdgeWindow in it that says so.
    function popoutWindow() {
        const slot = stage.slotOf(stage.wid);
        if (!slot)
            return null;
        for (let i = 0; i < slot.data.length; i++) {
            const o = slot.data[i];
            if (typeof o?.label === "string" && o.label.startsWith("popout "))
                return o;
        }
        return null;
    }

    // The pointer resting on taskbar button `index`, the way the panel
    // reports it.
    function hoverButton(w, index) {
        const n = w.items.length;
        const i = index < 0 ? n + index : Math.min(index, n - 1);
        w.handleHover(w.centreOf(i), stage.horizontal);
    }

    function open() {
        const slot = stage.slotOf(stage.wid);
        const w = slot?.widget;
        if (!w) {
            console.warn(`preview: no '${stage.wid}' on the panel`);
            return;
        }
        if (stage.wid === "tasks") {
            if (w.items.length === 0) {
                console.warn("preview: the taskbar is empty -- run with PREVIEW_DEMO=1");
                return;
            }
            stage.hoverButton(w, stage.button);
            if (stage.moves)
                moveTimer.start();
        } else if (Quickshell.env("PREVIEW_TAIL") === "1") {
            // Pointing at its middle, as a widget that hangs its popout from
            // one point names that point.
            w.popoutTail = true;
            PanelModel.clickRequested(stage.wid, mock.screenName);
            w.requestPopout(stage.wid, (stage.horizontal ? slot.width : slot.height) / 2);
        } else if (typeof w.showOverflow === "function") {
            // The tray: a click lands on an icon, and the flyout is the
            // chevron's.
            w.showOverflow();
        } else {
            PanelModel.clickRequested(stage.wid, mock.screenName);
        }
    }

    Timer {
        // The window list arrives a moment after the widget loads.
        running: true
        interval: 500
        onTriggered: stage.open()
    }

    Timer {
        id: moveTimer
        interval: 900
        onTriggered: {
            stage.hoverButton(stage.slotOf(stage.wid).widget, stage.moveTo);
            grabTimer.interval = parseInt(Quickshell.env("PREVIEW_MOVE_MS") || "60");
            grabTimer.restart();
        }
    }

    Timer {
        id: grabTimer
        // Long enough for the popout's contents to build and its entrance to
        // finish; the harness takes its own picture after this.
        running: !stage.moves
        interval: Math.max(900, parseInt(Quickshell.env("PREVIEW_DELAY") || "2500") - 700)
        onTriggered: {
            const win = stage.popoutWindow();
            if (!win?.visible) {
                console.warn("preview: the popout did not open");
                return;
            }
            win.drawing.grabToImage(r => {
                shot.win = win;
                shot.source = r.url;
                if (stage.alone.length > 0)
                    r.saveToFile(stage.alone);
            });
        }
    }
}
