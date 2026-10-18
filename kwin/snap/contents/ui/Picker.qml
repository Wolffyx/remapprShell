/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Choosing a zone without a drag: the panel of layouts opened by Meta+Z
    for the active window, and Snap Assist, which once a window is snapped
    into a layout with zones still empty offers the screen's other windows
    for the first of them -- after a drag, after Meta+Z, and after each
    window it places, until the layout is full or it is put away.

    Both are shown in the chooser window (Chooser.qml), which takes clicks
    and keys. The screen, its layouts and the placing itself are main.qml's,
    reached through `host`.
*/

// KWin's types live in its own process and cannot be resolved by the linter.
// qmllint disable unqualified
import QtQuick
import org.kde.kwin
import "layouts.js" as Layouts

Item {
    id: picker

    // main.qml: the screen (`output`, `area`, `layouts`, `arrangement`,
    // `current`), the panel's measures, and `snap`.
    required property var host
    // Snap Assist, unless `rmpr windows behaviour` has turned it off.
    property bool assistOn: true

    // The KWin action Meta+Z reaches this script by. The key is this
    // project's own (scripts/lib/shortcut-actions.tsv, `snap`), held by the
    // session daemon as every key of ours is, and pressing it runs `windows
    // snap pick` -- which invokes this through kglobalaccel. A script can call
    // D-Bus and never be called; an action of KWin's is the way in. The same
    // name is in scripts/lib/windows/snap.sh.
    readonly property string pickAction: "Snap Layouts: Active Window"

    // Snap Assist's measures: the widest a window's cell grows, the gap
    // between cells and around them, the line for its title, and the shape
    // of its picture.
    readonly property var metrics: ({ cell: 300, gap: 18, pad: 28, label: 28, aspect: 16 / 10 })

    // The keys both answer, besides the digits.
    readonly property var arrows: ({ [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
                                     [Qt.Key_Up]: "up", [Qt.Key_Down]: "down" })
    readonly property var confirms: [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space]

    // What the chooser shows: "layouts" (Meta+Z), "assist", or "".
    property string mode: ""
    property var subject: null         // the window Meta+Z is placing
    property var hover: null           // its zone so far, { layout, zone }
    property int armed: -1             // the layout chosen by its number
    property var assistLayout: null    // the layout Snap Assist is filling
    property var assistTaken: []       // for each of its zones, whether it is filled
    property int assistZone: -1        // the zone it is filling
    property var offered: []           // the windows offered for it
    property int selected: -1          // the one chosen so far

    readonly property var target: picker.hover
        ? Layouts.place(picker.host.layouts[picker.hover.layout].zones[picker.hover.zone], picker.host.area) : null
    // Snap Assist's zones and cells, in the chooser's own pixels.
    readonly property var assistZones: picker.assistLayout
        ? picker.assistLayout.zones.map(z => picker.local(Layouts.place(z, picker.host.area))) : []
    readonly property var assistCells: picker.assistZone >= 0 && picker.assistZones.length > 0
        ? Layouts.grid(picker.offered.length, picker.assistZones[picker.assistZone], picker.metrics).cells : []

    function local(r) {
        return Layouts.rect(r.x - picker.host.area.x, r.y - picker.host.area.y, r.width, r.height);
    }

    function open(mode) {
        picker.mode = mode;
        chooser.open();
    }

    // Everything the chooser was showing let go of, and the window hidden.
    // KWin hides it too, for a click outside it, and that comes back here.
    function close() {
        picker.mode = "";
        picker.subject = null;
        picker.hover = null;
        picker.armed = -1;
        picker.assistLayout = null;
        picker.assistZone = -1;
        picker.offered = [];
        picker.selected = -1;
        chooser.close();
    }

    // A window gone while it was being placed or offered.
    function forget(w) {
        if (w === picker.subject)
            picker.close();
        if (!picker.offered.includes(w))
            return;
        picker.offered = picker.offered.filter(o => o !== w);
        picker.selected = Math.min(picker.selected, picker.offered.length - 1);
        if (picker.offered.length === 0)
            picker.close();
    }

    // After a window is snapped: Snap Assist, if there is anything to offer,
    // and the chooser put away if not.
    function followUp(layout) {
        if (!picker.offerAssist(layout))
            picker.close();
    }

    // ---- Meta+Z ------------------------------------------------------------

    // The panel for the active window, with no drag. Pressed again while the
    // chooser is up, it puts it away.
    function pickActive() {
        if (picker.mode !== "") {
            picker.close();
            return;
        }
        const w = Workspace.activeWindow;
        if (picker.host.dragged !== null || !picker.host.snappable(w))
            return;
        picker.host.settle(w.output);
        picker.subject = w;
        picker.hover = null;
        picker.armed = -1;
        picker.open("layouts");
    }

    // A zone chosen on that panel: the window goes there, and Snap Assist
    // follows, as it does after a drag.
    function place(hit) {
        const w = picker.subject;
        const layout = picker.host.layouts[hit.layout];
        picker.subject = null;
        picker.host.snap(w, layout, layout.zones[hit.zone]);
        picker.followUp(layout);
    }

    // The arrows move between zones, across cards as they lie; a digit
    // chooses a layout by its number and then a zone of it by its own, as
    // Windows has it; Enter or Space takes the zone; Escape closes.
    function layoutsKey(key) {
        const digit = key - Qt.Key_1;
        if (digit >= 0 && digit < 9)
            return picker.pickDigit(digit);
        const direction = picker.arrows[key];
        if (direction)
            return picker.stepZone(direction);
        if (picker.confirms.includes(key) && picker.hover)
            return picker.place(picker.hover);
        if (key === Qt.Key_Escape)
            picker.close();
    }

    function pickDigit(n) {
        const layouts = picker.host.layouts;
        if (picker.armed < 0 && n < layouts.length) {
            picker.armed = n;
            picker.hover = { layout: n, zone: 0 };
            return;
        }
        if (picker.armed >= 0 && n < layouts[picker.armed].zones.length)
            picker.place({ layout: picker.armed, zone: n });
    }

    // The first arrow starts on the layout the tiles make now, or the first.
    function stepZone(direction) {
        const list = Layouts.zoneList(picker.host.arrangement);
        const at = picker.hover ? list.findIndex(z => Layouts.sameHit(z, picker.hover)) : -1;
        const next = at >= 0 ? list[Layouts.nearest(list.map(z => z.rect), at, direction)]
                             : list.find(z => z.layout === Math.max(0, picker.host.current));
        picker.hover = { layout: next.layout, zone: next.zone };
        picker.armed = -1;
    }

    function zoneAt(x, y) {
        const area = picker.host.area;
        return picker.host.zoneAt(Qt.point(area.x + x, area.y + y), chooser, flyout);
    }

    // ---- Snap Assist -------------------------------------------------------

    // The windows on the screen in front that a zone could be given, the one
    // on top first.
    function screenWindows() {
        const desk = Workspace.currentDesktop;
        const screen = picker.host.output;
        const onDesktop = w => w.onAllDesktops === true || Array.from(w.desktops || []).some(d => d.id === desk.id);
        return Array.from(Workspace.stackingOrder).reverse()
            .filter(w => picker.host.snappable(w) && !!w.output && w.output.name === screen.name && onDesktop(w));
    }

    // For each zone of a layout, the window in it now, or null: one in its
    // tile, or where KWin has no tiles, one at its place. A minimised window
    // is in none -- its zone shows empty, and it is offered for it.
    function occupants(layout, screen) {
        const top = picker.host.rootTile(picker.host.output);
        return layout.zones.map(zone => {
            const leaf = top ? Layouts.leafFor(top, zone) : null;
            const inside = leaf ? Layouts.windowsIn(leaf, screen) : [];
            const box = Layouts.place(zone, picker.host.area);
            return screen.find(w => w.minimized !== true
                && (leaf ? inside.includes(w) : Layouts.matches(w.frameGeometry, box, 2))) || null;
        });
    }

    // The screen's other windows, offered for the first empty zone of a
    // layout a window was just snapped into. False when Snap Assist is off,
    // or there is no empty zone or no window to offer.
    function offerAssist(layout) {
        if (!picker.assistOn)
            return false;
        const screen = picker.screenWindows();
        const taken = picker.occupants(layout, screen);
        const zone = taken.indexOf(null);
        const offered = zone < 0 ? [] : screen.filter(w => !taken.includes(w));
        if (offered.length === 0)
            return false;
        picker.assistLayout = layout;
        picker.assistTaken = taken.map(w => w !== null);
        picker.assistZone = zone;
        picker.offered = offered;
        picker.selected = 0;
        picker.open("assist");
        return true;
    }

    // An offered window into the zone, made the active one, and on to the
    // next empty zone.
    function choose(i) {
        const w = picker.offered[i];
        const layout = picker.assistLayout;
        if (w.minimized === true)
            w.minimized = false;
        picker.host.snap(w, layout, layout.zones[picker.assistZone]);
        Workspace.activeWindow = w;
        picker.followUp(layout);
    }

    function assistKey(key) {
        const direction = picker.arrows[key];
        if (direction) {
            picker.selected = Layouts.nearest(picker.assistCells, picker.selected, direction);
            return;
        }
        if (picker.confirms.includes(key) && picker.selected >= 0)
            return picker.choose(picker.selected);
        if (key === Qt.Key_Escape)
            picker.close();
    }

    function cellAt(x, y) {
        return picker.assistCells.findIndex(c => Layouts.inside(c, x, y, 6));
    }

    // ---- the pointer -------------------------------------------------------

    function pointerMoved(x, y) {
        if (picker.mode === "assist") {
            const i = picker.cellAt(x, y);
            if (i >= 0)
                picker.selected = i;
            return;
        }
        const hit = picker.zoneAt(x, y);
        if (!Layouts.sameHit(hit, picker.hover))
            picker.hover = hit;
    }

    // A click on a zone or a window takes it; one anywhere else, or with any
    // other button, puts the chooser away.
    function pointerClicked(x, y, button) {
        if (button !== Qt.LeftButton)
            return picker.close();
        if (picker.mode === "assist")
            return picker.chooseAt(picker.cellAt(x, y));
        const hit = picker.zoneAt(x, y);
        if (!hit)
            return picker.close();
        picker.place(hit);
    }

    function chooseAt(i) {
        if (i < 0)
            return picker.close();
        picker.choose(i);
    }

    // ShortcutHandler is made at run time, so that a KWin without it loads
    // the rest of the script and only Meta+Z does nothing.
    function listen() {
        try {
            const handler = Qt.createQmlObject(`import org.kde.kwin; ShortcutHandler {
                name: "${picker.pickAction}"; text: "Snap layouts: a zone for the active window"; sequence: "" }`,
                picker, "pickAction");
            handler.activated.connect(picker.pickActive);
        } catch (e) {
            console.warn(`snap layouts: this KWin has no ShortcutHandler, so no key opens them (${e})`);
        }
    }

    Connections {
        target: Workspace
        enabled: picker.mode !== ""

        function onCurrentDesktopChanged() {
            picker.close();
        }
    }

    Component.onCompleted: picker.listen()

    // The panel numbered, or Snap Assist, in a window that takes clicks and
    // keys -- which the drag's panel cannot, and need not. Chooser.qml says
    // how it is made so that it can.
    Chooser {
        id: chooser

        area: picker.host.area
        onPointerMoved: (x, y) => picker.pointerMoved(x, y)
        onPointerClicked: (x, y, button) => picker.pointerClicked(x, y, button)
        onKeyPressed: key => picker.mode === "assist" ? picker.assistKey(key) : picker.layoutsKey(key)
        onVisibleChanged: {
            if (!chooser.visible && picker.mode !== "")
                picker.close();
        }

        Preview {
            area: picker.host.area
            target: picker.mode === "layouts" ? picker.target : null
        }

        Flyout {
            id: flyout

            visible: picker.mode === "layouts"
            x: Math.round((chooser.width - flyout.implicitWidth) / 2)
            y: picker.host.topGap - flyout.shadowPad
            width: flyout.implicitWidth
            height: flyout.implicitHeight
            arrangement: picker.host.arrangement
            hover: picker.hover
            current: picker.host.current
            revealed: true
            numbered: true
            armed: picker.armed
        }

        Assist {
            anchors.fill: parent
            visible: picker.mode === "assist"
            zones: picker.assistZones
            taken: picker.assistTaken
            target: picker.assistZone
            offered: picker.offered
            cells: picker.assistCells
            selected: picker.selected
            label: picker.metrics.label
        }
    }
}
