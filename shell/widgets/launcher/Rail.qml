pragma ComponentBehavior: Bound

// The two-pane start menu's rail: a button per category down it, and recent
// files at its foot. Choosing one clears the search, which would otherwise be
// showing instead of the view chosen.
//
// A column of buttons, not a panel of its own. It used to be filled a shade
// lighter than the menu and rounded on its left, which put a second background
// inside the popout's -- and, where its corner radius did not land exactly on
// the card's, left the menu's bottom-left corner looking square. One surface,
// a hairline where one part ends and the next begins.

import QtQuick
import QtQuick.Controls
import qs.domain.launcher.apps
import qs.domain.theme

Item {
    id: rail

    // The menu's field, cleared on the way to another view.
    required property TextField field
    // Which view is showing: "home", a category, "everything" or "recent".
    required property string view
    signal viewChosen(string chosen)

    function choose(chosen) {
        rail.field.text = "";
        rail.viewChosen(chosen);
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.out
    }

    Column {
        y: 14
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        Repeater {
            model: Apps.categories

            RailButton {
                id: category
                required property var modelData
                glyph: category.modelData.glyph
                current: (category.modelData.id === "all" && rail.view === "home")
                         || rail.view === category.modelData.id
                onChosen: rail.choose(category.modelData.id === "all" ? "home" : category.modelData.id)
            }
        }
    }

    // Recent files, at the foot of the rail. Its glyph stays the one size,
    // current or not, as it always has.
    RailButton {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        glyph: "history"
        glyphSize: 22
        current: rail.view === "recent"
        onChosen: rail.choose("recent")
    }
}
