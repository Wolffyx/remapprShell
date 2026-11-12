pragma ComponentBehavior: Bound

// A global menu: the menus of the window in front -- File, Edit, View... --
// on the panel, after the application's name in bold, as a macOS menu bar
// has them.
//
// The menus come from the application itself, over DBus, through the
// compiled `KdeAppMenu` module (`make plugin`), loaded by name from
// platform/appmenu/MenuSource.qml so a shell without it draws the name alone.
// While this widget is on the panel, KDE applications move their menu bar out
// of their window and into it; take the widget off and they put it back. An
// application that keeps its own menu -- most browsers and Electron
// applications, anything that draws one of its own -- shows its name only.
//
// A click opens that menu under its title; while one is open, moving along
// the titles opens the next, as a menu bar does. A submenu opens in place,
// with the way back at its top. Choosing an entry is the application's own
// click.

import QtQuick
import qs.core
import qs.domain.theme
import qs.domain.windows
import qs.ui.primitives

BarWidget {
    id: root

    readonly property bool showAppName: root.widgetConfig?.showAppName ?? true

    readonly property var menu: source.status === Loader.Ready ? source.item : null
    readonly property var window: WindowsService.windowFor(root.screenName)
    readonly property string appName: root.window ? WindowsService.appNameFor(root.window) : (root.menu?.title ?? "")

    // The top level, without the separators some applications put there.
    readonly property var items: (root.menu?.items ?? []).filter(i => !i.separator && i.label.length > 0)

    property int hoveredIndex: -1
    property int openIndex: -1
    readonly property var openItem: root.items[root.openIndex] ?? null

    property bool _complained: false

    present: (root.showAppName && root.appName.length > 0) || root.items.length > 0

    wantsHover: true
    popoutPadding: 6
    popoutWidth: 300

    implicitWidth: row.implicitWidth + 2 * row.x
    implicitHeight: root.tileSize

    Loader {
        id: source
        source: Qt.resolvedUrl("../../platform/appmenu/MenuSource.qml")
        onStatusChanged: {
            if (source.status !== Loader.Error || root._complained)
                return;
            root._complained = true;
            Log.info("appmenu", "no global menu: the KdeAppMenu module is not installed "
                                + "(build it with `make plugin`); showing the application's name only");
        }
    }

    function centreOf(index) {
        return root.centreAlong(titles, index, false, row.x);
    }

    function open(index) {
        const item = root.items[index];
        if (!item)
            return;
        root.openIndex = index;
        root.menu.aboutToShow(item.id);
        root.popoutVisible = true;
        root.requestPopout("appmenu", root.centreOf(index));
    }

    // Moving along the titles with a menu open opens the next one.
    function handleHover(position, horizontal) {
        root.hoveredIndex = root.indexAlong(titles, position, row.spacing, false, row.x);
        if (root.popoutVisible && root.hoveredIndex >= 0 && root.hoveredIndex !== root.openIndex)
            root.open(root.hoveredIndex);
    }

    onDismissPopout: root.hoveredIndex = -1

    function handleActivate(button) {
        if (root.hoveredIndex < 0)
            return;
        if (root.popoutVisible && root.openIndex === root.hoveredIndex) {
            root.popoutVisible = false;
            return;
        }
        root.open(root.hoveredIndex);
    }

    onPopoutVisibleChanged: {
        if (!root.popoutVisible)
            root.openIndex = -1;
    }

    // Chosen: the application's click, and the menu goes.
    function choose(id) {
        root.menu?.activate(id);
        root.popoutVisible = false;
    }

    Row {
        id: row
        x: Math.round(6 * Math.max(0.7, root.unit))
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showAppName && root.appName.length > 0
            rightPadding: 8
            text: root.appName
            font.weight: Font.Bold
        }

        Repeater {
            id: titles
            model: root.items

            Item {
                id: title

                required property var modelData
                required property int index
                readonly property bool lit: title.index === root.openIndex || title.index === root.hoveredIndex

                anchors.verticalCenter: parent.verticalCenter
                width: label.implicitWidth + 16
                height: Math.max(18, root.tileSize - 8)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusOf(8)
                    color: title.index === root.openIndex ? Theme.s2 : (title.lit ? Theme.hover : "transparent")
                }

                PanelText {
                    id: label
                    anchors.centerIn: parent
                    text: title.modelData.label
                    opacity: title.modelData.enabled ? 1 : 0.45
                }
            }
        }
    }

    popout: Component {
        AppMenuPopout { widget: root }
    }
}
