pragma ComponentBehavior: Bound

// The built-in start menu, in the three layouts the design has:
//
//   twopane  categories down a rail; pinned apps and recent files; and
//            beside them you, what is playing, the machine, and the session
//   grid     pinned apps and recent files
//   list     every application, A to Z, with an index down the side
//
// Typing anywhere searches, as the search field says; with the action prefix
// it offers the shell's actions too. The arranging is Apps' and the choosing
// the provider's -- this only draws.
//
// This file is what the layouts share: the provider, which view is showing,
// and the one search field. Each layout is a file of its own (TwoPaneMenu,
// GridMenu, ListMenu), built from the parts beside them.

import QtQuick
import QtQuick.Controls
import qs.domain.launcher.providers
import qs.domain.system
import qs.domain.theme

Item {
    id: menu

    required property BuiltinProvider provider
    readonly property string layout: menu.provider.layout

    // Which part of the menu is showing: "home" (pinned and recent), a rail
    // category, "everything", or "recent".
    property string view: "home"
    readonly property bool searching: menu.provider.query.length > 0

    implicitWidth: menu.layout === "twopane" ? 928 : menu.layout === "grid" ? 496 : 420
    implicitHeight: menu.layout === "twopane" ? 668 : menu.layout === "grid" ? 540 : 600

    focus: true
    Keys.forwardTo: [search]

    // The machine's numbers are read only while the two-pane menu, which
    // shows them, is open.
    readonly property bool twopane: menu.layout === "twopane"
    property bool watching: false

    function watchStats(on) {
        if (on !== menu.watching) {
            menu.watching = on;
            SystemStats.watch(on);
        }
    }

    onTwopaneChanged: menu.watchStats(menu.twopane)
    Component.onDestruction: menu.watchStats(false)
    Component.onCompleted: {
        menu.watchStats(menu.twopane);
        Qt.callLater(() => search.forceActiveFocus());
    }

    // The field: a real one, typed into from anywhere in the menu. Each
    // layout's SearchBox takes it in.
    TextField {
        id: search
        anchors.fill: parent
        focus: true
        color: Theme.fg
        selectionColor: Theme.accC
        selectedTextColor: Theme.accCFg
        font.family: Theme.fontFamily
        font.pixelSize: 15
        background: null
        leftPadding: 2
        text: menu.provider.query

        onTextChanged: {
            menu.provider.query = text;
            menu.provider.selectedIndex = 0;
        }

        Keys.onDownPressed: menu.provider.moveSelection(1)
        Keys.onUpPressed: menu.provider.moveSelection(-1)
        Keys.onReturnPressed: menu.provider.activateSelected()
        Keys.onEnterPressed: menu.provider.activateSelected()
        Keys.onEscapePressed: {
            if (text.length > 0)
                text = "";
            else
                menu.provider.close();
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: menu.layout === "grid" ? gridLayout : menu.layout === "list" ? listLayout : twoPaneLayout
    }

    Component {
        id: twoPaneLayout

        TwoPaneMenu {
            provider: menu.provider
            field: search
            view: menu.view
            searching: menu.searching
            onViewChosen: chosen => menu.view = chosen
        }
    }

    Component {
        id: gridLayout

        GridMenu {
            provider: menu.provider
            field: search
            view: menu.view
            searching: menu.searching
            onViewChosen: chosen => menu.view = chosen
        }
    }

    Component {
        id: listLayout

        ListMenu {
            provider: menu.provider
            field: search
            searching: menu.searching
        }
    }
}
