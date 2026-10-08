import QtQuick
import Quickshell
import qs.domain.sidebar
import qs.domain.surfaces
import qs.features.overlays

// The sidebar's edge: the grip, a pull, and the ways it opens and closes.
// A "screen" the size of the picture, a stand-in scrollbar down its right
// edge, the handle on that edge and the sidebar clipped to it.
//
// PREVIEW_STATE:
//   grip     pushed into at y 300: the grip lit there, and nowhere else
//   pull     pulled 45% of the way out, the pointer still down
//   closing  pulled a third of the way, then let go short: back to its edge
//   stays    pulled half way and let go: all the way out
//   edge     opened from the edge, the pointer never arriving: closes itself
//   toggle   opened, closed, reopened mid-slide
//   rest     the pointer at rest against a shared side: the grip lit there
//   rest-left  ... and gone again before it counted: nothing lit
//
// What each ends as is logged ("preview report"), and the picture is of the
// end -- so the ones that close are pictures of nothing but the scrollbar.
Stage {
    id: stage

    readonly property string state_: Quickshell.env("PREVIEW_STATE") || "grip"

    Item {
        id: screenArea
        anchors.fill: parent
        clip: true

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 14
            color: "#55606a"
            Rectangle { y: 260; width: parent.width; height: 160; radius: 7; color: "#a0aab4" }
        }

        SidebarHandle {
            id: handle
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        // As ShellScreens has it: there while Surfaces says so.
        Loader {
            id: sidebar
            active: stage.state_ !== "grip" && Surfaces.sidebar
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 16
            anchors.bottomMargin: 16
            sourceComponent: Sidebar {
                width: implicitWidth
                height: screenArea.height - 32
            }
        }
    }

    function report(what) {
        console.info(`preview ${what}: shown=${sidebar.item ? sidebar.item.shown.toFixed(2) : "gone"}`
            + ` sidebar=${Surfaces.sidebar} leaving=${Surfaces.sidebarLeaving}`
            + ` pull=${Surfaces.sidebarPull} by=${Surfaces.sidebarOpenedBy || "-"}`
            + ` grip=${handle.lit ? "lit at " + handle.gripCentre : "dark"}`);
    }

    readonly property var start: ({
        grip: () => { handle.gripY = 300; handle.pushed = true; },
        pull: () => Surfaces.pullSidebar("", 0.45),
        closing: () => { Surfaces.pullSidebar("", 0.3); later.run(400, () => Surfaces.releaseSidebar(false)); },
        stays: () => { Surfaces.pullSidebar("", 0.5); Surfaces.releaseSidebar(true); },
        edge: () => Surfaces.openSidebar("", "edge"),
        rest: () => SidebarReveal.resting("sidebar-reveal", -1, 300, "", true),
        "rest-left": () => {
            SidebarReveal.resting("sidebar-reveal", -1, 300, "", true);
            later.run(100, () => SidebarReveal.resting("sidebar-reveal", -1, 300, "", false));
        },
        toggle: () => {
            Surfaces.toggleSidebar("");
            later.run(500, () => { Surfaces.toggleSidebar(""); later.run(80, () => Surfaces.toggleSidebar("")); });
        }
    })

    Component.onCompleted: {
        const f = stage.start[stage.state_];
        if (f)
            f();
        ending.start();
    }

    Timer {
        id: later
        property var then: null
        function run(ms, f) { later.then = f; later.interval = ms; later.restart(); }
        onTriggered: {
            const f = later.then;
            later.then = null;
            if (f)
                f();
        }
    }

    Timer {
        id: ending
        interval: 1200
        onTriggered: stage.report("report")
    }
}
