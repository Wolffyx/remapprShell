// The global menu's popout, offscreen, with a made-up File menu: entries
// with shortcuts, a tick, a separator and a submenu. The widget itself loads
// the compiled module, which asks every KDE application for its menu -- not
// something a preview should do to the desktop it runs on.
//
//   dev/preview/preview.sh dev/preview/appmenu.qml out.png 420 520 dark

import QtQuick
import qs.domain.theme
import qs.widgets.appmenu

Rectangle {
    color: Theme.s1

    QtObject {
        id: fake
        readonly property int popoutWidth: 300
        readonly property int popoutPadding: 6
        readonly property var menu: null
        readonly property var openItem: ({ id: 1, label: "File", children: [
            { id: 2, label: "New Window", enabled: true, shortcut: "Ctrl+N", children: [] },
            { id: 3, label: "New Tab", enabled: true, shortcut: "Ctrl+T", children: [] },
            { id: 4, label: "Open Recent", enabled: true, submenu: true, children: [
                { id: 41, label: "notes.md", enabled: true, children: [] } ] },
            { id: 5, separator: true, label: "", children: [] },
            { id: 6, label: "Show Hidden Files", enabled: true, toggle: "checkmark", checked: true, shortcut: "Alt+.", children: [] },
            { id: 7, label: "Print…", enabled: false, shortcut: "Ctrl+P", children: [] },
            { id: 8, separator: true, label: "", children: [] },
            { id: 9, label: "Quit", enabled: true, shortcut: "Ctrl+Q", children: [] }
        ] })
        function choose(id) {}
    }

    Rectangle {
        x: 20
        y: 20
        width: fake.popoutWidth
        height: pop.implicitHeight + 2 * fake.popoutPadding
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.out

        AppMenuPopout {
            id: pop
            x: fake.popoutPadding
            y: fake.popoutPadding
            widget: fake
        }
    }
}
