// The search field on the panel.
//
// A field that is really a button: it opens whatever searches -- the search
// provider LauncherService resolves from `launcher.searchProvider`, KRunner
// unless told otherwise. Typing into the panel itself would need the keyboard
// on the panel, which costs every other widget a click (see Panel.qml).

import QtQuick
import qs.ui.primitives
import qs.domain.launcher

BarWidget {
    id: root

    readonly property string label: root.widgetConfig?.label ?? "Search"
    readonly property bool vertical: !(root.bar?.horizontal ?? true)

    // The panel's click reaches a widget only through its MouseArea, which
    // listens only for a widget that takes hover or has a popout.
    wantsHover: true

    tooltip: root.label.length > 0 && !root.vertical ? "" : "Search"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        LauncherService.toggle("search");
    }

    BarButton {
        id: button
        thickness: root.bar?.thickness ?? 40
        vertical: root.vertical
        hovered: root.hovered
        active: LauncherService.searchProvider.visible
        filled: true
        glyph: "search"
        fallback: "search"
        text: root.label
    }
}
