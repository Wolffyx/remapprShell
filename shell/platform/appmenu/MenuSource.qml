// The application menu of the window in front, where the compositor and the
// application will give one -- what the global menu widget draws.
//
// `KdeAppMenu` is this project's compiled part (plugin/, `make plugin`): it
// knows which menu is whose through KWin's window-management protocol, and
// reads the menu over DBus. Loaded by name rather than imported by the widget
// -- see widgets/appmenu/Widget.qml -- so a shell without the plugin draws the
// application's name and nothing else instead of failing to load the widget.
// Everything that can be missing is in this file.
//
// While this exists it asks for applications' menus (ActiveWindowMenu.acquire):
// KDE applications move their menu bar from the window into the panel, and
// put it back when the last global menu goes.

import QtQuick
import KdeAppMenu

Item {
    id: root

    // [{ id, label, enabled, separator, toggle, checked, shortcut, icon,
    //    submenu, children }], top level first. See plugin/src/dbusmenu.h.
    readonly property var items: menu.items
    readonly property bool supported: ActiveWindowMenu.supported
    readonly property string appId: ActiveWindowMenu.appId
    readonly property string title: ActiveWindowMenu.title

    function activate(id) { menu.activate(id); }
    function aboutToShow(id) { menu.aboutToShow(id); }

    DBusMenuModel {
        id: menu
        service: ActiveWindowMenu.service
        path: ActiveWindowMenu.path
    }

    Component.onCompleted: ActiveWindowMenu.acquire()
    Component.onDestruction: ActiveWindowMenu.release()
}
