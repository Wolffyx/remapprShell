/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What the keyboard is doing, and what is playing: Caps Lock, the keyboard
    layout, and the media players.

    Plasma's own objects, each made once. The greeter draws one view per
    screen from one QML engine (see PasswordSync), so a singleton is one Caps
    Lock, one list of layouts and one list of players for every screen and
    every part of every style -- where each part used to make its own, and a
    style drawing the warning under its field and the layout in its corner
    held two of each.

    Only the modules the package already imports, and nothing that can fail
    to load: a part every style shares that did not load would take the glass
    fallback down with the style that failed.
*/
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.workspace.keyboardlayout as Layouts

QtObject {
    id: keys

    // --- Caps Lock --------------------------------------------------------

    readonly property KeyboardIndicator.KeyState capsLock: KeyboardIndicator.KeyState {
        key: Qt.Key_CapsLock
    }

    readonly property bool caps: keys.capsLock.locked

    // --- the layout -------------------------------------------------------

    readonly property Layouts.KeyboardLayout keyboardLayout: Layouts.KeyboardLayout {}

    // Every layout the person set up, in their order, and the one typed in
    // now -- or null before the list has arrived.
    readonly property var layouts: keys.keyboardLayout.layoutsList
    readonly property var current: keys.layouts[keys.keyboardLayout.layout] ?? null
    readonly property string layoutName: keys.current?.longName ?? ""

    // A password typed on the wrong layout is refused as surely as a wrong
    // one, and counts against the account the same. The first layout in the
    // list is the one a person set up as theirs; any other is worth saying.
    readonly property bool otherLayout: keys.layouts.length > 1 && keys.keyboardLayout.layout > 0

    function nextLayout(): void {
        if (keys.layouts.length > 1)
            keys.keyboardLayout.switchToNextLayout();
    }

    // --- what is playing --------------------------------------------------

    // The players Plasma's own lock screen would show, which is the module
    // it uses: a player it can control is one these can control too.
    readonly property Mpris.MultiplexerModel players: Mpris.MultiplexerModel {}

    component Player: QtObject {
        required property var model
    }

    readonly property Instantiator playerRow: Instantiator {
        model: keys.players
        delegate: Player {}
    }

    // The one player Plasma's lock screen would control, or null.
    readonly property var player: keys.playerRow.count > 0
        ? (keys.playerRow.objectAt(0) as Player)?.model ?? null : null
}
